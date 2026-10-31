-- ItamarOS Connect: consent-based group invitations, optional images, and message receipts.
-- Run AFTER migration.sql and extended-features.sql on a configured Supabase instance.
-- This file is not deployed by merely committing it to GitHub.

alter table public.itamar_profiles
  add column if not exists avatar_path text,
  add column if not exists read_receipts boolean not null default true;
alter table public.itamar_rooms
  add column if not exists description text not null default '',
  add column if not exists avatar_path text;
alter table public.itamar_rooms
  drop constraint if exists itamar_rooms_description_length;
alter table public.itamar_rooms
  add constraint itamar_rooms_description_length check (char_length(description)<=500);

-- These pictures are intentionally public. Never store secret contact data in this bucket.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('itamar-connect-avatars','itamar-connect-avatars',true,5242880,
       array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;
create policy "upload own profile picture" on storage.objects
  for insert to authenticated with check (
    bucket_id='itamar-connect-avatars' and
    (storage.foldername(name))[1]='profiles' and
    (storage.foldername(name))[2]=auth.uid()::text
  );
create policy "group admins upload group picture" on storage.objects
  for insert to authenticated with check (
    bucket_id='itamar-connect-avatars' and
    (storage.foldername(name))[1]='groups' and
    exists(
      select 1 from public.itamar_members m
      join public.itamar_rooms r on r.id=m.room_id
      where m.user_id=auth.uid() and m.role='admin'
        and r.kind='group' and m.room_id::text=(storage.foldername(name))[2]
    )
  );
-- Public bucket access is limited to public avatars; never make message attachments public.
create policy "view public avatars" on storage.objects for select
to anon,authenticated using(bucket_id='itamar-connect-avatars');

create or replace function public.itamar_set_profile_options(
  p_read_receipts boolean,
  p_avatar_path text default null
) returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 if p_avatar_path is not null and
   (left(p_avatar_path,length('profiles/'||auth.uid()::text||'/')) <>
    'profiles/'||auth.uid()::text||'/') then raise exception 'Invalid avatar path'; end if;
 update public.itamar_profiles set read_receipts=coalesce(p_read_receipts,true),
  avatar_path=coalesce(p_avatar_path,avatar_path) where id=auth.uid();
 return found;
end $$;

create or replace function public.itamar_set_group_details(
 p_room uuid,p_title text,p_description text,p_avatar_path text default null
) returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if auth.uid() is null or not exists(
   select 1 from public.itamar_rooms r join public.itamar_members m on m.room_id=r.id
   where r.id=p_room and r.kind='group' and m.user_id=auth.uid() and m.role='admin')
   then raise exception 'Group admin required'; end if;
 if char_length(btrim(coalesce(p_title,''))) not between 1 and 90 or
    char_length(coalesce(p_description,''))>500 then raise exception 'Invalid group details'; end if;
 if p_avatar_path is not null and
    left(p_avatar_path,length('groups/'||p_room::text||'/')) <>
    'groups/'||p_room::text||'/' then raise exception 'Invalid group picture path'; end if;
 update public.itamar_rooms set title=btrim(p_title),
  description=coalesce(p_description,''),
  avatar_path=coalesce(p_avatar_path,avatar_path) where id=p_room;
 return found;
end $$;

create table if not exists public.itamar_group_invites (
 id uuid primary key default gen_random_uuid(),
 code text not null unique check(code ~ '^[a-f0-9]{32}$'),
 group_id uuid not null references public.itamar_rooms(id) on delete cascade,
 creator_id uuid not null references auth.users(id) on delete cascade,
 target_id uuid references auth.users(id) on delete cascade,
 expires_at timestamptz not null,
 max_uses integer not null default 50 check(max_uses between 1 and 100),
 uses integer not null default 0 check(uses>=0),
 revoked_at timestamptz,
 created_at timestamptz not null default now()
);
create index if not exists itamar_invites_group on public.itamar_group_invites(group_id);
alter table public.itamar_group_invites enable row level security;
create policy "group admins review invites" on public.itamar_group_invites for select to authenticated
 using(exists(select 1 from public.itamar_members m where m.room_id=group_id and
 m.user_id=auth.uid() and m.role='admin'));
-- No direct client writes or anonymous reads.

create or replace function public.itamar_invite_to_group(
 p_group uuid, p_username text default null
) returns text language plpgsql security definer set search_path=public,pg_temp as $$
declare recipient uuid;
declare invitation text;
begin
 if auth.uid() is null or not exists(
  select 1 from public.itamar_members m join public.itamar_rooms r on r.id=m.room_id
  where r.id=p_group and r.kind='group' and m.user_id=auth.uid() and m.role='admin')
   then raise exception 'Only admins can invite'; end if;
 if nullif(btrim(coalesce(p_username,'')),'') is not null then
  select id into recipient from public.itamar_profiles
   where username=lower(trim(leading '@' from btrim(p_username)));
  if recipient is null or recipient=auth.uid() then raise exception 'User unavailable'; end if;
  if exists(select 1 from public.itamar_blocks b
   where (b.blocker_id=auth.uid() and b.blocked_id=recipient)
   or (b.blocker_id=recipient and b.blocked_id=auth.uid())) then
   raise exception 'Cannot invite this user'; end if;
 end if;
 invitation:=encode(gen_random_bytes(16),'hex');
 insert into public.itamar_group_invites(code,group_id,creator_id,target_id,expires_at,max_uses)
 values(invitation,p_group,auth.uid(),recipient,now()+interval '24 hours',
        case when recipient is null then 50 else 1 end);
 return invitation;
end $$;

create or replace function public.itamar_accept_group_invite(p_code text)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare inv public.itamar_group_invites%rowtype;
begin
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 select * into inv from public.itamar_group_invites where code=lower(p_code) for update;
 if inv.id is null or inv.expires_at<=now() or inv.revoked_at is not null
   or inv.uses>=inv.max_uses then raise exception 'Invalid or expired invitation'; end if;
 if inv.target_id is not null and inv.target_id<>auth.uid()
   then raise exception 'Invitation belongs to another account'; end if;
 if exists(select 1 from public.itamar_blocks b join public.itamar_members m on m.user_id=b.blocker_id
   where m.room_id=inv.group_id and b.blocked_id=auth.uid()) then
   raise exception 'Cannot join this group'; end if;
 if not exists(select 1 from public.itamar_members where room_id=inv.group_id and user_id=auth.uid()) then
   if (select count(*) from public.itamar_members where room_id=inv.group_id)>=50
     then raise exception 'Group full'; end if;
   insert into public.itamar_members(room_id,user_id,role)
    values(inv.group_id,auth.uid(),'member');
   update public.itamar_group_invites set uses=uses+1 where id=inv.id;
 end if;
 return inv.group_id;
end $$;

create or replace function public.itamar_revoke_group_invite(p_code text)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
begin
 update public.itamar_group_invites i set revoked_at=now()
 where i.code=lower(p_code) and
 exists(select 1 from public.itamar_members m where m.room_id=i.group_id and
   m.user_id=auth.uid() and m.role='admin');
 return found;
end $$;

-- Client acknowledgements reflect actual authenticated device activity.
create table if not exists public.itamar_receipts (
 message_id uuid not null references public.itamar_messages(id) on delete cascade,
 recipient_id uuid not null references auth.users(id) on delete cascade,
 delivered_at timestamptz,
 read_at timestamptz,
 primary key(message_id,recipient_id)
);
create index if not exists itamar_receipts_user on public.itamar_receipts(recipient_id);
alter table public.itamar_receipts enable row level security;
create policy "sender and recipient can see message receipts" on public.itamar_receipts
 for select to authenticated using(recipient_id=auth.uid() or exists(
  select 1 from public.itamar_messages msg where msg.id=message_id and msg.sender_id=auth.uid()));
grant select on public.itamar_receipts to authenticated;

create or replace function public.itamar_ack_room(p_room uuid,p_read boolean default false)
returns integer language plpgsql security definer set search_path=public,pg_temp as $$
declare n integer;
declare can_read boolean;
begin
 if auth.uid() is null or not public.itamar_is_member(p_room) then
   raise exception 'Room membership required'; end if;
 select coalesce(p.read_receipts,true) into can_read from public.itamar_profiles p where p.id=auth.uid();
 insert into public.itamar_receipts(message_id,recipient_id,delivered_at,read_at)
 select msg.id,auth.uid(),now(),case when p_read and can_read then now() else null end
 from (select id from public.itamar_messages where room_id=p_room and sender_id<>auth.uid()
       order by created_at desc limit 150) msg
 on conflict(message_id,recipient_id) do update set
   delivered_at=coalesce(public.itamar_receipts.delivered_at,excluded.delivered_at),
   read_at=coalesce(public.itamar_receipts.read_at,excluded.read_at);
 get diagnostics n=row_count;
 return n;
end $$;

-- Aggregate only messages the caller sent; no private recipient IDs are returned.
create or replace function public.itamar_my_message_status(p_room uuid)
returns table(message_id uuid, recipient_count bigint, delivered_count bigint, read_count bigint)
language sql stable security definer set search_path=public,pg_temp as $$
 select msg.id,
  (select count(*) from public.itamar_members m where m.room_id=p_room and m.user_id<>auth.uid()),
  (select count(*) from public.itamar_receipts rec where rec.message_id=msg.id and rec.delivered_at is not null),
  (select count(*) from public.itamar_receipts rec where rec.message_id=msg.id and rec.read_at is not null)
 from (select id from public.itamar_messages where room_id=p_room and sender_id=auth.uid()
       order by created_at desc limit 150) msg
 where auth.uid() is not null and public.itamar_is_member(p_room);
$$;

revoke all on function public.itamar_set_profile_options(boolean,text) from public;
revoke all on function public.itamar_set_group_details(uuid,text,text,text) from public;
revoke all on function public.itamar_invite_to_group(uuid,text) from public;
revoke all on function public.itamar_accept_group_invite(text) from public;
revoke all on function public.itamar_revoke_group_invite(text) from public;
revoke all on function public.itamar_ack_room(uuid,boolean) from public;
revoke all on function public.itamar_my_message_status(uuid) from public;
grant execute on function public.itamar_set_profile_options(boolean,text) to authenticated;
grant execute on function public.itamar_set_group_details(uuid,text,text,text) to authenticated;
grant execute on function public.itamar_invite_to_group(uuid,text) to authenticated;
grant execute on function public.itamar_accept_group_invite(text) to authenticated;
grant execute on function public.itamar_revoke_group_invite(text) to authenticated;
grant execute on function public.itamar_ack_room(uuid,boolean) to authenticated;
grant execute on function public.itamar_my_message_status(uuid) to authenticated;
grant select on public.itamar_group_invites to authenticated;
