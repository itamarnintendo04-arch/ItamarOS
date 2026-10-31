-- ItamarOS Connect: Supabase migration for private chat and public broadcast channels.
-- Apply once to a project you control. Keep service_role keys on the server ONLY.
-- Signed-in user identities are Supabase Auth IDs; no phone-contact upload.

create extension if not exists pgcrypto;

create table if not exists public.itamar_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique check (username ~ '^[a-z0-9_.]{3,24}$'),
  display_name text not null check (char_length(display_name) between 1 and 70),
  about text not null default '' check (char_length(about) <= 160),
  created_at timestamptz not null default now()
);

create table if not exists public.itamar_rooms (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('chat','channel')),
  title text not null check (char_length(title) between 1 and 90),
  owner_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.itamar_members (
  room_id uuid not null references public.itamar_rooms(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  muted boolean not null default false,
  joined_at timestamptz not null default now(),
  primary key (room_id,user_id)
);

create table if not exists public.itamar_messages (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.itamar_rooms(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (char_length(btrim(body)) between 1 and 4000),
  created_at timestamptz not null default now()
);
create index if not exists itamar_messages_room_time on public.itamar_messages(room_id, created_at desc);
create index if not exists itamar_rooms_owner on public.itamar_rooms(owner_id);
create index if not exists itamar_members_user on public.itamar_members(user_id);

create table if not exists public.itamar_blocks (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id,blocked_id),
  check (blocker_id <> blocked_id)
);

create table if not exists public.itamar_parent_invites (
  code text primary key check (code ~ '^[a-f0-9]{32}$'),
  child_id uuid not null references auth.users(id) on delete cascade,
  expires_at timestamptz not null,
  redeemed_by uuid references auth.users(id) on delete set null,
  redeemed_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists itamar_parent_invites_child on public.itamar_parent_invites(child_id);

create table if not exists public.itamar_parent_links (
  child_id uuid not null references auth.users(id) on delete cascade,
  parent_id uuid not null references auth.users(id) on delete cascade,
  parent_name text not null check (char_length(parent_name) between 1 and 70),
  relationship text not null check (relationship in ('Parent','Legal guardian')),
  created_at timestamptz not null default now(),
  primary key(child_id,parent_id),
  check (child_id <> parent_id)
);

-- Avoid recursive membership-policy evaluation.
create or replace function public.itamar_is_member(p_room uuid)
returns boolean language sql stable security definer set search_path = public, pg_temp
as $$
  select exists(select 1 from public.itamar_members
    where room_id = p_room and user_id = (select auth.uid()));
$$;

alter table public.itamar_profiles enable row level security;
alter table public.itamar_rooms enable row level security;
alter table public.itamar_members enable row level security;
alter table public.itamar_messages enable row level security;
alter table public.itamar_blocks enable row level security;
alter table public.itamar_parent_invites enable row level security;
alter table public.itamar_parent_links enable row level security;

create policy "authenticated profile discovery" on public.itamar_profiles
  for select to authenticated using (true);
create policy "edit my profile" on public.itamar_profiles
  for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));
create policy "insert my profile" on public.itamar_profiles
  for insert to authenticated with check (id = (select auth.uid()));

create policy "see joined rooms and public channels" on public.itamar_rooms
  for select to authenticated
  using (public.itamar_is_member(id) or kind = 'channel');
create policy "members see participants" on public.itamar_members
  for select to authenticated using (public.itamar_is_member(room_id));
create policy "read only room messages" on public.itamar_messages
  for select to authenticated using (public.itamar_is_member(room_id));
create policy "send authorized messages" on public.itamar_messages
  for insert to authenticated
  with check (
    sender_id = (select auth.uid()) and public.itamar_is_member(room_id)
    and exists (select 1 from public.itamar_rooms r where r.id = room_id
                and (r.kind = 'chat' or r.owner_id = (select auth.uid())))
    and not exists (select 1 from public.itamar_members other
       join public.itamar_blocks b on b.blocker_id = other.user_id
       where other.room_id = room_id and b.blocked_id = (select auth.uid()))
  );

create policy "my blocks" on public.itamar_blocks
  for select to authenticated using (blocker_id = (select auth.uid()));
create policy "block accounts" on public.itamar_blocks
  for insert to authenticated with check (blocker_id = (select auth.uid()));
create policy "unblock accounts" on public.itamar_blocks
  for delete to authenticated using (blocker_id = (select auth.uid()));

create policy "see own invite metadata" on public.itamar_parent_invites
  for select to authenticated using (child_id = (select auth.uid()));
create policy "see only my family links" on public.itamar_parent_links
  for select to authenticated using (child_id = (select auth.uid()) or parent_id = (select auth.uid()));

-- Every room and family-link creation is performed by an authorized RPC;
-- clients cannot add arbitrary participants or self-assign an owner role.
create or replace function public.itamar_create_room(
  p_kind text, p_title text, p_username text default null
) returns uuid
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  me uuid := auth.uid();
  target uuid;
  new_id uuid;
  title_clean text := btrim(coalesce(p_title,''));
begin
  if me is null then raise exception 'Sign in required'; end if;
  if p_kind not in ('chat','channel') then raise exception 'Unknown room type'; end if;
  if length(title_clean) < 1 or length(title_clean) > 90 then raise exception 'Invalid title'; end if;
  if p_kind = 'chat' then
    select id into target from public.itamar_profiles
      where username = lower(trim(leading '@' from btrim(coalesce(p_username,''))));
    if target is null or target = me then raise exception 'Username not found'; end if;
    if exists (select 1 from public.itamar_blocks b
      where (b.blocker_id = target and b.blocked_id = me)
         or (b.blocker_id = me and b.blocked_id = target)) then
      raise exception 'Conversation unavailable';
    end if;
  end if;
  insert into public.itamar_rooms(kind,title,owner_id)
  values (p_kind,title_clean,me) returning id into new_id;
  insert into public.itamar_members(room_id,user_id) values (new_id,me);
  if p_kind = 'chat' then
    insert into public.itamar_members(room_id,user_id) values (new_id,target);
  end if;
  return new_id;
end $$;

create or replace function public.itamar_join_channel(p_room uuid)
returns boolean language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if auth.uid() is null then raise exception 'Sign in required'; end if;
  if not exists(select 1 from public.itamar_rooms where id=p_room and kind='channel') then
    raise exception 'Channel unavailable';
  end if;
  insert into public.itamar_members(room_id,user_id)
  values(p_room,auth.uid()) on conflict do nothing;
  return true;
end $$;

create or replace function public.itamar_leave_room(p_room uuid)
returns boolean language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if exists(select 1 from public.itamar_rooms where id=p_room and owner_id=auth.uid()) then
    raise exception 'Owner cannot leave their room';
  end if;
  delete from public.itamar_members where room_id=p_room and user_id=auth.uid();
  return found;
end $$;


create or replace function public.itamar_set_mute(p_room uuid, p_muted boolean)
returns boolean language plpgsql security definer set search_path = public, pg_temp as $
begin
  if auth.uid() is null then raise exception 'Sign in required'; end if;
  update public.itamar_members set muted = p_muted
  where room_id = p_room and user_id = auth.uid();
  if not found then raise exception 'Not a member'; end if;
  return true;
end $;

create or replace function public.itamar_my_rooms()
returns table(id uuid, title text, kind text, owner_id uuid, muted boolean, latest_at timestamptz)
language sql stable security definer set search_path = public, pg_temp as $$
  select r.id,r.title,r.kind,r.owner_id,m.muted,
    (select max(msg.created_at) from public.itamar_messages msg where msg.room_id=r.id) as latest_at
  from public.itamar_rooms r join public.itamar_members m on m.room_id=r.id
  where m.user_id = auth.uid()
  order by latest_at desc nulls last, r.created_at desc;
$$;

create or replace function public.itamar_my_updates()
returns table(id uuid, room_id uuid, title text, body text, created_at timestamptz)
language sql stable security definer set search_path = public, pg_temp as $$
  select msg.id,msg.room_id,r.title,msg.body,msg.created_at
  from public.itamar_messages msg
  join public.itamar_rooms r on r.id=msg.room_id
  join public.itamar_members m on m.room_id=r.id and m.user_id=auth.uid()
  where not m.muted and msg.sender_id<>auth.uid()
  order by msg.created_at desc limit 100;
$$;

create or replace function public.itamar_create_parent_invite()
returns text language plpgsql security definer set search_path = public, pg_temp as $$
declare generated text;
begin
  if auth.uid() is null then raise exception 'Sign in required'; end if;
  delete from public.itamar_parent_invites where child_id = auth.uid() and redeemed_by is null;
  generated := encode(gen_random_bytes(16),'hex');
  insert into public.itamar_parent_invites(code,child_id,expires_at)
  values(generated,auth.uid(),now()+interval '15 minutes');
  return generated;
end $$;

create or replace function public.itamar_redeem_parent_invite(
  p_code text,p_name text,p_relationship text
) returns boolean language plpgsql security definer set search_path = public, pg_temp as $$
declare linked_child uuid;
begin
  if auth.uid() is null then raise exception 'Sign in required'; end if;
  if not exists(select 1 from auth.users u where u.id=auth.uid() and u.email_confirmed_at is not null) then
    raise exception 'Verified email required for parent invitation';
  end if;
  if length(btrim(coalesce(p_name,''))) not between 1 and 70 or
     p_relationship not in ('Parent','Legal guardian') then
    raise exception 'Invalid parent details';
  end if;
  update public.itamar_parent_invites set redeemed_by=auth.uid(),redeemed_at=now()
  where code=p_code and expires_at > now() and redeemed_by is null and child_id <> auth.uid()
  returning child_id into linked_child;
  if linked_child is null then raise exception 'Invitation expired or already used'; end if;
  insert into public.itamar_parent_links(child_id,parent_id,parent_name,relationship)
  values(linked_child,auth.uid(),btrim(p_name),p_relationship)
  on conflict(child_id,parent_id) do update
  set parent_name=excluded.parent_name,relationship=excluded.relationship;
  return true;
end $$;

revoke all on function public.itamar_is_member(uuid) from public;
revoke all on function public.itamar_create_room(text,text,text) from public;
revoke all on function public.itamar_join_channel(uuid) from public;
revoke all on function public.itamar_leave_room(uuid) from public;
revoke all on function public.itamar_set_mute(uuid,boolean) from public;
revoke all on function public.itamar_my_rooms() from public;
revoke all on function public.itamar_my_updates() from public;
revoke all on function public.itamar_create_parent_invite() from public;
revoke all on function public.itamar_redeem_parent_invite(text,text,text) from public;
grant execute on function public.itamar_is_member(uuid) to authenticated;
grant execute on function public.itamar_create_room(text,text,text) to authenticated;
grant execute on function public.itamar_join_channel(uuid) to authenticated;
grant execute on function public.itamar_leave_room(uuid) to authenticated;
grant execute on function public.itamar_set_mute(uuid,boolean) to authenticated;
grant execute on function public.itamar_my_rooms() to authenticated;
grant execute on function public.itamar_my_updates() to authenticated;
grant execute on function public.itamar_create_parent_invite() to authenticated;
grant execute on function public.itamar_redeem_parent_invite(text,text,text) to authenticated;

-- Access to base tables remains restricted by RLS. No service-role secret
-- or private Apple signing credential belongs in web or mobile clients.

-- Table-level grants still use the row-specific RLS policies above.
revoke all on public.itamar_profiles,public.itamar_rooms,public.itamar_members,
 public.itamar_messages,public.itamar_blocks,public.itamar_parent_invites,
 public.itamar_parent_links from anon;
grant select,insert,update on public.itamar_profiles to authenticated;
grant select on public.itamar_rooms,public.itamar_members,
 public.itamar_parent_invites,public.itamar_parent_links to authenticated;
grant select,insert on public.itamar_messages to authenticated;
grant select,insert,delete on public.itamar_blocks to authenticated;
