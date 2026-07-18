-- Make 1:1 exercise completion rewards auditable and expose exercise-only
-- activity counts for the profile.

alter table public.point_transactions
  add column if not exists quick_match_id uuid
  references public.exercise_quick_matches(id) on delete set null;

alter table public.point_transactions
  drop constraint if exists point_transactions_reason_check;
alter table public.point_transactions
  add constraint point_transactions_reason_check
  check (reason in (
    'raid_attendance',
    'raid_hosting',
    'raid_completion_bonus',
    'raid_absence_penalty',
    'quick_match_completion',
    'reward_redemption',
    'adjustment'
  )) not valid;

create unique index if not exists point_transactions_quick_match_uidx
  on public.point_transactions(user_id, quick_match_id, reason)
  where quick_match_id is not null and reason = 'quick_match_completion';

create or replace function public.get_my_exercise_activity_summary()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_hosted_count int;
  v_raid_participated_count int;
  v_quick_match_count int;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  select count(*)::int into v_hosted_count
  from public.raids raid
  where raid.organizer_id = v_uid
    and raid.status = 'completed';

  select count(*)::int into v_raid_participated_count
  from public.raid_participants participant
  join public.raids raid on raid.id = participant.raid_id
  where participant.user_id = v_uid
    and participant.status = 'approved'
    and participant.role = 'member'
    and raid.status = 'completed';

  select count(*)::int into v_quick_match_count
  from public.exercise_quick_matches quick_match
  where quick_match.status = 'completed'
    and v_uid in (quick_match.requester_id, quick_match.matched_user_id);

  return jsonb_build_object(
    'hosted_count', v_hosted_count,
    'participated_count', v_raid_participated_count + v_quick_match_count
  );
end;
$$;

create or replace function public.complete_exercise_quick_match(
  p_quick_match_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_uid uuid := auth.uid();
  v_match public.exercise_quick_matches%rowtype;
  v_member uuid;
  v_wallet public.user_point_wallets%rowtype;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  select * into v_match
  from public.exercise_quick_matches
  where id = p_quick_match_id
  for update;

  if not found or v_uid not in (v_match.requester_id, v_match.matched_user_id) then
    return jsonb_build_object('ok', false, 'reason', 'not_allowed');
  end if;
  if v_match.status = 'completed' then
    return jsonb_build_object('ok', true, 'already_completed', true, 'points_each', 0);
  end if;
  if v_match.status not in ('matched', 'in_progress')
    or v_match.matched_user_id is null then
    return jsonb_build_object('ok', false, 'reason', 'not_completable');
  end if;

  update public.exercise_quick_matches
  set status = 'completed', completed_at = now(), updated_at = now()
  where id = v_match.id;

  foreach v_member in array array[v_match.requester_id, v_match.matched_user_id]
  loop
    if not exists (
      select 1
      from public.point_transactions tx
      where tx.user_id = v_member
        and tx.quick_match_id = v_match.id
        and tx.reason = 'quick_match_completion'
    ) then
      perform private.ensure_point_wallet(v_member);
      update public.user_point_wallets
      set available_points = available_points + 100,
          lifetime_points = lifetime_points + 100,
          updated_at = now()
      where user_id = v_member
      returning * into v_wallet;

      insert into public.point_transactions(
        user_id, quick_match_id, direction, reason, amount,
        available_after, lifetime_after, memo
      ) values (
        v_member, v_match.id, 'credit', 'quick_match_completion', 100,
        v_wallet.available_points, v_wallet.lifetime_points,
        '1대1 운동 매칭 완료'
      );
    end if;

    perform private.enqueue_push(
      v_member,
      'exercise_match_completed',
      '1대1 운동 완료',
      '함께 운동을 완료해 활동 포인트 100P를 받았어요.',
      jsonb_build_object(
        'quick_match_id', v_match.id,
        'route', '/quick-match'
      ),
      'exercise-match-completed-' || v_match.id::text || '-' || v_member::text,
      'high'
    );
  end loop;

  return jsonb_build_object('ok', true, 'points_each', 100);
end;
$$;

revoke all on function public.get_my_exercise_activity_summary()
  from public, anon;
grant execute on function public.get_my_exercise_activity_summary()
  to authenticated;

revoke all on function public.complete_exercise_quick_match(uuid)
  from public, anon;
grant execute on function public.complete_exercise_quick_match(uuid)
  to authenticated;
