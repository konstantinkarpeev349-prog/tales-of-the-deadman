begin;
create or replace function public.admin_warning_users(p_search text default '')
returns table(user_id uuid,display_name text,archive_level smallint,selected_faction text,is_todm_team boolean,is_banned boolean)
language plpgsql security definer set search_path='' stable as $$
begin
 if not exists(select 1 from public.account_access a where a.user_id=auth.uid() and not a.is_banned and (a.is_admin or (a.is_todm_team and a.archive_level>=4))) then raise exception 'Доступ только для администратора или сотрудника IV ранга' using errcode='42501'; end if;
 return query select p.user_id,p.display_name::text,a.archive_level,p.selected_faction::text,a.is_todm_team,a.is_banned from public.profiles p join public.account_access a on a.user_id=p.user_id where p.user_id<>auth.uid() and p.display_name::text ilike '%'||left(btrim(coalesce(p_search,'')),100)||'%' order by p.display_name limit 50;
end;$$;
create or replace function public.admin_warning_send(p_user_id uuid,p_reason text)
returns void language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from public.account_access a where a.user_id=auth.uid() and not a.is_banned and (a.is_admin or (a.is_todm_team and a.archive_level>=4))) then raise exception 'Доступ только для администратора или сотрудника IV ранга' using errcode='42501'; end if;
 if p_user_id=auth.uid() then raise exception 'Нельзя отправить предупреждение самому себе'; end if;
 if not exists(select 1 from public.account_access a where a.user_id=p_user_id) then raise exception 'Пользователь не найден'; end if;
 if char_length(btrim(coalesce(p_reason,''))) not between 3 and 2000 then raise exception 'Укажите причину от 3 до 2000 символов'; end if;
 insert into public.user_warnings(user_id,issued_by,reason) values(p_user_id,auth.uid(),btrim(p_reason));
end;$$;
revoke all on function public.admin_warning_users(text),public.admin_warning_send(uuid,text) from public,anon;
grant execute on function public.admin_warning_users(text),public.admin_warning_send(uuid,text) to authenticated;
commit;
