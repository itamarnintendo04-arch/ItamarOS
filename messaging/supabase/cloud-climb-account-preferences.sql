-- Apply to ItamarOS Supabase AFTER the existing Cloud Climb game migrations.
-- Same auth.users ID in ItamarOS and Cloud Climb. The standalone offline demo stays local.
create table if not exists public.itamar_climb_preferences (
 user_id uuid primary key references auth.users(id) on delete cascade,
 equipped_hero text not null default 'starter' check (equipped_hero ~ '^[a-z0-9_]{1,50}$'),
 selected_world integer not null default 1 check (selected_world between 1 and 11),
 twilight_sky boolean not null default false,
 auto_hide_controls boolean not null default true,
 show_tips boolean not null default true,
 updated_at timestamptz not null default now()
);
alter table public.itamar_climb_preferences enable row level security;
drop policy if exists climb_prefs_owner_read on public.itamar_climb_preferences;
drop policy if exists climb_prefs_owner_insert on public.itamar_climb_preferences;
drop policy if exists climb_prefs_owner_update on public.itamar_climb_preferences;
create policy climb_prefs_owner_read on public.itamar_climb_preferences
 for select to authenticated using (user_id=(select auth.uid()));
create policy climb_prefs_owner_insert on public.itamar_climb_preferences
 for insert to authenticated with check (user_id=(select auth.uid()));
create policy climb_prefs_owner_update on public.itamar_climb_preferences
 for update to authenticated using (user_id=(select auth.uid()))
 with check (user_id=(select auth.uid()));
revoke all on public.itamar_climb_preferences from anon;
grant select,insert,update on public.itamar_climb_preferences to authenticated;

create or replace function public.itamar_climb_get_preferences()
returns jsonb language plpgsql security invoker set search_path=public,pg_temp as $$
declare p public.itamar_climb_preferences%rowtype;
begin
 if auth.uid() is null then raise exception 'Login required'; end if;
 select * into p from public.itamar_climb_preferences where user_id=auth.uid();
 if not found then return jsonb_build_object(
  'exists',false,'equipped_hero','starter','selected_world',1,
  'twilight_sky',false,'auto_hide_controls',true,'show_tips',true
 ); end if;
 return jsonb_build_object(
  'exists',true,'equipped_hero',p.equipped_hero,'selected_world',p.selected_world,
  'twilight_sky',p.twilight_sky,'auto_hide_controls',p.auto_hide_controls,
  'show_tips',p.show_tips
 );
end $$;

create or replace function public.itamar_climb_save_preferences(
 p_equipped_hero text,p_selected_world integer,p_twilight_sky boolean,
 p_auto_hide_controls boolean,p_show_tips boolean
) returns jsonb language plpgsql security invoker set search_path=public,pg_temp as $$
declare me uuid:=auth.uid();
begin
 if me is null then raise exception 'Login required'; end if;
 if p_equipped_hero is null or p_equipped_hero !~ '^[a-z0-9_]{1,50}$'
    or p_selected_world is null or p_selected_world not between 1 and 11
    or p_twilight_sky is null or p_auto_hide_controls is null or p_show_tips is null
 then raise exception 'Invalid game preferences'; end if;
 -- Cosmetic commands must not unlock progress or characters.
 if p_equipped_hero<>'starter' and not exists(
  select 1 from public.itamar_climb_characters where user_id=me and character_id=p_equipped_hero
 ) then raise exception 'Character not unlocked'; end if;
 if p_selected_world between 2 and 10 and not exists(
  select 1 from public.itamar_climb_world_unlocks where user_id=me and world=p_selected_world
 ) then raise exception 'World not unlocked'; end if;
 if p_selected_world=11 and (
  select count(*) from public.itamar_climb_colored_rewards where user_id=me
 )<10 then raise exception 'Secret world not unlocked'; end if;
 insert into public.itamar_climb_preferences
  (user_id,equipped_hero,selected_world,twilight_sky,auto_hide_controls,show_tips,updated_at)
 values (me,p_equipped_hero,p_selected_world,p_twilight_sky,p_auto_hide_controls,p_show_tips,now())
 on conflict(user_id) do update set
  equipped_hero=excluded.equipped_hero,selected_world=excluded.selected_world,
  twilight_sky=excluded.twilight_sky,auto_hide_controls=excluded.auto_hide_controls,
  show_tips=excluded.show_tips,updated_at=now();
 return jsonb_build_object('saved',true);
end $$;
revoke all on function public.itamar_climb_get_preferences() from public;
revoke all on function public.itamar_climb_save_preferences(text,integer,boolean,boolean,boolean) from public;
grant execute on function public.itamar_climb_get_preferences() to authenticated;
grant execute on function public.itamar_climb_save_preferences(text,integer,boolean,boolean,boolean) to authenticated;
