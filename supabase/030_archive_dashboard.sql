-- Stage 10: account dashboard preferences.
begin;
create table if not exists public.archive_achievement_favorites(user_id uuid not null references auth.users(id) on delete cascade,achievement_code text not null references public.achievement_definitions(code),position smallint not null check(position between 1 and 3),created_at timestamptz not null default now(),primary key(user_id,achievement_code),unique(user_id,position));
alter table public.archive_achievement_favorites enable row level security;
revoke all on public.archive_achievement_favorites from public,anon,authenticated;
grant select on public.archive_achievement_favorites to authenticated;
drop policy if exists "read own achievement favorites" on public.archive_achievement_favorites;
create policy "read own achievement favorites" on public.archive_achievement_favorites for select to authenticated using(user_id=auth.uid() or public.archive_is_staff());
create or replace function public.archive_toggle_achievement_favorite(p_code text) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_position smallint;v_codes jsonb;
begin
 if v_user is null then raise exception 'Требуется авторизация' using errcode='42501';end if;
 if exists(select 1 from public.archive_achievement_favorites where user_id=v_user and achievement_code=p_code) then delete from public.archive_achievement_favorites where user_id=v_user and achievement_code=p_code;
 else
  if not exists(select 1 from public.user_achievements where user_id=v_user and achievement_code=p_code and is_active) then raise exception 'Достижение ещё не получено' using errcode='42501';end if;
  select s into v_position from generate_series(1,3) s where not exists(select 1 from public.archive_achievement_favorites f where f.user_id=v_user and f.position=s) order by s limit 1;
  if v_position is null then raise exception 'Можно выбрать не более трёх достижений' using errcode='22023';end if;
  insert into public.archive_achievement_favorites(user_id,achievement_code,position) values(v_user,p_code,v_position);
 end if;
 select coalesce(jsonb_agg(achievement_code order by position),'[]'::jsonb) into v_codes from public.archive_achievement_favorites where user_id=v_user;
 return v_codes;
end;$$;
create or replace function public.archive_get_my_dashboard(p_ledger_limit integer default 20) returns jsonb language plpgsql security definer stable set search_path='' as $$
declare v_user uuid:=auth.uid();v_summary jsonb;
begin
 if v_user is null then raise exception 'Требуется авторизация' using errcode='42501';end if;
 v_summary:=public.archive_get_my_summary(p_ledger_limit);
 return v_summary||jsonb_build_object('favorites',coalesce((select jsonb_agg(f.achievement_code order by f.position) from public.archive_achievement_favorites f where f.user_id=v_user),'[]'::jsonb),'rules',jsonb_build_object('archive_i_points',public.archive_rule_integer('archive_i_points'),'archive_ii_points',public.archive_rule_integer('archive_ii_points'),'archive_iii_points',public.archive_rule_integer('archive_iii_points')));
end;$$;
revoke all on function public.archive_toggle_achievement_favorite(text),public.archive_get_my_dashboard(integer) from public,anon,authenticated;
grant execute on function public.archive_toggle_achievement_favorite(text),public.archive_get_my_dashboard(integer) to authenticated;
commit;
