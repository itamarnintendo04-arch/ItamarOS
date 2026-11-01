-- ItamarOS Connect, fourth source migration. Execute AFTER all three earlier files
-- on a dedicated, tested database. This file was NOT applied to a live server.
-- Reactions, replies, disappearing text, blocks, and user-submitted reports.
-- It does not implement calls, E2EE, or view-once attachments.

alter table public.itamar_messages
  add column if not exists reply_to uuid references public.itamar_messages(id) on delete set null,
  add column if not exists expires_at timestamptz;
create index if not exists itamar_messages_expires_at
  on public.itamar_messages (expires_at) where expires_at is not null;

create table if not exists public.itamar_reactions (
  message_id uuid not null references public.itamar_messages(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  emoji text not null check (char_length(emoji) between 1 and 8),
  created_at timestamptz not null default now(),
  primary key (message_id,user_id)
);
create index if not exists itamar_reactions_user on public.itamar_reactions(user_id);
alter table public.itamar_reactions enable row level security;
revoke all on public.itamar_reactions from anon, authenticated;
grant select on public.itamar_reactions to authenticated;
create policy "Room members see message reactions"
  on public.itamar_reactions for select to authenticated
  using (exists (
    select 1 from public.itamar_messages m
    where m.id=message_id and m.deleted_at is null
      and (m.expires_at is null or m.expires_at>now())
      and public.itamar_is_member(m.room_id)
  ));

-- No arbitrary emoji or reactions on deleted, expired, blocked, or inaccessible messages.
create or replace function public.itamar_react(p_message uuid, p_emoji text)
returns boolean language plpgsql security definer set search_path = '' as $$
declare target public.itamar_messages%rowtype;
begin
  if auth.uid() is null or p_emoji is null or
     p_emoji not in ('👍','❤️','😂','😮','😢','🙏','🎉') then
    raise exception 'Invalid reaction';
  end if;
  select * into target from public.itamar_messages where id=p_message;
  if target.id is null or target.deleted_at is not null or
     (target.expires_at is not null and target.expires_at<=now()) or
     not public.itamar_is_member(target.room_id) or
     exists (select 1 from public.itamar_blocks b
       where (b.blocker_id=auth.uid() and b.blocked_id=target.sender_id)
         or (b.blocker_id=target.sender_id and b.blocked_id=auth.uid())) then
    raise exception 'Message unavailable';
  end if;
  insert into public.itamar_reactions(message_id,user_id,emoji)
    values(p_message,auth.uid(),p_emoji)
    on conflict(message_id,user_id) do update
    set emoji=excluded.emoji,created_at=now();
  return true;
end $$;

create or replace function public.itamar_remove_reaction(p_message uuid)
returns boolean language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'Sign in required'; end if;
  delete from public.itamar_reactions
  where message_id=p_message and user_id=auth.uid();
  return true;
end $$;

create or replace function public.itamar_send_reply(
 p_room uuid,p_parent uuid,p_body text
) returns uuid language plpgsql security definer set search_path = '' as $$
declare result uuid;
declare owner uuid;
begin
  if auth.uid() is null or not public.itamar_is_member(p_room)
    or char_length(btrim(coalesce(p_body,''))) not between 1 and 4000
    or not exists(select 1 from public.itamar_rooms r where r.id=p_room and
       (r.kind in ('chat','group') or r.owner_id=auth.uid())) then
    raise exception 'Cannot reply';
  end if;
  select sender_id into owner from public.itamar_messages m where
      m.id=p_parent and m.room_id=p_room and m.deleted_at is null
      and not m.is_view_once
      and (m.expires_at is null or m.expires_at>now());
  if owner is null or exists(select 1 from public.itamar_blocks b
      where (b.blocker_id=owner and b.blocked_id=auth.uid())
         or (b.blocker_id=auth.uid() and b.blocked_id=owner)) then
      raise exception 'Reply target unavailable';
  end if;
  insert into public.itamar_messages(room_id,sender_id,body,reply_to)
  values(p_room,auth.uid(),btrim(p_body),p_parent)
  returning id into result;
  return result;
end $$;

create or replace function public.itamar_send_disappearing_text(
 p_room uuid,p_body text,p_seconds integer
) returns uuid language plpgsql security definer set search_path = '' as $$
declare result uuid;
begin
  if auth.uid() is null or not public.itamar_is_member(p_room)
    or char_length(btrim(coalesce(p_body,''))) not between 1 and 4000
    or p_seconds not in (3600,86400,604800)
    or not exists(select 1 from public.itamar_rooms r
      where r.id=p_room and (r.kind in ('chat','group') or r.owner_id=auth.uid()))
    or exists(select 1 from public.itamar_members other
      join public.itamar_blocks b on b.blocker_id=other.user_id
      where other.room_id=p_room and b.blocked_id=auth.uid()) then
      raise exception 'Cannot send disappearing message';
  end if;
  insert into public.itamar_messages(room_id,sender_id,body,expires_at)
  values(p_room,auth.uid(),btrim(p_body),now()+make_interval(secs=>p_seconds))
  returning id into result;
  return result;
end $$;

-- Expired messages cannot be read through the messages endpoint. This is
-- *visibility expiry*, not guaranteed deletion of backups/screenshots/exports.
drop policy if exists "read only room messages" on public.itamar_messages;
create policy "read only room messages"
  on public.itamar_messages for select to authenticated
  using (public.itamar_is_member(room_id)
    and (expires_at is null or expires_at>now()));

create or replace function public.itamar_my_updates()
returns table(id uuid,room_id uuid,title text,body text,created_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select msg.id,msg.room_id,r.title,msg.body,msg.created_at
  from public.itamar_messages msg
  join public.itamar_rooms r on r.id=msg.room_id
  join public.itamar_members member on member.room_id=r.id
    and member.user_id=auth.uid()
  where not member.muted and msg.sender_id<>auth.uid()
    and msg.deleted_at is null and not msg.is_view_once
    and (msg.expires_at is null or msg.expires_at>now())
  order by msg.created_at desc limit 100;
$$;

create table if not exists public.itamar_message_reports (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.itamar_messages(id) on delete cascade,
  reporter_id uuid not null references auth.users(id) on delete cascade,
  reason text not null check(reason in ('Spam','Harassment','Threats','Other')),
  detail text not null default '' check(char_length(detail)<=500),
  created_at timestamptz not null default now(),
  unique(message_id,reporter_id)
);
alter table public.itamar_message_reports enable row level security;
revoke all on public.itamar_message_reports from anon,authenticated;
grant select on public.itamar_message_reports to authenticated;
create policy "Reporters view only their own reports"
 on public.itamar_message_reports for select to authenticated
 using(reporter_id=auth.uid());

-- Reporting records a flag for future human moderation; there is currently
-- no moderator dashboard or response SLA. Never promise review/action.
create or replace function public.itamar_report_message(
 p_message uuid,p_reason text,p_detail text default ''
) returns uuid language plpgsql security definer set search_path = '' as $$
declare target public.itamar_messages%rowtype;
declare result uuid;
begin
 if auth.uid() is null or p_reason not in ('Spam','Harassment','Threats','Other')
    or char_length(coalesce(p_detail,''))>500 then
   raise exception 'Invalid report';
 end if;
 select * into target from public.itamar_messages m where m.id=p_message;
 if target.id is null or target.sender_id=auth.uid() or
    not public.itamar_is_member(target.room_id) then
   raise exception 'Message unavailable';
 end if;
 insert into public.itamar_message_reports(message_id,reporter_id,reason,detail)
 values(p_message,auth.uid(),p_reason,coalesce(p_detail,''))
 on conflict(message_id,reporter_id) do update
 set reason=excluded.reason, detail=excluded.detail
 returning id into result;
 return result;
end $$;

-- Existing itamar_blocks RLS permits blocking/unblocking own targets; prevent
-- contact-by-username chat creation with blocked users in the existing RPC.
-- Existing read access to pre-block chats is NOT retroactively revoked. In a
-- production chat service, define a policy for hiding/parting blocked chats.

revoke all on function public.itamar_react(uuid,text) from public,anon;
revoke all on function public.itamar_remove_reaction(uuid) from public,anon;
revoke all on function public.itamar_send_reply(uuid,uuid,text) from public,anon;
revoke all on function public.itamar_send_disappearing_text(uuid,text,integer) from public,anon;
revoke all on function public.itamar_report_message(uuid,text,text) from public,anon;
grant execute on function public.itamar_react(uuid,text) to authenticated;
grant execute on function public.itamar_remove_reaction(uuid) to authenticated;
grant execute on function public.itamar_send_reply(uuid,uuid,text) to authenticated;
grant execute on function public.itamar_send_disappearing_text(uuid,text,integer) to authenticated;
grant execute on function public.itamar_report_message(uuid,text,text) to authenticated;
