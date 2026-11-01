-- ItamarOS native push foundation. APNs and Firebase credentials must be configured
-- outside GitHub before delivery can begin. Only opted-in signed-in devices register.
create table if not exists public.itamar_push_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  device_id uuid not null,
  provider text not null check (provider in ('apns','fcm')),
  token text not null,
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(user_id, device_id)
);
create index if not exists itamar_push_devices_user_idx on public.itamar_push_devices(user_id,enabled);
create table if not exists public.itamar_push_outbox (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references auth.users(id) on delete cascade,
  message_id uuid not null references public.itamar_messages(id) on delete cascade,
  room_id uuid not null references public.itamar_rooms(id) on delete cascade,
  kind text not null default 'message',
  title text not null default 'ItamarOS Connect',
  body text not null default 'New message',
  status text not null default 'pending' check (status in ('pending','sent','failed')),
  attempts integer not null default 0 check (attempts between 0 and 20),
  last_error text,
  created_at timestamptz not null default now(),
  processed_at timestamptz,
  unique(message_id,recipient_id)
);
create index if not exists itamar_push_outbox_pending_idx on public.itamar_push_outbox(status,created_at);
alter table public.itamar_push_devices enable row level security;
alter table public.itamar_push_outbox enable row level security;
revoke all on public.itamar_push_devices,public.itamar_push_outbox from anon,authenticated;

create or replace function public.itamar_push_register(p_device_id uuid,p_provider text,p_token text)
returns boolean language plpgsql security definer set search_path='' as $$
declare me uuid:=auth.uid(); n integer;
begin
  if me is null or not exists(select 1 from public.itamar_profiles where id=me)
    then raise exception 'Sign in and set a username first';end if;
  if p_device_id is null or p_provider not in ('apns','fcm') or
     p_token is null or length(p_token) not between 32 and 4096 or
     p_token ~ '[[:space:]]' then
     raise exception 'Invalid push device registration';
  end if;
  if p_provider='apns' and (p_token !~ '^[0-9a-f]{64,}$' or length(p_token)>256)
    then raise exception 'Invalid APNs token';end if;
  select count(*) into n from public.itamar_push_devices where user_id=me and device_id<>p_device_id;
  if n>=5 then raise exception 'Maximum five push devices per account';end if;
  insert into public.itamar_push_devices(user_id,device_id,provider,token)
    values(me,p_device_id,p_provider,p_token)
    on conflict(user_id,device_id) do update
     set provider=excluded.provider,token=excluded.token,enabled=true,updated_at=now();
  return true;
end $$;

create or replace function public.itamar_push_unregister(p_device_id uuid)
returns boolean language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null then raise exception 'Sign in first';end if;
  delete from public.itamar_push_devices
   where user_id=auth.uid() and device_id=p_device_id;
  return true;
end $$;

-- A message is only queued for currently unmuted room members who have opted in
-- with a device token. Do not copy message body or attachment data into pushes.
create or replace function public.itamar_queue_message_push()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if new.deleted_at is not null then return new;end if;
  insert into public.itamar_push_outbox(recipient_id,message_id,room_id,kind,title,body)
  select m.user_id,new.id,new.room_id,'message','ItamarOS Connect','New message'
  from public.itamar_members m
  where m.room_id=new.room_id
    and m.user_id<>new.sender_id
    and not coalesce(m.muted,false)
    and exists(select 1 from public.itamar_push_devices d
      where d.user_id=m.user_id and d.enabled)
    and not exists (select 1 from public.itamar_blocks b
      where (b.blocker_id=m.user_id and b.blocked_id=new.sender_id)
         or (b.blocker_id=new.sender_id and b.blocked_id=m.user_id))
    and (select count(*) from public.itamar_push_outbox q
      where q.recipient_id=m.user_id and q.created_at>now()-interval '1 minute')<30
  on conflict(message_id,recipient_id) do nothing;
  return new;
end $$;
drop trigger if exists itamar_push_on_message on public.itamar_messages;
create trigger itamar_push_on_message
after insert on public.itamar_messages
for each row execute function public.itamar_queue_message_push();

revoke all on function public.itamar_push_register(uuid,text,text) from public,anon;
revoke all on function public.itamar_push_unregister(uuid) from public,anon;
revoke all on function public.itamar_queue_message_push() from public,anon,authenticated;
grant execute on function public.itamar_push_register(uuid,text,text) to authenticated;
grant execute on function public.itamar_push_unregister(uuid) to authenticated;
