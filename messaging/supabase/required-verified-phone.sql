-- Applied in ItamarOS Supabase after the base, extended, experience,
-- conversation-tools and security-realtime migrations.
-- Accounts without a confirmed Supabase Auth phone cannot access chat messages.
create or replace function public.itamar_is_member(p_room uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.itamar_members m
 join auth.users u on u.id=m.user_id
 where m.room_id=p_room and m.user_id=auth.uid()
 and u.phone_confirmed_at is not null);
$$;
revoke all on function public.itamar_is_member(uuid) from public,anon;
grant execute on function public.itamar_is_member(uuid) to authenticated;

create or replace function public.itamar_my_rooms()
returns table(id uuid,title text,kind text,owner_id uuid,muted boolean,latest_at timestamptz)
language sql stable security definer set search_path='' as $$
 select r.id,r.title,r.kind,r.owner_id,m.muted,
 (select max(msg.created_at) from public.itamar_messages msg where msg.room_id=r.id)
 from public.itamar_rooms r join public.itamar_members m on m.room_id=r.id
 where m.user_id=auth.uid() and public.itamar_is_member(r.id)
 order by 6 desc nulls last,r.created_at desc;
$$;
revoke all on function public.itamar_my_rooms() from public,anon;
grant execute on function public.itamar_my_rooms() to authenticated;

create or replace function public.itamar_my_rooms_v2()
returns table(id uuid,title text,kind text,owner_id uuid,muted boolean,
 latest_at timestamptz,description text,avatar_path text)
language sql stable security definer set search_path='' as $$
 select r.id,r.title,r.kind,r.owner_id,m.muted,
 (select max(msg.created_at) from public.itamar_messages msg where msg.room_id=r.id),
 r.description,r.avatar_path
 from public.itamar_rooms r join public.itamar_members m on m.room_id=r.id
 where m.user_id=auth.uid() and public.itamar_is_member(r.id)
 order by 6 desc nulls last,r.created_at desc;
$$;
revoke all on function public.itamar_my_rooms_v2() from public,anon;
grant execute on function public.itamar_my_rooms_v2() to authenticated;

create or replace function public.itamar_my_updates()
returns table(id uuid,room_id uuid,title text,body text,created_at timestamptz)
language sql stable security definer set search_path='' as $$
 select msg.id,msg.room_id,r.title,msg.body,msg.created_at
 from public.itamar_messages msg
 join public.itamar_rooms r on r.id=msg.room_id
 join public.itamar_members member on member.room_id=r.id and member.user_id=auth.uid()
 where public.itamar_is_member(msg.room_id)
 and not member.muted and msg.sender_id<>auth.uid()
 and msg.deleted_at is null and not msg.is_view_once
 and (msg.expires_at is null or msg.expires_at>now())
 and not exists (select 1 from public.itamar_blocks b where
 (b.blocker_id=auth.uid() and b.blocked_id=msg.sender_id) or
 (b.blocker_id=msg.sender_id and b.blocked_id=auth.uid()))
 order by msg.created_at desc limit 100;
$$;
revoke all on function public.itamar_my_updates() from public,anon;
grant execute on function public.itamar_my_updates() to authenticated;
