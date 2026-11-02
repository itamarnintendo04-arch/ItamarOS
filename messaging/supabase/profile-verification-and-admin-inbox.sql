-- ItamarOS profile verification, scoped administrator inbox, audit trail.
-- Apply using a privileged database migrator. The public API has NO write access.
create table if not exists public.itamar_profile_badges(
  user_id uuid primary key references auth.users(id) on delete cascade,
  badge text not null check (badge in ('green','blue')),
  awarded_by uuid references auth.users(id) on delete set null,
  awarded_at timestamptz not null default now()
);
alter table public.itamar_profile_badges enable row level security;
revoke all on public.itamar_profile_badges from public,anon,authenticated;
grant select on public.itamar_profile_badges to anon,authenticated;
grant select,insert,update,delete on public.itamar_profile_badges to service_role;
drop policy if exists "Public can see approved profile badges" on public.itamar_profile_badges;
create policy "Public can see approved profile badges"
  on public.itamar_profile_badges for select to anon,authenticated using (true);

create table if not exists public.itamar_admin_notices(
 id uuid primary key default gen_random_uuid(),
 sender_id uuid not null references auth.users(id) on delete cascade,
 recipient_id uuid not null references auth.users(id) on delete cascade,
 body text not null check(length(body) between 1 and 1500),
 created_at timestamptz not null default now(),
 read_at timestamptz
);
create index if not exists itamar_admin_notices_recipient_idx
  on public.itamar_admin_notices(recipient_id,created_at desc);
alter table public.itamar_admin_notices enable row level security;
revoke all on public.itamar_admin_notices from public,anon,authenticated;
grant select on public.itamar_admin_notices to authenticated;
grant update(read_at) on public.itamar_admin_notices to authenticated;
grant all on public.itamar_admin_notices to service_role;
drop policy if exists "Recipient can read official notices" on public.itamar_admin_notices;
create policy "Recipient can read official notices" on public.itamar_admin_notices
  for select to authenticated using((select auth.uid())=recipient_id);
drop policy if exists "Recipient can mark notices as read" on public.itamar_admin_notices;
create policy "Recipient can mark notices as read" on public.itamar_admin_notices
  for update to authenticated using((select auth.uid())=recipient_id)
  with check((select auth.uid())=recipient_id);

create table if not exists public.itamar_admin_audit(
 id bigserial primary key,
 actor_id uuid references auth.users(id) on delete set null,
 action text not null,
 target_id uuid references auth.users(id) on delete set null,
 occurred_at timestamptz not null default now()
);
alter table public.itamar_admin_audit enable row level security;
revoke all on public.itamar_admin_audit from public,anon,authenticated;
grant all on public.itamar_admin_audit to service_role;
-- Assignment of the first administrator is an operator-only action in the auth admin API.
-- NEVER automatically grant admin status based on a supplied email or static PIN.
