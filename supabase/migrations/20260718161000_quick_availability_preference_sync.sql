-- An online user must also have a preference row to enter candidate scoring.

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
declare
  v_uid uuid := auth.uid();
  v_reason text;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;

  if not p_online then
    update public.worker_presence
    set status = 'offline',
        share_location = false,
        online_until = null,
        updated_at = now()
    where worker_id = v_uid;
    return jsonb_build_object('ok', true, 'online', false);
  end if;

  v_reason := private.exercise_location_reason(
    p_lat,
    p_lng,
    p_accuracy_m,
    p_captured_at
  );
  if v_reason is not null then
    return jsonb_build_object('ok', false, 'reason', v_reason);
  end if;

  if p_max_distance_m not in (1000, 3000, 5000)
    or coalesce(cardinality(p_exercise_types), 0) = 0 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_preferences');
  end if;

  insert into public.user_exercise_preferences(
    user_id,
    preferred_exercises,
    max_distance_m,
    updated_at
  ) values (
    v_uid,
    p_exercise_types,
    p_max_distance_m,
    now()
  )
  on conflict (user_id) do update
  set preferred_exercises = excluded.preferred_exercises,
      max_distance_m = excluded.max_distance_m,
      updated_at = now();

  insert into public.worker_presence(
    worker_id,
    status,
    geo,
    max_distance_km,
    preferred_tags,
    share_location,
    updated_at,
    online_until
  ) values (
    v_uid,
    'online',
    st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography,
    p_max_distance_m / 1000.0,
    p_exercise_types,
    true,
    now(),
    now() + interval '30 minutes'
  )
  on conflict (worker_id) do update
  set status = 'online',
      geo = excluded.geo,
      max_distance_km = excluded.max_distance_km,
      preferred_tags = excluded.preferred_tags,
      share_location = true,
      updated_at = now(),
      online_until = now() + interval '30 minutes';

  return jsonb_build_object(
    'ok', true,
    'online', true,
    'online_until', now() + interval '30 minutes'
  );
end;
$$;

revoke all on function public.set_exercise_match_availability(
  boolean,
  double precision,
  double precision,
  double precision,
  timestamptz,
  int,
  text[]
) from public, anon;
grant execute on function public.set_exercise_match_availability(
  boolean,
  double precision,
  double precision,
  double precision,
  timestamptz,
  int,
  text[]
) to authenticated;
