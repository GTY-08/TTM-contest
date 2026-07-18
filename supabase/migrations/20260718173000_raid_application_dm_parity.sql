-- Bring premium raid applicant DMs to parity with the existing general-match
-- applicant chat: ordered messages, profile-aware bubbles, images, read state,
-- and push delivery. Existing text messages remain valid.

alter table public.raid_application_messages
  add column if not exists message_type text not null default 'text',
  add column if not exists attachment_url text,
  add column if not exists deleted_at timestamptz;

alter table public.raid_application_messages
  drop constraint if exists raid_application_messages_content_check;
alter table public.raid_application_messages
  drop constraint if exists raid_application_messages_message_type_check;
alter table public.raid_application_messages
  drop constraint if exists raid_application_messages_payload_check;

alter table public.raid_application_messages
  add constraint raid_application_messages_message_type_check
    check (message_type in ('text', 'image')) not valid,
  add constraint raid_application_messages_payload_check
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

create or replace function public.is_raid_application_participant(
  p_participant_id uuid
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
    where p.id = p_participant_id
      and auth.uid() in (p.user_id, r.organizer_id)
  );
$$;

revoke all on function public.is_raid_application_participant(uuid) from public;
grant execute on function public.is_raid_application_participant(uuid)
  to authenticated;

create table if not exists public.raid_application_reads (
  participant_id uuid not null
    references public.raid_participants(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  last_read_at timestamptz not null default now(),
  primary key (participant_id, user_id)
);

alter table public.raid_application_reads enable row level security;

drop policy if exists raid_application_reads_select
  on public.raid_application_reads;
create policy raid_application_reads_select
on public.raid_application_reads
for select
to authenticated
using (public.is_raid_application_participant(participant_id));

do $$
begin
  if exists (
    select 1 from pg_publication where pubname = 'supabase_realtime'
  ) then
    begin
      alter publication supabase_realtime
        add table public.raid_application_reads;
    exception
      when duplicate_object then null;
    end;
  end if;
end;
$$;

drop policy if exists chat_attachments_select_raid_application
  on storage.objects;
create policy chat_attachments_select_raid_application
on storage.objects
for select
to authenticated
using (
  bucket_id = 'chat_attachments'
  and (storage.foldername(name))[1] = 'raid-application'
  and public.is_raid_application_participant(
    ((storage.foldername(name))[2])::uuid
  )
);

drop policy if exists chat_attachments_insert_raid_application
  on storage.objects;
create policy chat_attachments_insert_raid_application
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'chat_attachments'
  and (storage.foldername(name))[1] = 'raid-application'
  and public.is_raid_application_participant(
    ((storage.foldername(name))[2])::uuid
  )
  and (storage.foldername(name))[3] = auth.uid()::text
);

drop function if exists public.send_raid_application_message(uuid, text);

create function public.send_raid_application_message(
  p_participant_id uuid,
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
  v_participant public.raid_participants%rowtype;
  v_raid public.raids%rowtype;
  v_type text := coalesce(nullif(trim(p_message_type), ''), 'text');
  v_content text := trim(coalesce(p_content, ''));
  v_attachment text := nullif(trim(coalesce(p_attachment_url, '')), '');
  v_message public.raid_application_messages%rowtype;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
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
    '/chat_attachments/raid-application/' || p_participant_id::text ||
    '/' || v_uid::text || '/' in v_attachment
  ) = 0 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_attachment');
  end if;

  perform public.assert_can_send_message(v_uid);

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
  if v_participant.status not in ('applied', 'waitlisted', 'approved')
     or v_raid.status in ('completed', 'cancelled') then
    return jsonb_build_object('ok', false, 'reason', 'application_closed');
  end if;

  insert into public.raid_application_messages(
    participant_id,
    sender_id,
    content,
    message_type,
    attachment_url
  ) values (
    p_participant_id,
    v_uid,
    v_content,
    v_type,
    v_attachment
  )
  returning * into v_message;

  return jsonb_build_object(
    'ok', true,
    'message_id', v_message.id,
    'created_at', v_message.created_at
  );
end;
$$;

create or replace function public.mark_raid_application_chat_read(
  p_participant_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  if not public.is_raid_application_participant(p_participant_id) then
    raise exception 'not_participant';
  end if;

  insert into public.raid_application_reads(
    participant_id,
    user_id,
    last_read_at
  ) values (
    p_participant_id,
    v_uid,
    now()
  )
  on conflict (participant_id, user_id) do update
    set last_read_at = excluded.last_read_at;
end;
$$;

create or replace function public.get_raid_application_read_state(
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
  v_organizer_id uuid;
  v_counterpart_id uuid;
  v_my_read timestamptz;
  v_counterpart_read timestamptz;
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

  select r.organizer_id into v_organizer_id
  from public.raids r
  where r.id = v_participant.raid_id;
  if v_uid = v_participant.user_id then
    v_counterpart_id := v_organizer_id;
  elsif v_uid = v_organizer_id then
    v_counterpart_id := v_participant.user_id;
  else
    return jsonb_build_object('ok', false, 'reason', 'not_participant');
  end if;

  select last_read_at into v_my_read
  from public.raid_application_reads
  where participant_id = p_participant_id and user_id = v_uid;

  select last_read_at into v_counterpart_read
  from public.raid_application_reads
  where participant_id = p_participant_id and user_id = v_counterpart_id;

  return jsonb_build_object(
    'ok', true,
    'my_last_read_at', v_my_read,
    'counterpart_last_read_at', v_counterpart_read
  );
end;
$$;

create or replace function private.trg_raid_application_messages_push_outbox()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_participant public.raid_participants%rowtype;
  v_raid public.raids%rowtype;
  v_recipient uuid;
  v_sender_nickname text;
  v_preview text;
begin
  select p.* into v_participant
  from public.raid_participants p
  where p.id = new.participant_id;
  if not found then return new; end if;

  select r.* into v_raid
  from public.raids r
  where r.id = v_participant.raid_id;
  if not found then return new; end if;

  if new.sender_id = v_participant.user_id then
    v_recipient := v_raid.organizer_id;
  elsif new.sender_id = v_raid.organizer_id then
    v_recipient := v_participant.user_id;
  else
    return new;
  end if;

  select nickname into v_sender_nickname
  from public.users
  where id = new.sender_id;
  v_preview := case
    when new.message_type = 'image' then '[사진]'
    else left(regexp_replace(new.content, '\s+', ' ', 'g'), 80)
  end;

  perform private.enqueue_push(
    v_recipient,
    'raid_application_message',
    coalesce(v_sender_nickname, '상대방'),
    v_preview,
    jsonb_build_object(
      'raid_id', v_participant.raid_id,
      'participant_id', new.participant_id,
      'message_id', new.id,
      'route', '/raid/' || v_participant.raid_id::text ||
        '/applications/' || new.participant_id::text || '/chat'
    ),
    'raid_application_chat_' || new.participant_id::text,
    'normal'
  );
  return new;
end;
$$;

drop trigger if exists trg_raid_application_messages_push_outbox
  on public.raid_application_messages;
create trigger trg_raid_application_messages_push_outbox
after insert on public.raid_application_messages
for each row
execute function private.trg_raid_application_messages_push_outbox();

revoke all on function public.send_raid_application_message(
  uuid, text, text, text
) from public;
revoke all on function public.mark_raid_application_chat_read(uuid) from public;
revoke all on function public.get_raid_application_read_state(uuid) from public;

grant execute on function public.send_raid_application_message(
  uuid, text, text, text
) to authenticated;
grant execute on function public.mark_raid_application_chat_read(uuid)
  to authenticated;
grant execute on function public.get_raid_application_read_state(uuid)
  to authenticated;
grant select on public.raid_application_messages to authenticated;
grant select on public.raid_application_reads to authenticated;

-- Reuse the existing FCM outbox for the premium matching lifecycle.
create or replace function private.trg_raid_participant_push_outbox()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_raid public.raids%rowtype;
  v_nickname text;
begin
  if new.role = 'organizer' then return new; end if;
  if tg_op = 'UPDATE' and new.status is not distinct from old.status then
    return new;
  end if;

  select r.* into v_raid from public.raids r where r.id = new.raid_id;
  if not found then return new; end if;
  select nickname into v_nickname from public.users where id = new.user_id;

  if new.status = 'applied' and v_raid.organizer_id is not null then
    perform private.enqueue_push(
      v_raid.organizer_id,
      'raid_application_received',
      '새 참가 신청이 도착했어요',
      coalesce(v_nickname, '지원자') || '님이 ' || v_raid.title || '에 지원했어요.',
      jsonb_build_object(
        'raid_id', v_raid.id,
        'participant_id', new.id,
        'route', '/raid/' || v_raid.id::text
      ),
      'raid-application-' || new.id::text,
      'high'
    );
  elsif new.status = 'approved' and tg_op = 'UPDATE' then
    perform private.enqueue_push(
      new.user_id,
      'raid_application_approved',
      '참가 신청이 수락됐어요',
      v_raid.title || ' 참가가 확정됐어요.',
      jsonb_build_object(
        'raid_id', v_raid.id,
        'participant_id', new.id,
        'route', '/raid/' || v_raid.id::text
      ),
      'raid-decision-' || new.id::text,
      'high'
    );
  elsif new.status = 'approved' and tg_op = 'INSERT'
        and v_raid.organizer_id is not null
        and v_raid.organizer_id <> new.user_id then
    perform private.enqueue_push(
      v_raid.organizer_id,
      'raid_participant_joined',
      '참가자가 확정됐어요',
      coalesce(v_nickname, '참가자') || '님이 ' || v_raid.title || '에 참가해요.',
      jsonb_build_object(
        'raid_id', v_raid.id,
        'participant_id', new.id,
        'route', '/raid/' || v_raid.id::text
      ),
      'raid-participant-' || new.id::text,
      'normal'
    );
  elsif new.status = 'waitlisted' then
    perform private.enqueue_push(
      new.user_id,
      'raid_application_waitlisted',
      '참가 신청이 대기 상태예요',
      v_raid.title || '의 자리가 나면 바로 알려드릴게요.',
      jsonb_build_object(
        'raid_id', v_raid.id,
        'participant_id', new.id,
        'route', '/raid/' || v_raid.id::text
      ),
      'raid-decision-' || new.id::text,
      'normal'
    );
  elsif new.status = 'rejected' then
    perform private.enqueue_push(
      new.user_id,
      'raid_application_rejected',
      '참가 신청 결과가 도착했어요',
      v_raid.title || ' 참가 신청이 수락되지 않았어요.',
      jsonb_build_object(
        'raid_id', v_raid.id,
        'participant_id', new.id,
        'route', '/raid/' || v_raid.id::text
      ),
      'raid-decision-' || new.id::text,
      'normal'
    );
  elsif new.status = 'cancelled' and v_raid.organizer_id is not null then
    perform private.enqueue_push(
      v_raid.organizer_id,
      'raid_participant_cancelled',
      '참가자가 취소했어요',
      coalesce(v_nickname, '참가자') || '님이 ' || v_raid.title || ' 참가를 취소했어요.',
      jsonb_build_object(
        'raid_id', v_raid.id,
        'participant_id', new.id,
        'route', '/raid/' || v_raid.id::text
      ),
      'raid-cancel-' || new.id::text,
      'normal'
    );
  end if;
  return new;
end;
$$;

drop trigger if exists trg_raid_participants_push_outbox
  on public.raid_participants;
create trigger trg_raid_participants_push_outbox
after insert or update of status on public.raid_participants
for each row
execute function private.trg_raid_participant_push_outbox();

create table if not exists private.raid_start_push_log (
  raid_id uuid not null references public.raids(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (raid_id, user_id)
);

create or replace function private.dispatch_due_raid_start_pushes()
returns integer
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_count integer := 0;
begin
  with due as (
    select r.id as raid_id, r.title, p.user_id
    from public.raids r
    join public.raid_participants p
      on p.raid_id = r.id and p.status = 'approved'
    where r.starts_at <= now()
      and r.starts_at > now() - interval '3 minutes'
      and r.status not in ('completed', 'cancelled')
  ), logged as (
    insert into private.raid_start_push_log(raid_id, user_id)
    select d.raid_id, d.user_id from due d
    on conflict (raid_id, user_id) do nothing
    returning raid_id, user_id
  ), pushed as (
    insert into public.push_outbox(
      user_id,
      push_type,
      title,
      body,
      data,
      collapse_key,
      priority
    )
    select
      l.user_id,
      'raid_started',
      '운동을 시작할 시간이에요',
      r.title || ' 참가자들과 만나 운동을 시작해 보세요.',
      jsonb_build_object(
        'raid_id', r.id,
        'route', '/raid/' || r.id::text
      ),
      'raid-start-' || r.id::text || '-' || l.user_id::text,
      'high'
    from logged l
    join public.raids r on r.id = l.raid_id
    returning 1
  )
  select count(*) into v_count from pushed;
  return v_count;
end;
$$;

do $$
declare
  v_job_id bigint;
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    select jobid into v_job_id
    from cron.job
    where jobname = 'ttm-raid-start-push';
    if v_job_id is not null then
      perform cron.unschedule(v_job_id);
    end if;
    perform cron.schedule(
      'ttm-raid-start-push',
      '* * * * *',
      'select private.dispatch_due_raid_start_pushes();'
    );
  end if;
end;
$$;
