-- Online 2-player game variants + original 4-player Cloud Climb lobby.
-- Run after messaging/supabase/online-games.sql. No Crossy Road Castle assets/code.
create table if not exists public.itamar_party_rooms (
 id uuid primary key default gen_random_uuid(),
 code text not null unique default upper(left(replace(gen_random_uuid()::text,'-',''),10)),
 game text not null check (game in ('connect_four','rock_paper_scissors','cloud_climb')),
 host_id uuid not null references auth.users(id) on delete cascade,
 player2 uuid references auth.users(id) on delete set null,
 player3 uuid references auth.users(id) on delete set null,
 player4 uuid references auth.users(id) on delete set null,
 status text not null default 'waiting' check (status in ('waiting','playing','finished')),
 board text not null default repeat('_',42) check (length(board)=42 and board ~ '^[XO_]+$'),
 turn_slot integer not null default 1 check (turn_slot in (1,2)),
 winner text not null default '' check (winner in ('','X','O','draw')),
 choice1 text not null default '' check (choice1 in ('','rock','paper','scissors')),
 choice2 text not null default '' check (choice2 in ('','rock','paper','scissors')),
 positions jsonb not null default '{}'::jsonb,
 seed integer not null default floor(random()*2000000000)::integer,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 expires_at timestamptz not null default (now()+interval '12 hours'),
 constraint party_distinct check (
   (player2 is null or player2<>host_id) and
   (player3 is null or (player3<>host_id and player3 is distinct from player2)) and
   (player4 is null or (player4<>host_id and player4 is distinct from player2 and player4 is distinct from player3)))
);
create index if not exists itamar_party_host_idx on public.itamar_party_rooms(host_id,created_at desc);
alter table public.itamar_party_rooms enable row level security;
revoke all on public.itamar_party_rooms from anon, authenticated;
-- All reads and writes are through authenticated RPC with row locks.
create or replace function public.itamar_party_public(g public.itamar_party_rooms, me uuid)
returns jsonb language sql stable set search_path='' as $$
 select (to_jsonb(g)-'choice1'-'choice2') ||
   jsonb_build_object('your_choice',
      case when me=g.host_id then g.choice1 when me=g.player2 then g.choice2 else '' end) ||
   (case when g.status='finished' and g.game='rock_paper_scissors'
      then jsonb_build_object('revealed_choices',jsonb_build_array(g.choice1,g.choice2))
      else '{}'::jsonb end);
$$;
revoke all on function public.itamar_party_public(public.itamar_party_rooms,uuid) from public,anon,authenticated;

create or replace function public.itamar_party_create(p_game text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare me uuid:=auth.uid(); g public.itamar_party_rooms%rowtype;
begin
 if me is null or not exists(select 1 from public.itamar_profiles where id=me) then
   raise exception 'Create your unique username before playing';
 end if;
 if p_game not in ('connect_four','rock_paper_scissors','cloud_climb') then
   raise exception 'Unsupported game';
 end if;
 if (select count(*) from public.itamar_party_rooms
     where host_id=me and status='waiting' and expires_at>now())>=3 then
   raise exception 'Close an unused lobby before creating more';
 end if;
 insert into public.itamar_party_rooms(game,host_id)
   values(p_game,me) returning * into g;
 return public.itamar_party_public(g,me);
end $$;

create or replace function public.itamar_party_join(p_code text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare me uuid:=auth.uid();g public.itamar_party_rooms%rowtype;
begin
 if me is null or not exists(select 1 from public.itamar_profiles where id=me) then
   raise exception 'Create your unique username before playing';
 end if;
 if p_code is null or p_code !~ '^[a-fA-F0-9]{10}$' then
   raise exception 'Enter a valid 10-character code'; end if;
 -- The existing shared budget prevents rapid room-code guessing.
 if (select count(*) from public.itamar_game_join_attempts
     where user_id=me and attempted_at>now()-interval '5 minutes')>=12 then
   raise exception 'Too many join attempts. Try later';
 end if;
 insert into public.itamar_game_join_attempts(user_id) values(me);
 select * into g from public.itamar_party_rooms where code=upper(p_code) for update;
 if not found or g.expires_at<now() then raise exception 'Room not found or expired'; end if;
 if me in (g.host_id,g.player2,g.player3,g.player4) then
   return public.itamar_party_public(g,me);
 end if;
 if exists(select 1 from public.itamar_blocks where
   (blocker_id=me and blocked_id=g.host_id) or
   (blocker_id=g.host_id and blocked_id=me)) then raise exception 'Room unavailable';end if;
 if g.game<>'cloud_climb' and g.status<>'waiting' then raise exception 'Match already started';end if;
 if g.game='cloud_climb' and g.status='finished' then raise exception 'This run has finished';end if;
 if g.player2 is null then
   update public.itamar_party_rooms
     set player2=me,status='playing',updated_at=now() where id=g.id returning * into g;
 elsif g.game='cloud_climb' and g.player3 is null then
   update public.itamar_party_rooms
     set player3=me,updated_at=now() where id=g.id returning * into g;
 elsif g.game='cloud_climb' and g.player4 is null then
   update public.itamar_party_rooms
     set player4=me,updated_at=now() where id=g.id returning * into g;
 else raise exception 'Room is full';
 end if;
 return public.itamar_party_public(g,me);
end $$;

create or replace function public.itamar_party_state(p_code text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare me uuid:=auth.uid(); g public.itamar_party_rooms%rowtype;
begin
 if me is null or p_code is null or p_code !~ '^[a-fA-F0-9]{10}$' then raise exception 'Invalid code';end if;
 select * into g from public.itamar_party_rooms where code=upper(p_code)
   and (host_id=me or player2=me or player3=me or player4=me);
 if not found then raise exception 'Not a player in this room'; end if;
 return public.itamar_party_public(g,me);
end $$;

create or replace function public.itamar_party_move(p_code text,p_column integer default null,p_choice text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare me uuid:=auth.uid();g public.itamar_party_rooms%rowtype;symbol text; idx integer;col integer;
declare b text; r integer; c integer; count_run integer; step_r integer;step_c integer; did_win boolean:=false;
begin
 if me is null or p_code is null or p_code !~ '^[a-fA-F0-9]{10}$' then raise exception 'Invalid code';end if;
 select * into g from public.itamar_party_rooms where code=upper(p_code) for update;
 if not found or g.status<>'playing' or g.expires_at<now() then raise exception 'Match is not active';end if;
 if me<>g.host_id and me is distinct from g.player2 then raise exception 'Not an authorized player';end if;
 if g.game='cloud_climb' then raise exception 'This game uses movement, not turns';end if;
 symbol:=case when me=g.host_id then 'X' else 'O' end;
 if g.game='rock_paper_scissors' then
   if p_choice not in ('rock','paper','scissors') then raise exception 'Choose rock, paper or scissors';end if;
   if (symbol='X' and g.choice1<>'') or (symbol='O' and g.choice2<>'') then
     raise exception 'Already selected your move';end if;
   if symbol='X' then g.choice1:=p_choice;else g.choice2:=p_choice;end if;
   if g.choice1<>'' and g.choice2<>'' then
     g.status:='finished';
     g.winner:=case
       when g.choice1=g.choice2 then 'draw'
       when (g.choice1='rock' and g.choice2='scissors') or
            (g.choice1='scissors' and g.choice2='paper') or
            (g.choice1='paper' and g.choice2='rock') then 'X'
       else 'O' end;
   end if;
 else
   if g.turn_slot<>(case when symbol='X' then 1 else 2 end) then raise exception 'Wait your turn';end if;
   if p_column is null or p_column not between 0 and 6 then raise exception 'Column must be 0 to 6';end if;
   b:=g.board;idx:=0;
   for r in reverse 0..5 loop
     if substr(b,r*7+p_column+1,1)='_' then
       idx:=r*7+p_column+1;exit;
     end if;
   end loop;
   if idx=0 then raise exception 'This column is full';end if;
   b:=overlay(b placing symbol from idx for 1);
   r:=(idx-1)/7;c:=(idx-1)%7;
   -- Four connected discs, checked in four orientations.
   for step_r,step_c in
     select * from (values (1,0),(0,1),(1,1),(1,-1)) dirs(dr,dc)
   loop
     count_run:=1;
     for col in 1..3 loop
       exit when r+step_r*col not between 0 and 5 or c+step_c*col not between 0 and 6;
       exit when substr(b,(r+step_r*col)*7+c+step_c*col+1,1)<>symbol;
       count_run:=count_run+1;
     end loop;
     for col in 1..3 loop
       exit when r-step_r*col not between 0 and 5 or c-step_c*col not between 0 and 6;
       exit when substr(b,(r-step_r*col)*7+c-step_c*col+1,1)<>symbol;
       count_run:=count_run+1;
     end loop;
     if count_run>=4 then did_win:=true;exit;end if;
   end loop;
   g.board:=b;
   g.turn_slot:=3-g.turn_slot;
   if did_win then g.winner:=symbol;g.status:='finished';
   elsif position('_' in b)=0 then g.winner:='draw';g.status:='finished';end if;
 end if;
 update public.itamar_party_rooms
  set board=g.board,turn_slot=g.turn_slot,winner=g.winner,status=g.status,
      choice1=g.choice1,choice2=g.choice2,updated_at=now()
  where id=g.id returning * into g;
 return public.itamar_party_public(g,me);
end $$;

-- Chat invitations are permitted for exactly two-player games.
-- Cloud Climb has code-only entry, never auto-shares a code.
create or replace function public.itamar_party_invite(p_code text,p_username text)
returns uuid language plpgsql security definer set search_path='' as $$
declare me uuid:=auth.uid();g public.itamar_party_rooms%rowtype;target uuid; room uuid;
begin
 if me is null or p_code is null or p_code !~ '^[a-fA-F0-9]{10}$' then raise exception 'Invalid code';end if;
 select * into g from public.itamar_party_rooms where code=upper(p_code) and host_id=me;
 if not found or g.game='cloud_climb' or g.status<>'waiting' or g.expires_at<now() then
   raise exception 'Only the host of a waiting two-player game may invite';
 end if;
 select id into target from public.itamar_profiles
   where username=lower(trim(leading '@' from btrim(coalesce(p_username,''))));
 if target is null or target=me then raise exception 'Choose another registered username';end if;
 if (select count(*) from public.itamar_messages where sender_id=me and
     body like '%Game room code:%' and created_at>now()-interval '1 hour')>=12 then
   raise exception 'Invitation limit reached';
 end if;
 room:=public.itamar_create_room('chat','Game invite',lower(trim(leading '@' from btrim(p_username))));
 insert into public.itamar_messages(room_id,sender_id,body)
 values(room,me,'🎮 ItamarOS game invite ('||g.game||'). Open Games → Online room. Game room code: '||g.code);
 return room;
end $$;

create or replace function public.itamar_party_position(p_code text,p_x numeric,p_y numeric)
returns jsonb language plpgsql security definer set search_path='' as $$
declare me uuid:=auth.uid(); g public.itamar_party_rooms%rowtype; slot text;
begin
 if me is null or p_code is null or p_code !~ '^[a-fA-F0-9]{10}$' then raise exception 'Invalid code';end if;
 if p_x is null or p_y is null or p_x not between 0 and 1024 or p_y not between 0 and 2048 then
   raise exception 'Position outside playfield';end if;
 select * into g from public.itamar_party_rooms where code=upper(p_code) for update;
 if not found or g.game<>'cloud_climb' or g.status not in ('waiting','playing') or g.expires_at<now() then
   raise exception 'No active platform game';end if;
 slot:=case when g.host_id=me then '1' when g.player2=me then '2'
       when g.player3=me then '3' when g.player4=me then '4' else null end;
 if slot is null then raise exception 'Not a player';end if;
 -- Coordinates are provisional client data, never used for scores, prizes, or trusted achievements.
 update public.itamar_party_rooms set positions=jsonb_set(g.positions,array[slot],
   jsonb_build_object('x',p_x,'y',p_y,'at',extract(epoch from now())),true),
   updated_at=now() where id=g.id returning * into g;
 return public.itamar_party_public(g,me);
end $$;

revoke all on function public.itamar_party_create(text) from public,anon;
revoke all on function public.itamar_party_join(text) from public,anon;
revoke all on function public.itamar_party_state(text) from public,anon;
revoke all on function public.itamar_party_move(text,integer,text) from public,anon;
revoke all on function public.itamar_party_invite(text,text) from public,anon;
revoke all on function public.itamar_party_position(text,numeric,numeric) from public,anon;
grant execute on function public.itamar_party_create(text) to authenticated;
grant execute on function public.itamar_party_join(text) to authenticated;
grant execute on function public.itamar_party_state(text) to authenticated;
grant execute on function public.itamar_party_move(text,integer,text) to authenticated;
grant execute on function public.itamar_party_invite(text,text) to authenticated;
grant execute on function public.itamar_party_position(text,numeric,numeric) to authenticated;
