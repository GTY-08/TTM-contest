-- Predictive automatic raid generation.
-- Replaces the earlier fixed weighted-sum selector with a demand model that
-- combines spatial decay, Bayesian attendance reliability, exercise affinity,
-- historical slot success, and a diversity penalty.

create or replace function public.generate_scheduled_raids(p_days int default 7)
returns jsonb
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_venue public.exercise_venues%rowtype;
  v_day date;
  v_time time;
  v_starts timestamptz;
  v_exercise text;
  v_expected numeric;
  v_potential int;
  v_objective numeric;
  v_slot_success numeric;
  v_recent_same int;
  v_basis text;
  v_inserted int := 0;
  v_skipped int := 0;
  v_min_participants int;
  v_max_participants int;
begin
  if auth.uid() is not null and not public.is_admin() then
    raise exception 'admin_required';
  end if;

  for v_venue in
    select *
    from public.exercise_venues
    where is_active
  loop
    for v_offset in 0..greatest(1, least(coalesce(p_days, 7), 14)) - 1
    loop
      v_day := (now() at time zone 'Asia/Seoul')::date + v_offset;

      if extract(isodow from v_day)::smallint = any(v_venue.active_days) then
        foreach v_time in array v_venue.auto_start_times
        loop
          v_starts := (v_day + v_time) at time zone 'Asia/Seoul';

          if v_starts <= now() + interval '30 minutes' then
            v_skipped := v_skipped + 1;
            continue;
          end if;

          v_exercise := null;
          v_expected := 0;
          v_potential := 0;
          v_objective := 0;
          v_slot_success := 0.5;
          v_recent_same := 0;

          with scored_users as (
            select
              ex.exercise_type,
              p.user_id,
              -- D: spatial affinity. The exponential decay makes nearby users
              -- contribute more while avoiding a hard linear drop-off.
              exp(
                -least(distance_data.distance_m, 5000.0)
                / greatest(750.0, p.max_distance_m * 0.60)
              ) as distance_affinity,
              -- R: Bayesian-smoothed attendance reliability.
              -- Beta(3,1) prior prevents one absence or one attendance from
              -- dominating users with little history.
              (
                3.0 + history_data.attended_count
              ) / (
                4.0 + history_data.resolved_count
              ) as attendance_reliability,
              -- E: diminishing-return affinity for the same exercise.
              1.0 - exp(-history_data.same_exercise_count / 3.0) as exercise_affinity,
              slot_data.success_rate as slot_success,
              recent_data.recent_same_count
            from unnest(v_venue.supported_exercises) as ex(exercise_type)
            join public.user_exercise_preferences p
              on ex.exercise_type = any(p.preferred_exercises)
            cross join lateral (
              select st_distance(p.activity_geo, v_venue.geo) as distance_m
            ) distance_data
            cross join lateral (
              select
                count(*) filter (
                  where r.status = 'completed'
                    and rp.attendance_status in ('present', 'late', 'left_early')
                )::double precision as attended_count,
                count(*) filter (
                  where r.status = 'completed'
                    and rp.attendance_status not in ('pending', 'disputed')
                )::double precision as resolved_count,
                count(*) filter (
                  where r.status = 'completed'
                    and r.exercise_type = ex.exercise_type
                    and rp.attendance_status in ('present', 'late', 'left_early')
                )::double precision as same_exercise_count
              from public.raid_participants rp
              join public.raids r on r.id = rp.raid_id
              where rp.user_id = p.user_id
                and rp.status = 'approved'
                and r.starts_at >= now() - interval '180 days'
            ) history_data
            cross join lateral (
              select
                (
                  2.0 + count(*) filter (where r.status = 'completed')
                ) / (
                  4.0 + count(*) filter (where r.status in ('completed', 'cancelled'))
                ) as success_rate
              from public.raids r
              where r.venue_id = v_venue.id
                and r.exercise_type = ex.exercise_type
                and r.source = 'auto'
                and r.starts_at >= now() - interval '90 days'
                and r.starts_at < now()
                and extract(
                  isodow from r.starts_at at time zone 'Asia/Seoul'
                )::smallint = extract(isodow from v_day)::smallint
                and abs(
                  extract(
                    epoch from (
                      (r.starts_at at time zone 'Asia/Seoul')::time - v_time
                    )
                  )
                ) <= 3600
            ) slot_data
            cross join lateral (
              select count(*)::int as recent_same_count
              from public.raids r
              where r.venue_id = v_venue.id
                and r.exercise_type = ex.exercise_type
                and r.source = 'auto'
                and r.status <> 'cancelled'
                and r.starts_at >= v_starts - interval '14 days'
                and r.starts_at < v_starts
            ) recent_data
            where p.activity_geo is not null
              and extract(isodow from v_day)::smallint = any(p.available_days)
              and (
                (
                  p.available_start <= p.available_end
                  and v_time between p.available_start and p.available_end
                )
                or (
                  p.available_start > p.available_end
                  and (v_time >= p.available_start or v_time <= p.available_end)
                )
              )
              and distance_data.distance_m <= least(5000, p.max_distance_m)
          ), aggregated as (
            select
              exercise_type,
              sum(
                0.40 * distance_affinity
                + 0.25 * attendance_reliability
                + 0.20 * exercise_affinity
                + 0.15 * slot_success
              ) as expected_attendance,
              count(*)::int as potential_participants,
              max(slot_success) as slot_success,
              max(recent_same_count) as recent_same_count
            from scored_users
            group by exercise_type
          ), ranked as (
            select
              exercise_type,
              expected_attendance,
              potential_participants,
              slot_success,
              recent_same_count,
              -- J: objective score. Repeatedly scheduling the same exercise at
              -- the same venue receives an exponential diversity penalty.
              expected_attendance
                * power(0.82::double precision, recent_same_count)
                + 0.05 * sqrt(potential_participants::double precision)
                as objective_score
            from aggregated
          )
          select
            exercise_type,
            round(expected_attendance::numeric, 3),
            potential_participants,
            round(objective_score::numeric, 3),
            round(slot_success::numeric, 3),
            recent_same_count
          into
            v_exercise,
            v_expected,
            v_potential,
            v_objective,
            v_slot_success,
            v_recent_same
          from ranked
          order by objective_score desc,
                   expected_attendance desc,
                   potential_participants desc,
                   exercise_type
          limit 1;

          if v_exercise is null then
            -- Keep a deterministic exploration path when no preference data is
            -- available, so new areas can still collect demand history.
            v_exercise := v_venue.supported_exercises[
              1 + mod(
                extract(doy from v_day)::int + extract(hour from v_time)::int,
                cardinality(v_venue.supported_exercises)
              )
            ];
            v_expected := 0;
            v_potential := 0;
            v_objective := 0;
            v_slot_success := 0.5;
            v_recent_same := 0;
            v_basis := 'predictive_v2_exploration';
          elsif v_expected >= v_venue.recommended_min_participants - 0.5 then
            v_basis := 'predictive_v2_demand';
          else
            v_basis := 'predictive_v2_low_demand';
          end if;

          -- Adapt capacity to predicted attendance while preserving the venue's
          -- configured safety bounds.
          if v_expected >= 3 then
            v_min_participants := greatest(
              3,
              least(
                v_venue.recommended_min_participants,
                floor(v_expected)::int
              )
            );
          else
            v_min_participants := v_venue.recommended_min_participants;
          end if;

          v_max_participants := least(
            v_venue.max_participants,
            greatest(
              v_min_participants,
              ceil(greatest(v_expected, v_min_participants) * 1.35)::int
            )
          );

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
              when 'soccer' then '축구'
              when 'cycling' then '자전거'
              when 'fitness' then '기초 체력 운동'
              else v_exercise
            end,
            format(
              '예상 참여 %.2f명 · 후보 %s명 · 시간대 성공률 %.0f%%',
              v_expected,
              v_potential,
              v_slot_success * 100
            ),
            v_starts,
            v_venue.default_duration_minutes,
            v_min_participants,
            v_max_participants,
            v_venue.default_intensity,
            v_venue.beginner_friendly,
            'recruiting',
            v_objective,
            v_potential,
            v_basis
          )
          on conflict do nothing;

          if found then
            v_inserted := v_inserted + 1;
          end if;
        end loop;
      end if;
    end loop;
  end loop;

  return jsonb_build_object(
    'ok', true,
    'model', 'predictive_v2',
    'inserted', v_inserted,
    'skipped_past_slots', v_skipped
  );
end;
$$;

revoke all on function public.generate_scheduled_raids(int) from public, anon;
grant execute on function public.generate_scheduled_raids(int) to authenticated;
