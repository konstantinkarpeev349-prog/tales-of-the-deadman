begin;

alter table public.account_access add column if not exists avatar_hidden boolean not null default false;
alter table public.profiles add column if not exists hidden_avatar_url text;

create or replace function public.admin_avatar_states(p_user_ids uuid[])
returns table(user_id uuid,avatar_hidden boolean)
language plpgsql security definer set search_path='' stable as $$
begin
 if not exists(select 1 from public.account_access a where a.user_id=auth.uid() and not a.is_banned and (a.is_admin or (a.is_todm_team and a.archive_level>=4))) then raise exception 'Доступ только для администратора или сотрудника IV ранга' using errcode='42501'; end if;
 return query select a.user_id,a.avatar_hidden from public.account_access a where a.user_id=any(coalesce(p_user_ids,array[]::uuid[]));
end;$$;

create or replace function public.admin_set_avatar_hidden(p_user_id uuid,p_hidden boolean)
returns void language plpgsql security definer set search_path='' as $$
declare old_row public.account_access;new_row public.account_access;
begin
 if not exists(select 1 from public.account_access a where a.user_id=auth.uid() and not a.is_banned and (a.is_admin or (a.is_todm_team and a.archive_level>=4))) then raise exception 'Доступ только для администратора или сотрудника IV ранга' using errcode='42501'; end if;
 select * into old_row from public.account_access where user_id=p_user_id for update;
 if not found then raise exception 'Пользователь не найден'; end if;
 if old_row.is_admin or p_user_id=auth.uid() then raise exception 'Скрытие портрета администратора или самого себя запрещено'; end if;
 if coalesce(p_hidden,false) then
  update public.profiles set hidden_avatar_url=coalesce(avatar_url,hidden_avatar_url),avatar_url=null,updated_at=now() where user_id=p_user_id;
 else
  update public.profiles set avatar_url=coalesce(avatar_url,hidden_avatar_url),hidden_avatar_url=null,updated_at=now() where user_id=p_user_id;
 end if;
 update public.account_access set avatar_hidden=coalesce(p_hidden,false),updated_at=now() where user_id=p_user_id returning * into new_row;
 insert into public.admin_access_log(actor,target,before_state,after_state) values(auth.uid(),p_user_id,to_jsonb(old_row),to_jsonb(new_row));
end;$$;

create or replace function public.profile_set_avatar(p_avatar_url text)
returns void language plpgsql security definer set search_path='' as $$
begin
 perform public.assert_active_user();
 if exists(select 1 from public.account_access a where a.user_id=auth.uid() and a.avatar_hidden) then raise exception 'Ваш портрет скрыт сотрудником TODM' using errcode='42501'; end if;
 if p_avatar_url is null or char_length(p_avatar_url)>2048 then raise exception 'Недопустимый адрес аватара'; end if;
 update public.profiles set avatar_url=p_avatar_url,updated_at=now() where user_id=auth.uid();
end;$$;

revoke all on function public.admin_avatar_states(uuid[]),public.admin_set_avatar_hidden(uuid,boolean) from public,anon;
grant execute on function public.admin_avatar_states(uuid[]),public.admin_set_avatar_hidden(uuid,boolean) to authenticated;
commit;
