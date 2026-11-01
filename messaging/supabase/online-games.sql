-- Multiplayer Tic-Tac-Toe v1 (phone/iPhone share the same Supabase backend).
-- Apply after messaging/supabase/migration.sql. Every mutation is server-authoritative.
create table if not exists public.itamar_game_matches (
 id uuid primary key default gen_random_uuid(),
 code text not null unique default upper(left(replace(gen_random_uuid()::text,'-',''),10)),
 game text not null default 'tic_tac_toe' check (game='tic_tac_toe'),
 host_id uuid not null references auth.users(id) on delete cascade,
 guest_id uuid references auth.users(id) on delete set null,
 board text not null default '_________' check (board ~ '^[XO_]{9}$'),
 turn text not null default 'X' check (turn in ('X','O')),
 winner text not null default '' check (winner in ('','X','O','draw')),
 status text not null default 'waiting' check (status in ('waiting','playing','finished')),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 expires_at timestamptz not null default (now()+interval '24 hours'),
 constraint different_players check (guest_id is null or guest_id<>host_id)
);
create index if not exists itamar_game_matches_host_idx on public.itamar_game_matches(host_id,created_at desc);
create table if not exists public.itamar_game_invites (
 match_id uuid not null references public.itamar_game_matches(id) on delete cascade,
 recipient_id uuid not null references auth.users(id) on delete cascade,
 created_at timestamptz not null default now(),
 primary key (match_id,recipient_id)
);
create table if not exists public.itamar_game_join_attempts (
 user_id uuid not null references auth.users(id) on delete cascade,
 attempted_at timestamptz not null default now()
);
create index if not exists itamar_game_attempts_user_idx on public.itamar_game_join_attempts(user_id,attempted_at desc);
alter table public.itamar_game_matches enable row level security;
alter table public.itamar_game_invites enable row level security;
alter table public.itamar_game_join_attempts enable row level security;
revoke all on public.itamar_game_matches, public.itamar_game_invites, public.itamar_game_join_attempts from anon, authenticated;
grant select on public.itamar_game_matches to authenticated;
drop policy if exists "game participants can read game" on public.itamar_game_matches;
create policy "game participants can read game" on public.itamar_game_matches
for select to authenticated using (host_id=(select auth.uid()) or guest_id=(select auth.uid()));

create or replace function public.itamar_game_create()
returns jsonb language plpgsql security definer set search_path='' as $$
declare me uuid:=auth.uid(); g public.itamar_game_matches%rowtype;
begin
 if me is null or not exists(select 1 from public.itamar_profiles where id=me) then raise exception 'Create a username profile first'; end if;
 if (select count(*) from public.itamar_game_matches where host_id=me and status='waiting' and expires_at>now())>=3 then
   raise exception 'You already have three waiting matches';
 end if;
 insert into public.itamar_game_matches(host_id) values(me) returning * into g;
 return to_jsonb(g);
end $$;

create or replace function public.itamar_game_join(p_code text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare me uuid:=auth.uid(); g public.itamar_game_matches%rowtype;
begin
 if me is null or not exists(select 1 from public.itamar_profiles where id=me) then raise exception 'Create a username profile first'; end if;
 if p_code is null or p_code !~ '^[A-Fa-f0-9]{10}$' then raise exception 'Enter a 10-character game code'; end if;
 delete from public.itamar_game_join_attempts where attempted_at<now()-interval '1 day';
 if (select count(*) from public.itamar_game_join_attempts where user_id=me and attempted_at>now()-interval '5 minutes')>=12 then
   raise exception 'Too many attempts. Try again later';
 end if;
 insert into public.itamar_game_join_attempts(user_id) values(me);
 select * into g from public.itamar_game_matches where code=upper(p_code) for update;
 if not found or g.expires_at<=now() then raise exception 'Match not found or expired'; end if;
 if g.host_id=me or g.guest_id=me then return to_jsonb(g); end if;
 if g.status<>'waiting' or g.guest_id is not null then raise exception 'This match already has two players'; end if;
 if exists(select 1 from public.itamar_blocks where
   (blocker_id=me and blocked_id=g.host_id) or (blocker_id=g.host_id and blocked_id=me)) then
   raise exception 'This match is unavailable';
 end if;
 update public.itamar_game_matches set guest_id=me,status='playing',updated_at=now() where id=g.id returning * into g;
 return to_jsonb(g);
end $$;

create or replace function public.itamar_game_get(p_code text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare me uuid:=auth.uid(); g public.itamar_game_matches%rowtype;
begin
 if me is null or p_code is null or p_code !~ '^[A-Fa-f0-9]{10}$' then raise exception 'Invalid game code'; end if;
 select * into g from public.itamar_game_matches where code=upper(p_code) and (host_id=me or guest_id=me);
 if not found then raise exception 'You are not a participant in this match'; end if;
 return to_jsonb(g);
end $$;

create or replace function public.itamar_game_move(p_code text,p_position integer)
returns jsonb language plpgsql security definer set search_path='' as $$
declare me uuid:=auth.uid(); g public.itamar_game_matches%rowtype;
declare piece text; new_board text; combo integer[]; wins integer[][]:=array[
 array[1,2,3],array[4,5,6],array[7,8,9],
 array[1,4,7],array[2,5,8],array[3,6,9],
 array[1,5,9],array[3,5,7]];
begin
 if me is null or p_code is null or p_code !~ '^[A-Fa-f0-9]{10}$' then raise exception 'Invalid game code'; end if;
 select * into g from public.itamar_game_matches where code=upper(p_code) for update;
 if not found or g.expires_at<=now() or g.status<>'playing' then raise exception 'This match is not active'; end if;
 piece:=case when g.host_id=me then 'X' when g.guest_id=me then 'O' else null end;
 if piece is null then raise exception 'You are not a player'; end if;
 if g.turn<>piece then raise exception 'Wait for the other player'; end if;
 if p_position is null or p_position not between 0 and 8 or substr(g.board,p_position+1,1)<>'_' then
   raise exception 'Invalid or occupied square';
 end if;
 new_board:=overlay(g.board placing piece from p_position+1 for 1);
 g.winner:='';
 foreach combo slice 1 in array wins loop
   if substr(new_board,combo[1],1)=piece and substr(new_board,combo[2],1)=piece
     and substr(new_board,combo[3],1)=piece then g.winner:=piece; exit; end if;
 end loop;
 if g.winner='' and position('_' in new_board)=0 then g.winner:='draw'; end if;
 update public.itamar_game_matches
   set board=new_board,turn=case when piece='X' then 'O' else 'X' end,
       winner=g.winner,status=case when g.winner='' then 'playing' else 'finished' end,
       updated_at=now()
 where id=g.id returning * into g;
 return to_jsonb(g);
end $$;

-- Invitations are delivered to a selected @username inside a real ItamarOS chat.
-- Block checks are enforced by itamar_create_room; invitations are once per person per match.
create or replace function public.itamar_game_invite(p_code text,p_username text)
returns uuid language plpgsql security definer set search_path='' as $$
declare me uuid:=auth.uid();g public.itamar_game_matches%rowtype; target uuid; room uuid;
begin
 if me is null or p_code is null or p_code !~ '^[A-Fa-f0-9]{10}$' then raise exception 'Invalid game code'; end if;
 select * into g from public.itamar_game_matches where code=upper(p_code) and host_id=me;
 if not found or g.status<>'waiting' or g.expires_at<=now() then raise exception 'Only the host of a waiting match can invite players'; end if;
 select id into target from public.itamar_profiles where username=lower(trim(leading '@' from btrim(coalesce(p_username,''))));
 if target is null or target=me then raise exception 'Choose a valid other username'; end if;
 if exists(select 1 from public.itamar_game_invites where match_id=g.id and recipient_id=target) then
   raise exception 'You already invited this username';
 end if;
 if (select count(*) from public.itamar_game_invites where match_id=g.id)>=15 then
   raise exception 'Invitation limit reached for this match';
 end if;
 room:=public.itamar_create_room('chat','Game invite',lower(trim(leading '@' from btrim(p_username))));
 insert into public.itamar_messages(room_id,sender_id,body)
 values(room,me,'🎮 Tic-Tac-Toe invitation! Open Games → Online match and enter code: '||g.code);
 insert into public.itamar_game_invites(match_id,recipient_id) values(g.id,target);
 return room;
end $$;

-- Functions are exposed through RPC only to authenticated accounts.
revoke all on function public.itamar_game_create() from public, anon;
revoke all on function public.itamar_game_join(text) from public, anon;
revoke all on function public.itamar_game_get(text) from public, anon;
revoke all on function public.itamar_game_move(text,integer) from public, anon;
revoke all on function public.itamar_game_invite(text,text) from public, anon;
grant execute on function public.itamar_game_create() to authenticated;
grant execute on function public.itamar_game_join(text) to authenticated;
grant execute on function public.itamar_game_get(text) to authenticated;
grant execute on function public.itamar_game_move(text,integer) to authenticated;
grant execute on function public.itamar_game_invite(text,text) to authenticated;
