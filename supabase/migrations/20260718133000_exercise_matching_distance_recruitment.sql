-- Exercise discovery, foreground-distance validation, 1:1 quick matching,
-- and urgent raid recruitment. Legacy errand matching tables stay untouched.

create extension if not exists postgis;

create table if not exists public.user_exercise_preferences (
  user_id uuid primary key references public.users(id) on delete cascade,
  activity_geo geography(point, 4326),
  activity_label text,
  preferred_exercises text[] not null default array['walking']::text[],
  fitness_level text not null default 'beginner'
    check (fitness_level in ('beginner', 'intermediate', 'advanced')),
  available_days smallint[] not null default array[1,2,3,4,5,6,7]::smallint[],
  available_start time not null default '06:00',
  available_end time not null default '22:00',
  max_distance_m int not null default 5000
    check (max_distance_m in (1000, 3000, 5000)),
  updated_at timestamptz not null default now(),
  check (cardinality(preferred_exercises) > 0),
  check (cardinality(available_days) > 0)
);

create index if not exists user_exercise_preferences_geo_idx
  on public.user_exercise_preferences using gist(activity_geo);

create table if not exists public.exercise_quick_matches (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.users(id) on delete cascade,
  matched_user_id uuid references public.users(id) on delete set null,
  meeting_source text not null check (meeting_source in ('current', 'venue')),
  meeting_venue_id uuid references public.exercise_venues(id) on delete restrict,
  meeting_geo geography(point, 4326) not null,
  meeting_label text not null,
  exercise_type text not null,
  duration_minutes int not null check (duration_minutes between 20 and 240),
  intensity text not null default 'medium'
    check (intensity in ('low', 'medium', 'high')),
  partner_level_pref text not null default 'similar'
    check (partner_level_pref in ('any', 'similar', 'beginner')),
  max_distance_m int not null check (max_distance_m in (1000, 3000, 5000)),
  starts_at timestamptz not null default now(),
  ends_at timestamptz not null,
  status text not null default 'searching'
    check (status in ('searching', 'matched', 'in_progress', 'completed', 'cancelled', 'expired', 'failed')),
  current_stage int not null default 0 check (current_stage between 0 and 10),
  next_advance_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '80 seconds'),
  matched_at timestamptz,
  completed_at timestamptz,
  cancelled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((meeting_source = 'venue') = (meeting_venue_id is not null)),
  check (ends_at > starts_at),
  check (matched_user_id is null or matched_user_id <> requester_id)
);

create unique index if not exists exercise_quick_matches_requester_active_uidx
  on public.exercise_quick_matches(requester_id)
  where status in ('searching', 'matched', 'in_progress');
create index if not exists exercise_quick_matches_due_idx
  on public.exercise_quick_matches(status, next_advance_at)
  where status = 'searching';
create index if not exists exercise_quick_matches_geo_idx
  on public.exercise_quick_matches using gist(meeting_geo);

create table if not exists public.exercise_match_offers (
  id uuid primary key default gen_random_uuid(),
  quick_match_id uuid not null references public.exercise_quick_matches(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  distance_m int not null check (distance_m >= 0),
  match_score numeric(8,2) not null default 0,
  stage int not null check (stage between 1 and 10),
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'declined', 'expired')),
  expires_at timestamptz not null,
  responded_at timestamptz,
  created_at timestamptz not null default now(),
  unique (quick_match_id, user_id)
);

create index if not exists exercise_match_offers_user_idx
  on public.exercise_match_offers(user_id, status, expires_at);

create table if not exists public.exercise_match_messages (
  id uuid primary key default gen_random_uuid(),
  quick_match_id uuid not null references public.exercise_quick_matches(id) on delete cascade,
  sender_id uuid not null references public.users(id) on delete cascade,
  content text not null check (length(trim(content)) between 1 and 2000),
  created_at timestamptz not null default now()
);

create index if not exists exercise_match_messages_match_idx
  on public.exercise_match_messages(quick_match_id, created_at);

create table if not exists public.raid_recruitment_campaigns (
  id uuid primary key default gen_random_uuid(),
  raid_id uuid not null references public.raids(id) on delete cascade,
  created_by uuid references public.users(id) on delete cascade,
  fill_goal text not null default 'minimum' check (fill_goal in ('minimum', 'maximum')),
  target_participants int not null check (target_participants >= 1),
  approval_mode text not null default 'manual' check (approval_mode in ('instant', 'manual')),
  status text not null default 'recruiting'
    check (status in ('recruiting', 'filled', 'closed', 'expired')),
  current_stage int not null default 0 check (current_stage between 0 and 3),
  next_expand_at timestamptz not null default now(),
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists raid_recruitment_campaigns_active_uidx
  on public.raid_recruitment_campaigns(raid_id)
  where status = 'recruiting';
create index if not exists raid_recruitment_campaigns_due_idx
  on public.raid_recruitment_campaigns(status, next_expand_at)
  where status = 'recruiting';

create table if not exists public.raid_recruitment_offers (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references public.raid_recruitment_campaigns(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  distance_m int,
  match_score numeric(8,2) not null default 0,
  stage int not null check (stage between 0 and 3),
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'declined', 'expired')),
  expires_at timestamptz not null,
  responded_at timestamptz,
  created_at timestamptz not null default now(),
  unique (campaign_id, user_id)
);

create index if not exists raid_recruitment_offers_user_idx
  on public.raid_recruitment_offers(user_id, status, expires_at);

alter table public.raids
  add column if not exists demand_score numeric(10,2),
  add column if not exists potential_participant_count int,
  add column if not exists generation_basis text;

alter table public.user_exercise_preferences enable row level security;
alter table public.exercise_quick_matches enable row level security;
alter table public.exercise_match_offers enable row level security;
alter table public.exercise_match_messages enable row level security;
alter table public.raid_recruitment_campaigns enable row level security;
alter table public.raid_recruitment_offers enable row level security;

revoke all on table public.user_exercise_preferences,
  public.exercise_quick_matches, public.exercise_match_offers,
  public.exercise_match_messages, public.raid_recruitment_campaigns,
  public.raid_recruitment_offers from anon, authenticated;

grant select on table public.user_exercise_preferences to authenticated;
grant select on table public.exercise_quick_matches, public.exercise_match_offers,
  public.exercise_match_messages, public.raid_recruitment_campaigns,
  public.raid_recruitment_offers to authenticated;
grant insert on table public.exercise_match_messages to authenticated;

drop policy if exists user_exercise_preferences_select on public.user_exercise_preferences;
create policy user_exercise_preferences_select on public.user_exercise_preferences
  for select to authenticated using (user_id = auth.uid());

drop policy if exists exercise_quick_matches_select on public.exercise_quick_matches;
create policy exercise_quick_matches_select on public.exercise_quick_matches
  for select to authenticated using (
    requester_id = auth.uid() or matched_user_id = auth.uid()
    or exists (
      select 1 from public.exercise_match_offers o
      where o.quick_match_id = exercise_quick_matches.id and o.user_id = auth.uid()
    )
  );

drop policy if exists exercise_match_offers_select on public.exercise_match_offers;
create policy exercise_match_offers_select on public.exercise_match_offers
  for select to authenticated using (
    user_id = auth.uid() or exists (
      select 1 from public.exercise_quick_matches q
      where q.id = exercise_match_offers.quick_match_id and q.requester_id = auth.uid()
    )
  );

drop policy if exists exercise_match_messages_select on public.exercise_match_messages;
create policy exercise_match_messages_select on public.exercise_match_messages
  for select to authenticated using (
    exists (
      select 1 from public.exercise_quick_matches q
      where q.id = exercise_match_messages.quick_match_id
        and q.status in ('matched', 'in_progress', 'completed')
        and auth.uid() in (q.requester_id, q.matched_user_id)
    )
  );

drop policy if exists exercise_match_messages_insert on public.exercise_match_messages;
create policy exercise_match_messages_insert on public.exercise_match_messages
  for insert to authenticated with check (
    sender_id = auth.uid() and exists (
      select 1 from public.exercise_quick_matches q
      where q.id = exercise_match_messages.quick_match_id
        and q.status in ('matched', 'in_progress')
        and auth.uid() in (q.requester_id, q.matched_user_id)
    )
  );

drop policy if exists raid_recruitment_campaigns_select on public.raid_recruitment_campaigns;
create policy raid_recruitment_campaigns_select on public.raid_recruitment_campaigns
  for select to authenticated using (
    created_by = auth.uid()
    or exists (select 1 from public.raid_recruitment_offers o where o.campaign_id = raid_recruitment_campaigns.id and o.user_id = auth.uid())
    or public.is_admin()
  );

drop policy if exists raid_recruitment_offers_select on public.raid_recruitment_offers;
create policy raid_recruitment_offers_select on public.raid_recruitment_offers
  for select to authenticated using (
    user_id = auth.uid()
    or exists (select 1 from public.raid_recruitment_campaigns c where c.id = raid_recruitment_offers.campaign_id and c.created_by = auth.uid())
    or public.is_admin()
  );

create or replace function private.exercise_location_reason(
  p_lat double precision,
  p_lng double precision,
  p_accuracy_m double precision,
  p_captured_at timestamptz
)
returns text
language sql
stable
set search_path = public
as $$
  select case
    when p_lat is null or p_lng is null or p_captured_at is null then 'location_required'
    when p_lat not between -90 and 90 or p_lng not between -180 and 180 then 'invalid_location'
    when p_accuracy_m is null or p_accuracy_m < 0 or p_accuracy_m > 200 then 'inaccurate_location'
    when p_captured_at < now() - interval '2 minutes' or p_captured_at > now() + interval '1 minute' then 'stale_location'
    else null
  end;
$$;

create or replace function private.exercise_schedule_conflict(
  p_user_id uuid,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_exclude_raid_id uuid default null,
  p_exclude_quick_match_id uuid default null
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.raid_participants p
    join public.raids r on r.id = p.raid_id
    where p.user_id = p_user_id
      and p.status = 'approved'
      and r.status not in ('completed', 'cancelled')
      and (p_exclude_raid_id is null or r.id <> p_exclude_raid_id)
      and tstzrange(r.starts_at, r.starts_at + make_interval(mins => r.duration_minutes), '[)')
          && tstzrange(p_starts_at, p_ends_at, '[)')
  ) or exists (
    select 1
    from public.exercise_quick_matches q
    where q.status in ('matched', 'in_progress')
      and p_user_id in (q.requester_id, q.matched_user_id)
      and (p_exclude_quick_match_id is null or q.id <> p_exclude_quick_match_id)
      and tstzrange(q.starts_at, q.ends_at, '[)') && tstzrange(p_starts_at, p_ends_at, '[)')
  );
$$;

create or replace function private.enforce_raid_schedule_conflict()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
declare v_raid public.raids%rowtype;
begin
  if new.status <> 'approved'
    or (tg_op = 'UPDATE' and old.status = 'approved') then
    return new;
  end if;
  select * into v_raid from public.raids where id = new.raid_id;
  if private.exercise_schedule_conflict(
    new.user_id, v_raid.starts_at,
    v_raid.starts_at + make_interval(mins => v_raid.duration_minutes),
    new.raid_id, null
  ) then
    raise exception 'schedule_conflict';
  end if;
  return new;
end;
$$;

drop trigger if exists raid_participants_schedule_conflict on public.raid_participants;
create trigger raid_participants_schedule_conflict
before insert or update of status on public.raid_participants
for each row execute function private.enforce_raid_schedule_conflict();

create or replace function public.list_raids(
  p_lat double precision default null,
  p_lng double precision default null,
  p_radius_m int default null,
  p_exercise_type text default null,
  p_fee_type text default null,
  p_limit int default 30,
  p_cursor_starts_at timestamptz default null,
  p_cursor_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare v_uid uuid := auth.uid(); v_origin geography; v_result jsonb;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_lat is not null and p_lng is not null then
    v_origin := st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography;
  end if;
  select coalesce(jsonb_agg(item order by starts_at, id), '[]'::jsonb) into v_result
  from (
    select r.id, r.starts_at, jsonb_build_object(
      'id', r.id, 'source', r.source, 'organizer_id', r.organizer_id,
      'exercise_type', r.exercise_type, 'title', r.title, 'description', r.description,
      'starts_at', r.starts_at, 'duration_minutes', r.duration_minutes,
      'min_participants', r.min_participants, 'max_participants', r.max_participants,
      'participant_count', (select count(*) from public.raid_participants p where p.raid_id = r.id and p.status = 'approved'),
      'intensity', r.intensity, 'beginner_friendly', r.beginner_friendly,
      'participation_fee', r.participation_fee, 'free_cancel_at', r.free_cancel_at,
      'status', r.status,
      'distance_m', case when v_origin is null then null else round(st_distance(v.geo, v_origin))::int end,
      'venue', jsonb_build_object(
        'id', v.id, 'name', v.name, 'address', v.address,
        'latitude', st_y(v.geo::geometry), 'longitude', st_x(v.geo::geometry),
        'supported_exercises', v.supported_exercises
      ),
      'my_participant', (
        select jsonb_build_object('id', me.id, 'status', me.status, 'role', me.role,
          'payment_status', me.payment_status, 'attendance_status', me.attendance_status)
        from public.raid_participants me where me.raid_id = r.id and me.user_id = v_uid
      )
    ) item
    from public.raids r
    join public.exercise_venues v on v.id = r.venue_id
    where r.status in ('scheduled', 'recruiting', 'confirmed', 'in_progress', 'attendance')
      and r.starts_at >= now() - interval '4 hours'
      and (p_exercise_type is null or p_exercise_type = 'all' or r.exercise_type = p_exercise_type)
      and (p_fee_type is null or p_fee_type = 'all'
        or (p_fee_type = 'free' and r.participation_fee = 0)
        or (p_fee_type = 'paid' and r.participation_fee > 0))
      and (p_radius_m is null or v_origin is null or st_dwithin(v.geo, v_origin, greatest(500, least(p_radius_m, 5000))))
      and (p_cursor_starts_at is null or (r.starts_at, r.id) > (p_cursor_starts_at, p_cursor_id))
    order by r.starts_at, r.id
    limit greatest(1, least(coalesce(p_limit, 30), 50))
  ) q;
  return v_result;
end;
$$;

create or replace function public.get_raid_join_eligibility(
  p_raid_id uuid,
  p_lat double precision,
  p_lng double precision,
  p_accuracy_m double precision,
  p_captured_at timestamptz
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, private
as $$
declare v_uid uuid := auth.uid(); v_reason text; v_raid public.raids%rowtype; v_geo geography; v_distance int;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  v_reason := private.exercise_location_reason(p_lat, p_lng, p_accuracy_m, p_captured_at);
  if v_reason is not null then return jsonb_build_object('ok', true, 'eligible', false, 'reason', v_reason, 'max_distance_m', 5000); end if;
  select r.* into v_raid from public.raids r where r.id = p_raid_id;
  if not found then return jsonb_build_object('ok', false, 'eligible', false, 'reason', 'raid_not_found'); end if;
  v_geo := st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography;
  select round(st_distance(v.geo, v_geo))::int into v_distance from public.exercise_venues v where v.id = v_raid.venue_id;
  if v_distance > 5000 then
    return jsonb_build_object('ok', true, 'eligible', false, 'reason', 'outside_raid_range', 'distance_m', v_distance, 'max_distance_m', 5000);
  end if;
  if private.exercise_schedule_conflict(v_uid, v_raid.starts_at,
      v_raid.starts_at + make_interval(mins => v_raid.duration_minutes), v_raid.id, null) then
    return jsonb_build_object('ok', true, 'eligible', false, 'reason', 'schedule_conflict', 'distance_m', v_distance, 'max_distance_m', 5000);
  end if;
  return jsonb_build_object('ok', true, 'eligible', true, 'distance_m', v_distance, 'max_distance_m', 5000);
end;
$$;

create or replace function public.join_free_raid_nearby(
  p_raid_id uuid, p_lat double precision, p_lng double precision,
  p_accuracy_m double precision, p_captured_at timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = public, private
as $$
declare v_check jsonb;
begin
  v_check := public.get_raid_join_eligibility(p_raid_id, p_lat, p_lng, p_accuracy_m, p_captured_at);
  if not coalesce((v_check->>'eligible')::boolean, false) then return v_check; end if;
  return public.join_free_raid(p_raid_id) || jsonb_build_object('distance_m', (v_check->>'distance_m')::int);
exception when raise_exception then
  if sqlerrm = 'schedule_conflict' then return jsonb_build_object('ok', false, 'reason', 'schedule_conflict'); end if;
  raise;
end;
$$;

create or replace function public.apply_premium_raid_nearby(
  p_raid_id uuid, p_message text, p_lat double precision, p_lng double precision,
  p_accuracy_m double precision, p_captured_at timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = public, private
as $$
declare v_check jsonb;
begin
  v_check := public.get_raid_join_eligibility(p_raid_id, p_lat, p_lng, p_accuracy_m, p_captured_at);
  if not coalesce((v_check->>'eligible')::boolean, false) then return v_check; end if;
  return public.apply_premium_raid(p_raid_id, p_message) || jsonb_build_object('distance_m', (v_check->>'distance_m')::int);
end;
$$;

-- The old RPCs do not receive a foreground location and would bypass the 5 km rule.
revoke all on function public.join_free_raid(uuid) from authenticated;
revoke all on function public.apply_premium_raid(uuid, text) from authenticated;

create or replace function public.get_my_exercise_preferences()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare v_uid uuid := auth.uid(); v_result jsonb;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select jsonb_build_object(
    'user_id', p.user_id, 'activity_label', p.activity_label,
    'latitude', case when p.activity_geo is null then null else st_y(p.activity_geo::geometry) end,
    'longitude', case when p.activity_geo is null then null else st_x(p.activity_geo::geometry) end,
    'preferred_exercises', p.preferred_exercises, 'fitness_level', p.fitness_level,
    'available_days', p.available_days, 'available_start', p.available_start,
    'available_end', p.available_end, 'max_distance_m', p.max_distance_m,
    'updated_at', p.updated_at
  ) into v_result from public.user_exercise_preferences p where p.user_id = v_uid;
  return coalesce(v_result, jsonb_build_object(
    'user_id', v_uid, 'preferred_exercises', array['walking']::text[],
    'fitness_level', 'beginner', 'available_days', array[1,2,3,4,5,6,7]::smallint[],
    'available_start', '06:00', 'available_end', '22:00', 'max_distance_m', 5000
  ));
end;
$$;

create or replace function public.upsert_my_exercise_preferences(
  p_activity_label text,
  p_lat double precision,
  p_lng double precision,
  p_preferred_exercises text[],
  p_fitness_level text,
  p_available_days smallint[],
  p_available_start time,
  p_available_end time,
  p_max_distance_m int
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_lat is not null and (p_lng is null or p_lat not between -90 and 90 or p_lng not between -180 and 180) then raise exception 'invalid_location'; end if;
  if p_fitness_level not in ('beginner', 'intermediate', 'advanced') then raise exception 'invalid_fitness_level'; end if;
  if p_max_distance_m not in (1000, 3000, 5000) then raise exception 'invalid_distance'; end if;
  if coalesce(cardinality(p_preferred_exercises), 0) = 0 or coalesce(cardinality(p_available_days), 0) = 0 then raise exception 'invalid_preferences'; end if;
  insert into public.user_exercise_preferences(
    user_id, activity_geo, activity_label, preferred_exercises, fitness_level,
    available_days, available_start, available_end, max_distance_m, updated_at
  ) values (
    v_uid,
    case when p_lat is null then null else st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography end,
    nullif(trim(coalesce(p_activity_label, '')), ''), p_preferred_exercises,
    p_fitness_level, p_available_days, p_available_start, p_available_end,
    p_max_distance_m, now()
  ) on conflict (user_id) do update set
    activity_geo = excluded.activity_geo, activity_label = excluded.activity_label,
    preferred_exercises = excluded.preferred_exercises, fitness_level = excluded.fitness_level,
    available_days = excluded.available_days, available_start = excluded.available_start,
    available_end = excluded.available_end, max_distance_m = excluded.max_distance_m,
    updated_at = now();
  return jsonb_build_object('ok', true);
end;
$$;

create or replace function public.set_exercise_match_availability(
  p_online boolean,
  p_lat double precision,
  p_lng double precision,
  p_accuracy_m double precision,
  p_captured_at timestamptz,
  p_max_distance_m int,
  p_exercise_types text[]
)
returns jsonb
language plpgsql
security definer
set search_path = public, private
as $$
declare v_uid uuid := auth.uid(); v_reason text;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if not p_online then
    update public.worker_presence set status = 'offline', share_location = false,
      online_until = null, updated_at = now() where worker_id = v_uid;
    return jsonb_build_object('ok', true, 'online', false);
  end if;
  v_reason := private.exercise_location_reason(p_lat, p_lng, p_accuracy_m, p_captured_at);
  if v_reason is not null then return jsonb_build_object('ok', false, 'reason', v_reason); end if;
  if p_max_distance_m not in (1000, 3000, 5000) or coalesce(cardinality(p_exercise_types), 0) = 0 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_preferences');
  end if;
  insert into public.worker_presence(
    worker_id, status, geo, max_distance_km, preferred_tags, share_location, updated_at, online_until
  ) values (
    v_uid, 'online', st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography,
    p_max_distance_m / 1000.0, p_exercise_types, true, now(), now() + interval '30 minutes'
  ) on conflict (worker_id) do update set
    status = 'online', geo = excluded.geo, max_distance_km = excluded.max_distance_km,
    preferred_tags = excluded.preferred_tags, share_location = true,
    updated_at = now(), online_until = now() + interval '30 minutes';
  return jsonb_build_object('ok', true, 'online', true, 'online_until', now() + interval '30 minutes');
end;
$$;

create or replace function public.create_exercise_quick_match(
  p_meeting_source text,
  p_venue_id uuid,
  p_meeting_label text,
  p_exercise_type text,
  p_duration_minutes int,
  p_intensity text,
  p_partner_level_pref text,
  p_max_distance_m int,
  p_lat double precision,
  p_lng double precision,
  p_accuracy_m double precision,
  p_captured_at timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_uid uuid := auth.uid(); v_reason text; v_user_geo geography; v_meeting_geo geography;
  v_label text; v_id uuid; v_starts timestamptz := now(); v_ends timestamptz;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  v_reason := private.exercise_location_reason(p_lat, p_lng, p_accuracy_m, p_captured_at);
  if v_reason is not null then return jsonb_build_object('ok', false, 'reason', v_reason); end if;
  if p_meeting_source not in ('current', 'venue') or p_max_distance_m not in (1000, 3000, 5000)
    or p_duration_minutes not between 20 and 240 or p_intensity not in ('low', 'medium', 'high')
    or p_partner_level_pref not in ('any', 'similar', 'beginner') then
    return jsonb_build_object('ok', false, 'reason', 'invalid_match_options');
  end if;
  v_user_geo := st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography;
  if p_meeting_source = 'venue' then
    select geo, name into v_meeting_geo, v_label from public.exercise_venues where id = p_venue_id and is_active;
    if not found then return jsonb_build_object('ok', false, 'reason', 'venue_not_found'); end if;
    if not st_dwithin(v_meeting_geo, v_user_geo, 5000) then return jsonb_build_object('ok', false, 'reason', 'outside_venue_range'); end if;
  else
    v_meeting_geo := v_user_geo;
    v_label := coalesce(nullif(trim(p_meeting_label), ''), '현재 위치 근처');
  end if;
  v_ends := v_starts + make_interval(mins => p_duration_minutes);
  if private.exercise_schedule_conflict(v_uid, v_starts, v_ends, null, null) then
    return jsonb_build_object('ok', false, 'reason', 'schedule_conflict');
  end if;
  if exists (select 1 from public.exercise_quick_matches where requester_id = v_uid and status in ('searching', 'matched', 'in_progress')) then
    return jsonb_build_object('ok', false, 'reason', 'active_match_exists');
  end if;
  insert into public.exercise_quick_matches(
    requester_id, meeting_source, meeting_venue_id, meeting_geo, meeting_label,
    exercise_type, duration_minutes, intensity, partner_level_pref, max_distance_m,
    starts_at, ends_at, next_advance_at, expires_at
  ) values (
    v_uid, p_meeting_source, case when p_meeting_source = 'venue' then p_venue_id else null end,
    v_meeting_geo, v_label, trim(p_exercise_type), p_duration_minutes, p_intensity,
    p_partner_level_pref, p_max_distance_m, v_starts, v_ends, now(), now() + interval '80 seconds'
  ) returning id into v_id;
  execute 'select public.advance_exercise_quick_match($1)' using v_id;
  return jsonb_build_object('ok', true, 'quick_match_id', v_id);
end;
$$;

create or replace function public.advance_exercise_quick_match(p_quick_match_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_q public.exercise_quick_matches%rowtype; v_stage int; v_radius int; v_inserted int := 0;
begin
  select * into v_q from public.exercise_quick_matches where id = p_quick_match_id for update;
  if not found then return jsonb_build_object('ok', false, 'reason', 'match_not_found'); end if;
  if auth.uid() is not null and auth.uid() <> v_q.requester_id and not public.is_admin() then raise exception 'not_allowed'; end if;
  if v_q.status <> 'searching' then return jsonb_build_object('ok', false, 'reason', 'not_searching'); end if;
  if now() >= v_q.expires_at or (v_q.current_stage = 10 and now() >= v_q.next_advance_at) then
    update public.exercise_quick_matches set status = 'failed', updated_at = now() where id = v_q.id;
    update public.exercise_match_offers set status = 'expired' where quick_match_id = v_q.id and status = 'pending';
    return jsonb_build_object('ok', true, 'status', 'failed');
  end if;
  if v_q.current_stage > 0 and now() < v_q.next_advance_at then
    return jsonb_build_object('ok', true, 'status', 'waiting', 'stage', v_q.current_stage, 'next_advance_at', v_q.next_advance_at);
  end if;
  v_stage := least(v_q.current_stage + 1, 10);
  v_radius := ceil(v_q.max_distance_m * v_stage / 10.0)::int;

  with candidates as (
    select wp.worker_id,
      round(st_distance(wp.geo, v_q.meeting_geo))::int distance_m,
      (100 - least(st_distance(wp.geo, v_q.meeting_geo) / 100.0, 50)
       + case when pref.fitness_level = coalesce(req_pref.fitness_level, pref.fitness_level) then 12 else 0 end
       + case when v_q.partner_level_pref = 'beginner' and pref.fitness_level = 'beginner' then 15
              when v_q.partner_level_pref = 'similar' and pref.fitness_level = coalesce(req_pref.fitness_level, pref.fitness_level) then 15 else 0 end
       + coalesce(u.rating, 0) * 2)::numeric(8,2) score
    from public.worker_presence wp
    join public.user_exercise_preferences pref on pref.user_id = wp.worker_id
    left join public.user_exercise_preferences req_pref on req_pref.user_id = v_q.requester_id
    join public.users u on u.id = wp.worker_id
    where wp.worker_id <> v_q.requester_id
      and wp.status = 'online' and wp.share_location and wp.geo is not null
      and wp.updated_at >= now() - interval '10 minutes'
      and (wp.online_until is null or wp.online_until > now())
      and v_q.exercise_type = any(pref.preferred_exercises)
      and extract(isodow from now() at time zone 'Asia/Seoul')::smallint = any(pref.available_days)
      and (now() at time zone 'Asia/Seoul')::time between pref.available_start and pref.available_end
      and st_dwithin(wp.geo, v_q.meeting_geo, least(v_radius, pref.max_distance_m, round(wp.max_distance_km * 1000)::int))
      and not private.exercise_schedule_conflict(wp.worker_id, v_q.starts_at, v_q.ends_at, null, v_q.id)
      and not exists (
        select 1 from public.exercise_quick_matches active
        where active.id <> v_q.id and active.status in ('searching', 'matched', 'in_progress')
          and wp.worker_id in (active.requester_id, active.matched_user_id)
      )
      and not exists (select 1 from public.exercise_match_offers old where old.quick_match_id = v_q.id and old.user_id = wp.worker_id)
    order by score desc, distance_m, wp.worker_id
    limit 5
  ), inserted as (
    insert into public.exercise_match_offers(quick_match_id, user_id, distance_m, match_score, stage, expires_at)
    select v_q.id, c.worker_id, c.distance_m, c.score, v_stage, least(v_q.expires_at, now() + interval '20 seconds')
    from candidates c on conflict (quick_match_id, user_id) do nothing
    returning id, user_id
  ), pushed as (
    insert into public.push_outbox(user_id, push_type, title, body, data, collapse_key)
    select i.user_id, 'exercise_match_offer', '지금 함께 운동할 사람을 찾고 있어요',
      v_q.meeting_label || '에서 ' || v_q.exercise_type || ' 매칭 요청이 도착했어요.',
      jsonb_build_object('quick_match_id', v_q.id, 'offer_id', i.id, 'route', '/quick-match'),
      'exercise-match-' || v_q.id::text
    from inserted i returning 1
  ) select count(*) into v_inserted from pushed;

  update public.exercise_quick_matches
  set current_stage = v_stage,
      next_advance_at = now() + case when v_stage = 10 then interval '20 seconds' else interval '6 seconds' end,
      updated_at = now()
  where id = v_q.id;
  return jsonb_build_object('ok', true, 'status', 'searching', 'stage', v_stage,
    'radius_m', v_radius, 'offers_created', v_inserted);
end;
$$;

create or replace function public.respond_exercise_match_offer(
  p_offer_id uuid,
  p_accept boolean,
  p_lat double precision,
  p_lng double precision,
  p_accuracy_m double precision,
  p_captured_at timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_uid uuid := auth.uid(); v_offer public.exercise_match_offers%rowtype;
  v_q public.exercise_quick_matches%rowtype; v_reason text; v_geo geography; v_distance int;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into v_offer from public.exercise_match_offers where id = p_offer_id for update;
  if not found or v_offer.user_id <> v_uid then return jsonb_build_object('ok', false, 'reason', 'offer_not_found'); end if;
  select * into v_q from public.exercise_quick_matches where id = v_offer.quick_match_id for update;
  if v_offer.status <> 'pending' or v_offer.expires_at <= now() or v_q.status <> 'searching' then
    return jsonb_build_object('ok', false, 'reason', 'offer_expired');
  end if;
  if not p_accept then
    update public.exercise_match_offers set status = 'declined', responded_at = now() where id = v_offer.id;
    return jsonb_build_object('ok', true, 'accepted', false);
  end if;
  v_reason := private.exercise_location_reason(p_lat, p_lng, p_accuracy_m, p_captured_at);
  if v_reason is not null then return jsonb_build_object('ok', false, 'reason', v_reason); end if;
  v_geo := st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography;
  v_distance := round(st_distance(v_geo, v_q.meeting_geo))::int;
  if v_distance > v_q.max_distance_m then return jsonb_build_object('ok', false, 'reason', 'outside_match_range', 'distance_m', v_distance); end if;
  perform pg_advisory_xact_lock(hashtextextended(least(v_uid::text, v_q.requester_id::text), 0));
  perform pg_advisory_xact_lock(hashtextextended(greatest(v_uid::text, v_q.requester_id::text), 0));
  if private.exercise_schedule_conflict(v_uid, v_q.starts_at, v_q.ends_at, null, v_q.id)
    or private.exercise_schedule_conflict(v_q.requester_id, v_q.starts_at, v_q.ends_at, null, v_q.id) then
    return jsonb_build_object('ok', false, 'reason', 'schedule_conflict');
  end if;
  if exists (
    select 1 from public.exercise_quick_matches other
    where other.id <> v_q.id and other.status in ('searching', 'matched', 'in_progress')
      and v_uid in (other.requester_id, other.matched_user_id)
  ) then return jsonb_build_object('ok', false, 'reason', 'active_match_exists'); end if;
  update public.exercise_quick_matches set status = 'matched', matched_user_id = v_uid,
    matched_at = now(), updated_at = now() where id = v_q.id and status = 'searching';
  if not found then return jsonb_build_object('ok', false, 'reason', 'already_matched'); end if;
  update public.exercise_match_offers set status = case when id = v_offer.id then 'accepted' else 'expired' end,
    responded_at = case when id = v_offer.id then now() else responded_at end
    where quick_match_id = v_q.id and status = 'pending';
  insert into public.push_outbox(user_id, push_type, title, body, data, collapse_key)
  values
    (v_q.requester_id, 'exercise_match_matched', '운동 파트너를 찾았어요', v_q.meeting_label || '에서 만나요.',
      jsonb_build_object('quick_match_id', v_q.id, 'route', '/quick-match/' || v_q.id::text), 'exercise-match-result-' || v_q.id::text),
    (v_uid, 'exercise_match_matched', '운동 매칭이 확정됐어요', v_q.meeting_label || '에서 만나요.',
      jsonb_build_object('quick_match_id', v_q.id, 'route', '/quick-match/' || v_q.id::text), 'exercise-match-result-' || v_q.id::text);
  return jsonb_build_object('ok', true, 'accepted', true, 'quick_match_id', v_q.id);
end;
$$;

create or replace function public.get_my_exercise_quick_match()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare v_uid uuid := auth.uid(); v_result jsonb;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select jsonb_build_object(
    'id', q.id, 'requester_id', q.requester_id, 'matched_user_id', q.matched_user_id,
    'meeting_source', q.meeting_source, 'meeting_venue_id', q.meeting_venue_id,
    'meeting_label', q.meeting_label, 'latitude', st_y(q.meeting_geo::geometry),
    'longitude', st_x(q.meeting_geo::geometry), 'exercise_type', q.exercise_type,
    'duration_minutes', q.duration_minutes, 'intensity', q.intensity,
    'partner_level_pref', q.partner_level_pref, 'max_distance_m', q.max_distance_m,
    'starts_at', q.starts_at, 'ends_at', q.ends_at, 'status', q.status,
    'current_stage', q.current_stage, 'next_advance_at', q.next_advance_at,
    'expires_at', q.expires_at, 'matched_at', q.matched_at,
    'partner', case when partner.id is null then null else jsonb_build_object(
      'id', partner.id, 'nickname', partner.nickname, 'profile_image_url', partner.profile_image_url,
      'rating', partner.rating) end
  ) into v_result
  from public.exercise_quick_matches q
  left join public.users partner on partner.id = case when q.requester_id = v_uid then q.matched_user_id else q.requester_id end
  where v_uid in (q.requester_id, q.matched_user_id)
    and q.status in ('searching', 'matched', 'in_progress')
  order by q.created_at desc limit 1;
  return v_result;
end;
$$;

create or replace function public.list_my_exercise_match_offers()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', o.id, 'quick_match_id', o.quick_match_id, 'distance_m', o.distance_m,
      'match_score', o.match_score, 'stage', o.stage, 'status', o.status,
      'expires_at', o.expires_at, 'meeting_label', q.meeting_label,
      'exercise_type', q.exercise_type, 'duration_minutes', q.duration_minutes,
      'intensity', q.intensity, 'requester', jsonb_build_object(
        'id', u.id, 'nickname', u.nickname, 'profile_image_url', u.profile_image_url, 'rating', u.rating)
    ) order by o.created_at desc)
    from public.exercise_match_offers o
    join public.exercise_quick_matches q on q.id = o.quick_match_id
    join public.users u on u.id = q.requester_id
    where o.user_id = v_uid and o.status = 'pending' and o.expires_at > now() and q.status = 'searching'
  ), '[]'::jsonb);
end;
$$;

create or replace function public.cancel_exercise_quick_match(p_quick_match_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare v_uid uuid := auth.uid(); v_q public.exercise_quick_matches%rowtype;
begin
  select * into v_q from public.exercise_quick_matches where id = p_quick_match_id for update;
  if not found or v_uid not in (v_q.requester_id, v_q.matched_user_id) then return jsonb_build_object('ok', false, 'reason', 'not_allowed'); end if;
  if v_q.status not in ('searching', 'matched', 'in_progress') then return jsonb_build_object('ok', false, 'reason', 'already_closed'); end if;
  update public.exercise_quick_matches set status = 'cancelled', cancelled_at = now(), updated_at = now() where id = v_q.id;
  update public.exercise_match_offers set status = 'expired' where quick_match_id = v_q.id and status = 'pending';
  return jsonb_build_object('ok', true);
end;
$$;

create or replace function public.complete_exercise_quick_match(p_quick_match_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, private
as $$
declare v_uid uuid := auth.uid(); v_q public.exercise_quick_matches%rowtype; v_member uuid;
begin
  select * into v_q from public.exercise_quick_matches where id = p_quick_match_id for update;
  if not found or v_uid not in (v_q.requester_id, v_q.matched_user_id) then return jsonb_build_object('ok', false, 'reason', 'not_allowed'); end if;
  if v_q.status not in ('matched', 'in_progress') then return jsonb_build_object('ok', false, 'reason', 'not_completable'); end if;
  update public.exercise_quick_matches set status = 'completed', completed_at = now(), updated_at = now() where id = v_q.id;
  foreach v_member in array array[v_q.requester_id, v_q.matched_user_id] loop
    perform private.ensure_point_wallet(v_member);
    update public.user_point_wallets set available_points = available_points + 100,
      lifetime_points = lifetime_points + 100, updated_at = now() where user_id = v_member;
    insert into public.point_transactions(user_id, direction, reason, amount, available_after, lifetime_after, memo)
    select v_member, 'credit', 'adjustment', 100, available_points, lifetime_points,
      '지금 운동 매칭 완료' from public.user_point_wallets where user_id = v_member;
  end loop;
  return jsonb_build_object('ok', true, 'points', 100);
end;
$$;

create or replace function public.start_raid_recruitment(
  p_raid_id uuid,
  p_fill_goal text default 'minimum',
  p_approval_mode text default 'manual'
)
returns jsonb
language plpgsql
security definer
set search_path = public, private
as $$
declare v_uid uuid := auth.uid(); v_raid public.raids%rowtype; v_target int; v_id uuid;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into v_raid from public.raids where id = p_raid_id for update;
  if not found then return jsonb_build_object('ok', false, 'reason', 'raid_not_found'); end if;
  if v_raid.organizer_id is distinct from v_uid and not public.is_admin() then return jsonb_build_object('ok', false, 'reason', 'not_organizer'); end if;
  if v_raid.status not in ('recruiting', 'confirmed') or v_raid.starts_at <= now() then return jsonb_build_object('ok', false, 'reason', 'raid_not_recruiting'); end if;
  if p_fill_goal not in ('minimum', 'maximum') then return jsonb_build_object('ok', false, 'reason', 'invalid_goal'); end if;
  v_target := case when p_fill_goal = 'maximum' then v_raid.max_participants else v_raid.min_participants end;
  if (select count(*) from public.raid_participants where raid_id = v_raid.id and status = 'approved') >= v_target then
    return jsonb_build_object('ok', false, 'reason', 'target_already_met');
  end if;
  insert into public.raid_recruitment_campaigns(
    raid_id, created_by, fill_goal, target_participants, approval_mode, expires_at
  ) values (
    v_raid.id, v_uid, p_fill_goal,
    v_target, case when v_raid.participation_fee = 0 then 'instant'
      when p_approval_mode = 'instant' then 'instant' else 'manual' end,
    v_raid.starts_at
  ) on conflict (raid_id) where status = 'recruiting' do update set
    fill_goal = excluded.fill_goal, target_participants = excluded.target_participants,
    approval_mode = excluded.approval_mode, next_expand_at = now(), updated_at = now()
  returning id into v_id;
  execute 'select public.advance_raid_recruitment($1)' using v_id;
  return jsonb_build_object('ok', true, 'campaign_id', v_id);
end;
$$;

create or replace function public.advance_raid_recruitment(p_campaign_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_campaign public.raid_recruitment_campaigns%rowtype; v_raid public.raids%rowtype;
  v_stage int; v_radius int; v_count int; v_created int := 0;
begin
  select * into v_campaign from public.raid_recruitment_campaigns where id = p_campaign_id for update;
  if not found then return jsonb_build_object('ok', false, 'reason', 'campaign_not_found'); end if;
  select * into v_raid from public.raids where id = v_campaign.raid_id;
  if auth.uid() is not null and auth.uid() <> v_campaign.created_by and not public.is_admin() then raise exception 'not_allowed'; end if;
  select count(*) into v_count from public.raid_participants where raid_id = v_raid.id and status = 'approved';
  if v_count >= v_campaign.target_participants then
    update public.raid_recruitment_campaigns set status = 'filled', updated_at = now() where id = v_campaign.id;
    return jsonb_build_object('ok', true, 'status', 'filled');
  end if;
  if v_raid.status in ('cancelled', 'completed', 'in_progress', 'attendance') or now() >= v_raid.starts_at then
    update public.raid_recruitment_campaigns set status = 'closed', updated_at = now() where id = v_campaign.id;
    return jsonb_build_object('ok', true, 'status', 'closed');
  end if;
  if now() < v_campaign.next_expand_at then return jsonb_build_object('ok', true, 'status', 'waiting', 'stage', v_campaign.current_stage); end if;
  v_stage := least(v_campaign.current_stage + 1, 3);
  v_radius := case v_stage when 1 then 1000 when 2 then 3000 else 5000 end;

  with candidates as (
    select pref.user_id,
      round(st_distance(coalesce(wp.geo, pref.activity_geo), venue.geo))::int distance_m,
      (100 - least(st_distance(coalesce(wp.geo, pref.activity_geo), venue.geo) / 100.0, 50)
        + case when v_raid.exercise_type = any(pref.preferred_exercises) then 20 else 0 end
        + coalesce(u.rating, 0) * 2)::numeric(8,2) score
    from public.user_exercise_preferences pref
    join public.users u on u.id = pref.user_id
    left join public.worker_presence wp on wp.worker_id = pref.user_id and wp.share_location and wp.geo is not null
    join public.exercise_venues venue on venue.id = v_raid.venue_id
    where pref.user_id <> coalesce(v_raid.organizer_id, '00000000-0000-0000-0000-000000000000'::uuid)
      and coalesce(wp.geo, pref.activity_geo) is not null
      and v_raid.exercise_type = any(pref.preferred_exercises)
      and v_radius <= pref.max_distance_m
      and st_dwithin(coalesce(wp.geo, pref.activity_geo), venue.geo, v_radius)
      and not private.exercise_schedule_conflict(pref.user_id, v_raid.starts_at,
        v_raid.starts_at + make_interval(mins => v_raid.duration_minutes), v_raid.id, null)
      and not exists (select 1 from public.raid_participants p where p.raid_id = v_raid.id and p.user_id = pref.user_id and p.status in ('approved', 'applied'))
      and not exists (select 1 from public.raid_recruitment_offers old where old.campaign_id = v_campaign.id and old.user_id = pref.user_id)
    order by score desc, distance_m, pref.user_id
    limit greatest(v_campaign.target_participants - v_count, 1) * 3
  ), inserted as (
    insert into public.raid_recruitment_offers(campaign_id, user_id, distance_m, match_score, stage, expires_at)
    select v_campaign.id, c.user_id, c.distance_m, c.score, v_stage, v_raid.starts_at
    from candidates c on conflict (campaign_id, user_id) do nothing
    returning id, user_id
  ), pushed as (
    insert into public.push_outbox(user_id, push_type, title, body, data, collapse_key)
    select i.user_id, 'raid_recruitment_offer', '가까운 운동 레이드에서 참가자를 찾고 있어요',
      v_raid.title || '에 지금 참가할 수 있어요.',
      jsonb_build_object('raid_id', v_raid.id, 'campaign_id', v_campaign.id,
        'offer_id', i.id, 'route', '/raid/' || v_raid.id::text),
      'raid-recruitment-' || v_campaign.id::text
    from inserted i returning 1
  ) select count(*) into v_created from pushed;
  update public.raid_recruitment_campaigns set current_stage = v_stage,
    next_expand_at = now() + interval '30 seconds', updated_at = now()
  where id = v_campaign.id;
  return jsonb_build_object('ok', true, 'status', 'recruiting', 'stage', v_stage,
    'radius_m', v_radius, 'offers_created', v_created);
end;
$$;

create or replace function public.respond_raid_recruitment_offer(
  p_offer_id uuid,
  p_accept boolean,
  p_lat double precision,
  p_lng double precision,
  p_accuracy_m double precision,
  p_captured_at timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_uid uuid := auth.uid(); v_offer public.raid_recruitment_offers%rowtype;
  v_campaign public.raid_recruitment_campaigns%rowtype; v_raid public.raids%rowtype;
  v_reason text; v_geo geography; v_venue_geo geography; v_distance int; v_participant public.raid_participants%rowtype;
  v_count int; v_balance numeric;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into v_offer from public.raid_recruitment_offers where id = p_offer_id for update;
  if not found or v_offer.user_id <> v_uid then return jsonb_build_object('ok', false, 'reason', 'offer_not_found'); end if;
  select * into v_campaign from public.raid_recruitment_campaigns where id = v_offer.campaign_id for update;
  select * into v_raid from public.raids where id = v_campaign.raid_id for update;
  if v_offer.status <> 'pending' or v_campaign.status <> 'recruiting' or now() >= v_raid.starts_at then
    return jsonb_build_object('ok', false, 'reason', 'offer_expired');
  end if;
  if not p_accept then
    update public.raid_recruitment_offers set status = 'declined', responded_at = now() where id = v_offer.id;
    return jsonb_build_object('ok', true, 'accepted', false);
  end if;
  v_reason := private.exercise_location_reason(p_lat, p_lng, p_accuracy_m, p_captured_at);
  if v_reason is not null then return jsonb_build_object('ok', false, 'reason', v_reason); end if;
  v_geo := st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography;
  select geo into v_venue_geo from public.exercise_venues where id = v_raid.venue_id;
  v_distance := round(st_distance(v_geo, v_venue_geo))::int;
  if v_distance > 5000 then return jsonb_build_object('ok', false, 'reason', 'outside_raid_range', 'distance_m', v_distance); end if;
  if private.exercise_schedule_conflict(v_uid, v_raid.starts_at,
      v_raid.starts_at + make_interval(mins => v_raid.duration_minutes), v_raid.id, null) then
    return jsonb_build_object('ok', false, 'reason', 'schedule_conflict');
  end if;
  select count(*) into v_count from public.raid_participants where raid_id = v_raid.id and status = 'approved';
  if v_count >= v_raid.max_participants then return jsonb_build_object('ok', false, 'reason', 'raid_full'); end if;

  insert into public.raid_participants(
    raid_id, user_id, role, status, application_message, payment_status, attendance_status,
    approved_by, approved_at
  ) values (
    v_raid.id, v_uid, 'member',
    case when v_campaign.approval_mode = 'instant' then 'approved' else 'applied' end,
    '긴급 모집을 통해 참가 신청',
    case when v_campaign.approval_mode = 'instant' and v_raid.participation_fee > 0 then 'held' else 'not_required' end,
    'pending', case when v_campaign.approval_mode = 'instant' then v_campaign.created_by else null end,
    case when v_campaign.approval_mode = 'instant' then now() else null end
  ) on conflict (raid_id, user_id) do update set
    status = excluded.status, application_message = excluded.application_message,
    payment_status = excluded.payment_status, cancelled_at = null,
    approved_by = excluded.approved_by, approved_at = excluded.approved_at, updated_at = now()
  where raid_participants.status in ('waitlisted', 'cancelled', 'rejected')
  returning * into v_participant;
  if v_participant.id is null then return jsonb_build_object('ok', false, 'reason', 'already_joined'); end if;

  if v_campaign.approval_mode = 'instant' and v_raid.participation_fee > 0 then
    perform private.ensure_demo_wallet(v_uid);
    select balance into v_balance from public.demo_wallets where user_id = v_uid for update;
    if coalesce(v_balance, 0) < v_raid.participation_fee then raise exception 'insufficient_balance'; end if;
    update public.demo_wallets set balance = balance - v_raid.participation_fee,
      escrow_hold = escrow_hold + v_raid.participation_fee,
      total_spent = total_spent + v_raid.participation_fee, updated_at = now()
    where user_id = v_uid returning balance into v_balance;
    insert into public.raid_fee_holds(raid_id, participant_id, payer_id, organizer_id, amount)
    values (v_raid.id, v_participant.id, v_uid, v_campaign.created_by, v_raid.participation_fee);
    insert into public.raid_fee_transactions(raid_id, user_id, direction, amount, reason, balance_after)
    values (v_raid.id, v_uid, 'hold', v_raid.participation_fee, 'participation_fee', v_balance);
  end if;
  update public.raid_recruitment_offers set status = 'accepted', responded_at = now() where id = v_offer.id;
  if v_campaign.approval_mode = 'manual' then
    insert into public.push_outbox(user_id, push_type, title, body, data, collapse_key)
    values (v_campaign.created_by, 'raid_recruitment_application', '긴급 참가 신청이 도착했어요',
      v_raid.title || ' 참가자를 확인해 주세요.',
      jsonb_build_object('raid_id', v_raid.id, 'participant_id', v_participant.id,
        'route', '/raid/' || v_raid.id::text), 'raid-application-' || v_participant.id::text);
  end if;
  perform private.refresh_raid_recruitment(v_raid.id);
  select count(*) into v_count from public.raid_participants where raid_id = v_raid.id and status = 'approved';
  if v_count >= v_campaign.target_participants then
    update public.raid_recruitment_campaigns set status = 'filled', updated_at = now() where id = v_campaign.id;
    update public.raid_recruitment_offers set status = 'expired' where campaign_id = v_campaign.id and status = 'pending';
  end if;
  return jsonb_build_object('ok', true, 'accepted', true,
    'approval_status', case when v_campaign.approval_mode = 'instant' then 'approved' else 'applied' end,
    'raid_id', v_raid.id);
exception when raise_exception then
  if sqlerrm = 'insufficient_balance' then return jsonb_build_object('ok', false, 'reason', 'insufficient_balance'); end if;
  if sqlerrm = 'schedule_conflict' then return jsonb_build_object('ok', false, 'reason', 'schedule_conflict'); end if;
  raise;
end;
$$;

create or replace function public.get_raid_recruitment_status(p_raid_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare v_uid uuid := auth.uid(); v_result jsonb;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select jsonb_build_object(
    'id', c.id, 'raid_id', c.raid_id, 'fill_goal', c.fill_goal,
    'target_participants', c.target_participants, 'approval_mode', c.approval_mode,
    'status', c.status, 'current_stage', c.current_stage,
    'next_expand_at', c.next_expand_at, 'expires_at', c.expires_at,
    'offer_count', (select count(*) from public.raid_recruitment_offers o where o.campaign_id = c.id),
    'accepted_count', (select count(*) from public.raid_recruitment_offers o where o.campaign_id = c.id and o.status = 'accepted')
  ) into v_result from public.raid_recruitment_campaigns c
  where c.raid_id = p_raid_id and (c.created_by = v_uid or public.is_admin())
  order by c.created_at desc limit 1;
  return v_result;
end;
$$;

create or replace function public.list_my_raid_recruitment_offers()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object(
    'id', o.id, 'campaign_id', o.campaign_id, 'raid_id', r.id,
    'distance_m', o.distance_m, 'status', o.status, 'expires_at', o.expires_at,
    'title', r.title, 'exercise_type', r.exercise_type, 'starts_at', r.starts_at,
    'participation_fee', r.participation_fee,
    'venue_name', v.name, 'approval_mode', c.approval_mode
  ) order by o.created_at desc)
  from public.raid_recruitment_offers o
  join public.raid_recruitment_campaigns c on c.id = o.campaign_id
  join public.raids r on r.id = c.raid_id
  join public.exercise_venues v on v.id = r.venue_id
  where o.user_id = v_uid and o.status = 'pending' and r.starts_at > now()), '[]'::jsonb);
end;
$$;

create or replace function private.advance_exercise_matching()
returns void
language plpgsql
security definer
set search_path = public, private
as $$
declare x record;
begin
  for x in select id from public.exercise_quick_matches where status = 'searching' and next_advance_at <= now() loop
    perform public.advance_exercise_quick_match(x.id);
  end loop;
  for x in select id from public.raid_recruitment_campaigns where status = 'recruiting' and next_expand_at <= now() loop
    perform public.advance_raid_recruitment(x.id);
  end loop;
  for x in
    select r.id, r.organizer_id creator
    from public.raids r
    where r.status in ('recruiting', 'confirmed')
      and r.starts_at between now() and now() + interval '60 minutes'
      and (select count(*) from public.raid_participants p where p.raid_id = r.id and p.status = 'approved') < r.min_participants
      and not exists (select 1 from public.raid_recruitment_campaigns c where c.raid_id = r.id and c.status = 'recruiting')
  loop
    insert into public.raid_recruitment_campaigns(raid_id, created_by, fill_goal, target_participants, approval_mode, expires_at)
    select r.id, x.creator, 'minimum', r.min_participants,
      case when r.participation_fee = 0 then 'instant' else 'manual' end, r.starts_at
    from public.raids r where r.id = x.id on conflict do nothing;
  end loop;
end;
$$;

-- Demand-aware generator: a preference match is weighted more than fallback rotation.
create or replace function public.generate_scheduled_raids(p_days int default 7)
returns jsonb
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_venue public.exercise_venues%rowtype; v_day date; v_time time; v_exercise text;
  v_starts timestamptz; v_inserted int := 0; v_score numeric; v_potential int; v_basis text;
begin
  if auth.uid() is not null and not public.is_admin() then raise exception 'admin_required'; end if;
  for v_venue in select * from public.exercise_venues where is_active loop
    for v_offset in 0..greatest(1, least(coalesce(p_days, 7), 14)) - 1 loop
      v_day := (now() at time zone 'Asia/Seoul')::date + v_offset;
      if extract(isodow from v_day)::smallint = any(v_venue.active_days) then
        foreach v_time in array v_venue.auto_start_times loop
          v_starts := (v_day + v_time) at time zone 'Asia/Seoul';
          if v_starts > now() + interval '30 minutes' then
            select exercise_type, score, potential into v_exercise, v_score, v_potential from (
              select ex exercise_type,
                sum(4
                  + case when extract(isodow from v_day)::smallint = any(p.available_days)
                    and v_time between p.available_start and p.available_end then 3 else 0 end
                  + case when st_dwithin(p.activity_geo, v_venue.geo, 3000) then 2 else 1 end)::numeric score,
                count(*)::int potential
              from unnest(v_venue.supported_exercises) ex
              join public.user_exercise_preferences p on ex = any(p.preferred_exercises)
              where p.activity_geo is not null and st_dwithin(p.activity_geo, v_venue.geo, 5000)
              group by ex order by score desc, potential desc, ex limit 1
            ) demand;
            if coalesce(v_potential, 0) >= v_venue.recommended_min_participants then
              v_basis := 'demand';
            else
              v_exercise := v_venue.supported_exercises[
                1 + mod(extract(doy from v_day)::int + extract(hour from v_time)::int,
                  cardinality(v_venue.supported_exercises))
              ];
              v_score := coalesce(v_score, 0); v_potential := coalesce(v_potential, 0); v_basis := 'venue_fallback';
            end if;
            insert into public.raids(
              venue_id, source, exercise_type, title, description, starts_at,
              duration_minutes, min_participants, max_participants, intensity,
              beginner_friendly, status, demand_score, potential_participant_count, generation_basis
            ) values (
              v_venue.id, 'auto', v_exercise,
              v_venue.name || ' ' || case v_exercise
                when 'running' then '러닝' when 'walking' then '걷기'
                when 'badminton' then '배드민턴' when 'basketball' then '농구'
                when 'fitness' then '기초 체력 운동' else v_exercise end,
              '가까운 사람들과 함께하는 운동 레이드', v_starts,
              v_venue.default_duration_minutes, v_venue.recommended_min_participants,
              v_venue.max_participants, v_venue.default_intensity,
              v_venue.beginner_friendly, 'recruiting', v_score, v_potential, v_basis
            ) on conflict do nothing;
            if found then v_inserted := v_inserted + 1; end if;
          end if;
        end loop;
      end if;
    end loop;
  end loop;
  return jsonb_build_object('ok', true, 'inserted', v_inserted);
end;
$$;

do $$
declare f record;
begin
  for f in
    select p.oid::regprocedure signature
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname in (
      'list_raids', 'get_raid_join_eligibility', 'join_free_raid_nearby',
      'apply_premium_raid_nearby', 'get_my_exercise_preferences',
      'upsert_my_exercise_preferences', 'set_exercise_match_availability',
      'create_exercise_quick_match', 'advance_exercise_quick_match',
      'respond_exercise_match_offer', 'get_my_exercise_quick_match',
      'list_my_exercise_match_offers', 'cancel_exercise_quick_match',
      'complete_exercise_quick_match', 'start_raid_recruitment',
      'advance_raid_recruitment', 'respond_raid_recruitment_offer',
      'get_raid_recruitment_status', 'list_my_raid_recruitment_offers'
    )
  loop
    execute format('revoke all on function %s from public, anon', f.signature);
    execute format('grant execute on function %s to authenticated', f.signature);
  end loop;
end;
$$;

revoke all on function private.exercise_location_reason(double precision, double precision, double precision, timestamptz) from public, anon, authenticated;
revoke all on function private.exercise_schedule_conflict(uuid, timestamptz, timestamptz, uuid, uuid) from public, anon, authenticated;
revoke all on function private.enforce_raid_schedule_conflict() from public, anon, authenticated;
revoke all on function private.advance_exercise_matching() from public, anon, authenticated;

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    begin alter publication supabase_realtime add table public.exercise_quick_matches; exception when duplicate_object then null; end;
    begin alter publication supabase_realtime add table public.exercise_match_offers; exception when duplicate_object then null; end;
    begin alter publication supabase_realtime add table public.exercise_match_messages; exception when duplicate_object then null; end;
    begin alter publication supabase_realtime add table public.raid_recruitment_campaigns; exception when duplicate_object then null; end;
    begin alter publication supabase_realtime add table public.raid_recruitment_offers; exception when duplicate_object then null; end;
  end if;
end;
$$;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule(jobid) from cron.job where jobname = 'ttm-exercise-matching';
    perform cron.schedule('ttm-exercise-matching', '* * * * *', 'select private.advance_exercise_matching();');
  end if;
end;
$$;
