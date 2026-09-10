begin;

create or replace function public.admin_set_chat_restrictions(p_user_id uuid,p_mute_general boolean,p_mute_faction boolean)
returns void language plpgsql security definer set search_path='' as $$
declare old_row public.account_access; new_row public.account_access; notice_text text;
begin
 if not exists(select 1 from public.account_access a where a.user_id=auth.uid() and not a.is_banned and (a.is_admin or (a.is_todm_team and a.archive_level>=4))) then raise exception 'Доступ только для администратора или сотрудника IV ранга' using errcode='42501'; end if;
 select * into old_row from public.account_access where user_id=p_user_id for update;
 if not found then raise exception 'Пользователь не найден'; end if;
 if old_row.is_admin or p_user_id=auth.uid() then raise exception 'Ограничение администратора запрещено'; end if;
 update public.account_access set mute_general_chat=coalesce(p_mute_general,false),mute_faction_chat=coalesce(p_mute_faction,false),updated_at=now() where user_id=p_user_id returning * into new_row;
 if not old_row.mute_general_chat and new_row.mute_general_chat and not old_row.mute_faction_chat and new_row.mute_faction_chat then
  notice_text='АРХИВ TODM — ОГРАНИЧЕНИЕ: Вам запрещена отправка сообщений в общем чате и чате вашей фракции. Для уточнения причины обратитесь к сотрудникам TODM.';
 elsif not old_row.mute_general_chat and new_row.mute_general_chat then
  notice_text='АРХИВ TODM — ОГРАНИЧЕНИЕ: Вам запрещена отправка сообщений в общем чате. Для уточнения причины обратитесь к сотрудникам TODM.';
 elsif not old_row.mute_faction_chat and new_row.mute_faction_chat then
  notice_text='АРХИВ TODM — ОГРАНИЧЕНИЕ: Вам запрещена отправка сообщений в чате вашей фракции. Для уточнения причины обратитесь к сотрудникам TODM.';
 end if;
 if notice_text is not null then insert into public.user_warnings(user_id,issued_by,reason) values(p_user_id,auth.uid(),notice_text); end if;
 insert into public.admin_access_log(actor,target,before_state,after_state) values(auth.uid(),p_user_id,to_jsonb(old_row),to_jsonb(new_row));
end;$$;

revoke all on function public.admin_set_chat_restrictions(uuid,boolean,boolean) from public,anon;
grant execute on function public.admin_set_chat_restrictions(uuid,boolean,boolean) to authenticated;
commit;
