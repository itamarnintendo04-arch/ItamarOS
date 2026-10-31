-- Apply after messaging/supabase/migration.sql and extended-features.sql.
-- Group joins require an explicit acceptance (no silent additions).
-- Store only a SHA-256 hash of public join tokens; raw tokens are returned once.
alter table public.itamar_profiles add column if not exists avatar_path text;
alter table public.itamar_rooms add column if not exists description text not null default '';
alter table public.itamar_rooms add column if not exists avatar_path text;
alter table public.itamar_rooms add constraint itamar_room_description_len check (char_length(description) <= 500);

create table if not exists public.itamar_group_invites (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.itamar_rooms(id) on delete cascade,
  invited_by uuid not null references auth.users(id) on delete cascade,
  target_id uuid references auth.users(id) on delete cascade,
  token_hash text unique,
  expires_at timestamptz not null,
  max_uses integer not null default 1 check(max_uses between 1 and 100),
  used_count integer not null default 0 check(used_count >= 0),
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  check ((target_id is null) <> (token_hash is null))
);
create index if not exists itamar_group_invites_inbox
 on public.itamar_group_invites(target_id,created_at desc) where target_id is not null;
create index if not exists itamar_group_invites_admin on public.itamar_group_invites(room_id,created_at desc);
alter table public.itamar_group_invites enable row level security;
revoke all on public.itamar_group_invites from public,anon,authenticated;

create or replace function public.itamar_can_manage_group(p_room uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select exists(
  select 1 from public.itamar_rooms r
  join public.itamar_members m on m.room_id=r.id
  where r.id=p_room and r.kind='group' and m.user_id=auth.uid()
    and m.role='admin'
 );
$$;

create or replace function public.itamar_make_group_invite(
 p_room uuid,p_username text default null
) returns text language plpgsql security definer set search_path=public,extensions,pg_temp as $$
declare
 secret text; target uuid; invite_id uuid; used_today int;
begin
 if auth.uid() is null or not public.itamar_can_manage_group(p_room) then
   raise exception 'Only a group admin may create an invitation';
 end if;
 select count(*) into used_today from public.itamar_group_invites
 where invited_by=auth.uid() and created_at>now()-interval '24 hours';
 if used_today>=25 then raise exception 'Daily invitation limit reached'; end if;
 if nullif(btrim(coalesce(p_username,'')),'') is not null then
   select id into target from public.itamar_profiles
     where username=lower(trim(leading '@' from btrim(p_username)));
   if target is null or target=auth.uid() then raise exception 'User unavailable'; end if;
   if exists(select 1 from public.itamar_blocks b where
       (b.blocker_id=auth.uid() and b.blocked_id=target)
       or (b.blocker_id=target and b.blocked_id=auth.uid()))
    then raise exception 'User unavailable'; end if;
   insert into public.itamar_group_invites(room_id,invited_by,target_id,expires_at)
    values(p_room,auth.uid(),target,now()+interval '7 days') returning id into invite_id;
   return invite_id::text;
 end if;
 secret:=encode(gen_random_bytes(24),'hex');
 insert into public.itamar_group_invites(room_id,invited_by,token_hash,expires_at,max_uses)
 values(p_room,auth.uid(),encode(digest(secret,'sha256'),'hex'),now()+interval '7 days',100);
 return secret;
end $$;

create or replace function public.itamar_my_group_invites()
returns table(id uuid,room_id uuid,group_title text,invited_by uuid,expires_at timestamptz)
language sql stable security definer set search_path=public,pg_temp as $$
 select i.id,i.room_id,r.title,i.invited_by,i.expires_at
 from public.itamar_group_invites i
 join public.itamar_rooms r on r.id=i.room_id
 where i.target_id=auth.uid() and i.revoked_at is null and
       i.expires_at>now() and i.used_count=0
 order by i.created_at desc limit 50;
$$;

create or replace function public.itamar_respond_group_invite(p_invite uuid,p_accept boolean)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare inv public.itamar_group_invites%rowtype; owner uuid;
begin
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 select * into inv from public.itamar_group_invites
 where id=p_invite and target_id=auth.uid() for update;
 if inv.id is null or inv.revoked_at is not null or inv.expires_at<=now() or inv.used_count>0
 then raise exception 'Invitation expired or unavailable'; end if;
 if p_accept then
   select owner_id into owner from public.itamar_rooms where id=inv.room_id and kind='group';
   if owner is null then raise exception 'Group not found'; end if;
   if exists(select 1 from public.itamar_blocks where
     (blocker_id=owner and blocked_id=auth.uid())
     or (blocker_id=auth.uid() and blocked_id=owner))
   then raise exception 'Group unavailable'; end if;
   if (select count(*) from public.itamar_members where room_id=inv.room_id)>=100
   then raise exception 'Group is full'; end if;
   insert into public.itamar_members(room_id,user_id) values(inv.room_id,auth.uid())
    on conflict do nothing;
 end if;
 update public.itamar_group_invites set revoked_at=now(),used_count=case when p_accept then 1 else 0 end
 where id=p_invite;
 return true;
end $$;

create or replace function public.itamar_join_group_by_link(p_code text)
returns boolean language plpgsql security definer set search_path=public,extensions,pg_temp as $$
declare inv public.itamar_group_invites%rowtype; group_owner uuid; inserted int;
begin
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 if p_code !~ '^[a-f0-9]{48}$' then raise exception 'Invalid invitation'; end if;
 select * into inv from public.itamar_group_invites
 where token_hash=encode(digest(p_code,'sha256'),'hex')
   and target_id is null for update;
 if inv.id is null or inv.revoked_at is not null or inv.expires_at<=now()
   or inv.used_count>=inv.max_uses then raise exception 'Invalid or expired invitation'; end if;
 select owner_id into group_owner from public.itamar_rooms where id=inv.room_id and kind='group';
 if group_owner is null then raise exception 'Group unavailable'; end if;
 if exists(select 1 from public.itamar_blocks where
    (blocker_id=group_owner and blocked_id=auth.uid())
    or (blocker_id=auth.uid() and blocked_id=group_owner))
 then raise exception 'Group unavailable'; end if;
 if (select count(*) from public.itamar_members where room_id=inv.room_id)>=100
 then raise exception 'Group is full'; end if;
 insert into public.itamar_members(room_id,user_id)
 values(inv.room_id,auth.uid()) on conflict do nothing;
 get diagnostics inserted=row_count;
 if inserted>0 then
    update public.itamar_group_invites set used_count=used_count+1 where id=inv.id;
 end if;
 return true;
end $$;

create or replace function public.itamar_revoke_group_links(p_room uuid)
returns integer language plpgsql security definer set search_path=public,pg_temp as $$
declare n int;
begin
 if auth.uid() is null or not public.itamar_can_manage_group(p_room) then
   raise exception 'Group admin required'; end if;
 update public.itamar_group_invites set revoked_at=now()
  where room_id=p_room and target_id is null and revoked_at is null;
 get diagnostics n=row_count;
 return n;
end $$;

-- Override older direct-add group creation: every suggested participant receives an
-- invitation instead of being placed in the group without permission.
create or replace function public.itamar_create_group(p_title text,p_usernames text[] default '{}')
returns uuid language plpgsql security definer set search_path=public,extensions,pg_temp as $$
declare id uuid; name text; uniq text[]; username_count int;
begin
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 if length(btrim(coalesce(p_title,''))) not between 1 and 90
 then raise exception 'Group name must be 1–90 characters'; end if;
 select coalesce(array_agg(distinct lower(trim(leading '@' from btrim(n)))),'{}')
 into uniq from unnest(coalesce(p_usernames,'{}')) n
 where btrim(n) <> '';
 username_count:=coalesce(array_length(uniq,1),0);
 if username_count>30 then raise exception 'Too many initial invitations'; end if;
 insert into public.itamar_rooms(kind,title,owner_id)
 values('group',btrim(p_title),auth.uid()) returning public.itamar_rooms.id into id;
 insert into public.itamar_members(room_id,user_id,role) values(id,auth.uid(),'admin');
 foreach name in array uniq loop
    perform public.itamar_make_group_invite(id,name);
 end loop;
 return id;
end $$;

-- Group managers can rename and invite (not silently add) people. Never remove owner.
create or replace function public.itamar_group_manage(
 p_room uuid,p_operation text,p_username text default null,p_title text default null
) returns boolean language plpgsql security definer set search_path=public,extensions,pg_temp as $$
declare target uuid; owner uuid;
begin
 if auth.uid() is null or not public.itamar_can_manage_group(p_room)
 then raise exception 'Group admin required'; end if;
 select owner_id into owner from public.itamar_rooms where id=p_room;
 if p_operation='rename' then
   if length(btrim(coalesce(p_title,''))) not between 1 and 90 then
     raise exception 'Invalid group name'; end if;
   update public.itamar_rooms set title=btrim(p_title) where id=p_room;
 elsif p_operation='add' then
   perform public.itamar_make_group_invite(p_room,p_username);
 elsif p_operation='remove' then
   select id into target from public.itamar_profiles
     where username=lower(trim(leading '@' from btrim(coalesce(p_username,''))));
   if target is null or target=owner or target=auth.uid() then
     raise exception 'Cannot remove this person'; end if;
   delete from public.itamar_members where room_id=p_room and user_id=target;
 else raise exception 'Unsupported group action';
 end if;
 return true;
end $$;

-- Photo attachments are restricted to avatars uploaded by their owners/admins.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
 values('itamar-connect-avatars','itamar-connect-avatars',false,5242880,
        array['image/jpeg','image/png','image/webp','image/heic'])
 on conflict(id) do nothing;

create policy "profile and group avatar owner uploads" on storage.objects for insert to authenticated
with check(bucket_id='itamar-connect-avatars' and (
 ((storage.foldername(name))[1]='profiles' and
  (storage.foldername(name))[2]=auth.uid()::text)
 or
 ((storage.foldername(name))[1]='groups' and
  public.itamar_can_manage_group(((storage.foldername(name))[2])::uuid))
));
create policy "authenticated see public profile avatars and member group avatars"
on storage.objects for select to authenticated
using(bucket_id='itamar-connect-avatars' and (
 ((storage.foldername(name))[1]='profiles')
 or
 ((storage.foldername(name))[1]='groups' and
  public.itamar_is_member(((storage.foldername(name))[2])::uuid))
));

create or replace function public.itamar_set_profile_avatar(p_path text)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 if p_path is not null and
   (left(p_path,length('profiles/'||auth.uid()::text||'/'))<>
       'profiles/'||auth.uid()::text||'/'
    or not exists(select 1 from storage.objects where bucket_id='itamar-connect-avatars' and name=p_path))
 then raise exception 'Invalid avatar'; end if;
 update public.itamar_profiles set avatar_path=p_path where id=auth.uid();
 return found;
end $$;

create or replace function public.itamar_update_group_profile(
 p_room uuid,p_title text,p_description text default '',p_avatar_path text default null
) returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if auth.uid() is null or not public.itamar_can_manage_group(p_room)
 then raise exception 'Group admin required'; end if;
 if length(btrim(coalesce(p_title,''))) not between 1 and 90 or
    length(coalesce(p_description,''))>500 then raise exception 'Invalid group details'; end if;
 if p_avatar_path is not null and
   (left(p_avatar_path,length('groups/'||p_room::text||'/'))<>
     'groups/'||p_room::text||'/'
    or not exists(select 1 from storage.objects where bucket_id='itamar-connect-avatars' and name=p_avatar_path))
 then raise exception 'Invalid group photo'; end if;
 update public.itamar_rooms
 set title=btrim(p_title),description=coalesce(p_description,''),avatar_path=p_avatar_path
 where id=p_room and kind='group';
 return found;
end $$;

revoke all on function public.itamar_can_manage_group(uuid) from public;
revoke all on function public.itamar_make_group_invite(uuid,text) from public;
revoke all on function public.itamar_my_group_invites() from public;
revoke all on function public.itamar_respond_group_invite(uuid,boolean) from public;
revoke all on function public.itamar_join_group_by_link(text) from public;
revoke all on function public.itamar_revoke_group_links(uuid) from public;
revoke all on function public.itamar_set_profile_avatar(text) from public;
revoke all on function public.itamar_update_group_profile(uuid,text,text,text) from public;
grant execute on function public.itamar_can_manage_group(uuid) to authenticated;
grant execute on function public.itamar_make_group_invite(uuid,text) to authenticated;
grant execute on function public.itamar_my_group_invites() to authenticated;
grant execute on function public.itamar_respond_group_invite(uuid,boolean) to authenticated;
grant execute on function public.itamar_join_group_by_link(text) to authenticated;
grant execute on function public.itamar_revoke_group_links(uuid) to authenticated;
grant execute on function public.itamar_set_profile_avatar(text) to authenticated;
grant execute on function public.itamar_update_group_profile(uuid,text,text,text) to authenticated;
