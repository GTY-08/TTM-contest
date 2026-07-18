-- Allow premium raids at a user-selected map point and keep discovery local in time.

alter table public.raids
  add constraint raids_start_within_creation_window
  check (starts_at <= created_at + interval '6 hours') not valid;

drop function if exists public.create_premium_raid(
  uuid, text, text, text, timestamptz, int, int, int, text, boolean, numeric
);

create or replace function public.create_premium_raid(
  p_location_name text,
  p_location_address text,
  p_lat double precision,
  p_lng double precision,
  p_exercise_type text,
  p_title text,
  p_description text,
  p_starts_at timestamptz,
  p_duration_minutes int,
  p_min_participants int,
  p_max_participants int,
  p_intensity text,
  p_beginner_friendly boolean,
  p_participation_fee numeric default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_uid uuid := auth.uid();
  v_raid public.raids%rowtype;
  v_venue_id uuid;
  v_location_name text;
  v_location_address text;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  if not coalesce((select is_premium from public.users where id = v_uid), false) then
    raise exception 'premium_required';
  end if;
  if p_lat is null or p_lng is null
    or p_lat not between -90 and 90
    or p_lng not between -180 and 180
    or (p_lat = 0 and p_lng = 0) then
    raise exception 'invalid_location';
  end if;
  if p_exercise_type not in ('walking', 'running', 'badminton', 'basketball', 'fitness') then
    raise exception 'invalid_exercise_type';
  end if;
  if p_starts_at <= now() + interval '10 minutes' then
    raise exception 'start_time_too_soon';
  end if;
  if p_starts_at > now() + interval '6 hours' then
    raise exception 'start_time_too_late';
  end if;
  if p_duration_minutes not between 20 and 240 then
    raise exception 'invalid_duration';
  end if;
  if p_min_participants < 3
    or p_max_participants < p_min_participants
    or p_max_participants > 30 then
    raise exception 'invalid_capacity';
  end if;

  v_location_name := left(
    coalesce(nullif(trim(p_location_name), ''), '선택한 운동 장소'),
    80
  );
  v_location_address := left(
    coalesce(nullif(trim(p_location_address), ''), v_location_name),
    200
  );

  insert into public.exercise_venues(
    name,
    address,
    category,
    geo,
    supported_exercises,
    auto_start_times,
    default_duration_minutes,
    recommended_min_participants,
    max_participants,
    default_intensity,
    beginner_friendly,
    is_active,
    created_by
  ) values (
    v_location_name,
    v_location_address,
    'raid_custom',
    st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography,
    array[p_exercise_type],
    array['00:00'::time],
    p_duration_minutes,
    p_min_participants,
    p_max_participants,
    p_intensity,
    coalesce(p_beginner_friendly, true),
    false,
    v_uid
  ) returning id into v_venue_id;

  insert into public.raids(
    venue_id,
    source,
    organizer_id,
    exercise_type,
    title,
    description,
    starts_at,
    duration_minutes,
    min_participants,
    max_participants,
    intensity,
    beginner_friendly,
    participation_fee,
    free_cancel_at,
    status
  ) values (
    v_venue_id,
    'premium',
    v_uid,
    p_exercise_type,
    trim(p_title),
    trim(coalesce(p_description, '')),
    p_starts_at,
    p_duration_minutes,
    p_min_participants,
    p_max_participants,
    p_intensity,
    coalesce(p_beginner_friendly, true),
    floor(greatest(coalesce(p_participation_fee, 0), 0)),
    p_starts_at - interval '2 hours',
    'recruiting'
  ) returning * into v_raid;

  insert into public.raid_participants(
    raid_id,
    user_id,
    role,
    status,
    payment_status,
    attendance_status,
    approved_by,
    approved_at
  ) values (
    v_raid.id,
    v_uid,
    'organizer',
    'approved',
    'not_required',
    'exempt',
    v_uid,
    now()
  );

  perform private.refresh_raid_recruitment(v_raid.id);
  return jsonb_build_object('ok', true, 'raid_id', v_raid.id);
end;
$$;

revoke all on function public.create_premium_raid(
  text, text, double precision, double precision, text, text, text,
  timestamptz, int, int, int, text, boolean, numeric
) from public, anon;
grant execute on function public.create_premium_raid(
  text, text, double precision, double precision, text, text, text,
  timestamptz, int, int, int, text, boolean, numeric
) to authenticated;

create or replace function public.list_raids(
  p_lat double precision default null,
  p_lng double precision default null,
  p_radius_m int default null,
  p_exercise_type text default null,
  p_fee_type text default null,
  p_limit int default 2,
  p_cursor_starts_at timestamptz default null,
  p_cursor_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_origin geography;
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  if p_lat is not null and p_lng is not null then
    v_origin := st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography;
  end if;

  with candidates as (
    select
      r.*,
      v.name as venue_name,
      v.address as venue_address,
      v.geo as venue_geo,
      v.supported_exercises as venue_supported_exercises,
      case
        when v_origin is null then null
        else round(st_distance(v.geo, v_origin))::int
      end as distance_m,
      row_number() over (
        partition by
          round(st_y(v.geo::geometry)::numeric, 4),
          round(st_x(v.geo::geometry)::numeric, 4)
        order by r.starts_at, r.id
      ) as location_rank
    from public.raids r
    join public.exercise_venues v on v.id = r.venue_id
    where r.status in ('scheduled', 'recruiting', 'confirmed')
      and r.starts_at > now()
      and r.starts_at <= now() + interval '6 hours'
      and (
        p_exercise_type is null
        or p_exercise_type = 'all'
        or r.exercise_type = p_exercise_type
      )
      and (
        p_fee_type is null
        or p_fee_type = 'all'
        or (p_fee_type = 'free' and r.participation_fee = 0)
        or (p_fee_type = 'paid' and r.participation_fee > 0)
      )
      and (
        p_radius_m is null
        or v_origin is null
        or st_dwithin(
          v.geo,
          v_origin,
          greatest(500, least(p_radius_m, 5000))
        )
      )
      and (
        p_cursor_starts_at is null
        or (r.starts_at, r.id) > (p_cursor_starts_at, p_cursor_id)
      )
  ), picked as (
    select *
    from candidates
    where location_rank = 1
    order by starts_at, id
    limit greatest(1, least(coalesce(p_limit, 2), 2))
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', r.id,
        'source', r.source,
        'organizer_id', r.organizer_id,
        'exercise_type', r.exercise_type,
        'title', r.title,
        'description', r.description,
        'starts_at', r.starts_at,
        'duration_minutes', r.duration_minutes,
        'min_participants', r.min_participants,
        'max_participants', r.max_participants,
        'participant_count', (
          select count(*)
          from public.raid_participants p
          where p.raid_id = r.id and p.status = 'approved'
        ),
        'intensity', r.intensity,
        'beginner_friendly', r.beginner_friendly,
        'participation_fee', r.participation_fee,
        'free_cancel_at', r.free_cancel_at,
        'status', r.status,
        'distance_m', r.distance_m,
        'venue', jsonb_build_object(
          'id', r.venue_id,
          'name', r.venue_name,
          'address', r.venue_address,
          'latitude', st_y(r.venue_geo::geometry),
          'longitude', st_x(r.venue_geo::geometry),
          'supported_exercises', r.venue_supported_exercises
        ),
        'my_participant', (
          select jsonb_build_object(
            'id', me.id,
            'status', me.status,
            'role', me.role,
            'payment_status', me.payment_status,
            'attendance_status', me.attendance_status
          )
          from public.raid_participants me
          where me.raid_id = r.id and me.user_id = v_uid
        )
      ) order by r.starts_at, r.id
    ),
    '[]'::jsonb
  ) into v_result
  from picked r;

  return v_result;
end;
$$;

revoke all on function public.list_raids(
  double precision, double precision, int, text, text, int, timestamptz, uuid
) from public, anon;
grant execute on function public.list_raids(
  double precision, double precision, int, text, text, int, timestamptz, uuid
) to authenticated;

create or replace function public.generate_scheduled_raids(p_days int default 2)
returns jsonb
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_venue public.exercise_venues%rowtype;
  v_day date;
  v_time time;
  v_exercise text;
  v_starts timestamptz;
  v_inserted int := 0;
  v_visible_count int := 0;
  v_score numeric;
  v_potential int;
  v_basis text;
begin
  if auth.uid() is not null and not public.is_admin() then
    raise exception 'admin_required';
  end if;

  select count(*)::int into v_visible_count
  from public.raids
  where source = 'auto'
    and status in ('scheduled', 'recruiting', 'confirmed')
    and starts_at > now()
    and starts_at <= now() + interval '6 hours';

  if v_visible_count >= 2 then
    return jsonb_build_object('ok', true, 'inserted', 0);
  end if;

  for v_venue in
    select * from public.exercise_venues where is_active order by name
  loop
    for v_offset in 0..greatest(1, least(coalesce(p_days, 2), 2)) - 1
    loop
      v_day := (now() at time zone 'Asia/Seoul')::date + v_offset;
      if extract(isodow from v_day)::smallint = any(v_venue.active_days) then
        foreach v_time in array v_venue.auto_start_times
        loop
          v_starts := (v_day + v_time) at time zone 'Asia/Seoul';
          if v_starts > now() + interval '30 minutes'
            and v_starts <= now() + interval '6 hours' then
            select exercise_type, score, potential
            into v_exercise, v_score, v_potential
            from (
              select
                ex as exercise_type,
                sum(
                  4
                  + case
                      when extract(isodow from v_day)::smallint = any(p.available_days)
                        and (
                          (p.available_start <= p.available_end
                            and v_time between p.available_start and p.available_end)
                          or (p.available_start > p.available_end
                            and (v_time >= p.available_start or v_time <= p.available_end))
                        )
                      then 3 else 0
                    end
                  + case
                      when st_dwithin(p.activity_geo, v_venue.geo, 3000)
                      then 2 else 1
                    end
                  + case
                      when exists (
                        select 1
                        from public.raid_participants previous_participant
                        join public.raids previous_raid
                          on previous_raid.id = previous_participant.raid_id
                        where previous_participant.user_id = p.user_id
                          and previous_participant.status = 'approved'
                          and previous_raid.exercise_type = ex
                          and previous_raid.status = 'completed'
                      )
                      then 1 else 0
                    end
                )::numeric as score,
                count(*)::int as potential
              from unnest(v_venue.supported_exercises) ex
              join public.user_exercise_preferences p
                on ex = any(p.preferred_exercises)
              where p.activity_geo is not null
                and st_dwithin(p.activity_geo, v_venue.geo, 5000)
              group by ex
              order by score desc, potential desc, ex
              limit 1
            ) demand;

            if coalesce(v_potential, 0) >= v_venue.recommended_min_participants then
              v_basis := 'demand';
            else
              v_exercise := v_venue.supported_exercises[
                1 + mod(
                  extract(doy from v_day)::int + extract(hour from v_time)::int,
                  cardinality(v_venue.supported_exercises)
                )
              ];
              v_score := coalesce(v_score, 0);
              v_potential := coalesce(v_potential, 0);
              v_basis := 'venue_fallback';
            end if;

            insert into public.raids(
              venue_id,
              source,
              exercise_type,
              title,
              description,
              starts_at,
              duration_minutes,
              min_participants,
              max_participants,
              intensity,
              beginner_friendly,
              status,
              demand_score,
              potential_participant_count,
              generation_basis
            ) values (
              v_venue.id,
              'auto',
              v_exercise,
              v_venue.name || ' ' || case v_exercise
                when 'running' then '러닝'
                when 'walking' then '걷기'
                when 'badminton' then '배드민턴'
                when 'basketball' then '농구'
                when 'fitness' then '기초 체력 운동'
                else v_exercise
              end,
              '가까운 사람들과 함께하는 운동 레이드',
              v_starts,
              v_venue.default_duration_minutes,
              v_venue.recommended_min_participants,
              v_venue.max_participants,
              v_venue.default_intensity,
              v_venue.beginner_friendly,
              'recruiting',
              v_score,
              v_potential,
              v_basis
            ) on conflict do nothing;

            if found then
              v_inserted := v_inserted + 1;
              v_visible_count := v_visible_count + 1;
              if v_visible_count >= 2 then
                return jsonb_build_object('ok', true, 'inserted', v_inserted);
              end if;
            end if;
          end if;
        end loop;
      end if;
    end loop;
  end loop;

  return jsonb_build_object('ok', true, 'inserted', v_inserted);
end;
$$;

revoke all on function public.generate_scheduled_raids(int) from public, anon;
grant execute on function public.generate_scheduled_raids(int) to authenticated;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule(jobid)
    from cron.job
    where jobname = 'ttm-raid-generator';
    perform cron.schedule(
      'ttm-raid-generator',
      '*/30 * * * *',
      'select public.generate_scheduled_raids(2);'
    );
  end if;
end;
$$;

select public.generate_scheduled_raids(2);

-- Premium-raid applicants use the same private 1:1 conversation pattern as
-- general-request applicants. Only the applicant and raid organizer can read it.
create table if not exists public.raid_application_messages (
  id uuid primary key default gen_random_uuid(),
  participant_id uuid not null
    references public.raid_participants(id) on delete cascade,
  sender_id uuid not null references public.users(id) on delete restrict,
  content text not null check (length(trim(content)) between 1 and 2000),
  created_at timestamptz not null default now()
);

create index if not exists raid_application_messages_thread_idx
  on public.raid_application_messages(participant_id, created_at);

alter table public.raid_application_messages enable row level security;
revoke all on table public.raid_application_messages from public, anon;
grant select on table public.raid_application_messages to authenticated;

drop policy if exists raid_application_messages_select
  on public.raid_application_messages;
create policy raid_application_messages_select
  on public.raid_application_messages
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.raid_participants p
      join public.raids r on r.id = p.raid_id
      where p.id = raid_application_messages.participant_id
        and (
          p.user_id = (select auth.uid())
          or r.organizer_id = (select auth.uid())
        )
    )
  );

create or replace function public.send_raid_application_message(
  p_participant_id uuid,
  p_content text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_participant public.raid_participants%rowtype;
  v_organizer_id uuid;
  v_message_id uuid;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  if length(trim(coalesce(p_content, ''))) not between 1 and 2000 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_content');
  end if;

  select p.*
  into v_participant
  from public.raid_participants p
  where p.id = p_participant_id;

  if not found then
    return jsonb_build_object('ok', false, 'reason', 'application_not_found');
  end if;

  select r.organizer_id
  into v_organizer_id
  from public.raids r
  where r.id = v_participant.raid_id;

  if not found then
    return jsonb_build_object('ok', false, 'reason', 'raid_not_found');
  end if;
  if v_uid not in (v_participant.user_id, v_organizer_id) then
    return jsonb_build_object('ok', false, 'reason', 'not_participant');
  end if;
  if v_participant.status in ('rejected', 'cancelled') then
    return jsonb_build_object('ok', false, 'reason', 'application_closed');
  end if;

  insert into public.raid_application_messages(
    participant_id,
    sender_id,
    content
  ) values (
    v_participant.id,
    v_uid,
    trim(p_content)
  ) returning id into v_message_id;

  return jsonb_build_object('ok', true, 'message_id', v_message_id);
end;
$$;

revoke all on function public.send_raid_application_message(uuid, text)
  from public, anon;
grant execute on function public.send_raid_application_message(uuid, text)
  to authenticated;

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    begin
      alter publication supabase_realtime
        add table public.raid_application_messages;
    exception when duplicate_object then
      null;
    end;
  end if;
end;
$$;

-- Match the original quick-matching behavior: an explicit activity-ON window
-- is sufficient. Saved weekly preference hours must not silently hide offers.
create or replace function public.advance_exercise_quick_match(
  p_quick_match_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_q public.exercise_quick_matches%rowtype;
  v_stage int;
  v_radius int;
  v_inserted int := 0;
begin
  select * into v_q
  from public.exercise_quick_matches
  where id = p_quick_match_id
  for update;

  if not found then
    return jsonb_build_object('ok', false, 'reason', 'match_not_found');
  end if;
  if auth.uid() is not null
    and auth.uid() <> v_q.requester_id
    and not public.is_admin() then
    raise exception 'not_allowed';
  end if;
  if v_q.status <> 'searching' then
    return jsonb_build_object('ok', false, 'reason', 'not_searching');
  end if;
  if now() >= v_q.expires_at
    or (v_q.current_stage = 10 and now() >= v_q.next_advance_at) then
    update public.exercise_quick_matches
    set status = 'failed', updated_at = now()
    where id = v_q.id;
    update public.exercise_match_offers
    set status = 'expired'
    where quick_match_id = v_q.id and status = 'pending';
    return jsonb_build_object('ok', true, 'status', 'failed');
  end if;
  if v_q.current_stage > 0 and now() < v_q.next_advance_at then
    return jsonb_build_object(
      'ok', true,
      'status', 'waiting',
      'stage', v_q.current_stage,
      'next_advance_at', v_q.next_advance_at
    );
  end if;

  v_stage := least(v_q.current_stage + 1, 10);
  v_radius := ceil(v_q.max_distance_m * v_stage / 10.0)::int;

  with candidates as (
    select
      wp.worker_id,
      round(st_distance(wp.geo, v_q.meeting_geo))::int as distance_m,
      (
        100
        - least(st_distance(wp.geo, v_q.meeting_geo) / 100.0, 50)
        + case
            when pref.fitness_level = coalesce(
              req_pref.fitness_level,
              pref.fitness_level
            ) then 12 else 0
          end
        + case
            when v_q.partner_level_pref = 'beginner'
              and pref.fitness_level = 'beginner' then 15
            when v_q.partner_level_pref = 'similar'
              and pref.fitness_level = coalesce(
                req_pref.fitness_level,
                pref.fitness_level
              ) then 15
            else 0
          end
        + coalesce(u.rating, 0) * 2
      )::numeric(8, 2) as score
    from public.worker_presence wp
    left join public.user_exercise_preferences pref
      on pref.user_id = wp.worker_id
    left join public.user_exercise_preferences req_pref
      on req_pref.user_id = v_q.requester_id
    join public.users u on u.id = wp.worker_id
    where wp.worker_id <> v_q.requester_id
      and wp.status = 'online'
      and wp.share_location
      and wp.geo is not null
      and (wp.online_until is null or wp.online_until > now())
      and v_q.exercise_type = any(coalesce(wp.preferred_tags, array[]::text[]))
      and st_dwithin(
        wp.geo,
        v_q.meeting_geo,
        least(
          v_radius,
          round(coalesce(wp.max_distance_km, 5) * 1000)::int
        )
      )
      and not private.exercise_schedule_conflict(
        wp.worker_id,
        v_q.starts_at,
        v_q.ends_at,
        null,
        v_q.id
      )
      and not exists (
        select 1
        from public.exercise_quick_matches active
        where active.id <> v_q.id
          and active.status in ('searching', 'matched', 'in_progress')
          and wp.worker_id in (active.requester_id, active.matched_user_id)
      )
      and not exists (
        select 1
        from public.exercise_match_offers old
        where old.quick_match_id = v_q.id
          and old.user_id = wp.worker_id
      )
    order by score desc, distance_m, wp.worker_id
    limit 5
  ), inserted as (
    insert into public.exercise_match_offers(
      quick_match_id,
      user_id,
      distance_m,
      match_score,
      stage,
      expires_at
    )
    select
      v_q.id,
      c.worker_id,
      c.distance_m,
      c.score,
      v_stage,
      least(v_q.expires_at, now() + interval '20 seconds')
    from candidates c
    on conflict (quick_match_id, user_id) do nothing
    returning id, user_id
  ), pushed as (
    insert into public.push_outbox(
      user_id,
      push_type,
      title,
      body,
      data,
      collapse_key
    )
    select
      i.user_id,
      'exercise_match_offer',
      '지금 함께 운동할 사람을 찾고 있어요',
      v_q.meeting_label || '에서 운동 매칭 요청이 도착했어요.',
      jsonb_build_object(
        'quick_match_id', v_q.id,
        'offer_id', i.id,
        'route', '/quick-match'
      ),
      'exercise-match-' || v_q.id::text
    from inserted i
    returning 1
  )
  select count(*) into v_inserted from pushed;

  update public.exercise_quick_matches
  set current_stage = v_stage,
      next_advance_at = now() + case
        when v_stage = 10 then interval '20 seconds'
        else interval '6 seconds'
      end,
      updated_at = now()
  where id = v_q.id;

  return jsonb_build_object(
    'ok', true,
    'status', 'searching',
    'stage', v_stage,
    'radius_m', v_radius,
    'offers_created', v_inserted
  );
end;
$$;

revoke all on function public.advance_exercise_quick_match(uuid)
  from public, anon;
grant execute on function public.advance_exercise_quick_match(uuid)
  to authenticated;
