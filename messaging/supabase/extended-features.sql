-- ItamarOS Connect additional features: groups, user QR identifiers, private contacts,
-- opt-in verified-phone lookup, moderated polls and metadata for privately stored media.
-- Apply after migration.sql in the same Supabase project.
-- Never use unverified phone strings as an account identity.

alter table public.itamar_rooms drop constraint if exists itamar_rooms_kind_check;
alter table public.itamar_rooms add constraint itamar_rooms_kind_check check (kind in ('chat','group','channel'));

alter table public.itamar_members add column if not exists role text not null default 'member'
  check (role in ('member','admin'));
alter table public.itamar_profiles add column if not exists discoverable_by_phone boolean not null default false;

create table if not exists public.itamar_saved_contacts (
  owner_id uuid not null references auth.users(id) on delete cascade,
  contact_id uuid not null references auth.users(id) on delete cascade,
  nickname text not null default '' check (char_length(nickname) <= 70),
  created_at timestamptz not null default now(),
  primary key(owner_id,contact_id),
  check (owner_id <> contact_id)
);
alter table public.itamar_saved_contacts enable row level security;
create policy "my synced contacts" on public.itamar_saved_contacts
  for select to authenticated using (owner_id=auth.uid());
create policy "add a contact I chose" on public.itamar_saved_contacts
  for insert to authenticated with check (owner_id=auth.uid());
create policy "rename my contact" on public.itamar_saved_contacts
  for update to authenticated using (owner_id=auth.uid()) with check (owner_id=auth.uid());
create policy "remove my contact" on public.itamar_saved_contacts
  for delete to authenticated using (owner_id=auth.uid());
grant select,insert,update,delete on public.itamar_saved_contacts to authenticated;

create table if not exists public.itamar_phone_lookup_budget (
  user_id uuid primary key references auth.users(id) on delete cascade,
  window_start timestamptz not null default now(),
  attempts integer not null default 0
);
alter table public.itamar_phone_lookup_budget enable row level security;
-- No client-side read/write access: only the controlled lookup RPC touches this table.

create or replace function public.itamar_find_verified_phone(p_phone text)
returns table(id uuid, username text, display_name text)
language plpgsql security definer set search_path=public,pg_temp
as $$
declare
  lookup_phone text := btrim(coalesce(p_phone,''));
  used_count integer;
begin
  if auth.uid() is null then raise exception 'Login required'; end if;
  if lookup_phone !~ '^\+[1-9][0-9]{7,14}$' then
    raise exception 'Use international phone format, e.g. +972...';
  end if;
  insert into public.itamar_phone_lookup_budget(user_id,window_start,attempts)
  values(auth.uid(),now(),1)
  on conflict (user_id) do update set
    window_start=case when public.itamar_phone_lookup_budget.window_start < now() - interval '24 hours'
      then now() else public.itamar_phone_lookup_budget.window_start end,
    attempts=case when public.itamar_phone_lookup_budget.window_start < now() - interval '24 hours'
      then 1 else public.itamar_phone_lookup_budget.attempts+1 end
  returning attempts into used_count;
  if used_count > 10 then raise exception 'Phone lookup limit reached. Try again tomorrow.'; end if;
  -- Strict opt-in and real Supabase Auth phone OTP verification: NEVER match arbitrary profile phone text.
  return query select p.id,p.username,p.display_name
    from auth.users u join public.itamar_profiles p on p.id=u.id
    where u.phone=lookup_phone and u.phone_confirmed_at is not null
      and p.discoverable_by_phone=true and p.id<>auth.uid()
      and not exists (select 1 from public.itamar_blocks b where
        (b.blocker_id=auth.uid() and b.blocked_id=p.id) or
        (b.blocker_id=p.id and b.blocked_id=auth.uid()))
    limit 1;
end $$;

create or replace function public.itamar_add_contact(p_username text,p_nickname text default '')
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare target uuid;
begin
  if auth.uid() is null then raise exception 'Login required'; end if;
  select id into target from public.itamar_profiles
    where username=lower(trim(leading '@' from btrim(p_username))) and id<>auth.uid();
  if target is null then raise exception 'Username unavailable'; end if;
  if exists(select 1 from public.itamar_blocks where
    (blocker_id=target and blocked_id=auth.uid()) or
    (blocker_id=auth.uid() and blocked_id=target)) then raise exception 'Contact unavailable'; end if;
  insert into public.itamar_saved_contacts(owner_id,contact_id,nickname)
  values(auth.uid(),target,left(btrim(coalesce(p_nickname,'')),70))
  on conflict(owner_id,contact_id) do update set nickname=excluded.nickname;
  return true;
end $$;

create or replace function public.itamar_my_contacts()
returns table(id uuid,username text,display_name text,nickname text)
language sql stable security definer set search_path=public,pg_temp as $$
 select p.id,p.username,p.display_name,c.nickname
 from public.itamar_saved_contacts c
 join public.itamar_profiles p on p.id=c.contact_id
 where c.owner_id=auth.uid()
 order by coalesce(nullif(c.nickname,''),p.display_name);
$$;

create or replace function public.itamar_set_phone_discovery(p_enabled boolean)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if auth.uid() is null then raise exception 'Login required'; end if;
 update public.itamar_profiles set discoverable_by_phone=p_enabled where id=auth.uid();
 return found;
end $$;

create or replace function public.itamar_create_group(p_title text,p_usernames text[])
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare
  group_id uuid;
  members_count integer;
  added integer;
begin
  if auth.uid() is null then raise exception 'Sign in first'; end if;
  if length(btrim(coalesce(p_title,''))) not between 1 and 90 then raise exception 'Invalid title'; end if;
  members_count:=coalesce(array_length(p_usernames,1),0);
  if members_count<1 or members_count>30 then raise exception '1–30 invitations required'; end if;
  if exists(select 1 from unnest(p_usernames) nick
    where not exists(select 1 from public.itamar_profiles p
      where p.username=lower(trim(leading '@' from btrim(nick))))) then
    raise exception 'One or more usernames do not exist';
  end if;
  insert into public.itamar_rooms(kind,title,owner_id)
  values('group',left(btrim(p_title),90),auth.uid()) returning id into group_id;
  insert into public.itamar_members(room_id,user_id,role) values(group_id,auth.uid(),'admin');
  insert into public.itamar_members(room_id,user_id,role)
    select distinct group_id,p.id,'member'
    from public.itamar_profiles p where p.username=any(p_usernames) and p.id<>auth.uid()
      and not exists(select 1 from public.itamar_blocks b where
        (b.blocker_id=p.id and b.blocked_id=auth.uid()) or
        (b.blocker_id=auth.uid() and b.blocked_id=p.id))
    on conflict do nothing;
  return group_id;
end $$;

-- An authorized group owner/admin controls title and participant management.
create or replace function public.itamar_group_manage(p_room uuid,p_operation text,
 p_username text default null,p_title text default null)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare target uuid;
begin
 if auth.uid() is null or not exists(select 1 from public.itamar_members m
   join public.itamar_rooms r on r.id=m.room_id
   where m.room_id=p_room and m.user_id=auth.uid()
   and m.role='admin' and r.kind='group') then raise exception 'Group admin required'; end if;
 if p_operation='rename' then
   if length(btrim(coalesce(p_title,''))) not between 1 and 90 then raise exception 'Invalid title'; end if;
   update public.itamar_rooms set title=left(btrim(p_title),90) where id=p_room;
 else
   select id into target from public.itamar_profiles
     where username=lower(trim(leading '@' from btrim(coalesce(p_username,''))));
   if target is null then raise exception 'User not found'; end if;
   if p_operation='add' then
     if (select count(*) from public.itamar_members where room_id=p_room)>=31 then raise exception 'Group full'; end if;
     if exists(select 1 from public.itamar_blocks b where
       (b.blocker_id=target and b.blocked_id=auth.uid()) or
       (b.blocker_id=auth.uid() and b.blocked_id=target)) then raise exception 'Cannot add this contact'; end if;
     insert into public.itamar_members(room_id,user_id) values(p_room,target)
       on conflict do nothing;
   elsif p_operation='remove' then
     if target=auth.uid() then raise exception 'Cannot remove yourself using admin operation'; end if;
     delete from public.itamar_members where room_id=p_room and user_id=target;
   else raise exception 'Unsupported group action';
   end if;
 end if;
 return true;
end $$;

-- Allow text messages in groups in addition to direct chats.
drop policy if exists "send authorized messages" on public.itamar_messages;
create policy "send authorized messages" on public.itamar_messages
  for insert to authenticated with check (
    sender_id=auth.uid() and public.itamar_is_member(room_id)
    and exists(select 1 from public.itamar_rooms r where r.id=room_id
      and (r.kind in ('chat','group') or r.owner_id=auth.uid()))
    and not exists(select 1 from public.itamar_members other
      join public.itamar_blocks b on b.blocker_id=other.user_id
      where other.room_id=room_id and b.blocked_id=auth.uid())
  );

create table if not exists public.itamar_polls (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.itamar_rooms(id) on delete cascade,
  author_id uuid not null references auth.users(id) on delete cascade,
  question text not null check(char_length(question) between 1 and 300),
  options jsonb not null,
  multiple boolean not null default false,
  closed boolean not null default false,
  created_at timestamptz not null default now()
);
create table if not exists public.itamar_votes (
  poll_id uuid not null references public.itamar_polls(id) on delete cascade,
  voter_id uuid not null references auth.users(id) on delete cascade,
  option_index integer not null check(option_index between 0 and 11),
  primary key(poll_id,voter_id,option_index)
);
alter table public.itamar_polls enable row level security;
alter table public.itamar_votes enable row level security;
create policy "members can see polls" on public.itamar_polls for select to authenticated
 using(public.itamar_is_member(room_id));
create policy "members can see poll votes" on public.itamar_votes for select to authenticated
 using(exists(select 1 from public.itamar_polls p where p.id=poll_id and public.itamar_is_member(p.room_id)));
grant select on public.itamar_polls,public.itamar_votes to authenticated;

create or replace function public.itamar_create_poll(
 p_room uuid,p_question text,p_options text[],p_multiple boolean default false
) returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare output_id uuid;
begin
 if auth.uid() is null or not public.itamar_is_member(p_room)
   or not exists(select 1 from public.itamar_rooms r where r.id=p_room and r.kind='group')
 then raise exception 'Group membership required'; end if;
 if length(btrim(coalesce(p_question,''))) not between 1 and 300 or
    coalesce(array_length(p_options,1),0) not between 2 and 12 or
    exists(select 1 from unnest(p_options) v where length(btrim(v)) not between 1 and 120)
 then raise exception 'Poll requires a question and 2–12 valid options'; end if;
 insert into public.itamar_polls(room_id,author_id,question,options,multiple)
 values(p_room,auth.uid(),btrim(p_question),to_jsonb(p_options),p_multiple) returning id into output_id;
 return output_id;
end $$;

create or replace function public.itamar_vote_poll(p_poll uuid,p_option integer)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare p public.itamar_polls%rowtype;
begin
 select * into p from public.itamar_polls where id=p_poll;
 if p.id is null or not public.itamar_is_member(p.room_id) or p.closed then
   raise exception 'Poll unavailable'; end if;
 if p_option<0 or p_option>=jsonb_array_length(p.options) then raise exception 'Invalid choice'; end if;
 if not p.multiple then delete from public.itamar_votes where poll_id=p_poll and voter_id=auth.uid(); end if;
 insert into public.itamar_votes(poll_id,voter_id,option_index)
 values(p_poll,auth.uid(),p_option) on conflict do nothing;
 return true;
end $$;

-- Protect privileged functions: authenticated users only.
revoke all on function public.itamar_find_verified_phone(text) from public;
revoke all on function public.itamar_add_contact(text,text) from public;
revoke all on function public.itamar_my_contacts() from public;
revoke all on function public.itamar_set_phone_discovery(boolean) from public;
revoke all on function public.itamar_create_group(text,text[]) from public;
revoke all on function public.itamar_group_manage(uuid,text,text,text) from public;
revoke all on function public.itamar_create_poll(uuid,text,text[],boolean) from public;
revoke all on function public.itamar_vote_poll(uuid,integer) from public;
grant execute on function public.itamar_find_verified_phone(text) to authenticated;
grant execute on function public.itamar_add_contact(text,text) to authenticated;
grant execute on function public.itamar_my_contacts() to authenticated;
grant execute on function public.itamar_set_phone_discovery(boolean) to authenticated;
grant execute on function public.itamar_create_group(text,text[]) to authenticated;
grant execute on function public.itamar_group_manage(uuid,text,text,text) to authenticated;
grant execute on function public.itamar_create_poll(uuid,text,text[],boolean) to authenticated;
grant execute on function public.itamar_vote_poll(uuid,integer) to authenticated;

-- Review with Supabase database/security advisors before enabling production.
