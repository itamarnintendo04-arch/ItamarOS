-- ItamarOS Connect: apply after conversation-tools.sql.
-- Keeps privileged RPC functions signed-in only and enables live room messages.
do $secure$
declare fn record;
begin
 for fn in select p.oid::regprocedure as signature
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname like 'itamar_%' and p.prosecdef
 loop
  execute format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon',fn.signature);
  execute format('GRANT EXECUTE ON FUNCTION %s TO authenticated',fn.signature);
 end loop;
end $secure$;

do $realtime$
begin
 if not exists (select 1 from pg_publication_tables where
    pubname='supabase_realtime' and schemaname='public' and tablename='itamar_messages') then
   alter publication supabase_realtime add table public.itamar_messages;
 end if;
end $realtime$;

drop policy if exists "send authorized messages" on public.itamar_messages;
create policy "send authorized messages" on public.itamar_messages
for insert to authenticated with check (
 sender_id=(select auth.uid()) and public.itamar_is_member(room_id)
 and (attachment_path is null or
      (split_part(attachment_path,'/',1)=room_id::text and
       attachment_mime=any(array['image/jpeg','image/png','image/gif','image/webp','image/heic',
             'video/mp4','video/quicktime','audio/mpeg','audio/mp4','audio/wav',
             'application/pdf','text/plain','text/vcard','text/calendar'])))
 and exists (select 1 from public.itamar_rooms r where r.id=itamar_messages.room_id
   and (r.kind in ('chat','group') or r.owner_id=auth.uid()))
 and not exists (select 1 from public.itamar_rooms r
   join public.itamar_members peer on peer.room_id=r.id and peer.user_id<>auth.uid()
   join public.itamar_blocks b on
      ((b.blocker_id=peer.user_id and b.blocked_id=auth.uid()) or
       (b.blocker_id=auth.uid() and b.blocked_id=peer.user_id))
   where r.id=itamar_messages.room_id and r.kind='chat')
);

drop policy if exists "read only room messages" on public.itamar_messages;
create policy "read only room messages" on public.itamar_messages
for select to authenticated using (
  public.itamar_is_member(room_id)
  and (expires_at is null or expires_at>now())
  and not exists (select 1 from public.itamar_blocks b
   where (b.blocker_id=auth.uid() and b.blocked_id=itamar_messages.sender_id)
      or (b.blocker_id=itamar_messages.sender_id and b.blocked_id=auth.uid()))
);

create or replace function public.itamar_my_updates()
returns table(id uuid,room_id uuid,title text,body text,created_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select msg.id,msg.room_id,r.title,msg.body,msg.created_at
  from public.itamar_messages msg
  join public.itamar_rooms r on r.id=msg.room_id
  join public.itamar_members member on member.room_id=r.id and member.user_id=auth.uid()
  where not member.muted and msg.sender_id<>auth.uid()
    and msg.deleted_at is null and not msg.is_view_once
    and (msg.expires_at is null or msg.expires_at>now())
    and not exists (select 1 from public.itamar_blocks b
      where (b.blocker_id=auth.uid() and b.blocked_id=msg.sender_id)
         or (b.blocker_id=msg.sender_id and b.blocked_id=auth.uid()))
  order by msg.created_at desc limit 100;
$$;
revoke all on function public.itamar_my_updates() from public, anon;
grant execute on function public.itamar_my_updates() to authenticated;
