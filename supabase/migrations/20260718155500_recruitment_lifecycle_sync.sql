-- Keep urgent recruitment synchronized with normal joins, reviews, and leaves.

create or replace function private.refresh_raid_recruitment(p_raid_id uuid)
returns void
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_raid public.raids%rowtype;
  v_count int;
  v_filled_campaign_ids uuid[];
begin
  select * into v_raid
  from public.raids
  where id = p_raid_id
  for update;

  if not found then
    return;
  end if;

  select count(*) into v_count
  from public.raid_participants
  where raid_id = p_raid_id and status = 'approved';

  if v_raid.status in ('scheduled', 'recruiting', 'confirmed') then
    update public.raids
    set status = case
          when v_count >= v_raid.min_participants then 'confirmed'
          else 'recruiting'
        end,
        updated_at = now()
    where id = p_raid_id;
  end if;

  with filled as (
    update public.raid_recruitment_campaigns
    set status = 'filled', updated_at = now()
    where raid_id = p_raid_id
      and status = 'recruiting'
      and v_count >= target_participants
    returning id
  )
  select coalesce(array_agg(id), array[]::uuid[])
  into v_filled_campaign_ids
  from filled;

  if cardinality(v_filled_campaign_ids) > 0 then
    update public.raid_recruitment_offers
    set status = 'expired'
    where campaign_id = any(v_filled_campaign_ids)
      and status = 'pending';
  end if;

  if v_raid.status in ('cancelled', 'completed', 'in_progress', 'attendance') then
    with closed as (
      update public.raid_recruitment_campaigns
      set status = 'closed', updated_at = now()
      where raid_id = p_raid_id and status = 'recruiting'
      returning id
    )
    update public.raid_recruitment_offers
    set status = 'expired'
    where campaign_id in (select id from closed)
      and status = 'pending';
  end if;
end;
$$;

create or replace function private.start_recruitment_after_participant_leave()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_raid public.raids%rowtype;
  v_count int;
begin
  if old.status <> 'approved' or new.status = 'approved' then
    return new;
  end if;

  select * into v_raid
  from public.raids
  where id = new.raid_id;

  if not found
    or v_raid.status not in ('recruiting', 'confirmed')
    or v_raid.starts_at <= now() then
    return new;
  end if;

  select count(*) into v_count
  from public.raid_participants
  where raid_id = v_raid.id and status = 'approved';

  if v_count < v_raid.min_participants then
    insert into public.raid_recruitment_campaigns(
      raid_id,
      created_by,
      fill_goal,
      target_participants,
      approval_mode,
      next_expand_at,
      expires_at
    ) values (
      v_raid.id,
      v_raid.organizer_id,
      'minimum',
      v_raid.min_participants,
      case when v_raid.participation_fee = 0 then 'instant' else 'manual' end,
      now(),
      v_raid.starts_at
    )
    on conflict (raid_id) where status = 'recruiting'
    do update set
      target_participants = excluded.target_participants,
      next_expand_at = now(),
      updated_at = now();
  end if;

  return new;
end;
$$;

drop trigger if exists raid_participant_leave_starts_recruitment
  on public.raid_participants;
create trigger raid_participant_leave_starts_recruitment
after update of status on public.raid_participants
for each row
execute function private.start_recruitment_after_participant_leave();

create or replace function public.list_my_raid_recruitment_offers()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', o.id,
      'campaign_id', o.campaign_id,
      'raid_id', r.id,
      'distance_m', o.distance_m,
      'status', o.status,
      'expires_at', o.expires_at,
      'title', r.title,
      'exercise_type', r.exercise_type,
      'starts_at', r.starts_at,
      'participation_fee', r.participation_fee,
      'venue_name', v.name,
      'approval_mode', c.approval_mode
    ) order by o.created_at desc)
    from public.raid_recruitment_offers o
    join public.raid_recruitment_campaigns c on c.id = o.campaign_id
    join public.raids r on r.id = c.raid_id
    join public.exercise_venues v on v.id = r.venue_id
    where o.user_id = v_uid
      and o.status = 'pending'
      and o.expires_at > now()
      and c.status = 'recruiting'
      and r.status in ('recruiting', 'confirmed')
      and r.starts_at > now()
  ), '[]'::jsonb);
end;
$$;

revoke all on function private.refresh_raid_recruitment(uuid)
  from public, anon, authenticated;
revoke all on function private.start_recruitment_after_participant_leave()
  from public, anon, authenticated;
revoke all on function public.list_my_raid_recruitment_offers()
  from public, anon;
grant execute on function public.list_my_raid_recruitment_offers()
  to authenticated;
