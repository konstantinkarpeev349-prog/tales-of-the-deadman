-- Give TODM IV the complete staff panel while keeping staff/owner protection.
begin;

create or replace function public.admin_update_access(p_user_id uuid,p_level integer,p_team boolean,p_full boolean,p_banned boolean,p_updated_at timestamptz)
returns void language plpgsql security definer set search_path='' as $$
declare v_actor public.account_access;old_row public.account_access;new_row public.account_access;v_limited boolean;
begin
 select * into v_actor from public.account_access where user_id=auth.uid() and not is_banned for update;
 if not found or not (v_actor.is_admin or v_actor.is_author or (v_actor.is_todm_team and v_actor.archive_level>=4)) then raise exception 'Доступ только для TODM IV/V' using errcode='42501';end if;
 v_limited:=not (v_actor.is_admin or v_actor.is_author);
 select * into old_row from public.account_access where user_id=p_user_id for update;
 if not found then raise exception 'Пользователь не найден' using errcode='22023';end if;
 if p_user_id='8cd4aa8b-a90a-4e67-9112-9dbc170c27bc'::uuid or old_row.is_admin or old_row.is_author then raise exception 'Изменение владельца и администраторов через панель запрещено' using errcode='42501';end if;
 if p_user_id=auth.uid() then raise exception 'Нельзя изменять собственные права' using errcode='42501';end if;
 if v_limited and (old_row.is_todm_team or old_row.archive_level>=4) then raise exception 'TODM IV не может изменять или блокировать другого сотрудника TODM IV' using errcode='42501';end if;
 if p_updated_at is null or old_row.updated_at<>p_updated_at then raise exception 'Данные изменились. Обновите список и повторите.';end if;
 if p_level is null or p_team is null or p_full is null or p_banned is null then raise exception 'Недопустимые параметры' using errcode='22023';end if;
 if v_limited and (p_level not between 0 and 3 or p_team) then raise exception 'TODM IV не может назначать уровень TODM IV' using errcode='42501';end if;
 if not v_limited and p_level not between 0 and 4 then raise exception 'Недопустимый уровень' using errcode='22023';end if;
 if p_team<>(p_level=4) or (p_level=4 and not p_full) then raise exception 'Уровень IV требует плашку TODM и полный доступ';end if;
 update public.account_access set archive_level=p_level,is_todm_team=p_team,full_access=p_full,is_banned=p_banned,updated_at=now() where user_id=p_user_id;
 update public.account_access set full_access=p_full where user_id=p_user_id returning * into new_row;
 insert into public.admin_access_log(actor,target,before_state,after_state) values(auth.uid(),p_user_id,to_jsonb(old_row),to_jsonb(new_row));
 insert into public.archive_audit_log(actor_id,target_user_id,action,object_type,object_key,before_state,after_state,reason) values(auth.uid(),p_user_id,'ACCESS_UPDATED','access',p_user_id::text,to_jsonb(old_row),to_jsonb(new_row),'Изменение через панель TODM');
end;$$;

create or replace function public.admin_set_faction_leader(p_faction public.todm_faction,p_user_id uuid default null)
returns void language plpgsql security definer set search_path='' as $$
declare previous_leader uuid;
begin
 if not public.archive_is_staff() then raise exception 'Доступ только для TODM IV/V' using errcode='42501';end if;
 select fl.user_id into previous_leader from public.faction_leaders fl where fl.faction=p_faction;
 if p_user_id is not null and not exists(select 1 from public.profiles p join public.account_access a on a.user_id=p.user_id where p.user_id=p_user_id and p.selected_faction=p_faction and not a.is_banned) then raise exception 'Пользователь должен состоять в выбранной фракции';end if;
 delete from public.faction_leaders where faction=p_faction or(p_user_id is not null and user_id=p_user_id);
 if p_user_id is not null then
  insert into public.faction_leaders(faction,user_id,appointed_by) values(p_faction,p_user_id,auth.uid());
  if previous_leader is distinct from p_user_id then
   insert into public.faction_leader_notifications(user_id,faction) values(p_user_id,p_faction);
   perform public.archive_reward_first_leadership_internal(p_user_id,p_faction,auth.uid());
   insert into public.archive_audit_log(actor_id,target_user_id,action,object_type,object_key,after_state,reason) values(auth.uid(),p_user_id,'FACTION_LEADER_APPOINTED','faction_leader',p_faction::text,jsonb_build_object('faction',p_faction),'Назначение лидера фракции');
  end if;
 end if;
end;$$;

revoke all on function public.admin_update_access(uuid,integer,boolean,boolean,boolean,timestamptz),public.admin_set_faction_leader(public.todm_faction,uuid) from public,anon,authenticated;
grant execute on function public.admin_update_access(uuid,integer,boolean,boolean,boolean,timestamptz),public.admin_set_faction_leader(public.todm_faction,uuid) to authenticated;
commit;
