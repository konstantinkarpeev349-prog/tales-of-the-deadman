begin;

alter table public.profiles add column if not exists faction_changed_at timestamptz;
alter table public.profiles add column if not exists faction_change_archive_level smallint;

-- Public profile reads are deliberately restricted to non-sensitive fields.
create or replace function public.social_profile(p_user_id uuid)
returns table(user_id uuid,display_name text,avatar_url text,selected_faction text,archive_level smallint,is_todm_team boolean,is_author boolean,is_supporter boolean)
language plpgsql security definer set search_path='' stable as $$
begin
  if auth.uid() is null or exists(select 1 from public.account_access aa where aa.user_id=auth.uid() and aa.is_banned) then
    raise exception 'Требуется активный аккаунт' using errcode='42501';
  end if;
  return query select p.user_id,p.display_name::text,p.avatar_url,p.selected_faction::text,a.archive_level,a.is_todm_team,a.is_author,a.is_supporter
  from public.profiles p join public.account_access a on a.user_id=p.user_id
  where p.user_id=p_user_id and not a.is_banned;
end;$$;

create or replace function public.social_profiles(p_user_ids uuid[])
returns table(user_id uuid,display_name text,avatar_url text,selected_faction text,archive_level smallint,is_todm_team boolean,is_author boolean,is_supporter boolean)
language plpgsql security definer set search_path='' stable as $$
begin
  if auth.uid() is null or exists(select 1 from public.account_access aa where aa.user_id=auth.uid() and aa.is_banned) then
    raise exception 'Требуется активный аккаунт' using errcode='42501';
  end if;
  return query select p.user_id,p.display_name::text,p.avatar_url,p.selected_faction::text,a.archive_level,a.is_todm_team,a.is_author,a.is_supporter
  from public.profiles p join public.account_access a on a.user_id=p.user_id
  where p.user_id=any(coalesce(p_user_ids,array[]::uuid[])) and not a.is_banned
  order by p.display_name;
end;$$;

-- Users update profile fields only through narrow server functions. Nickname is excluded.
revoke update on public.profiles from authenticated;

create or replace function public.profile_set_avatar(p_avatar_url text)
returns void language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null or exists(select 1 from public.account_access where user_id=auth.uid() and is_banned) then raise exception 'Нет доступа' using errcode='42501'; end if;
  if p_avatar_url is null or char_length(p_avatar_url)>2048 then raise exception 'Недопустимый адрес аватара'; end if;
  update public.profiles set avatar_url=p_avatar_url,updated_at=now() where user_id=auth.uid();
end;$$;

create or replace function public.profile_set_faction(p_faction public.todm_faction)
returns void language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null or exists(select 1 from public.account_access where user_id=auth.uid() and is_banned) then raise exception 'Нет доступа' using errcode='42501'; end if;
  if exists(select 1 from public.profiles p join public.account_access a on a.user_id=p.user_id where p.user_id=auth.uid() and p.selected_faction is not null and p.faction_changed_at>now()-interval '1 month' and p.faction_change_archive_level=a.archive_level) then
    raise exception 'Фракцию можно изменить раз в месяц или после изменения уровня Архива' using errcode='42501';
  end if;
  update public.profiles p set selected_faction=p_faction,faction_changed_at=now(),faction_change_archive_level=a.archive_level,updated_at=now()
  from public.account_access a where p.user_id=auth.uid() and a.user_id=p.user_id;
end;$$;

create or replace function public.admin_set_display_name(p_user_id uuid,p_display_name text)
returns void language plpgsql security definer set search_path='' as $$
begin
  if not exists(select 1 from public.account_access where user_id=auth.uid() and is_admin and not is_banned) then raise exception 'Доступ только для администратора' using errcode='42501'; end if;
  if p_display_name is null or char_length(btrim(p_display_name)) not between 3 and 32 or btrim(p_display_name)!~'^[A-Za-zА-Яа-яЁё0-9 _.-]+$' then raise exception 'Недопустимый ник'; end if;
  update public.profiles set display_name=btrim(p_display_name)::public.citext,updated_at=now() where user_id=p_user_id;
end;$$;

revoke all on function public.social_profile(uuid),public.social_profiles(uuid[]),public.profile_set_avatar(text),public.profile_set_faction(public.todm_faction),public.admin_set_display_name(uuid,text) from public,anon;
grant execute on function public.social_profile(uuid),public.social_profiles(uuid[]),public.profile_set_avatar(text),public.profile_set_faction(public.todm_faction),public.admin_set_display_name(uuid,text) to authenticated;
commit;
