begin;
create table if not exists public.admin_access_log (
 id bigint generated always as identity primary key,
 actor uuid not null, target uuid not null, before_state jsonb not null,
 after_state jsonb not null, created_at timestamptz not null default now()
);
alter table public.admin_access_log enable row level security;
revoke all on public.admin_access_log from anon, authenticated;

create or replace function public.admin_list_users(p_search text default '', p_offset integer default 0)
returns table(user_id uuid,email text,display_name text,archive_level smallint,full_access boolean,is_todm_team boolean,is_banned boolean,is_admin boolean,is_author boolean,updated_at timestamptz)
language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from public.account_access a where a.user_id=auth.uid() and a.is_admin and not a.is_banned) then
  raise exception 'Доступ только для администратора' using errcode='42501';
 end if;
 return query select u.id,u.email::text,p.display_name::text,a.archive_level,a.full_access,a.is_todm_team,a.is_banned,a.is_admin,a.is_author,a.updated_at
 from auth.users u join public.account_access a on a.user_id=u.id left join public.profiles p on p.user_id=u.id
 where coalesce(u.email,'') ilike '%'||left(coalesce(p_search,''),100)||'%' or coalesce(p.display_name::text,'') ilike '%'||left(coalesce(p_search,''),100)||'%'
 order by u.created_at desc,u.id limit 50 offset greatest(coalesce(p_offset,0),0);
end;$$;

create or replace function public.admin_update_access(p_user_id uuid,p_level integer,p_team boolean,p_full boolean,p_banned boolean,p_updated_at timestamptz)
returns void language plpgsql security definer set search_path='' as $$
declare old_row public.account_access; new_row public.account_access;
begin
 perform 1 from public.account_access where user_id=auth.uid() and is_admin and not is_banned for update;
 if not found then raise exception 'Доступ только для администратора' using errcode='42501'; end if;
 select * into old_row from public.account_access where user_id=p_user_id for update;
 if not found then raise exception 'Пользователь не найден'; end if;
 if old_row.is_admin or p_user_id=auth.uid() or p_user_id='8cd4aa8b-a90a-4e67-9112-9dbc170c27bc'::uuid then
  raise exception 'Изменение владельца и администраторов через панель запрещено';
 end if;
 if p_updated_at is null or old_row.updated_at <> p_updated_at then raise exception 'Данные изменились. Обновите список и повторите.'; end if;
 if p_level is null or p_level not between 0 and 4 or p_team is null or p_full is null or p_banned is null then raise exception 'Недопустимые параметры'; end if;
 if p_team <> (p_level=4) or (p_level=4 and not p_full) then raise exception 'Уровень IV требует плашку TODM и полный доступ'; end if;
 update public.account_access set archive_level=p_level,is_todm_team=p_team,full_access=p_full,is_banned=p_banned,updated_at=now() where user_id=p_user_id;
 -- The staff-rank trigger resets full_access when demoting; apply the explicit choice afterwards.
 update public.account_access set full_access=p_full where user_id=p_user_id returning * into new_row;
 insert into public.admin_access_log(actor,target,before_state,after_state) values(auth.uid(),p_user_id,to_jsonb(old_row),to_jsonb(new_row));
end;$$;
revoke all on function public.admin_list_users(text,integer) from public,anon;
revoke all on function public.admin_update_access(uuid,integer,boolean,boolean,boolean,timestamptz) from public,anon;
grant execute on function public.admin_list_users(text,integer) to authenticated;
grant execute on function public.admin_update_access(uuid,integer,boolean,boolean,boolean,timestamptz) to authenticated;
commit;
