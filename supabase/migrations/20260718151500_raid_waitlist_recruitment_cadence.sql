-- Notify existing waitlisted participants before widening urgent recruitment.

alter table public.raid_recruitment_campaigns
  add column if not exists waitlist_notified_at timestamptz;

create or replace function public.advance_raid_recruitment(p_campaign_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_campaign public.raid_recruitment_campaigns%rowtype;
  v_raid public.raids%rowtype;
  v_stage int;
  v_radius int;
  v_count int;
  v_created int := 0;
begin
  select * into v_campaign
  from public.raid_recruitment_campaigns
  where id = p_campaign_id
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'campaign_not_found');
  end if;

  select * into v_raid from public.raids where id = v_campaign.raid_id;
  if auth.uid() is not null
    and auth.uid() is distinct from v_campaign.created_by
    and not public.is_admin() then
    raise exception 'not_allowed';
  end if;

  select count(*) into v_count
  from public.raid_participants
  where raid_id = v_raid.id and status = 'approved';

  if v_count >= v_campaign.target_participants then
    update public.raid_recruitment_campaigns
    set status = 'filled', updated_at = now()
    where id = v_campaign.id;
    return jsonb_build_object('ok', true, 'status', 'filled');
  end if;

  if v_raid.status in ('cancelled', 'completed', 'in_progress', 'attendance')
    or now() >= v_raid.starts_at then
    update public.raid_recruitment_campaigns
    set status = 'closed', updated_at = now()
    where id = v_campaign.id;
    return jsonb_build_object('ok', true, 'status', 'closed');
  end if;

  if now() < v_campaign.next_expand_at then
    return jsonb_build_object(
      'ok', true, 'status', 'waiting', 'stage', v_campaign.current_stage
    );
  end if;

  if v_campaign.waitlist_notified_at is null then
    with inserted as (
      insert into public.raid_recruitment_offers(
        campaign_id, user_id, distance_m, match_score, stage, expires_at
      )
      select v_campaign.id, p.user_id, null, 120, 0, v_raid.starts_at
      from public.raid_participants p
      where p.raid_id = v_raid.id
        and p.status = 'waitlisted'
        and not private.exercise_schedule_conflict(
          p.user_id,
          v_raid.starts_at,
          v_raid.starts_at + make_interval(mins => v_raid.duration_minutes),
          v_raid.id,
          null
        )
      order by p.created_at
      on conflict (campaign_id, user_id) do nothing
      returning id, user_id
    ), pushed as (
      insert into public.push_outbox(
        user_id, push_type, title, body, data, collapse_key
      )
      select i.user_id, 'raid_recruitment_offer',
        '기다리던 레이드에 자리가 열렸어요',
        v_raid.title || '에 지금 참가할 수 있어요.',
        jsonb_build_object(
          'raid_id', v_raid.id,
          'campaign_id', v_campaign.id,
          'offer_id', i.id,
          'route', '/raid/' || v_raid.id::text
        ),
        'raid-recruitment-' || v_campaign.id::text
      from inserted i
      returning 1
    )
    select count(*) into v_created from pushed;

    update public.raid_recruitment_campaigns
    set waitlist_notified_at = now(),
        next_expand_at = now() + interval '30 seconds',
        updated_at = now()
    where id = v_campaign.id;

    return jsonb_build_object(
      'ok', true,
      'status', 'recruiting',
      'stage', 0,
      'audience', 'waitlist',
      'offers_created', v_created
    );
  end if;

  v_stage := least(v_campaign.current_stage + 1, 3);
  v_radius := case v_stage when 1 then 1000 when 2 then 3000 else 5000 end;

  with candidates as (
    select pref.user_id,
      round(st_distance(coalesce(wp.geo, pref.activity_geo), venue.geo))::int distance_m,
      (
        100
        - least(st_distance(coalesce(wp.geo, pref.activity_geo), venue.geo) / 100.0, 50)
        + case when v_raid.exercise_type = any(pref.preferred_exercises) then 20 else 0 end
        + coalesce(u.rating, 0) * 2
      )::numeric(8,2) score
    from public.user_exercise_preferences pref
    join public.users u on u.id = pref.user_id
    left join public.worker_presence wp
      on wp.worker_id = pref.user_id
      and wp.share_location
      and wp.geo is not null
    join public.exercise_venues venue on venue.id = v_raid.venue_id
    where pref.user_id <> coalesce(
      v_raid.organizer_id,
      '00000000-0000-0000-0000-000000000000'::uuid
    )
      and coalesce(wp.geo, pref.activity_geo) is not null
      and v_raid.exercise_type = any(pref.preferred_exercises)
      and v_radius <= pref.max_distance_m
      and st_dwithin(coalesce(wp.geo, pref.activity_geo), venue.geo, v_radius)
      and not private.exercise_schedule_conflict(
        pref.user_id,
        v_raid.starts_at,
        v_raid.starts_at + make_interval(mins => v_raid.duration_minutes),
        v_raid.id,
        null
      )
      and not exists (
        select 1 from public.raid_participants p
        where p.raid_id = v_raid.id
          and p.user_id = pref.user_id
          and p.status in ('approved', 'applied')
      )
      and not exists (
        select 1 from public.raid_recruitment_offers old
        where old.campaign_id = v_campaign.id
          and old.user_id = pref.user_id
      )
    order by score desc, distance_m, pref.user_id
    limit greatest(v_campaign.target_participants - v_count, 1) * 3
  ), inserted as (
    insert into public.raid_recruitment_offers(
      campaign_id, user_id, distance_m, match_score, stage, expires_at
    )
    select v_campaign.id, c.user_id, c.distance_m, c.score, v_stage, v_raid.starts_at
    from candidates c
    on conflict (campaign_id, user_id) do nothing
    returning id, user_id
  ), pushed as (
    insert into public.push_outbox(
      user_id, push_type, title, body, data, collapse_key
    )
    select i.user_id, 'raid_recruitment_offer',
      '가까운 운동 레이드에서 참가자를 찾고 있어요',
      v_raid.title || '에 지금 참가할 수 있어요.',
      jsonb_build_object(
        'raid_id', v_raid.id,
        'campaign_id', v_campaign.id,
        'offer_id', i.id,
        'route', '/raid/' || v_raid.id::text
      ),
      'raid-recruitment-' || v_campaign.id::text
    from inserted i
    returning 1
  )
  select count(*) into v_created from pushed;

  update public.raid_recruitment_campaigns
  set current_stage = v_stage,
      next_expand_at = now() + interval '30 seconds',
      updated_at = now()
  where id = v_campaign.id;

  return jsonb_build_object(
    'ok', true,
    'status', 'recruiting',
    'stage', v_stage,
    'radius_m', v_radius,
    'offers_created', v_created
  );
end;
$$;

revoke all on function public.advance_raid_recruitment(uuid) from public, anon;
grant execute on function public.advance_raid_recruitment(uuid) to authenticated;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule(jobid)
    from cron.job
    where jobname = 'ttm-exercise-matching';
    perform cron.schedule(
      'ttm-exercise-matching',
      '30 seconds',
      'select private.advance_exercise_matching();'
    );
  end if;
end;
$$;
