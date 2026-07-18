-- Break mutually recursive exercise-matching RLS policies and provide stable
-- chat contexts for the quick-match and premium-application DM screens.

create or replace function public.can_view_exercise_quick_match(
  p_quick_match_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.exercise_quick_matches q
    where q.id = p_quick_match_id
      and (
        q.requester_id = (select auth.uid())
        or q.matched_user_id = (select auth.uid())
        or exists (
          select 1
          from public.exercise_match_offers o
          where o.quick_match_id = q.id
            and o.user_id = (select auth.uid())
            and (
              o.status = 'accepted'
              or (o.status = 'pending' and o.expires_at > now())
            )
        )
      )
  );
$$;

create or replace function public.is_exercise_quick_match_requester(
  p_quick_match_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.exercise_quick_matches q
    where q.id = p_quick_match_id
      and q.requester_id = (select auth.uid())
  );
$$;

revoke all on function public.can_view_exercise_quick_match(uuid)
  from public, anon;
revoke all on function public.is_exercise_quick_match_requester(uuid)
  from public, anon;
grant execute on function public.can_view_exercise_quick_match(uuid)
  to authenticated;
grant execute on function public.is_exercise_quick_match_requester(uuid)
  to authenticated;

drop policy if exists exercise_quick_matches_select
  on public.exercise_quick_matches;
create policy exercise_quick_matches_select
on public.exercise_quick_matches
for select
to authenticated
using (public.can_view_exercise_quick_match(id));

drop policy if exists exercise_match_offers_select
  on public.exercise_match_offers;
create policy exercise_match_offers_select
on public.exercise_match_offers
for select
to authenticated
using (
  user_id = (select auth.uid())
  or public.is_exercise_quick_match_requester(quick_match_id)
);

drop policy if exists exercise_match_messages_select
  on public.exercise_match_messages;
create policy exercise_match_messages_select
on public.exercise_match_messages
for select
to authenticated
using (public.is_exercise_quick_match_participant(quick_match_id));

drop policy if exists raid_application_messages_select
  on public.raid_application_messages;
create policy raid_application_messages_select
on public.raid_application_messages
for select
to authenticated
using (public.is_raid_application_participant(participant_id));

create or replace function public.get_exercise_quick_match_chat_context(
  p_quick_match_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_match public.exercise_quick_matches%rowtype;
  v_partner public.users%rowtype;
  v_partner_id uuid;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;

  select q.* into v_match
  from public.exercise_quick_matches q
  where q.id = p_quick_match_id;

  if not found then
    return jsonb_build_object('ok', false, 'reason', 'match_not_found');
  end if;
  if v_match.matched_user_id is null
     or v_uid not in (v_match.requester_id, v_match.matched_user_id) then
    return jsonb_build_object('ok', false, 'reason', 'not_participant');
  end if;

  v_partner_id := case
    when v_uid = v_match.requester_id then v_match.matched_user_id
    else v_match.requester_id
  end;

  select u.* into v_partner
  from public.users u
  where u.id = v_partner_id;

  return jsonb_build_object(
    'ok', true,
    'id', v_match.id,
    'requester_id', v_match.requester_id,
    'matched_user_id', v_match.matched_user_id,
    'meeting_source', v_match.meeting_source,
    'meeting_venue_id', v_match.meeting_venue_id,
    'meeting_label', v_match.meeting_label,
    'latitude', st_y(v_match.meeting_geo::geometry),
    'longitude', st_x(v_match.meeting_geo::geometry),
    'exercise_type', v_match.exercise_type,
    'duration_minutes', v_match.duration_minutes,
    'intensity', v_match.intensity,
    'partner_level_pref', v_match.partner_level_pref,
    'max_distance_m', v_match.max_distance_m,
    'starts_at', v_match.starts_at,
    'ends_at', v_match.ends_at,
    'status', v_match.status,
    'current_stage', v_match.current_stage,
    'expires_at', v_match.expires_at,
    'matched_at', v_match.matched_at,
    'partner', jsonb_build_object(
      'id', v_partner.id,
      'nickname', v_partner.nickname,
      'profile_image_url', v_partner.profile_image_url,
      'rating', v_partner.rating,
      'is_premium', v_partner.is_premium
    )
  );
end;
$$;

create or replace function public.get_raid_application_chat_context(
  p_participant_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_participant public.raid_participants%rowtype;
  v_raid public.raids%rowtype;
  v_counterpart public.users%rowtype;
  v_is_applicant boolean;
  v_counterpart_id uuid;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;

  select p.* into v_participant
  from public.raid_participants p
  where p.id = p_participant_id;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'application_not_found');
  end if;

  select r.* into v_raid
  from public.raids r
  where r.id = v_participant.raid_id;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'raid_not_found');
  end if;

  if v_uid not in (v_participant.user_id, v_raid.organizer_id) then
    return jsonb_build_object('ok', false, 'reason', 'not_participant');
  end if;

  v_is_applicant := v_uid = v_participant.user_id;
  v_counterpart_id := case
    when v_is_applicant then v_raid.organizer_id
    else v_participant.user_id
  end;

  select u.* into v_counterpart
  from public.users u
  where u.id = v_counterpart_id;

  return jsonb_build_object(
    'ok', true,
    'is_applicant', v_is_applicant,
    'raid_id', v_raid.id,
    'raid_title', v_raid.title,
    'raid_status', v_raid.status,
    'participant', jsonb_build_object(
      'id', v_participant.id,
      'raid_id', v_participant.raid_id,
      'user_id', v_participant.user_id,
      'role', v_participant.role,
      'status', v_participant.status,
      'application_message', v_participant.application_message,
      'payment_status', v_participant.payment_status,
      'attendance_status', v_participant.attendance_status,
      'created_at', v_participant.created_at
    ),
    'counterpart', jsonb_build_object(
      'id', v_counterpart.id,
      'nickname', v_counterpart.nickname,
      'profile_image_url', v_counterpart.profile_image_url,
      'rating', v_counterpart.rating,
      'is_premium', v_counterpart.is_premium
    )
  );
end;
$$;

revoke all on function public.get_exercise_quick_match_chat_context(uuid)
  from public, anon;
revoke all on function public.get_raid_application_chat_context(uuid)
  from public, anon;
grant execute on function public.get_exercise_quick_match_chat_context(uuid)
  to authenticated;
grant execute on function public.get_raid_application_chat_context(uuid)
  to authenticated;
