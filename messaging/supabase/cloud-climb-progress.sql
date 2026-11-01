-- Cloud Climb account progress (apply once to the configured ItamarOS Supabase project).
-- Phone numbers never appear in this table. SMS verification signs in to auth.users.id.
-- Progress is a prototype client-authoritative save, not an anti-cheat game economy.
create table if not exists public.itamar_cloud_climb_progress (
 user_id uuid primary key references auth.users(id) on delete cascade,
 level integer not null default 1 check(level between 1 and 1000000),
 coins integer not null default 0 check(coins between 0 and 1000000000),
 hearts integer not null default 3 check(hearts between 0 and 3),
 boss_health integer not null default 3 check(boss_health between 1 and 3),
 shop_due integer not null default 0 check(shop_due between 0 and 1000000),
 game_over boolean not null default false,
 revision bigint not null default 1,
 updated_at timestamptz not null default now()
);
alter table public.itamar_cloud_climb_progress enable row level security;
revoke all on public.itamar_cloud_climb_progress from anon,authenticated;
grant select,insert,update on public.itamar_cloud_climb_progress to authenticated;
create policy "cloud_climb_owner_read" on public.itamar_cloud_climb_progress
 for select to authenticated using ((select auth.uid())=user_id);
create policy "cloud_climb_owner_insert" on public.itamar_cloud_climb_progress
 for insert to authenticated with check ((select auth.uid())=user_id);
create policy "cloud_climb_owner_update" on public.itamar_cloud_climb_progress
 for update to authenticated using ((select auth.uid())=user_id)
 with check ((select auth.uid())=user_id);

create or replace function public.itamar_cloud_climb_state()
returns jsonb language sql stable security invoker set search_path=''
as $$
 select coalesce((
   select jsonb_build_object(
     'exists',true,'level',p.level,'coins',p.coins,'hearts',p.hearts,
     'boss_health',p.boss_health,'shop_due',p.shop_due,'game_over',p.game_over,
     'revision',p.revision
   ) from public.itamar_cloud_climb_progress p where p.user_id=(select auth.uid())
 ),'{"exists":false,"revision":0}'::jsonb)
$$;
create or replace function public.itamar_cloud_climb_save(
 p_level integer,p_coins integer,p_hearts integer,p_boss_health integer,
 p_shop_due integer,p_game_over boolean,p_revision bigint
) returns jsonb language plpgsql security invoker set search_path=''
as $$
declare new_revision bigint;
begin
 if (select auth.uid()) is null then raise exception 'Sign in required'; end if;
 if p_level not between 1 and 1000000 or
    p_coins not between 0 and 1000000000 or
    p_hearts not between 0 and 3 or
    p_boss_health not between 1 and 3 or
    p_shop_due not between 0 and 1000000 or
    p_revision < 0 or p_game_over is null then
    raise exception 'Invalid Cloud Climb progress';
 end if;
 insert into public.itamar_cloud_climb_progress
    (user_id,level,coins,hearts,boss_health,shop_due,game_over,revision,updated_at)
 values ((select auth.uid()),p_level,p_coins,p_hearts,p_boss_health,p_shop_due,p_game_over,1,now())
 on conflict (user_id) do update set
    level=excluded.level,coins=excluded.coins,hearts=excluded.hearts,
    boss_health=excluded.boss_health,shop_due=excluded.shop_due,
    game_over=excluded.game_over,
    revision=public.itamar_cloud_climb_progress.revision+1,
    updated_at=now()
 where public.itamar_cloud_climb_progress.revision = p_revision
 returning revision into new_revision;
 if new_revision is null then
   return jsonb_build_object('saved',false,'conflict',true);
 end if;
 return jsonb_build_object('saved',true,'revision',new_revision);
end $$;
revoke all on function public.itamar_cloud_climb_state() from public,anon;
revoke all on function public.itamar_cloud_climb_save(integer,integer,integer,integer,integer,boolean,bigint) from public,anon;
grant execute on function public.itamar_cloud_climb_state() to authenticated;
grant execute on function public.itamar_cloud_climb_save(integer,integer,integer,integer,integer,boolean,bigint) to authenticated;
