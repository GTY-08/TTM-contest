-- Limit expired offer visibility and include prior participation in raid demand.

drop policy if exists exercise_quick_matches_select
  on public.exercise_quick_matches;
create policy exercise_quick_matches_select
  on public.exercise_quick_matches
  for select
  to authenticated
  using (
    requester_id = (select auth.uid())
    or matched_user_id = (select auth.uid())
    or exists (
      select 1
      from public.exercise_match_offers o
      where o.quick_match_id = exercise_quick_matches.id
        and o.user_id = (select auth.uid())
        and (
          o.status = 'accepted'
          or (o.status = 'pending' and o.expires_at > now())
        )
    )
  );

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
  v_exercise text;
  v_starts timestamptz;
  v_inserted int := 0;
  v_score numeric;
  v_potential int;
  v_basis text;
begin
  if auth.uid() is not null and not public.is_admin() then
    raise exception 'admin_required';
  end if;

  for v_venue in
    select * from public.exercise_venues where is_active
  loop
    for v_offset in 0..greatest(1, least(coalesce(p_days, 7), 14)) - 1
    loop
      v_day := (now() at time zone 'Asia/Seoul')::date + v_offset;
      if extract(isodow from v_day)::smallint = any(v_venue.active_days) then
        foreach v_time in array v_venue.auto_start_times
        loop
          v_starts := (v_day + v_time) at time zone 'Asia/Seoul';
          if v_starts > now() + interval '30 minutes' then
            select exercise_type, score, potential
            into v_exercise, v_score, v_potential
            from (
              select ex as exercise_type,
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
              venue_id, source, exercise_type, title, description, starts_at,
              duration_minutes, min_participants, max_participants, intensity,
              beginner_friendly, status, demand_score,
              potential_participant_count, generation_basis
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
            )
            on conflict do nothing;
            if found then
              v_inserted := v_inserted + 1;
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
