begin;

alter table public.account_access add column if not exists mute_general_chat boolean not null default false;
alter table public.account_access add column if not exists mute_faction_chat boolean not null default false;

create or replace function public.admin_list_users(p_search text default '', p_offset integer default 0)
returns table(user_id uuid,email text,display_name text,archive_level smallint,full_access boolean,is_todm_team boolean,is_banned boolean,is_admin boolean,is_author boolean,updated_at timestamptz)
language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from public.account_access a where a.user_id=auth.uid() and not a.is_banned and (a.is_admin or (a.is_todm_team and a.archive_level>=4))) then
  raise exception 'Доступ только для администратора или сотрудника IV ранга' using errcode='42501';
 end if;
 return query select u.id,u.email::text,p.display_name::text,a.archive_level,a.full_access,a.is_todm_team,a.is_banned,a.is_admin,a.is_author,a.updated_at
 from auth.users u join public.account_access a on a.user_id=u.id left join public.profiles p on p.user_id=u.id
 where coalesce(u.email,'') ilike '%'||left(coalesce(p_search,''),100)||'%' or coalesce(p.display_name::text,'') ilike '%'||left(coalesce(p_search,''),100)||'%'
 order by u.created_at desc,u.id limit 50 offset greatest(coalesce(p_offset,0),0);
end;$$;

create or replace function public.admin_chat_restrictions(p_user_ids uuid[])
returns table(user_id uuid,mute_general_chat boolean,mute_faction_chat boolean)
language plpgsql security definer set search_path='' stable as $$
begin
 if not exists(select 1 from public.account_access a where a.user_id=auth.uid() and not a.is_banned and (a.is_admin or (a.is_todm_team and a.archive_level>=4))) then raise exception 'Доступ только для администратора или сотрудника IV ранга' using errcode='42501'; end if;
 return query select a.user_id,a.mute_general_chat,a.mute_faction_chat from public.account_access a where a.user_id=any(coalesce(p_user_ids,array[]::uuid[]));
end;$$;

create or replace function public.admin_set_chat_restrictions(p_user_id uuid,p_mute_general boolean,p_mute_faction boolean)
returns void language plpgsql security definer set search_path='' as $$
declare old_row public.account_access;new_row public.account_access;
begin
 if not exists(select 1 from public.account_access a where a.user_id=auth.uid() and not a.is_banned and (a.is_admin or (a.is_todm_team and a.archive_level>=4))) then raise exception 'Доступ только для администратора или сотрудника IV ранга' using errcode='42501'; end if;
 select * into old_row from public.account_access where user_id=p_user_id for update;
 if not found then raise exception 'Пользователь не найден'; end if;
 if old_row.is_admin or p_user_id=auth.uid() then raise exception 'Ограничение администратора запрещено'; end if;
 update public.account_access set mute_general_chat=coalesce(p_mute_general,false),mute_faction_chat=coalesce(p_mute_faction,false),updated_at=now() where user_id=p_user_id returning * into new_row;
 insert into public.admin_access_log(actor,target,before_state,after_state) values(auth.uid(),p_user_id,to_jsonb(old_row),to_jsonb(new_row));
end;$$;

create or replace function public.chat_send(p_body text)
returns void language plpgsql security definer set search_path='' as $$
declare access_row public.account_access;
begin
 select * into access_row from public.account_access where user_id=auth.uid() and not is_banned for update;
 if not found then raise exception 'Нет доступа к чату' using errcode='42501'; end if;
 if access_row.mute_general_chat then raise exception 'Администратор запретил вам отправлять сообщения в общем чате' using errcode='42501'; end if;
 if p_body is null or char_length(btrim(p_body)) not between 1 and 2000 then raise exception 'Сообщение должно содержать от 1 до 2000 символов'; end if;
 if exists(select 1 from public.chat_messages where user_id=auth.uid() and created_at>clock_timestamp()-interval '2 seconds') then raise exception 'Подождите две секунды перед следующим сообщением'; end if;
 insert into public.chat_messages(user_id,body) values(auth.uid(),btrim(p_body));
end;$$;

create or replace function public.faction_message_send(p_body text,p_faction public.todm_faction default null) returns void language plpgsql security definer set search_path='' as $$
declare v_faction public.todm_faction;access_row public.account_access;
begin
 perform public.assert_active_user();
 select a.* into access_row from public.account_access a where a.user_id=auth.uid();
 if access_row.mute_faction_chat then raise exception 'Администратор запретил вам отправлять сообщения в чате фракции' using errcode='42501'; end if;
 select case when (a.is_admin or (a.is_todm_team and a.archive_level>=4)) and p_faction is not null then p_faction else p.selected_faction end
 into v_faction from public.profiles p join public.account_access a on a.user_id=p.user_id where p.user_id=auth.uid();
 if v_faction is null then raise exception 'Сначала выберите фракцию'; end if;
 if not public.faction_can_access(v_faction) then raise exception 'Чат фракции недоступен' using errcode='42501'; end if;
 if char_length(btrim(coalesce(p_body,''))) not between 1 and 2000 then raise exception 'Сообщение должно содержать от 1 до 2000 символов'; end if;
 if exists(select 1 from public.faction_messages m where m.user_id=auth.uid() and m.created_at>clock_timestamp()-interval '2 seconds') then raise exception 'Подождите две секунды'; end if;
 insert into public.faction_messages(faction,user_id,body) values(v_faction,auth.uid(),btrim(p_body));
end;$$;

revoke all on function public.admin_list_users(text,integer),public.admin_chat_restrictions(uuid[]),public.admin_set_chat_restrictions(uuid,boolean,boolean) from public,anon;
grant execute on function public.admin_list_users(text,integer),public.admin_chat_restrictions(uuid[]),public.admin_set_chat_restrictions(uuid,boolean,boolean) to authenticated;
commit;
