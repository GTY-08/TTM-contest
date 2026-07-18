-- Premium raid completion rewards and member-only live location sharing.

alter table public.point_transactions
  drop constraint if exists point_transactions_reason_check;
alter table public.point_transactions
  add constraint point_transactions_reason_check
  check (reason in (
    'raid_attendance',
    'raid_hosting',
    'raid_completion_bonus',
    'raid_absence_penalty',
    'reward_redemption',
    'adjustment'
  )) not valid;

create unique index if not exists point_transactions_raid_completion_uidx
  on public.point_transactions(user_id, raid_id, reason)
  where raid_id is not null
    and reason in ('raid_completion_bonus', 'raid_absence_penalty');

create table if not exists public.raid_participant_locations (
  raid_id uuid not null references public.raids(id) on delete cascade,
  participant_id uuid not null
    references public.raid_participants(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  accuracy_m double precision check (
    accuracy_m is null or accuracy_m between 0 and 1000
  ),
  captured_at timestamptz not null,
  updated_at timestamptz not null default now(),
  primary key (raid_id, user_id),
  unique (participant_id)
);

create index if not exists raid_participant_locations_fresh_idx
  on public.raid_participant_locations(raid_id, captured_at desc);

alter table public.raid_participant_locations enable row level security;
revoke all on table public.raid_participant_locations
  from public, anon, authenticated;
grant select on table public.raid_participant_locations to authenticated;

drop policy if exists raid_participant_locations_member_select
  on public.raid_participant_locations;
create policy raid_participant_locations_member_select
on public.raid_participant_locations
for select
to authenticated
using (
  public.is_raid_member(raid_id, (select auth.uid()))
  and exists (
    select 1
    from public.raid_participants participant
    where participant.id = raid_participant_locations.participant_id
      and participant.raid_id = raid_participant_locations.raid_id
      and participant.user_id = raid_participant_locations.user_id
      and participant.status = 'approved'
  )
  and exists (
    select 1
    from public.raids raid
    where raid.id = raid_participant_locations.raid_id
      and raid.status not in ('completed', 'cancelled')
  )
);

create or replace function public.update_my_raid_location(
  p_raid_id uuid,
  p_lat double precision,
  p_lng double precision,
  p_accuracy_m double precision,
  p_captured_at timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_participant public.raid_participants%rowtype;
  v_raid public.raids%rowtype;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_lat is null or p_lng is null
    or p_lat not between -90 and 90
    or p_lng not between -180 and 180
    or (p_lat = 0 and p_lng = 0) then
    return jsonb_build_object('ok', false, 'reason', 'invalid_location');
  end if;
  if p_accuracy_m is null or p_accuracy_m < 0 or p_accuracy_m > 500 then
    return jsonb_build_object('ok', false, 'reason', 'inaccurate_location');
  end if;
  if p_captured_at is null
    or p_captured_at < now() - interval '2 minutes'
    or p_captured_at > now() + interval '30 seconds' then
    return jsonb_build_object('ok', false, 'reason', 'stale_location');
  end if;

  select participant.* into v_participant
  from public.raid_participants participant
  where participant.raid_id = p_raid_id
    and participant.user_id = v_uid
    and participant.status = 'approved';
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'not_raid_member');
  end if;

  select raid.* into v_raid
  from public.raids raid
  where raid.id = p_raid_id;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'raid_not_found');
  end if;
  if v_raid.status in ('completed', 'cancelled') then
    return jsonb_build_object('ok', false, 'reason', 'raid_closed');
  end if;

  insert into public.raid_participant_locations(
    raid_id,
    participant_id,
    user_id,
    latitude,
    longitude,
    accuracy_m,
    captured_at,
    updated_at
  ) values (
    p_raid_id,
    v_participant.id,
    v_uid,
    p_lat,
    p_lng,
    p_accuracy_m,
    p_captured_at,
    now()
  )
  on conflict (raid_id, user_id) do update
  set participant_id = excluded.participant_id,
      latitude = excluded.latitude,
      longitude = excluded.longitude,
      accuracy_m = excluded.accuracy_m,
      captured_at = excluded.captured_at,
      updated_at = now();

  return jsonb_build_object('ok', true);
end;
$$;

create or replace function public.finalize_raid(p_raid_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_uid uuid := auth.uid();
  v_raid public.raids%rowtype;
  v_participant public.raid_participants%rowtype;
  v_wallet public.user_point_wallets%rowtype;
  v_hold record;
  v_balance numeric;
  v_total numeric := 0;
  v_host_points int := 0;
  v_adjustment int := 0;
  v_bonus_total int := 0;
  v_penalty_total int := 0;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into v_raid
  from public.raids
  where id = p_raid_id
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'raid_not_found');
  end if;
  if v_raid.status = 'completed' then
    return jsonb_build_object('ok', false, 'reason', 'already_completed');
  end if;
  if v_raid.status = 'cancelled' then
    return jsonb_build_object('ok', false, 'reason', 'raid_cancelled');
  end if;
  if v_raid.source = 'premium'
    and v_raid.organizer_id <> v_uid
    and not public.is_admin() then
    return jsonb_build_object('ok', false, 'reason', 'not_organizer');
  end if;
  if now() < v_raid.starts_at + make_interval(mins => v_raid.duration_minutes) then
    return jsonb_build_object('ok', false, 'reason', 'raid_not_finished');
  end if;
  if exists (
    select 1
    from public.raid_participants
    where raid_id = p_raid_id
      and role = 'member'
      and status = 'approved'
      and attendance_status in ('pending', 'disputed')
  ) then
    return jsonb_build_object('ok', false, 'reason', 'attendance_pending');
  end if;

  for v_participant in
    select participant.*
    from public.raid_participants participant
    where participant.raid_id = p_raid_id
      and participant.role = 'member'
      and participant.status = 'approved'
    order by participant.created_at
    for update
  loop
    v_adjustment := 0;
    perform private.ensure_point_wallet(v_participant.user_id);
    select * into v_wallet
    from public.user_point_wallets
    where user_id = v_participant.user_id
    for update;

    if v_participant.attendance_status in ('present', 'late', 'left_early')
      and not exists (
        select 1 from public.point_transactions
        where user_id = v_participant.user_id
          and raid_id = p_raid_id
          and reason = 'raid_completion_bonus'
      ) then
      v_adjustment := 100;
      update public.user_point_wallets
      set available_points = available_points + v_adjustment,
          lifetime_points = lifetime_points + v_adjustment,
          updated_at = now()
      where user_id = v_participant.user_id
      returning * into v_wallet;
      insert into public.point_transactions(
        user_id, raid_id, direction, reason, amount,
        available_after, lifetime_after, memo
      ) values (
        v_participant.user_id, p_raid_id, 'credit',
        'raid_completion_bonus', v_adjustment,
        v_wallet.available_points, v_wallet.lifetime_points,
        '레이드 완료 참여 보너스'
      );
      v_bonus_total := v_bonus_total + v_adjustment;
    elsif v_participant.attendance_status = 'absent'
      and not exists (
        select 1 from public.point_transactions
        where user_id = v_participant.user_id
          and raid_id = p_raid_id
          and reason = 'raid_absence_penalty'
      ) then
      v_adjustment := least(
        100,
        v_wallet.available_points,
        v_wallet.lifetime_points
      );
      if v_adjustment > 0 then
        update public.user_point_wallets
        set available_points = available_points - v_adjustment,
            lifetime_points = lifetime_points - v_adjustment,
            updated_at = now()
        where user_id = v_participant.user_id
        returning * into v_wallet;
        insert into public.point_transactions(
          user_id, raid_id, direction, reason, amount,
          available_after, lifetime_after, memo
        ) values (
          v_participant.user_id, p_raid_id, 'debit',
          'raid_absence_penalty', v_adjustment,
          v_wallet.available_points, v_wallet.lifetime_points,
          '레이드 불참 감점'
        );
        v_penalty_total := v_penalty_total + v_adjustment;
      end if;
    end if;

    perform private.enqueue_push(
      v_participant.user_id,
      'raid_completed',
      '레이드 완료',
      case
        when v_participant.attendance_status in ('present', 'late', 'left_early')
          then '참여 완료 보너스 100P를 받았어요.'
        when v_adjustment > 0
          then '불참으로 활동 포인트 ' || v_adjustment::text || 'P가 차감됐어요.'
        else '불참으로 기록됐어요. 보유 포인트가 없어 추가 차감은 없어요.'
      end,
      jsonb_build_object(
        'raid_id', p_raid_id,
        'route', '/raid/' || p_raid_id::text
      ),
      'raid-completed-' || p_raid_id::text || '-' || v_participant.user_id::text,
      'high'
    );
  end loop;

  if v_raid.organizer_id is not null then
    perform private.ensure_demo_wallet(v_raid.organizer_id);
    for v_hold in
      select *
      from public.raid_fee_holds
      where raid_id = p_raid_id and status = 'held'
      for update
    loop
      update public.demo_wallets
      set escrow_hold = greatest(0, escrow_hold - v_hold.amount),
          updated_at = now()
      where user_id = v_hold.payer_id;
      v_total := v_total + v_hold.amount;
      update public.raid_fee_holds
      set status = 'settled', settled_at = now(), updated_at = now()
      where id = v_hold.id;
      update public.raid_participants
      set payment_status = 'settled', updated_at = now()
      where id = v_hold.participant_id;
    end loop;
    if v_total > 0 then
      update public.demo_wallets
      set balance = balance + v_total,
          total_earned = total_earned + v_total,
          updated_at = now()
      where user_id = v_raid.organizer_id
      returning balance into v_balance;
      insert into public.raid_fee_transactions(
        raid_id, user_id, direction, amount, reason, balance_after
      ) values (
        p_raid_id, v_raid.organizer_id, 'credit', v_total,
        'organizer_settlement', v_balance
      );
    end if;
    v_host_points := private.award_raid_points(
      v_raid.organizer_id,
      p_raid_id,
      'raid_hosting'
    );
  end if;

  update public.raids
  set status = 'completed', completed_at = now(), updated_at = now()
  where id = p_raid_id;

  return jsonb_build_object(
    'ok', true,
    'settled_amount', v_total,
    'host_points', v_host_points,
    'participant_bonus_total', v_bonus_total,
    'absence_penalty_total', v_penalty_total
  );
end;
$$;

revoke all on function public.update_my_raid_location(
  uuid, double precision, double precision, double precision, timestamptz
) from public, anon;
grant execute on function public.update_my_raid_location(
  uuid, double precision, double precision, double precision, timestamptz
) to authenticated;

revoke all on function public.finalize_raid(uuid) from public, anon;
grant execute on function public.finalize_raid(uuid) to authenticated;

do $$
begin
  if exists (
    select 1 from pg_publication where pubname = 'supabase_realtime'
  ) then
    begin
      alter publication supabase_realtime
        add table public.raid_participant_locations;
    exception when duplicate_object then
      null;
    end;
  end if;
end;
$$;
