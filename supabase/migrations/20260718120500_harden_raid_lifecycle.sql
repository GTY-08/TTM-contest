-- Harden raid lifecycle authorization and award points only after final completion.

create or replace function public.leave_raid(p_raid_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_uid uuid := auth.uid();
  v_raid public.raids%rowtype;
  v_participant public.raid_participants%rowtype;
  v_hold public.raid_fee_holds%rowtype;
  v_refunded boolean := false;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  select * into v_raid from public.raids where id = p_raid_id for update;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'raid_not_found');
  end if;

  select * into v_participant
  from public.raid_participants
  where raid_id = p_raid_id and user_id = v_uid
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'not_participant');
  end if;
  if v_participant.role = 'organizer' then
    return jsonb_build_object('ok', false, 'reason', 'organizer_must_cancel_raid');
  end if;
  if v_raid.status in ('completed', 'cancelled') or v_raid.starts_at <= now() then
    return jsonb_build_object('ok', false, 'reason', 'raid_already_started');
  end if;

  select * into v_hold
  from public.raid_fee_holds
  where participant_id = v_participant.id and status = 'held'
  for update;

  if found and now() <= coalesce(v_raid.free_cancel_at, v_raid.starts_at) then
    perform private.refund_raid_hold(v_hold.id);
    v_refunded := true;
  end if;

  update public.raid_participants
  set status = 'cancelled', cancelled_at = now(), updated_at = now()
  where id = v_participant.id;

  perform private.refresh_raid_recruitment(p_raid_id);
  return jsonb_build_object('ok', true, 'refunded', v_refunded);
end;
$$;

create or replace function public.record_raid_attendance(
  p_participant_id uuid,
  p_status text
)
returns jsonb
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_uid uuid := auth.uid();
  v_participant public.raid_participants%rowtype;
  v_raid public.raids%rowtype;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_status not in ('present', 'late', 'left_early', 'absent') then
    raise exception 'invalid_attendance_status';
  end if;

  select * into v_participant
  from public.raid_participants
  where id = p_participant_id
  for update;
  if not found or v_participant.role = 'organizer'
    or v_participant.status <> 'approved' then
    return jsonb_build_object('ok', false, 'reason', 'invalid_participant');
  end if;

  select * into v_raid from public.raids
  where id = v_participant.raid_id
  for update;

  if v_raid.organizer_id <> v_uid and not public.is_admin() then
    return jsonb_build_object('ok', false, 'reason', 'not_organizer');
  end if;
  if v_raid.source <> 'premium' then
    return jsonb_build_object('ok', false, 'reason', 'peer_verification_required');
  end if;
  if v_raid.status in ('completed', 'cancelled') then
    return jsonb_build_object('ok', false, 'reason', 'raid_not_active');
  end if;
  if now() < v_raid.starts_at then
    return jsonb_build_object('ok', false, 'reason', 'raid_not_started');
  end if;

  update public.raid_participants
  set attendance_status = p_status, updated_at = now()
  where id = p_participant_id;

  return jsonb_build_object('ok', true, 'points_awarded', 0);
end;
$$;

create or replace function public.cast_attendance_vote(
  p_target_participant_id uuid,
  p_vote text
)
returns jsonb
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_uid uuid := auth.uid();
  v_target public.raid_participants%rowtype;
  v_raid public.raids%rowtype;
  v_responses int;
  v_present int;
  v_absent int;
  v_result text := 'pending';
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_vote not in ('present', 'cannot_confirm', 'absent') then
    raise exception 'invalid_vote';
  end if;

  select * into v_target
  from public.raid_participants
  where id = p_target_participant_id
  for update;
  if not found or v_target.role = 'organizer' or v_target.status <> 'approved' then
    return jsonb_build_object('ok', false, 'reason', 'invalid_target');
  end if;
  if v_target.user_id = v_uid then
    return jsonb_build_object('ok', false, 'reason', 'self_vote_forbidden');
  end if;

  select * into v_raid from public.raids where id = v_target.raid_id for update;
  if v_raid.status in ('completed', 'cancelled') then
    return jsonb_build_object('ok', false, 'reason', 'raid_not_active');
  end if;
  if not public.is_raid_member(v_raid.id, v_uid) then
    return jsonb_build_object('ok', false, 'reason', 'not_raid_member');
  end if;
  if v_raid.source = 'premium' and v_target.attendance_status <> 'disputed' then
    return jsonb_build_object('ok', false, 'reason', 'appeal_required');
  end if;
  if now() < v_raid.starts_at + make_interval(mins => v_raid.duration_minutes) then
    return jsonb_build_object('ok', false, 'reason', 'raid_not_finished');
  end if;

  insert into public.raid_attendance_votes(
    raid_id, target_participant_id, voter_id, vote
  )
  values (v_raid.id, v_target.id, v_uid, p_vote)
  on conflict (target_participant_id, voter_id)
  do update set vote = excluded.vote, updated_at = now();

  select count(*),
         count(*) filter (where vote = 'present'),
         count(*) filter (where vote = 'absent')
  into v_responses, v_present, v_absent
  from public.raid_attendance_votes
  where target_participant_id = v_target.id;

  if v_responses >= 2 and v_present > (v_present + v_absent) / 2.0 then
    v_result := 'present';
  elsif v_responses >= 2 and v_absent > (v_present + v_absent) / 2.0 then
    v_result := 'absent';
  end if;

  if v_result <> 'pending' then
    update public.raid_participants
    set attendance_status = v_result, updated_at = now()
    where id = v_target.id;
  end if;

  return jsonb_build_object(
    'ok', true,
    'result', v_result,
    'responses', v_responses,
    'present_votes', v_present,
    'absent_votes', v_absent,
    'points_awarded', 0
  );
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
  v_hold record;
  v_participant record;
  v_balance numeric;
  v_total numeric := 0;
  v_host_points int := 0;
  v_participant_points int := 0;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  select * into v_raid
  from public.raids
  where id = p_raid_id
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'raid_not_found');
  end if;
  if v_raid.status not in ('confirmed', 'in_progress', 'attendance') then
    return jsonb_build_object('ok', false, 'reason', 'raid_not_finalizable');
  end if;

  if v_raid.source = 'premium' then
    if v_raid.organizer_id <> v_uid and not public.is_admin() then
      return jsonb_build_object('ok', false, 'reason', 'not_organizer');
    end if;
  elsif not public.is_raid_member(v_raid.id, v_uid) and not public.is_admin() then
    return jsonb_build_object('ok', false, 'reason', 'not_raid_member');
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
      )
      values (
        p_raid_id, v_raid.organizer_id, 'credit', v_total,
        'organizer_settlement', v_balance
      );
    end if;
  end if;

  for v_participant in
    select user_id
    from public.raid_participants
    where raid_id = p_raid_id
      and role = 'member'
      and status = 'approved'
      and attendance_status in ('present', 'late', 'left_early')
  loop
    v_participant_points := v_participant_points
      + private.award_raid_points(
          v_participant.user_id,
          p_raid_id,
          'raid_attendance'
        );
  end loop;

  if v_raid.organizer_id is not null then
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
    'participant_points', v_participant_points,
    'host_points', v_host_points
  );
end;
$$;

create or replace function public.cancel_raid(
  p_raid_id uuid,
  p_reason text default '운영 사유'
)
returns jsonb
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_uid uuid := auth.uid();
  v_raid public.raids%rowtype;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  select * into v_raid
  from public.raids
  where id = p_raid_id
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'raid_not_found');
  end if;
  if v_raid.status in ('completed', 'cancelled') then
    return jsonb_build_object('ok', false, 'reason', 'raid_not_cancellable');
  end if;

  if v_raid.source = 'auto' then
    if not public.is_admin() then
      return jsonb_build_object('ok', false, 'reason', 'admin_required');
    end if;
  elsif v_raid.organizer_id <> v_uid and not public.is_admin() then
    return jsonb_build_object('ok', false, 'reason', 'not_organizer');
  end if;

  perform private.cancel_raid_internal(
    p_raid_id,
    coalesce(nullif(trim(coalesce(p_reason, '')), ''), '운영 사유')
  );
  return jsonb_build_object('ok', true);
end;
$$;

alter function public.admin_list_exercise_venues() volatile;
alter function public.get_raid_detail(uuid) volatile;

