-- Standalone opt-in pairing for an ItamarOS *account's own* devices.
-- No SMS, call logs, iMessage, WhatsApp or device address book ingestion.
-- Separate from the unreviewed ItamarConnect messaging migrations.

create table if not exists public.itamar_device_pairs (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  secret_hash text not null unique,
  desktop_name text not null check(char_length(desktop_name) between 1 and 60),
  phone_name text check(phone_name is null or char_length(phone_name) between 1 and 60)),
  companion_id uuid,
  sync_chats boolean not null default false,
  sync_contacts boolean not null default false,
  sync_files boolean not null default false,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  claimed_at timestamptz,
  revoked_at timestamptz
);
create index if not exists itamar_pairs_by_owner on public.itamar_device_pairs(owner_id,created_at desc);
alter table public.itamar_device_pairs enable row level security;
revoke all on public.itamar_device_pairs from public,anon,authenticated;

-- The pairing secret never appears in table API access, only to the owner
-- *at creation*; in the DB only a SHA-256 hash is stored.
create or replace function public.itamar_begin_pair(
 p_name text,p_chats boolean default false,p_contacts boolean default false,
 p_files boolean default false
) returns text language plpgsql security definer
set search_path='' as $$
declare code text;
begin
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 if char_length(btrim(coalesce(p_name,''))) not between 1 and 60 then
  raise exception 'Device name required'; end if;
 if (select count(*) from public.itamar_device_pairs
     where owner_id=auth.uid() and revoked_at is null
       and (claimed_at is not null or expires_at>now()))>=20 then
  raise exception 'Too many paired or pending devices'; end if;
 code:=encode(extensions.gen_random_bytes(24),'hex');
 insert into public.itamar_device_pairs (
  owner_id,secret_hash,desktop_name,expires_at,
  sync_chats,sync_contacts,sync_files
 ) values(auth.uid(),encode(extensions.digest(code,'sha256'),'hex'),
  btrim(p_name),now()+interval '10 minutes',
  coalesce(p_chats,false),coalesce(p_contacts,false),coalesce(p_files,false));
 return code;
end $$;

create or replace function public.itamar_pair_preview(p_code text)
returns table(desktop_name text,sync_chats boolean,sync_contacts boolean,
  sync_files boolean,expires_at timestamptz)
language sql security definer set search_path='' as $$
 select d.desktop_name,d.sync_chats,d.sync_contacts,d.sync_files,d.expires_at
 from public.itamar_device_pairs d
 where auth.uid() is not null
   and d.owner_id=auth.uid()
   and p_code~'^[0-9a-f]{48}$'
   and d.secret_hash=encode(extensions.digest(p_code,'sha256'),'hex')
   and d.claimed_at is null and d.revoked_at is null and d.expires_at>now()
 limit 1;
$$;

create or replace function public.itamar_accept_pair(
 p_code text,p_device uuid,p_phone_name text
) returns uuid language plpgsql security definer
set search_path='' as $$
declare pair_id uuid;
begin
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 if p_code !~ '^[0-9a-f]{48}$' or p_device is null or
   char_length(btrim(coalesce(p_phone_name,''))) not between 1 and 60 then
   raise exception 'Invalid pairing request'; end if;
 update public.itamar_device_pairs
 set companion_id=p_device,phone_name=btrim(p_phone_name),
     claimed_at=now()
 where owner_id=auth.uid()
   and secret_hash=encode(extensions.digest(p_code,'sha256'),'hex')
   and claimed_at is null and revoked_at is null and expires_at>now()
 returning id into pair_id;
 if pair_id is null then raise exception 'Pairing code expired, invalid or used'; end if;
 return pair_id;
end $$;

create or replace function public.itamar_my_device_pairs()
returns table(id uuid,desktop_name text,phone_name text,companion_id uuid,
  sync_chats boolean,sync_contacts boolean,sync_files boolean,
  created_at timestamptz,claimed_at timestamptz,revoked_at timestamptz)
language sql stable security definer set search_path='' as $$
 select d.id,d.desktop_name,d.phone_name,d.companion_id,
  d.sync_chats,d.sync_contacts,d.sync_files,
  d.created_at,d.claimed_at,d.revoked_at
 from public.itamar_device_pairs d where d.owner_id=auth.uid()
   and (d.claimed_at is not null or d.expires_at>now())
 order by d.created_at desc limit 40;
$$;

create or replace function public.itamar_revoke_pair(p_pair uuid)
returns boolean language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 update public.itamar_device_pairs set revoked_at=now()
 where id=p_pair and owner_id=auth.uid() and revoked_at is null;
 return found;
end $$;

revoke all on function public.itamar_begin_pair(text,boolean,boolean,boolean) from public,anon;
revoke all on function public.itamar_pair_preview(text) from public,anon;
revoke all on function public.itamar_accept_pair(text,uuid,text) from public,anon;
revoke all on function public.itamar_my_device_pairs() from public,anon;
revoke all on function public.itamar_revoke_pair(uuid) from public,anon;
grant execute on function public.itamar_begin_pair(text,boolean,boolean,boolean) to authenticated;
grant execute on function public.itamar_pair_preview(text) to authenticated;
grant execute on function public.itamar_accept_pair(text,uuid,text) to authenticated;
grant execute on function public.itamar_my_device_pairs() to authenticated;
grant execute on function public.itamar_revoke_pair(uuid) to authenticated;

comment on table public.itamar_device_pairs is
 'Opt-in same-account device pairing metadata; never contains private SMS, call logs, contacts, files or access tokens.';
