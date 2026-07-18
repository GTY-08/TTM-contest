-- TTM exercise raids, attendance, activity points, and reward catalog.
-- This migration is additive: legacy errand tables and RPCs remain untouched.

create extension if not exists postgis;

create table if not exists public.exercise_venues (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) between 2 and 80),
  address text not null check (length(trim(address)) between 2 and 200),
  category text not null default 'sports_facility',
  geo geography(point, 4326) not null,
  supported_exercises text[] not null default array['walking']::text[],
  active_days smallint[] not null default array[1,2,3,4,5,6,7]::smallint[],
  auto_start_times time[] not null default array['18:00'::time],
  default_duration_minutes int not null default 60
    check (default_duration_minutes between 20 and 240),
  recommended_min_participants int not null default 3
    check (recommended_min_participants between 3 and 100),
  max_participants int not null default 12
    check (max_participants between 3 and 200),
  default_intensity text not null default 'medium'
    check (default_intensity in ('low', 'medium', 'high')),
  beginner_friendly boolean not null default true,
  image_url text,
  is_active boolean not null default true,
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (recommended_min_participants <= max_participants),
  check (cardinality(supported_exercises) > 0),
  check (cardinality(auto_start_times) > 0)
);

create index if not exists exercise_venues_geo_idx
  on public.exercise_venues using gist (geo);
create index if not exists exercise_venues_active_idx
  on public.exercise_venues (is_active, name);

create table if not exists public.raids (
  id uuid primary key default gen_random_uuid(),
  venue_id uuid not null references public.exercise_venues(id) on delete restrict,
  source text not null check (source in ('auto', 'premium')),
  organizer_id uuid references public.users(id) on delete restrict,
  exercise_type text not null,
  title text not null check (length(trim(title)) between 2 and 100),
  description text not null default '',
  starts_at timestamptz not null,
  duration_minutes int not null check (duration_minutes between 20 and 240),
  min_participants int not null check (min_participants between 3 and 100),
  max_participants int not null check (max_participants between 3 and 200),
  intensity text not null default 'medium'
    check (intensity in ('low', 'medium', 'high')),
  beginner_friendly boolean not null default true,
  participation_fee numeric(12,0) not null default 0
    check (participation_fee between 0 and 100000),
  free_cancel_at timestamptz,
  status text not null default 'recruiting'
    check (status in (
      'scheduled', 'recruiting', 'confirmed', 'in_progress',
      'attendance', 'completed', 'cancelled'
    )),
  cancel_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz,
  cancelled_at timestamptz,
  check (min_participants <= max_participants),
  check (
    (source = 'auto' and organizer_id is null and participation_fee = 0)
    or (source = 'premium' and organizer_id is not null)
  )
);

create unique index if not exists raids_auto_venue_start_uidx
  on public.raids (venue_id, starts_at)
  where source = 'auto' and status <> 'cancelled';
create index if not exists raids_status_start_idx
  on public.raids (status, starts_at);
create index if not exists raids_organizer_idx
  on public.raids (organizer_id, starts_at desc);

create table if not exists public.raid_participants (
  id uuid primary key default gen_random_uuid(),
  raid_id uuid not null references public.raids(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  role text not null default 'member' check (role in ('organizer', 'member')),
  status text not null default 'applied'
    check (status in ('applied', 'waitlisted', 'approved', 'rejected', 'cancelled')),
  application_message text,
  payment_status text not null default 'not_required'
    check (payment_status in (
      'not_required', 'payment_pending', 'paid', 'held',
      'settlement_pending', 'settled', 'refund_pending', 'refunded'
    )),
  attendance_status text not null default 'pending'
    check (attendance_status in (
      'pending', 'present', 'late', 'left_early', 'absent', 'exempt', 'disputed'
    )),
  approved_by uuid references public.users(id) on delete set null,
  approved_at timestamptz,
  cancelled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (raid_id, user_id)
);

create index if not exists raid_participants_raid_status_idx
  on public.raid_participants (raid_id, status, created_at);
create index if not exists raid_participants_user_idx
  on public.raid_participants (user_id, created_at desc);

create table if not exists public.raid_messages (
  id uuid primary key default gen_random_uuid(),
  raid_id uuid not null references public.raids(id) on delete cascade,
  sender_id uuid not null references public.users(id) on delete cascade,
  content text not null check (length(trim(content)) between 1 and 2000),
  created_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index if not exists raid_messages_raid_created_idx
  on public.raid_messages (raid_id, created_at);

create table if not exists public.raid_chat_reads (
  raid_id uuid not null references public.raids(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  last_read_at timestamptz not null default now(),
  primary key (raid_id, user_id)
);

create table if not exists public.raid_attendance_votes (
  id uuid primary key default gen_random_uuid(),
  raid_id uuid not null references public.raids(id) on delete cascade,
  target_participant_id uuid not null references public.raid_participants(id) on delete cascade,
  voter_id uuid not null references public.users(id) on delete cascade,
  vote text not null check (vote in ('present', 'cannot_confirm', 'absent')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (target_participant_id, voter_id)
);

create table if not exists public.raid_attendance_appeals (
  id uuid primary key default gen_random_uuid(),
  raid_id uuid not null references public.raids(id) on delete cascade,
  participant_id uuid not null references public.raid_participants(id) on delete cascade,
  reason text not null check (length(trim(reason)) between 5 and 1000),
  status text not null default 'open'
    check (status in ('open', 'upheld', 'dismissed')),
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  unique (participant_id, status)
);

create table if not exists public.raid_fee_holds (
  id uuid primary key default gen_random_uuid(),
  raid_id uuid not null references public.raids(id) on delete cascade,
  participant_id uuid not null unique references public.raid_participants(id) on delete cascade,
  payer_id uuid not null references public.users(id) on delete restrict,
  organizer_id uuid not null references public.users(id) on delete restrict,
  amount numeric(12,0) not null check (amount > 0),
  status text not null default 'held'
    check (status in ('held', 'settlement_pending', 'settled', 'refunded')),
  held_at timestamptz not null default now(),
  settled_at timestamptz,
  refunded_at timestamptz,
  updated_at timestamptz not null default now()
);

create table if not exists public.raid_fee_transactions (
  id uuid primary key default gen_random_uuid(),
  raid_id uuid not null references public.raids(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  direction text not null check (direction in ('hold', 'credit', 'refund')),
  amount numeric(12,0) not null check (amount > 0),
  reason text not null check (reason in ('participation_fee', 'organizer_settlement', 'raid_refund')),
  balance_after numeric(12,0) not null,
  created_at timestamptz not null default now()
);

create index if not exists raid_fee_transactions_user_idx
  on public.raid_fee_transactions (user_id, created_at desc);

create table if not exists public.user_point_wallets (
  user_id uuid primary key references public.users(id) on delete cascade,
  available_points int not null default 0 check (available_points >= 0),
  lifetime_points int not null default 0 check (lifetime_points >= 0),
  updated_at timestamptz not null default now()
);

create table if not exists public.point_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  raid_id uuid references public.raids(id) on delete set null,
  direction text not null check (direction in ('credit', 'debit')),
  reason text not null check (reason in ('raid_attendance', 'raid_hosting', 'reward_redemption', 'adjustment')),
  amount int not null check (amount > 0),
  available_after int not null check (available_after >= 0),
  lifetime_after int not null check (lifetime_after >= 0),
  memo text,
  created_at timestamptz not null default now()
);

create unique index if not exists point_transactions_raid_reward_uidx
  on public.point_transactions (user_id, raid_id, reason)
  where raid_id is not null and reason in ('raid_attendance', 'raid_hosting');
create index if not exists point_transactions_user_idx
  on public.point_transactions (user_id, created_at desc);

create table if not exists public.activity_level_rules (
  level int primary key check (level between 1 and 100),
  title text not null,
  required_lifetime_points int not null unique check (required_lifetime_points >= 0)
);

create table if not exists public.reward_catalog_items (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text not null default '',
  category text not null default 'gifticon',
  point_cost int not null check (point_cost > 0),
  stock int not null default 0 check (stock >= 0),
  icon_key text not null default 'gift',
  accent_color text not null default '#0B7A75',
  is_active boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.reward_redemptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  catalog_item_id uuid not null references public.reward_catalog_items(id) on delete restrict,
  points_spent int not null check (points_spent > 0),
  status text not null default 'issued' check (status in ('requested', 'issued', 'cancelled')),
  issue_code text not null unique,
  issued_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists reward_redemptions_user_idx
  on public.reward_redemptions (user_id, created_at desc);

alter table public.exercise_venues enable row level security;
alter table public.raids enable row level security;
alter table public.raid_participants enable row level security;
alter table public.raid_messages enable row level security;
alter table public.raid_chat_reads enable row level security;
alter table public.raid_attendance_votes enable row level security;
alter table public.raid_attendance_appeals enable row level security;
alter table public.raid_fee_holds enable row level security;
alter table public.raid_fee_transactions enable row level security;
alter table public.user_point_wallets enable row level security;
alter table public.point_transactions enable row level security;
alter table public.activity_level_rules enable row level security;
alter table public.reward_catalog_items enable row level security;
alter table public.reward_redemptions enable row level security;

revoke all on table public.exercise_venues, public.raids, public.raid_participants,
  public.raid_messages, public.raid_chat_reads, public.raid_attendance_votes,
  public.raid_attendance_appeals, public.raid_fee_holds, public.raid_fee_transactions,
  public.user_point_wallets, public.point_transactions, public.activity_level_rules,
  public.reward_catalog_items, public.reward_redemptions
from public, anon, authenticated;

grant select on table public.exercise_venues, public.raids, public.activity_level_rules,
  public.reward_catalog_items to authenticated;
grant select on table public.raid_participants, public.raid_messages, public.raid_chat_reads,
  public.raid_attendance_votes, public.raid_attendance_appeals, public.raid_fee_holds,
  public.raid_fee_transactions, public.user_point_wallets, public.point_transactions,
  public.reward_redemptions to authenticated;
grant insert on table public.raid_messages to authenticated;
grant all on all tables in schema public to service_role;

create or replace function public.is_raid_member(p_raid_id uuid, p_user_id uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.raid_participants p
    where p.raid_id = p_raid_id
      and p.user_id = p_user_id
      and p.status = 'approved'
  );
$$;

revoke all on function public.is_raid_member(uuid, uuid) from public, anon;
grant execute on function public.is_raid_member(uuid, uuid) to authenticated;

create policy exercise_venues_select on public.exercise_venues
for select to authenticated
using (is_active or public.is_admin());

create policy raids_select on public.raids
for select to authenticated using (true);

create policy raid_participants_select on public.raid_participants
for select to authenticated
using (
  user_id = (select auth.uid())
  or public.is_raid_member(raid_id)
  or exists (
    select 1 from public.raids r
    where r.id = raid_participants.raid_id
      and r.organizer_id = (select auth.uid())
  )
  or public.is_admin()
);

create policy raid_messages_select on public.raid_messages
for select to authenticated
using (public.is_raid_member(raid_id) or public.is_admin());

create policy raid_messages_insert on public.raid_messages
for insert to authenticated
with check (
  sender_id = (select auth.uid())
  and public.is_raid_member(raid_id)
  and exists (
    select 1 from public.raids r
    where r.id = raid_messages.raid_id
      and r.status not in ('completed', 'cancelled')
  )
);

create policy raid_chat_reads_select on public.raid_chat_reads
for select to authenticated
using (public.is_raid_member(raid_id) or public.is_admin());

create policy raid_attendance_votes_select on public.raid_attendance_votes
for select to authenticated
using (public.is_raid_member(raid_id) or public.is_admin());

create policy raid_attendance_appeals_select on public.raid_attendance_appeals
for select to authenticated
using (public.is_raid_member(raid_id) or public.is_admin());

create policy raid_fee_holds_select on public.raid_fee_holds
for select to authenticated
using (
  payer_id = (select auth.uid())
  or organizer_id = (select auth.uid())
  or public.is_admin()
);

create policy raid_fee_transactions_select on public.raid_fee_transactions
for select to authenticated
using (user_id = (select auth.uid()) or public.is_admin());

create policy user_point_wallets_select on public.user_point_wallets
for select to authenticated
using (user_id = (select auth.uid()) or public.is_admin());

create policy point_transactions_select on public.point_transactions
for select to authenticated
using (user_id = (select auth.uid()) or public.is_admin());

create policy activity_level_rules_select on public.activity_level_rules
for select to authenticated using (true);

create policy reward_catalog_items_select on public.reward_catalog_items
for select to authenticated using (is_active or public.is_admin());

create policy reward_redemptions_select on public.reward_redemptions
for select to authenticated
using (user_id = (select auth.uid()) or public.is_admin());

create or replace function private.ensure_point_wallet(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public, private
as $$
begin
  insert into public.user_point_wallets(user_id)
  values (p_user_id)
  on conflict (user_id) do nothing;
end;
$$;

create or replace function private.ensure_point_wallet_for_user()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
begin
  perform private.ensure_point_wallet(new.id);
  return new;
end;
$$;

drop trigger if exists ensure_point_wallet_for_user on public.users;
create trigger ensure_point_wallet_for_user
after insert on public.users
for each row execute function private.ensure_point_wallet_for_user();

insert into public.user_point_wallets(user_id)
select id from public.users
on conflict (user_id) do nothing;

create or replace function private.refresh_raid_recruitment(p_raid_id uuid)
returns void
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_raid public.raids%rowtype;
  v_count int;
begin
  select * into v_raid from public.raids where id = p_raid_id for update;
  if not found or v_raid.status not in ('scheduled', 'recruiting', 'confirmed') then
    return;
  end if;
  select count(*) into v_count
  from public.raid_participants
  where raid_id = p_raid_id and status = 'approved';

  update public.raids
  set status = case when v_count >= v_raid.min_participants then 'confirmed' else 'recruiting' end,
      updated_at = now()
  where id = p_raid_id;
end;
$$;

create or replace function private.award_raid_points(
  p_user_id uuid,
  p_raid_id uuid,
  p_reason text
)
returns int
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_raid public.raids%rowtype;
  v_wallet public.user_point_wallets%rowtype;
  v_today int;
  v_wanted int;
  v_award int;
begin
  if p_reason not in ('raid_attendance', 'raid_hosting') then
    raise exception 'invalid_point_reason';
  end if;
  if exists (
    select 1 from public.point_transactions
    where user_id = p_user_id and raid_id = p_raid_id and reason = p_reason
  ) then
    return 0;
  end if;

  select * into v_raid from public.raids where id = p_raid_id;
  if not found then return 0; end if;

  perform private.ensure_point_wallet(p_user_id);
  select * into v_wallet
  from public.user_point_wallets where user_id = p_user_id for update;

  select coalesce(sum(amount), 0)::int into v_today
  from public.point_transactions
  where user_id = p_user_id
    and direction = 'credit'
    and reason in ('raid_attendance', 'raid_hosting')
    and created_at >= date_trunc('day', now() at time zone 'Asia/Seoul') at time zone 'Asia/Seoul';

  v_wanted := 100 + floor(v_raid.duration_minutes / 10.0)::int * 20;
  v_award := greatest(0, least(v_wanted, 500 - v_today));
  if v_award <= 0 then return 0; end if;

  update public.user_point_wallets
  set available_points = available_points + v_award,
      lifetime_points = lifetime_points + v_award,
      updated_at = now()
  where user_id = p_user_id
  returning * into v_wallet;

  insert into public.point_transactions(
    user_id, raid_id, direction, reason, amount,
    available_after, lifetime_after, memo
  ) values (
    p_user_id, p_raid_id, 'credit', p_reason, v_award,
    v_wallet.available_points, v_wallet.lifetime_points,
    case when p_reason = 'raid_hosting' then '레이드 운영 포인트' else '운동 참여 포인트' end
  );
  return v_award;
end;
$$;

create or replace function private.refund_raid_hold(p_hold_id uuid)
returns void
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_hold public.raid_fee_holds%rowtype;
  v_balance numeric;
begin
  select * into v_hold from public.raid_fee_holds where id = p_hold_id for update;
  if not found or v_hold.status <> 'held' then return; end if;

  update public.demo_wallets
  set balance = balance + v_hold.amount,
      escrow_hold = greatest(0, escrow_hold - v_hold.amount),
      total_spent = greatest(0, total_spent - v_hold.amount),
      updated_at = now()
  where user_id = v_hold.payer_id
  returning balance into v_balance;

  update public.raid_fee_holds
  set status = 'refunded', refunded_at = now(), updated_at = now()
  where id = v_hold.id;
  update public.raid_participants
  set payment_status = 'refunded', updated_at = now()
  where id = v_hold.participant_id;
  insert into public.raid_fee_transactions(raid_id, user_id, direction, amount, reason, balance_after)
  values (v_hold.raid_id, v_hold.payer_id, 'refund', v_hold.amount, 'raid_refund', v_balance);
end;
$$;

create or replace function private.cancel_raid_internal(p_raid_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = public, private
as $$
declare v_hold record;
begin
  update public.raids
  set status = 'cancelled', cancel_reason = p_reason,
      cancelled_at = now(), updated_at = now()
  where id = p_raid_id and status not in ('completed', 'cancelled');

  for v_hold in
    select id from public.raid_fee_holds where raid_id = p_raid_id and status = 'held'
  loop
    perform private.refund_raid_hold(v_hold.id);
  end loop;
end;
$$;

create or replace function public.list_exercise_venues()
returns jsonb
language sql
stable
security invoker
set search_path = public
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', v.id,
    'name', v.name,
    'address', v.address,
    'category', v.category,
    'latitude', st_y(v.geo::geometry),
    'longitude', st_x(v.geo::geometry),
    'supported_exercises', v.supported_exercises,
    'default_duration_minutes', v.default_duration_minutes,
    'recommended_min_participants', v.recommended_min_participants,
    'max_participants', v.max_participants,
    'default_intensity', v.default_intensity,
    'beginner_friendly', v.beginner_friendly,
    'image_url', v.image_url
  ) order by v.name), '[]'::jsonb)
  from public.exercise_venues v
  where v.is_active;
$$;

create or replace function public.list_nearby_raids(
  p_lat double precision default null,
  p_lng double precision default null,
  p_radius_m int default 10000
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_result jsonb;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select coalesce(jsonb_agg(item order by (item->>'starts_at')::timestamptz), '[]'::jsonb)
  into v_result
  from (
    select jsonb_build_object(
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
      'participant_count', count(p.id) filter (where p.status = 'approved'),
      'intensity', r.intensity,
      'beginner_friendly', r.beginner_friendly,
      'participation_fee', r.participation_fee,
      'free_cancel_at', r.free_cancel_at,
      'status', r.status,
      'venue', jsonb_build_object(
        'id', v.id, 'name', v.name, 'address', v.address,
        'latitude', st_y(v.geo::geometry), 'longitude', st_x(v.geo::geometry)
      ),
      'my_participant', (
        select jsonb_build_object('id', me.id, 'status', me.status, 'role', me.role,
          'payment_status', me.payment_status, 'attendance_status', me.attendance_status)
        from public.raid_participants me
        where me.raid_id = r.id and me.user_id = v_uid
      )
    ) as item
    from public.raids r
    join public.exercise_venues v on v.id = r.venue_id
    left join public.raid_participants p on p.raid_id = r.id
    where r.status in ('scheduled', 'recruiting', 'confirmed', 'in_progress', 'attendance')
      and r.starts_at >= now() - interval '4 hours'
      and (
        p_lat is null or p_lng is null
        or st_dwithin(
          v.geo,
          st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography,
          greatest(500, least(coalesce(p_radius_m, 10000), 50000))
        )
      )
    group by r.id, v.id
  ) q;
  return v_result;
end;
$$;

create or replace function public.get_raid_detail(p_raid_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare v_uid uuid := auth.uid(); v_result jsonb;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select jsonb_build_object(
    'raid', to_jsonb(r),
    'venue', jsonb_build_object(
      'id', v.id, 'name', v.name, 'address', v.address,
      'latitude', st_y(v.geo::geometry), 'longitude', st_x(v.geo::geometry),
      'supported_exercises', v.supported_exercises
    ),
    'organizer', case when u.id is null then null else jsonb_build_object(
      'id', u.id, 'nickname', u.nickname, 'profile_image_url', u.profile_image_url,
      'rating', u.rating, 'is_premium', u.is_premium
    ) end,
    'participants', case
      when public.is_raid_member(r.id, v_uid) or r.organizer_id = v_uid or public.is_admin()
      then coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', p.id, 'user_id', p.user_id, 'role', p.role, 'status', p.status,
          'payment_status', p.payment_status, 'attendance_status', p.attendance_status,
          'application_message', p.application_message,
          'nickname', pu.nickname, 'profile_image_url', pu.profile_image_url,
          'rating', pu.rating, 'is_premium', pu.is_premium
        ) order by p.created_at)
        from public.raid_participants p
        join public.users pu on pu.id = p.user_id
        where p.raid_id = r.id
      ), '[]'::jsonb)
      else '[]'::jsonb
    end,
    'participant_count', (
      select count(*) from public.raid_participants p
      where p.raid_id = r.id and p.status = 'approved'
    ),
    'my_participant', (
      select to_jsonb(p) from public.raid_participants p
      where p.raid_id = r.id and p.user_id = v_uid
    )
  ) into v_result
  from public.raids r
  join public.exercise_venues v on v.id = r.venue_id
  left join public.users u on u.id = r.organizer_id
  where r.id = p_raid_id;
  return v_result;
end;
$$;

create or replace function public.create_premium_raid(
  p_venue_id uuid,
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
declare v_uid uuid := auth.uid(); v_raid public.raids%rowtype; v_venue public.exercise_venues%rowtype;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if not coalesce((select is_premium from public.users where id = v_uid), false) then
    raise exception 'premium_required';
  end if;
  select * into v_venue from public.exercise_venues where id = p_venue_id and is_active;
  if not found then raise exception 'venue_not_found'; end if;
  if not (p_exercise_type = any(v_venue.supported_exercises)) then raise exception 'exercise_not_supported'; end if;
  if p_starts_at <= now() + interval '10 minutes' then raise exception 'start_time_too_soon'; end if;
  if p_min_participants < 3 or p_max_participants < p_min_participants then raise exception 'invalid_capacity'; end if;

  insert into public.raids(
    venue_id, source, organizer_id, exercise_type, title, description,
    starts_at, duration_minutes, min_participants, max_participants,
    intensity, beginner_friendly, participation_fee, free_cancel_at, status
  ) values (
    p_venue_id, 'premium', v_uid, trim(p_exercise_type), trim(p_title), trim(coalesce(p_description, '')),
    p_starts_at, p_duration_minutes, p_min_participants, p_max_participants,
    p_intensity, coalesce(p_beginner_friendly, true), floor(greatest(coalesce(p_participation_fee, 0), 0)),
    p_starts_at - interval '2 hours', 'recruiting'
  ) returning * into v_raid;

  insert into public.raid_participants(
    raid_id, user_id, role, status, payment_status, attendance_status, approved_by, approved_at
  ) values (v_raid.id, v_uid, 'organizer', 'approved', 'not_required', 'exempt', v_uid, now());
  perform private.refresh_raid_recruitment(v_raid.id);
  return jsonb_build_object('ok', true, 'raid_id', v_raid.id);
end;
$$;

create or replace function public.join_free_raid(p_raid_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, private
as $$
declare v_uid uuid := auth.uid(); v_raid public.raids%rowtype; v_count int; v_participant public.raid_participants%rowtype;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into v_raid from public.raids where id = p_raid_id for update;
  if not found then return jsonb_build_object('ok', false, 'reason', 'raid_not_found'); end if;
  if v_raid.source <> 'auto' or v_raid.participation_fee <> 0 then return jsonb_build_object('ok', false, 'reason', 'not_free_raid'); end if;
  if v_raid.status not in ('recruiting', 'confirmed') or v_raid.starts_at <= now() then
    return jsonb_build_object('ok', false, 'reason', 'raid_not_joinable');
  end if;
  select count(*) into v_count from public.raid_participants where raid_id = p_raid_id and status = 'approved';
  if v_count >= v_raid.max_participants then return jsonb_build_object('ok', false, 'reason', 'raid_full'); end if;

  insert into public.raid_participants(
    raid_id, user_id, role, status, payment_status, attendance_status, approved_at
  ) values (p_raid_id, v_uid, 'member', 'approved', 'not_required', 'pending', now())
  on conflict (raid_id, user_id) do update
    set status = 'approved', payment_status = 'not_required', attendance_status = 'pending',
        cancelled_at = null, approved_at = now(), updated_at = now()
    where raid_participants.status in ('cancelled', 'rejected')
  returning * into v_participant;
  if v_participant.id is null then return jsonb_build_object('ok', false, 'reason', 'already_joined'); end if;
  perform private.refresh_raid_recruitment(p_raid_id);
  return jsonb_build_object('ok', true, 'participant_id', v_participant.id);
end;
$$;

create or replace function public.apply_premium_raid(p_raid_id uuid, p_message text default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare v_uid uuid := auth.uid(); v_raid public.raids%rowtype; v_participant public.raid_participants%rowtype;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into v_raid from public.raids where id = p_raid_id for update;
  if not found then return jsonb_build_object('ok', false, 'reason', 'raid_not_found'); end if;
  if v_raid.source <> 'premium' then return jsonb_build_object('ok', false, 'reason', 'not_premium_raid'); end if;
  if v_raid.organizer_id = v_uid then return jsonb_build_object('ok', false, 'reason', 'organizer_cannot_apply'); end if;
  if v_raid.status not in ('recruiting', 'confirmed') or v_raid.starts_at <= now() then
    return jsonb_build_object('ok', false, 'reason', 'raid_not_joinable');
  end if;
  insert into public.raid_participants(raid_id, user_id, role, status, application_message)
  values (p_raid_id, v_uid, 'member', 'applied', nullif(trim(coalesce(p_message, '')), ''))
  on conflict (raid_id, user_id) do update
    set status = 'applied', application_message = excluded.application_message,
        payment_status = 'not_required', attendance_status = 'pending',
        cancelled_at = null, updated_at = now()
    where raid_participants.status in ('cancelled', 'rejected')
  returning * into v_participant;
  if v_participant.id is null then return jsonb_build_object('ok', false, 'reason', 'already_applied'); end if;
  return jsonb_build_object('ok', true, 'participant_id', v_participant.id);
end;
$$;

create or replace function public.review_raid_application(p_participant_id uuid, p_decision text)
returns jsonb
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_uid uuid := auth.uid();
  v_participant public.raid_participants%rowtype;
  v_raid public.raids%rowtype;
  v_count int;
  v_balance numeric;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_decision not in ('approved', 'waitlisted', 'rejected') then raise exception 'invalid_decision'; end if;
  select * into v_participant from public.raid_participants where id = p_participant_id for update;
  if not found then return jsonb_build_object('ok', false, 'reason', 'participant_not_found'); end if;
  select * into v_raid from public.raids where id = v_participant.raid_id for update;
  if v_raid.organizer_id <> v_uid then return jsonb_build_object('ok', false, 'reason', 'not_organizer'); end if;
  if v_participant.role = 'organizer' then return jsonb_build_object('ok', false, 'reason', 'invalid_participant'); end if;
  if v_participant.status not in ('applied', 'waitlisted') then return jsonb_build_object('ok', false, 'reason', 'already_reviewed'); end if;

  if p_decision = 'approved' then
    select count(*) into v_count from public.raid_participants
    where raid_id = v_raid.id and status = 'approved';
    if v_count >= v_raid.max_participants then return jsonb_build_object('ok', false, 'reason', 'raid_full'); end if;

    if v_raid.participation_fee > 0 then
      perform private.ensure_demo_wallet(v_participant.user_id);
      select balance into v_balance from public.demo_wallets
      where user_id = v_participant.user_id for update;
      if coalesce(v_balance, 0) < v_raid.participation_fee then
        return jsonb_build_object('ok', false, 'reason', 'insufficient_balance');
      end if;
      update public.demo_wallets
      set balance = balance - v_raid.participation_fee,
          escrow_hold = escrow_hold + v_raid.participation_fee,
          total_spent = total_spent + v_raid.participation_fee,
          updated_at = now()
      where user_id = v_participant.user_id
      returning balance into v_balance;
      insert into public.raid_fee_holds(raid_id, participant_id, payer_id, organizer_id, amount)
      values (v_raid.id, v_participant.id, v_participant.user_id, v_uid, v_raid.participation_fee);
      insert into public.raid_fee_transactions(raid_id, user_id, direction, amount, reason, balance_after)
      values (v_raid.id, v_participant.user_id, 'hold', v_raid.participation_fee, 'participation_fee', v_balance);
    end if;
  end if;

  update public.raid_participants
  set status = p_decision,
      payment_status = case
        when p_decision = 'approved' and v_raid.participation_fee > 0 then 'held'
        else 'not_required'
      end,
      approved_by = case when p_decision = 'approved' then v_uid else null end,
      approved_at = case when p_decision = 'approved' then now() else null end,
      updated_at = now()
  where id = v_participant.id;
  perform private.refresh_raid_recruitment(v_raid.id);
  return jsonb_build_object('ok', true, 'status', p_decision);
end;
$$;

create or replace function public.leave_raid(p_raid_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, private
as $$
declare v_uid uuid := auth.uid(); v_raid public.raids%rowtype; v_participant public.raid_participants%rowtype; v_hold public.raid_fee_holds%rowtype;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into v_raid from public.raids where id = p_raid_id for update;
  select * into v_participant from public.raid_participants
  where raid_id = p_raid_id and user_id = v_uid for update;
  if not found then return jsonb_build_object('ok', false, 'reason', 'not_participant'); end if;
  if v_participant.role = 'organizer' then return jsonb_build_object('ok', false, 'reason', 'organizer_must_cancel_raid'); end if;
  if v_raid.starts_at <= now() then return jsonb_build_object('ok', false, 'reason', 'raid_already_started'); end if;

  select * into v_hold from public.raid_fee_holds
  where participant_id = v_participant.id and status = 'held';
  if found and now() <= coalesce(v_raid.free_cancel_at, v_raid.starts_at) then
    perform private.refund_raid_hold(v_hold.id);
  end if;
  update public.raid_participants
  set status = 'cancelled', cancelled_at = now(), updated_at = now()
  where id = v_participant.id;
  perform private.refresh_raid_recruitment(p_raid_id);
  return jsonb_build_object('ok', true, 'refunded', found and now() <= coalesce(v_raid.free_cancel_at, v_raid.starts_at));
end;
$$;

create or replace function public.mark_raid_chat_read(p_raid_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null or not public.is_raid_member(p_raid_id, v_uid) then raise exception 'not_raid_member'; end if;
  insert into public.raid_chat_reads(raid_id, user_id, last_read_at)
  values (p_raid_id, v_uid, now())
  on conflict (raid_id, user_id) do update set last_read_at = excluded.last_read_at;
end;
$$;

create or replace function public.record_raid_attendance(
  p_participant_id uuid,
  p_status text
)
returns jsonb
language plpgsql
security definer
set search_path = public, private
as $$
declare v_uid uuid := auth.uid(); v_participant public.raid_participants%rowtype; v_raid public.raids%rowtype; v_points int := 0;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_status not in ('present', 'late', 'left_early', 'absent') then raise exception 'invalid_attendance_status'; end if;
  select * into v_participant from public.raid_participants where id = p_participant_id for update;
  if not found or v_participant.role = 'organizer' or v_participant.status <> 'approved' then
    return jsonb_build_object('ok', false, 'reason', 'invalid_participant');
  end if;
  select * into v_raid from public.raids where id = v_participant.raid_id for update;
  if v_raid.organizer_id <> v_uid and not public.is_admin() then
    return jsonb_build_object('ok', false, 'reason', 'not_organizer');
  end if;
  if v_raid.source <> 'premium' then return jsonb_build_object('ok', false, 'reason', 'peer_verification_required'); end if;
  if now() < v_raid.starts_at then return jsonb_build_object('ok', false, 'reason', 'raid_not_started'); end if;
  update public.raid_participants set attendance_status = p_status, updated_at = now()
  where id = p_participant_id;
  if p_status in ('present', 'late', 'left_early') then
    v_points := private.award_raid_points(v_participant.user_id, v_raid.id, 'raid_attendance');
  end if;
  return jsonb_build_object('ok', true, 'points_awarded', v_points);
end;
$$;

create or replace function public.cast_attendance_vote(
  p_target_participant_id uuid,
  p_vote text
)
returns jsonb
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_uid uuid := auth.uid();
  v_target public.raid_participants%rowtype;
  v_raid public.raids%rowtype;
  v_responses int;
  v_present int;
  v_absent int;
  v_result text := 'pending';
  v_points int := 0;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_vote not in ('present', 'cannot_confirm', 'absent') then raise exception 'invalid_vote'; end if;
  select * into v_target from public.raid_participants where id = p_target_participant_id for update;
  if not found or v_target.role = 'organizer' or v_target.status <> 'approved' then
    return jsonb_build_object('ok', false, 'reason', 'invalid_target');
  end if;
  if v_target.user_id = v_uid then return jsonb_build_object('ok', false, 'reason', 'self_vote_forbidden'); end if;
  select * into v_raid from public.raids where id = v_target.raid_id for update;
  if not public.is_raid_member(v_raid.id, v_uid) then return jsonb_build_object('ok', false, 'reason', 'not_raid_member'); end if;
  if v_raid.source = 'premium' and v_target.attendance_status <> 'disputed' then
    return jsonb_build_object('ok', false, 'reason', 'appeal_required');
  end if;
  if now() < v_raid.starts_at + make_interval(mins => v_raid.duration_minutes) then
    return jsonb_build_object('ok', false, 'reason', 'raid_not_finished');
  end if;

  insert into public.raid_attendance_votes(raid_id, target_participant_id, voter_id, vote)
  values (v_raid.id, v_target.id, v_uid, p_vote)
  on conflict (target_participant_id, voter_id)
  do update set vote = excluded.vote, updated_at = now();

  select count(*),
         count(*) filter (where vote = 'present'),
         count(*) filter (where vote = 'absent')
  into v_responses, v_present, v_absent
  from public.raid_attendance_votes where target_participant_id = v_target.id;

  if v_responses >= 2 and v_present > (v_present + v_absent) / 2.0 then
    v_result := 'present';
  elsif v_responses >= 2 and v_absent > (v_present + v_absent) / 2.0 then
    v_result := 'absent';
  end if;
  if v_result <> 'pending' then
    update public.raid_participants set attendance_status = v_result, updated_at = now()
    where id = v_target.id;
    if v_result = 'present' then
      v_points := private.award_raid_points(v_target.user_id, v_raid.id, 'raid_attendance');
    end if;
  end if;
  return jsonb_build_object(
    'ok', true, 'result', v_result, 'responses', v_responses,
    'present_votes', v_present, 'absent_votes', v_absent, 'points_awarded', v_points
  );
end;
$$;

create or replace function public.appeal_raid_attendance(p_raid_id uuid, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare v_uid uuid := auth.uid(); v_participant public.raid_participants%rowtype; v_appeal public.raid_attendance_appeals%rowtype;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into v_participant from public.raid_participants
  where raid_id = p_raid_id and user_id = v_uid and role = 'member' for update;
  if not found or v_participant.attendance_status not in ('absent', 'late', 'left_early') then
    return jsonb_build_object('ok', false, 'reason', 'attendance_not_appealable');
  end if;
  insert into public.raid_attendance_appeals(raid_id, participant_id, reason)
  values (p_raid_id, v_participant.id, trim(p_reason)) returning * into v_appeal;
  update public.raid_participants set attendance_status = 'disputed', updated_at = now()
  where id = v_participant.id;
  return jsonb_build_object('ok', true, 'appeal_id', v_appeal.id);
end;
$$;

create or replace function public.finalize_raid(p_raid_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_uid uuid := auth.uid();
  v_raid public.raids%rowtype;
  v_hold record;
  v_balance numeric;
  v_total numeric := 0;
  v_host_points int := 0;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into v_raid from public.raids where id = p_raid_id for update;
  if not found then return jsonb_build_object('ok', false, 'reason', 'raid_not_found'); end if;
  if v_raid.source = 'premium' and v_raid.organizer_id <> v_uid and not public.is_admin() then
    return jsonb_build_object('ok', false, 'reason', 'not_organizer');
  end if;
  if now() < v_raid.starts_at + make_interval(mins => v_raid.duration_minutes) then
    return jsonb_build_object('ok', false, 'reason', 'raid_not_finished');
  end if;
  if exists (
    select 1 from public.raid_participants
    where raid_id = p_raid_id and role = 'member' and status = 'approved'
      and attendance_status in ('pending', 'disputed')
  ) then return jsonb_build_object('ok', false, 'reason', 'attendance_pending'); end if;

  if v_raid.organizer_id is not null then
    perform private.ensure_demo_wallet(v_raid.organizer_id);
    for v_hold in
      select * from public.raid_fee_holds where raid_id = p_raid_id and status = 'held' for update
    loop
      update public.demo_wallets
      set escrow_hold = greatest(0, escrow_hold - v_hold.amount), updated_at = now()
      where user_id = v_hold.payer_id;
      v_total := v_total + v_hold.amount;
      update public.raid_fee_holds
      set status = 'settled', settled_at = now(), updated_at = now()
      where id = v_hold.id;
      update public.raid_participants set payment_status = 'settled', updated_at = now()
      where id = v_hold.participant_id;
    end loop;
    if v_total > 0 then
      update public.demo_wallets
      set balance = balance + v_total, total_earned = total_earned + v_total, updated_at = now()
      where user_id = v_raid.organizer_id returning balance into v_balance;
      insert into public.raid_fee_transactions(raid_id, user_id, direction, amount, reason, balance_after)
      values (p_raid_id, v_raid.organizer_id, 'credit', v_total, 'organizer_settlement', v_balance);
    end if;
    v_host_points := private.award_raid_points(v_raid.organizer_id, p_raid_id, 'raid_hosting');
  end if;

  update public.raids set status = 'completed', completed_at = now(), updated_at = now()
  where id = p_raid_id;
  return jsonb_build_object('ok', true, 'settled_amount', v_total, 'host_points', v_host_points);
end;
$$;

create or replace function public.cancel_raid(p_raid_id uuid, p_reason text default '운영 사유')
returns jsonb
language plpgsql
security definer
set search_path = public, private
as $$
declare v_uid uuid := auth.uid(); v_raid public.raids%rowtype;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into v_raid from public.raids where id = p_raid_id for update;
  if not found then return jsonb_build_object('ok', false, 'reason', 'raid_not_found'); end if;
  if v_raid.organizer_id <> v_uid and not public.is_admin() then
    return jsonb_build_object('ok', false, 'reason', 'not_organizer');
  end if;
  perform private.cancel_raid_internal(p_raid_id, nullif(trim(coalesce(p_reason, '')), ''));
  return jsonb_build_object('ok', true);
end;
$$;

create or replace function private.advance_due_raids()
returns jsonb
language plpgsql
security definer
set search_path = public, private
as $$
declare v_raid record; v_count int; v_started int := 0; v_cancelled int := 0; v_attendance int := 0;
begin
  for v_raid in select id, starts_at, duration_minutes, min_participants, status from public.raids
    where status in ('scheduled', 'recruiting', 'confirmed', 'in_progress')
  loop
    select count(*) into v_count from public.raid_participants
    where raid_id = v_raid.id and status = 'approved';
    if v_raid.status in ('scheduled', 'recruiting', 'confirmed') and v_raid.starts_at <= now() then
      if v_count < v_raid.min_participants then
        perform private.cancel_raid_internal(v_raid.id, '최소 인원 미달');
        v_cancelled := v_cancelled + 1;
      else
        update public.raids set status = 'in_progress', updated_at = now() where id = v_raid.id;
        v_started := v_started + 1;
      end if;
    elsif v_raid.status = 'in_progress'
      and v_raid.starts_at + make_interval(mins => v_raid.duration_minutes) <= now() then
      update public.raids set status = 'attendance', updated_at = now() where id = v_raid.id;
      v_attendance := v_attendance + 1;
    end if;
  end loop;
  return jsonb_build_object('started', v_started, 'cancelled', v_cancelled, 'attendance', v_attendance);
end;
$$;

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
  v_index int;
  v_inserted int := 0;
  v_starts timestamptz;
begin
  if auth.uid() is not null and not public.is_admin() then raise exception 'admin_required'; end if;
  for v_venue in select * from public.exercise_venues where is_active loop
    for v_offset in 0..greatest(1, least(coalesce(p_days, 7), 14)) - 1 loop
      v_day := (now() at time zone 'Asia/Seoul')::date + v_offset;
      if extract(isodow from v_day)::smallint = any(v_venue.active_days) then
        foreach v_time in array v_venue.auto_start_times loop
          v_index := 1 + mod(extract(doy from v_day)::int + extract(hour from v_time)::int,
            cardinality(v_venue.supported_exercises));
          v_exercise := v_venue.supported_exercises[v_index];
          v_starts := (v_day + v_time) at time zone 'Asia/Seoul';
          if v_starts > now() + interval '30 minutes' then
            insert into public.raids(
              venue_id, source, exercise_type, title, description, starts_at,
              duration_minutes, min_participants, max_participants,
              intensity, beginner_friendly, status
            ) values (
              v_venue.id, 'auto', v_exercise,
              v_venue.name || ' ' || case v_exercise
                when 'running' then '러닝' when 'walking' then '걷기'
                when 'badminton' then '배드민턴' when 'basketball' then '농구'
                when 'fitness' then '기초 체력 운동' else v_exercise end,
              '가까운 사람들과 함께하는 운동 레이드', v_starts,
              v_venue.default_duration_minutes, v_venue.recommended_min_participants,
              v_venue.max_participants, v_venue.default_intensity,
              v_venue.beginner_friendly, 'recruiting'
            ) on conflict do nothing;
            if found then v_inserted := v_inserted + 1; end if;
          end if;
        end loop;
      end if;
    end loop;
  end loop;
  return jsonb_build_object('ok', true, 'inserted', v_inserted);
end;
$$;

create or replace function public.get_my_reward_summary()
returns jsonb
language plpgsql
security definer
set search_path = public, private
as $$
declare v_uid uuid := auth.uid(); v_wallet public.user_point_wallets%rowtype; v_level jsonb;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  perform private.ensure_point_wallet(v_uid);
  select * into v_wallet from public.user_point_wallets where user_id = v_uid;
  select jsonb_build_object('level', l.level, 'title', l.title,
      'required_lifetime_points', l.required_lifetime_points,
      'next_required_points', (select min(required_lifetime_points) from public.activity_level_rules n where n.required_lifetime_points > l.required_lifetime_points))
  into v_level from public.activity_level_rules l
  where l.required_lifetime_points <= v_wallet.lifetime_points
  order by l.required_lifetime_points desc limit 1;
  return jsonb_build_object(
    'wallet', to_jsonb(v_wallet), 'level', v_level,
    'catalog', coalesce((select jsonb_agg(to_jsonb(c) order by c.sort_order, c.point_cost)
      from public.reward_catalog_items c where c.is_active), '[]'::jsonb),
    'transactions', coalesce((select jsonb_agg(to_jsonb(t) order by t.created_at desc)
      from (select * from public.point_transactions where user_id = v_uid order by created_at desc limit 30) t), '[]'::jsonb),
    'redemptions', coalesce((select jsonb_agg(to_jsonb(x) order by x.created_at desc)
      from (select rr.*, c.name as item_name from public.reward_redemptions rr
        join public.reward_catalog_items c on c.id = rr.catalog_item_id
        where rr.user_id = v_uid order by rr.created_at desc limit 20) x), '[]'::jsonb)
  );
end;
$$;

create or replace function public.redeem_reward(p_catalog_item_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_uid uuid := auth.uid();
  v_item public.reward_catalog_items%rowtype;
  v_wallet public.user_point_wallets%rowtype;
  v_redemption public.reward_redemptions%rowtype;
  v_code text;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into v_item from public.reward_catalog_items
  where id = p_catalog_item_id and is_active for update;
  if not found then return jsonb_build_object('ok', false, 'reason', 'reward_not_found'); end if;
  if v_item.stock <= 0 then return jsonb_build_object('ok', false, 'reason', 'out_of_stock'); end if;
  perform private.ensure_point_wallet(v_uid);
  select * into v_wallet from public.user_point_wallets where user_id = v_uid for update;
  if v_wallet.available_points < v_item.point_cost then
    return jsonb_build_object('ok', false, 'reason', 'insufficient_points');
  end if;
  update public.user_point_wallets
  set available_points = available_points - v_item.point_cost, updated_at = now()
  where user_id = v_uid returning * into v_wallet;
  update public.reward_catalog_items set stock = stock - 1, updated_at = now() where id = v_item.id;
  v_code := 'TTM-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12));
  insert into public.reward_redemptions(
    user_id, catalog_item_id, points_spent, status, issue_code, issued_at
  ) values (v_uid, v_item.id, v_item.point_cost, 'issued', v_code, now())
  returning * into v_redemption;
  insert into public.point_transactions(
    user_id, direction, reason, amount, available_after, lifetime_after, memo
  ) values (
    v_uid, 'debit', 'reward_redemption', v_item.point_cost,
    v_wallet.available_points, v_wallet.lifetime_points, v_item.name
  );
  return jsonb_build_object(
    'ok', true, 'redemption_id', v_redemption.id,
    'issue_code', v_code, 'available_points', v_wallet.available_points
  );
end;
$$;

create or replace function public.list_my_raids()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare v_uid uuid := auth.uid(); v_result jsonb;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select coalesce(jsonb_agg(item order by (item->>'starts_at')::timestamptz desc), '[]'::jsonb)
  into v_result from (
    select jsonb_build_object(
      'id', r.id, 'source', r.source, 'organizer_id', r.organizer_id,
      'exercise_type', r.exercise_type, 'title', r.title, 'starts_at', r.starts_at,
      'duration_minutes', r.duration_minutes, 'status', r.status,
      'participation_fee', r.participation_fee,
      'participant_count', (select count(*) from public.raid_participants x where x.raid_id = r.id and x.status = 'approved'),
      'venue', jsonb_build_object('id', v.id, 'name', v.name, 'address', v.address,
        'latitude', st_y(v.geo::geometry), 'longitude', st_x(v.geo::geometry)),
      'my_participant', to_jsonb(p)
    ) item
    from public.raid_participants p
    join public.raids r on r.id = p.raid_id
    join public.exercise_venues v on v.id = r.venue_id
    where p.user_id = v_uid and p.status not in ('rejected')
  ) q;
  return v_result;
end;
$$;

create or replace function public.admin_list_exercise_venues()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then raise exception 'admin_required'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object(
    'id', v.id, 'name', v.name, 'address', v.address, 'category', v.category,
    'latitude', st_y(v.geo::geometry), 'longitude', st_x(v.geo::geometry),
    'supported_exercises', v.supported_exercises, 'active_days', v.active_days,
    'auto_start_times', v.auto_start_times, 'default_duration_minutes', v.default_duration_minutes,
    'recommended_min_participants', v.recommended_min_participants,
    'max_participants', v.max_participants, 'default_intensity', v.default_intensity,
    'beginner_friendly', v.beginner_friendly, 'is_active', v.is_active,
    'created_at', v.created_at, 'updated_at', v.updated_at
  ) order by v.name) from public.exercise_venues v), '[]'::jsonb);
end;
$$;

create or replace function public.admin_upsert_exercise_venue(
  p_id uuid,
  p_name text,
  p_address text,
  p_category text,
  p_lat double precision,
  p_lng double precision,
  p_supported_exercises text[],
  p_active_days smallint[],
  p_auto_start_times time[],
  p_default_duration_minutes int,
  p_recommended_min_participants int,
  p_max_participants int,
  p_default_intensity text,
  p_beginner_friendly boolean,
  p_is_active boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare v_uid uuid := auth.uid(); v_id uuid;
begin
  if not public.is_admin() then raise exception 'admin_required'; end if;
  if p_id is null then
    insert into public.exercise_venues(
      name, address, category, geo, supported_exercises, active_days,
      auto_start_times,
      default_duration_minutes, recommended_min_participants, max_participants,
      default_intensity, beginner_friendly, is_active, created_by
    ) values (
      trim(p_name), trim(p_address), trim(p_category),
      st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography,
      p_supported_exercises, p_active_days, p_auto_start_times,
      p_default_duration_minutes,
      p_recommended_min_participants, p_max_participants, p_default_intensity,
      p_beginner_friendly, p_is_active, v_uid
    ) returning id into v_id;
  else
    update public.exercise_venues
    set name = trim(p_name), address = trim(p_address),
        category = trim(p_category),
        geo = st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography,
        supported_exercises = p_supported_exercises,
        active_days = p_active_days,
        auto_start_times = p_auto_start_times,
        default_duration_minutes = p_default_duration_minutes,
        recommended_min_participants = p_recommended_min_participants,
        max_participants = p_max_participants,
        default_intensity = p_default_intensity,
        beginner_friendly = p_beginner_friendly,
        is_active = p_is_active, updated_at = now()
    where id = p_id returning id into v_id;
  end if;
  return jsonb_build_object('ok', v_id is not null, 'id', v_id);
end;
$$;

insert into public.activity_level_rules(level, title, required_lifetime_points) values
  (1, '첫걸음', 0), (2, '워밍업', 500), (3, '꾸준한 움직임', 1500),
  (4, '활동 메이트', 3000), (5, '동네 운동가', 5000),
  (6, '레이드 러너', 7500), (7, '액티브 리더', 10500),
  (8, '운동 챔피언', 14000), (9, '지역 에이스', 18000),
  (10, '틈틈 마스터', 22500)
on conflict (level) do update set title = excluded.title,
  required_lifetime_points = excluded.required_lifetime_points;

insert into public.reward_catalog_items(name, description, point_cost, stock, icon_key, accent_color, sort_order) values
  ('스포츠 음료 교환권', '운동 후 가볍게 수분을 보충해 보세요.', 1500, 30, 'sports_drink', '#2F80ED', 10),
  ('편의점 3,000원 금액권', '가까운 편의점에서 사용할 수 있는 금액권이에요.', 3000, 20, 'convenience', '#27AE60', 20),
  ('카페 아메리카노 교환권', '운동 뒤 여유를 위한 음료 교환권이에요.', 4000, 20, 'coffee', '#9B6B43', 30),
  ('문화생활 5,000원 금액권', '책과 문화생활에 사용할 수 있는 금액권이에요.', 5000, 10, 'culture', '#9B51E0', 40)
on conflict do nothing;

-- Initial fixed raid locations. Admins can edit or deactivate them later.
insert into public.exercise_venues(
  name, address, geo, supported_exercises, auto_start_times,
  default_duration_minutes, recommended_min_participants, max_participants,
  default_intensity, beginner_friendly
) values
  ('한양대학교 운동장', '서울 성동구 왕십리로 222',
    st_setsrid(st_makepoint(127.0457, 37.5574), 4326)::geography,
    array['running','walking','fitness'], array['07:00'::time,'18:00'::time], 60, 3, 16, 'medium', true),
  ('살곶이체육공원', '서울 성동구 사근동 102-16',
    st_setsrid(st_makepoint(127.0490, 37.5555), 4326)::geography,
    array['running','walking','badminton','basketball'], array['10:00'::time,'18:30'::time], 60, 4, 20, 'medium', true),
  ('서울숲 가족마당', '서울 성동구 뚝섬로 273',
    st_setsrid(st_makepoint(127.0374, 37.5444), 4326)::geography,
    array['walking','running','fitness'], array['09:00'::time,'17:30'::time], 50, 3, 14, 'low', true)
on conflict do nothing;

do $$
declare f record;
begin
  for f in
    select p.oid::regprocedure as signature
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname in (
      'list_exercise_venues', 'list_nearby_raids', 'get_raid_detail',
      'create_premium_raid', 'join_free_raid', 'apply_premium_raid',
      'review_raid_application', 'leave_raid', 'mark_raid_chat_read',
      'record_raid_attendance', 'cast_attendance_vote', 'appeal_raid_attendance',
      'finalize_raid', 'cancel_raid', 'generate_scheduled_raids',
      'get_my_reward_summary', 'redeem_reward', 'list_my_raids',
      'admin_list_exercise_venues', 'admin_upsert_exercise_venue'
    )
  loop
    execute format('revoke all on function %s from public, anon', f.signature);
    execute format('grant execute on function %s to authenticated', f.signature);
  end loop;
end;
$$;

revoke all on function private.ensure_point_wallet(uuid) from public;
revoke all on function private.refresh_raid_recruitment(uuid) from public;
revoke all on function private.award_raid_points(uuid, uuid, text) from public;
revoke all on function private.refund_raid_hold(uuid) from public;
revoke all on function private.cancel_raid_internal(uuid, text) from public;
revoke all on function private.advance_due_raids() from public;

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    begin alter publication supabase_realtime add table public.raids; exception when duplicate_object then null; end;
    begin alter publication supabase_realtime add table public.raid_participants; exception when duplicate_object then null; end;
    begin alter publication supabase_realtime add table public.raid_messages; exception when duplicate_object then null; end;
    begin alter publication supabase_realtime add table public.raid_chat_reads; exception when duplicate_object then null; end;
    begin alter publication supabase_realtime add table public.user_point_wallets; exception when duplicate_object then null; end;
  end if;
end;
$$;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule(jobid) from cron.job where jobname = 'ttm-raid-lifecycle';
    perform cron.schedule('ttm-raid-lifecycle', '* * * * *', 'select private.advance_due_raids();');
    perform cron.unschedule(jobid) from cron.job where jobname = 'ttm-raid-generator';
    perform cron.schedule('ttm-raid-generator', '10 0 * * *', 'select public.generate_scheduled_raids(7);');
  end if;
end;
$$;

select public.generate_scheduled_raids(7);
