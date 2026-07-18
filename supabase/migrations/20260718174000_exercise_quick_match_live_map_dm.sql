-- Reuse the original matched-task experience for 1:1 exercise matches:
-- both participants publish live map positions and use the full DM contract.

alter table public.exercise_match_messages
  add column if not exists message_type text not null default 'text',
  add column if not exists attachment_url text,
  add column if not exists deleted_at timestamptz;

alter table public.exercise_match_messages
  drop constraint if exists exercise_match_messages_content_check;
alter table public.exercise_match_messages
  drop constraint if exists exercise_match_messages_message_type_check;
alter table public.exercise_match_messages
  drop constraint if exists exercise_match_messages_payload_check;

alter table public.exercise_match_messages
  add constraint exercise_match_messages_message_type_check
    check (message_type in ('text', 'image')) not valid,
  add constraint exercise_match_messages_payload_check
    check (
      deleted_at is not null
      or (
        message_type = 'text'
        and length(trim(content)) between 1 and 2000
      )
      or (
        message_type = 'image'
        and nullif(trim(coalesce(attachment_url, '')), '') is not null
        and length(content) <= 2000
      )
    ) not valid;

create or replace function public.is_exercise_quick_match_participant(
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
      and q.matched_user_id is not null
      and auth.uid() in (q.requester_id, q.matched_user_id)
      and q.status in ('matched', 'in_progress', 'completed')
  );
$$;

revoke all on function public.is_exercise_quick_match_participant(uuid)
  from public;
grant execute on function public.is_exercise_quick_match_participant(uuid)
  to authenticated;

create table if not exists public.exercise_quick_match_reads (
  quick_match_id uuid not null
    references public.exercise_quick_matches(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  last_read_at timestamptz not null default now(),
  primary key (quick_match_id, user_id)
);

create table if not exists public.exercise_quick_match_locations (
  quick_match_id uuid not null
    references public.exercise_quick_matches(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  accuracy_m double precision not null default 0
    check (accuracy_m between 0 and 5000),
  captured_at timestamptz not null,
  updated_at timestamptz not null default now(),
  primary key (quick_match_id, user_id)
);

alter table public.exercise_quick_match_reads enable row level security;
alter table public.exercise_quick_match_locations enable row level security;

drop policy if exists exercise_quick_match_reads_select
  on public.exercise_quick_match_reads;
create policy exercise_quick_match_reads_select
on public.exercise_quick_match_reads
for select
to authenticated
using (public.is_exercise_quick_match_participant(quick_match_id));

drop policy if exists exercise_quick_match_locations_select
  on public.exercise_quick_match_locations;
create policy exercise_quick_match_locations_select
on public.exercise_quick_match_locations
for select
to authenticated
using (public.is_exercise_quick_match_participant(quick_match_id));

do $$
begin
  if exists (
    select 1 from pg_publication where pubname = 'supabase_realtime'
  ) then
    begin
      alter publication supabase_realtime
        add table public.exercise_quick_match_reads;
    exception when duplicate_object then null;
    end;
    begin
      alter publication supabase_realtime
        add table public.exercise_quick_match_locations;
    exception when duplicate_object then null;
    end;
  end if;
end;
$$;

drop policy if exists chat_attachments_select_quick_match on storage.objects;
create policy chat_attachments_select_quick_match
on storage.objects
for select
to authenticated
using (
  bucket_id = 'chat_attachments'
  and (storage.foldername(name))[1] = 'quick-match'
  and public.is_exercise_quick_match_participant(
    ((storage.foldername(name))[2])::uuid
  )
);

drop policy if exists chat_attachments_insert_quick_match on storage.objects;
create policy chat_attachments_insert_quick_match
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'chat_attachments'
  and (storage.foldername(name))[1] = 'quick-match'
  and public.is_exercise_quick_match_participant(
    ((storage.foldername(name))[2])::uuid
  )
  and (storage.foldername(name))[3] = auth.uid()::text
);

drop policy if exists exercise_match_messages_insert
  on public.exercise_match_messages;
revoke insert on public.exercise_match_messages from authenticated;

create or replace function public.send_exercise_quick_match_message(
  p_quick_match_id uuid,
  p_content text,
  p_message_type text default 'text',
  p_attachment_url text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_match public.exercise_quick_matches%rowtype;
  v_type text := coalesce(nullif(trim(p_message_type), ''), 'text');
  v_content text := trim(coalesce(p_content, ''));
  v_attachment text := nullif(trim(coalesce(p_attachment_url, '')), '');
  v_message public.exercise_match_messages%rowtype;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if v_type not in ('text', 'image') then
    return jsonb_build_object('ok', false, 'reason', 'invalid_message_type');
  end if;
  if v_type = 'text' and length(v_content) not between 1 and 2000 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_content');
  end if;
  if v_type = 'image' and v_attachment is null then
    return jsonb_build_object('ok', false, 'reason', 'missing_attachment');
  end if;
  if v_type = 'image' and position(
    '/chat_attachments/quick-match/' || p_quick_match_id::text ||
    '/' || v_uid::text || '/' in v_attachment
  ) = 0 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_attachment');
  end if;

  perform public.assert_can_send_message(v_uid);
  select q.* into v_match
  from public.exercise_quick_matches q
  where q.id = p_quick_match_id;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'match_not_found');
  end if;
  if v_uid not in (v_match.requester_id, v_match.matched_user_id) then
    return jsonb_build_object('ok', false, 'reason', 'not_participant');
  end if;
  if v_match.status not in ('matched', 'in_progress') then
    return jsonb_build_object('ok', false, 'reason', 'match_closed');
  end if;

  insert into public.exercise_match_messages(
    quick_match_id,
    sender_id,
    content,
    message_type,
    attachment_url
  ) values (
    p_quick_match_id,
    v_uid,
    v_content,
    v_type,
    v_attachment
  ) returning * into v_message;

  return jsonb_build_object(
    'ok', true,
    'message_id', v_message.id,
    'created_at', v_message.created_at
  );
end;
$$;

create or replace function public.mark_exercise_quick_match_chat_read(
  p_quick_match_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if not public.is_exercise_quick_match_participant(p_quick_match_id) then
    raise exception 'not_participant';
  end if;
  insert into public.exercise_quick_match_reads(
    quick_match_id,
    user_id,
    last_read_at
  ) values (
    p_quick_match_id,
    v_uid,
    now()
  )
  on conflict (quick_match_id, user_id) do update
    set last_read_at = excluded.last_read_at;
end;
$$;

create or replace function public.get_exercise_quick_match_read_state(
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
  v_counterpart uuid;
  v_my_read timestamptz;
  v_counterpart_read timestamptz;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select q.* into v_match
  from public.exercise_quick_matches q
  where q.id = p_quick_match_id;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'match_not_found');
  end if;
  if v_uid = v_match.requester_id then
    v_counterpart := v_match.matched_user_id;
  elsif v_uid = v_match.matched_user_id then
    v_counterpart := v_match.requester_id;
  else
    return jsonb_build_object('ok', false, 'reason', 'not_participant');
  end if;

  select last_read_at into v_my_read
  from public.exercise_quick_match_reads
  where quick_match_id = p_quick_match_id and user_id = v_uid;
  select last_read_at into v_counterpart_read
  from public.exercise_quick_match_reads
  where quick_match_id = p_quick_match_id and user_id = v_counterpart;

  return jsonb_build_object(
    'ok', true,
    'my_last_read_at', v_my_read,
    'counterpart_last_read_at', v_counterpart_read
  );
end;
$$;

create or replace function public.update_exercise_quick_match_location(
  p_quick_match_id uuid,
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
  v_uid uuid := auth.uid();
  v_match public.exercise_quick_matches%rowtype;
  v_reason text;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select q.* into v_match
  from public.exercise_quick_matches q
  where q.id = p_quick_match_id;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'match_not_found');
  end if;
  if v_uid not in (v_match.requester_id, v_match.matched_user_id)
     or v_match.status not in ('matched', 'in_progress') then
    return jsonb_build_object('ok', false, 'reason', 'not_active_participant');
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

  insert into public.exercise_quick_match_locations(
    quick_match_id,
    user_id,
    latitude,
    longitude,
    accuracy_m,
    captured_at,
    updated_at
  ) values (
    p_quick_match_id,
    v_uid,
    p_lat,
    p_lng,
    greatest(coalesce(p_accuracy_m, 0), 0),
    p_captured_at,
    now()
  )
  on conflict (quick_match_id, user_id) do update set
    latitude = excluded.latitude,
    longitude = excluded.longitude,
    accuracy_m = excluded.accuracy_m,
    captured_at = excluded.captured_at,
    updated_at = now();
  return jsonb_build_object('ok', true);
end;
$$;

create or replace function private.trg_exercise_match_messages_push_outbox()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_match public.exercise_quick_matches%rowtype;
  v_recipient uuid;
  v_sender_nickname text;
  v_preview text;
begin
  select q.* into v_match
  from public.exercise_quick_matches q
  where q.id = new.quick_match_id;
  if not found then return new; end if;
  if new.sender_id = v_match.requester_id then
    v_recipient := v_match.matched_user_id;
  elsif new.sender_id = v_match.matched_user_id then
    v_recipient := v_match.requester_id;
  else
    return new;
  end if;
  if v_recipient is null then return new; end if;

  select nickname into v_sender_nickname
  from public.users
  where id = new.sender_id;
  v_preview := case
    when new.message_type = 'image' then '[사진]'
    else left(regexp_replace(new.content, '\s+', ' ', 'g'), 80)
  end;
  perform private.enqueue_push(
    v_recipient,
    'exercise_match_message',
    coalesce(v_sender_nickname, '운동 파트너'),
    v_preview,
    jsonb_build_object(
      'quick_match_id', new.quick_match_id,
      'message_id', new.id,
      'route', '/quick-match/' || new.quick_match_id::text || '/chat'
    ),
    'exercise-chat-' || new.quick_match_id::text,
    'normal'
  );
  return new;
end;
$$;

drop trigger if exists trg_exercise_match_messages_push_outbox
  on public.exercise_match_messages;
create trigger trg_exercise_match_messages_push_outbox
after insert on public.exercise_match_messages
for each row
execute function private.trg_exercise_match_messages_push_outbox();

revoke all on function public.send_exercise_quick_match_message(
  uuid, text, text, text
) from public;
revoke all on function public.mark_exercise_quick_match_chat_read(uuid)
  from public;
revoke all on function public.get_exercise_quick_match_read_state(uuid)
  from public;
revoke all on function public.update_exercise_quick_match_location(
  uuid, double precision, double precision, double precision, timestamptz
) from public;

grant execute on function public.send_exercise_quick_match_message(
  uuid, text, text, text
) to authenticated;
grant execute on function public.mark_exercise_quick_match_chat_read(uuid)
  to authenticated;
grant execute on function public.get_exercise_quick_match_read_state(uuid)
  to authenticated;
grant execute on function public.update_exercise_quick_match_location(
  uuid, double precision, double precision, double precision, timestamptz
) to authenticated;
grant select on public.exercise_match_messages to authenticated;
grant select on public.exercise_quick_match_reads to authenticated;
grant select on public.exercise_quick_match_locations to authenticated;
