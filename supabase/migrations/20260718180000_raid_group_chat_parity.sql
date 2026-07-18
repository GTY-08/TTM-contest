-- Bring raid group chat to feature parity with the existing TTM DM surfaces.

alter table public.raid_messages
  add column if not exists message_type text not null default 'text',
  add column if not exists attachment_url text;

alter table public.raid_messages
  drop constraint if exists raid_messages_content_check;
alter table public.raid_messages
  drop constraint if exists raid_messages_message_type_check;
alter table public.raid_messages
  drop constraint if exists raid_messages_payload_check;

alter table public.raid_messages
  add constraint raid_messages_message_type_check
    check (message_type in ('text', 'image')) not valid,
  add constraint raid_messages_payload_check
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

drop policy if exists chat_attachments_select_raid_group on storage.objects;
create policy chat_attachments_select_raid_group
on storage.objects
for select
to authenticated
using (
  bucket_id = 'chat_attachments'
  and (storage.foldername(name))[1] = 'raid-group'
  and public.is_raid_member(((storage.foldername(name))[2])::uuid)
);

drop policy if exists chat_attachments_insert_raid_group on storage.objects;
create policy chat_attachments_insert_raid_group
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'chat_attachments'
  and (storage.foldername(name))[1] = 'raid-group'
  and public.is_raid_member(((storage.foldername(name))[2])::uuid)
  and (storage.foldername(name))[3] = (select auth.uid())::text
);

create or replace function public.send_raid_group_message(
  p_raid_id uuid,
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
  v_raid public.raids%rowtype;
  v_type text := coalesce(nullif(trim(p_message_type), ''), 'text');
  v_content text := trim(coalesce(p_content, ''));
  v_attachment text := nullif(trim(coalesce(p_attachment_url, '')), '');
  v_message public.raid_messages%rowtype;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if not public.is_raid_member(p_raid_id, v_uid) then
    return jsonb_build_object('ok', false, 'reason', 'not_raid_member');
  end if;
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
    '/chat_attachments/raid-group/' || p_raid_id::text ||
    '/' || v_uid::text || '/' in v_attachment
  ) = 0 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_attachment');
  end if;

  perform public.assert_can_send_message(v_uid);
  select r.* into v_raid from public.raids r where r.id = p_raid_id;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'raid_not_found');
  end if;
  if v_raid.status in ('completed', 'cancelled') then
    return jsonb_build_object('ok', false, 'reason', 'raid_closed');
  end if;

  insert into public.raid_messages(
    raid_id,
    sender_id,
    content,
    message_type,
    attachment_url
  ) values (
    p_raid_id,
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

create or replace function public.mark_raid_message_deleted(p_message_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_message public.raid_messages%rowtype;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select m.* into v_message
  from public.raid_messages m
  where m.id = p_message_id;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'message_not_found');
  end if;
  if v_message.sender_id <> v_uid then
    return jsonb_build_object('ok', false, 'reason', 'not_message_sender');
  end if;

  update public.raid_messages
  set deleted_at = coalesce(deleted_at, now())
  where id = p_message_id;
  return jsonb_build_object('ok', true);
end;
$$;

create table if not exists public.raid_message_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.users(id) on delete cascade,
  reported_user_id uuid not null references public.users(id) on delete cascade,
  raid_id uuid not null references public.raids(id) on delete cascade,
  message_id uuid not null references public.raid_messages(id) on delete cascade,
  category text not null check (length(trim(category)) between 1 and 100),
  description text check (description is null or length(description) <= 1000),
  message_snapshot text not null,
  status text not null default 'pending'
    check (status in ('pending', 'reviewing', 'resolved', 'dismissed')),
  reviewed_by uuid references public.users(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  unique (reporter_id, message_id)
);

alter table public.raid_message_reports enable row level security;
revoke all on table public.raid_message_reports from public, anon, authenticated;
grant select on table public.raid_message_reports to authenticated;
grant all on table public.raid_message_reports to service_role;

drop policy if exists raid_message_reports_admin_select
  on public.raid_message_reports;
create policy raid_message_reports_admin_select
on public.raid_message_reports
for select
to authenticated
using (public.is_admin());

create or replace function public.submit_raid_message_report(
  p_message_id uuid,
  p_category text,
  p_description text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_message public.raid_messages%rowtype;
  v_snapshot text;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if length(trim(coalesce(p_category, ''))) not between 1 and 100 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_category');
  end if;
  if length(coalesce(p_description, '')) > 1000 then
    return jsonb_build_object('ok', false, 'reason', 'description_too_long');
  end if;

  select m.* into v_message
  from public.raid_messages m
  where m.id = p_message_id;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'message_not_found');
  end if;
  if not public.is_raid_member(v_message.raid_id, v_uid) then
    return jsonb_build_object('ok', false, 'reason', 'not_raid_member');
  end if;
  if v_message.sender_id = v_uid then
    return jsonb_build_object('ok', false, 'reason', 'cannot_report_self');
  end if;

  v_snapshot := case
    when v_message.message_type = 'image' then '[사진] ' || v_message.content
    else v_message.content
  end;

  insert into public.raid_message_reports(
    reporter_id,
    reported_user_id,
    raid_id,
    message_id,
    category,
    description,
    message_snapshot
  ) values (
    v_uid,
    v_message.sender_id,
    v_message.raid_id,
    v_message.id,
    trim(p_category),
    nullif(trim(coalesce(p_description, '')), ''),
    left(v_snapshot, 2000)
  )
  on conflict (reporter_id, message_id) do nothing;

  if not found then
    return jsonb_build_object('ok', false, 'reason', 'already_reported');
  end if;
  return jsonb_build_object('ok', true);
end;
$$;

create or replace function private.trg_raid_group_messages_push_outbox()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_recipient uuid;
  v_sender_nickname text;
  v_preview text;
begin
  select nickname into v_sender_nickname
  from public.users
  where id = new.sender_id;

  v_preview := case
    when new.message_type = 'image' then '[사진]'
    else left(regexp_replace(new.content, '\s+', ' ', 'g'), 80)
  end;

  for v_recipient in
    select p.user_id
    from public.raid_participants p
    where p.raid_id = new.raid_id
      and p.status = 'approved'
      and p.user_id <> new.sender_id
  loop
    perform private.enqueue_push(
      v_recipient,
      'raid_group_message',
      '레이드 단체채팅',
      coalesce(v_sender_nickname, '참가자') || ': ' || v_preview,
      jsonb_build_object(
        'raid_id', new.raid_id,
        'message_id', new.id,
        'route', '/raid/' || new.raid_id::text || '/chat'
      ),
      'raid-group-message-' || new.id::text,
      'normal'
    );
  end loop;
  return new;
end;
$$;

drop trigger if exists trg_raid_group_messages_push_outbox
  on public.raid_messages;
create trigger trg_raid_group_messages_push_outbox
after insert on public.raid_messages
for each row
execute function private.trg_raid_group_messages_push_outbox();

revoke all on function public.send_raid_group_message(
  uuid, text, text, text
) from public, anon;
revoke all on function public.mark_raid_message_deleted(uuid)
  from public, anon;
revoke all on function public.submit_raid_message_report(uuid, text, text)
  from public, anon;

grant execute on function public.send_raid_group_message(
  uuid, text, text, text
) to authenticated;
grant execute on function public.mark_raid_message_deleted(uuid)
  to authenticated;
grant execute on function public.submit_raid_message_report(uuid, text, text)
  to authenticated;
