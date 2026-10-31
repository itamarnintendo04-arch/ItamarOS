-- Third ItamarOS Connect migration: presentation, consent-based group invites,
-- server-controlled edits/deletions, optional read receipts, and one-time TEXT notes.
-- Run after migration.sql and extended-features.sql.
-- All phone numbers remain private. No user can fetch another user's contacts.

alter table public.itamar_profiles
  add column if not exists avatar_path text,
  add column if not exists read_receipts_enabled boolean not null default true;

alter table public.itamar_rooms
  add column if not exists description text not null default '',
  add column if not exists avatar_path text;
alter table public.itamar_rooms
  add constraint itamar_room_description_length check (char_length(description) <= 500);
alter table public.itamar_profiles
  add constraint itamar_profile_avatar_path_valid check
  (avatar_path is null or avatar_path like id::text || '/%');
alter table public.itamar_rooms
  add constraint itamar_room_avatar_path_valid check
  (avatar_path is null or avatar_path like id::text || '/%');

-- Public avatars intentionally reveal profile/group icons. No phone/contact data.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('itamar-connect-avatars','itamar-connect-avatars',true,3145728,
  array['image/jpeg','image/png','image/webp'])
on conflict(id) do nothing;

-- Object paths: profiles/<auth uid>/<uuid>.jpg ; groups/<room id>/<uuid>.jpg
create policy "upload my profile photo" on storage.objects
  for insert to authenticated with check
  (bucket_id='itamar-connect-avatars'
   and (storage.foldername(name))[1]='profiles'
   and (storage.foldername(name))[2]=auth.uid()::text);
create policy "upload photo to my owned group" on storage.objects
  for insert to authenticated with check
  (bucket_id='itamar-connect-avatars'
   and (storage.foldername(name))[1]='groups'
   and exists(select 1 from public.itamar_rooms r where
     r.id::text=(storage.foldername(name))[2] and r.kind='group'
     and r.owner_id=auth.uid()));

create or replace function public.itamar_set_group_details(
  p_room uuid,p_title text,p_description text,p_avatar text default null
) returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if auth.uid() is null or not exists(select 1 from public.itamar_rooms r
       where r.id=p_room and r.kind='group' and r.owner_id=auth.uid()) then
    raise exception 'Group owner permission required';
  end if;
  if length(btrim(coalesce(p_title,''))) not between 1 and 90 or
     length(coalesce(p_description,'')) > 500 or
     (p_avatar is not null and p_avatar not like 'groups/'||p_room::text||'/%')
  then raise exception 'Invalid group details'; end if;
  update public.itamar_rooms set title=btrim(p_title),
    description=coalesce(p_description,''),avatar_path=p_avatar where id=p_room;
  return true;
end $$;

create or replace function public.itamar_set_profile_prefs(
  p_avatar text,p_receipts boolean
) returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if auth.uid() is null then raise exception 'Sign in required'; end if;
  if p_avatar is not null and p_avatar not like 'profiles/'||auth.uid()::text||'/%'
  then raise exception 'Invalid avatar path'; end if;
  update public.itamar_profiles set avatar_path=p_avatar,
     read_receipts_enabled=coalesce(p_receipts,true) where id=auth.uid();
  return found;
end $$;

-- Correct avatar constraint: stored paths have named prefix before the UUID.
alter table public.itamar_profiles drop constraint if exists itamar_profile_avatar_path_valid;
alter table public.itamar_profiles add constraint itamar_profile_avatar_path_valid
  check (avatar_path is null or avatar_path like 'profiles/'||id::text||'/%');
alter table public.itamar_rooms drop constraint if exists itamar_room_avatar_path_valid;
alter table public.itamar_rooms add constraint itamar_room_avatar_path_valid
  check (avatar_path is null or avatar_path like 'groups/'||id::text||'/%');

create table if not exists public.itamar_group_invites(
  token_hash text primary key,
  room_id uuid not null references public.itamar_rooms(id) on delete cascade,
  created_by uuid not null references auth.users(id) on delete cascade,
  expires_at timestamptz not null,
  revoked boolean not null default false,
  created_at timestamptz not null default now()
);
alter table public.itamar_group_invites enable row level security;
-- No table privileges for clients. Tokens are stored hashed and used only by RPC.
revoke all on public.itamar_group_invites from anon,authenticated;

create or replace function public.itamar_make_group_invite(p_room uuid)
returns text language plpgsql security definer set search_path=public,pg_temp as $$
declare secret text:=encode(gen_random_bytes(24),'hex');
begin
  if auth.uid() is null or not exists(select 1 from public.itamar_rooms r
    join public.itamar_members m on m.room_id=r.id
    where r.id=p_room and r.kind='group' and m.user_id=auth.uid()
      and m.role='admin') then
    raise exception 'Only admins can invite';
  end if;
  insert into public.itamar_group_invites(token_hash,room_id,created_by,expires_at)
  values(encode(digest(secret,'sha256'),'hex'),p_room,auth.uid(),now()+interval '48 hours');
  return secret;
end $$;

create or replace function public.itamar_accept_group_invite(p_secret text)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare selected_room uuid;
begin
  if auth.uid() is null then raise exception 'Please sign in'; end if;
  if p_secret !~ '^[a-f0-9]{48}$' then raise exception 'Invalid invitation'; end if;
  select gi.room_id into selected_room from public.itamar_group_invites gi
   join public.itamar_rooms r on r.id=gi.room_id and r.kind='group'
   where gi.token_hash=encode(digest(p_secret,'sha256'),'hex')
     and gi.expires_at>now() and not gi.revoked
   limit 1;
  if selected_room is null then raise exception 'Invitation expired or revoked'; end if;
  if (select count(*) from public.itamar_members where room_id=selected_room)>=31
   then raise exception 'Group is full'; end if;
  if exists(select 1 from public.itamar_blocks b
     join public.itamar_members m on m.user_id=b.blocker_id and m.room_id=selected_room
     where b.blocked_id=auth.uid()) then raise exception 'Group unavailable'; end if;
  insert into public.itamar_members(room_id,user_id)
  values(selected_room,auth.uid()) on conflict do nothing;
  return selected_room;
end $$;

-- One gray check: accepted by server (no recipient acknowledgement yet).
-- Two gray: recipient opened its inbox and acknowledged delivery.
-- Two blue: recipient opened chat, if both sides permit read confirmations.
create table if not exists public.itamar_message_receipts(
  message_id uuid not null references public.itamar_messages(id) on delete cascade,
  recipient_id uuid not null references auth.users(id) on delete cascade,
  delivered_at timestamptz,
  read_at timestamptz,
  primary key(message_id,recipient_id)
);
create index if not exists itamar_receipts_recipient
 on public.itamar_message_receipts(recipient_id,delivered_at);
alter table public.itamar_message_receipts enable row level security;
-- The only exposed reads are the sender's receipt rows. A recipient's privacy
-- choice is applied when marking the chat read. No one can edit the table directly.
create policy "senders see receipts on their messages" on public.itamar_message_receipts
 for select to authenticated using(exists(
  select 1 from public.itamar_messages m where m.id=message_id and m.sender_id=auth.uid()));
grant select on public.itamar_message_receipts to authenticated;

create or replace function public.itamar_ack_messages(p_room uuid,p_opened boolean default false)
returns integer language plpgsql security definer set search_path=public,pg_temp as $$
declare n integer;
declare permitted boolean;
begin
  if auth.uid() is null or not public.itamar_is_member(p_room) then
     raise exception 'Room not available'; end if;
  select p.read_receipts_enabled into permitted from public.itamar_profiles p
     where p.id=auth.uid();
  insert into public.itamar_message_receipts(message_id,recipient_id,delivered_at,read_at)
   select m.id,auth.uid(),now(),
      case when p_opened and coalesce(permitted,true) then now() else null end
   from public.itamar_messages m
   where m.room_id=p_room and m.sender_id<>auth.uid()
   on conflict(message_id,recipient_id) do update
    set delivered_at=coalesce(public.itamar_message_receipts.delivered_at,excluded.delivered_at),
        read_at=case when p_opened and coalesce(permitted,true) then
          coalesce(public.itamar_message_receipts.read_at,now())
          else public.itamar_message_receipts.read_at end;
  get diagnostics n=row_count;
  return n;
end $$;

alter table public.itamar_messages
 add column if not exists edited_at timestamptz,
 add column if not exists deleted_at timestamptz,
 add column if not exists is_view_once boolean not null default false;
-- Never let the message sender replace someone else's text in the API.
create or replace function public.itamar_edit_message(p_message uuid,p_body text)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if auth.uid() is null or length(btrim(coalesce(p_body,''))) not between 1 and 4000
  then raise exception 'Invalid message'; end if;
  update public.itamar_messages set body=btrim(p_body),edited_at=now()
   where id=p_message and sender_id=auth.uid() and deleted_at is null
     and not is_view_once and attachment_path is null
     and created_at>=now()-interval '15 minutes';
  if not found then raise exception 'Editing window expired or message unavailable'; end if;
  return true;
end $$;

create or replace function public.itamar_delete_message(p_message uuid)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 update public.itamar_messages set
  body='Message deleted',deleted_at=now(),attachment_path=null,
  attachment_name=null,attachment_mime=null
  where id=p_message and sender_id=auth.uid() and deleted_at is null;
 if not found then raise exception 'Message unavailable'; end if;
 return true;
end $$;

-- One-time view is supported for TEXT ONLY. Media needs a separate controlled
-- delivery endpoint; never mark ordinary Storage URLs as 'view once'.
create table if not exists public.itamar_once_text(
 message_id uuid primary key references public.itamar_messages(id) on delete cascade,
 secret_body text not null check(char_length(secret_body) between 1 and 4000)
);
create table if not exists public.itamar_once_opened(
 message_id uuid not null references public.itamar_messages(id) on delete cascade,
 recipient_id uuid not null references auth.users(id) on delete cascade,
 opened_at timestamptz not null default now(),
 primary key(message_id,recipient_id)
);
alter table public.itamar_once_text enable row level security;
alter table public.itamar_once_opened enable row level security;
revoke all on public.itamar_once_text,public.itamar_once_opened from anon,authenticated;

create or replace function public.itamar_send_once_text(p_room uuid,p_text text)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare new_id uuid;
begin
 if auth.uid() is null or not public.itamar_is_member(p_room)
  or length(btrim(coalesce(p_text,''))) not between 1 and 4000
  or not exists(select 1 from public.itamar_rooms r where r.id=p_room
      and (r.kind in ('chat','group') or r.owner_id=auth.uid()))
  or exists(select 1 from public.itamar_members other
       join public.itamar_blocks b on b.blocker_id=other.user_id
       where other.room_id=p_room and b.blocked_id=auth.uid())
 then raise exception 'Cannot send one-time message'; end if;
 insert into public.itamar_messages(room_id,sender_id,body,is_view_once)
 values(p_room,auth.uid(),'View once · text',true) returning id into new_id;
 insert into public.itamar_once_text(message_id,secret_body) values(new_id,p_text);
 return new_id;
end $$;

create or replace function public.itamar_open_once_text(p_message uuid)
returns text language plpgsql security definer set search_path=public,pg_temp as $$
declare message_text text;
begin
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 -- Lock the message for an atomic one-open-per-recipient check.
 select t.secret_body into message_text
 from public.itamar_messages m join public.itamar_once_text t on t.message_id=m.id
 where m.id=p_message and m.is_view_once and m.sender_id<>auth.uid()
   and m.deleted_at is null and public.itamar_is_member(m.room_id)
 for update of t;
 if message_text is null then raise exception 'Message unavailable'; end if;
 insert into public.itamar_once_opened(message_id,recipient_id)
 values(p_message,auth.uid()) on conflict do nothing;
 if not found then raise exception 'Already opened'; end if;
 return message_text;
end $$;

revoke all on function public.itamar_set_profile_prefs(text,boolean) from public;
revoke all on function public.itamar_set_group_details(uuid,text,text,text) from public;
revoke all on function public.itamar_make_group_invite(uuid) from public;
revoke all on function public.itamar_accept_group_invite(text) from public;
revoke all on function public.itamar_ack_messages(uuid,boolean) from public;
revoke all on function public.itamar_edit_message(uuid,text) from public;
revoke all on function public.itamar_delete_message(uuid) from public;
revoke all on function public.itamar_send_once_text(uuid,text) from public;
revoke all on function public.itamar_open_once_text(uuid) from public;
grant execute on function public.itamar_set_profile_prefs(text,boolean) to authenticated;
grant execute on function public.itamar_set_group_details(uuid,text,text,text) to authenticated;
grant execute on function public.itamar_make_group_invite(uuid) to authenticated;
grant execute on function public.itamar_accept_group_invite(text) to authenticated;
grant execute on function public.itamar_ack_messages(uuid,boolean) to authenticated;
grant execute on function public.itamar_edit_message(uuid,text) to authenticated;
grant execute on function public.itamar_delete_message(uuid) to authenticated;
grant execute on function public.itamar_send_once_text(uuid,text) to authenticated;
grant execute on function public.itamar_open_once_text(uuid) to authenticated;

-- No background retention or expiration guarantee for secret text is implied.
-- Apply a separate retention policy and threat model before public distribution.

-- New RPC avoids altering the existing return signature, preserving older clients.
create or replace function public.itamar_my_rooms_v2()
returns table(id uuid,title text,kind text,owner_id uuid,muted boolean,
  latest_at timestamptz,description text,avatar_path text)
language sql stable security definer set search_path=public,pg_temp as $$
  select r.id,r.title,r.kind,r.owner_id,m.muted,
    (select max(msg.created_at) from public.itamar_messages msg where msg.room_id=r.id),
    r.description,r.avatar_path
  from public.itamar_rooms r join public.itamar_members m on m.room_id=r.id
  where m.user_id=auth.uid()
  order by 6 desc nulls last,r.created_at desc;
$$;
revoke all on function public.itamar_my_rooms_v2() from public;
grant execute on function public.itamar_my_rooms_v2() to authenticated;

-- Do not show read acknowledgement to senders who themselves disabled receipts.
drop policy if exists "senders see receipts on their messages" on public.itamar_message_receipts;
create policy "senders see receipts on their messages" on public.itamar_message_receipts
 for select to authenticated using(
   exists(select 1 from public.itamar_messages m
      where m.id=message_id and m.sender_id=auth.uid())
   and exists(select 1 from public.itamar_profiles p where p.id=auth.uid()
       and p.read_receipts_enabled=true)
 );
