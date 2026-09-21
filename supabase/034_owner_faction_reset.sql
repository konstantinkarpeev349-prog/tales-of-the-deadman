-- Owner-only faction reset and unrestricted owner faction switching.
begin;

create or replace function public.profile_set_faction(p_faction public.todm_faction)
returns void language plpgsql security definer set search_path='' as $$
declare v_user constant uuid:=auth.uid();v_level smallint;v_profile public.profiles;v_first boolean;v_owner boolean;
begin
 select a.archive_level,(a.is_admin or a.is_author) into v_level,v_owner from public.account_access a where a.user_id=v_user and not a.is_banned for update;
 if not found then raise exception 'Нет доступа' using errcode='42501';end if;
 if p_faction is null then raise exception 'Выберите фракцию' using errcode='22023';end if;
 select * into v_profile from public.profiles where user_id=v_user for update;
 v_first:=not exists(select 1 from public.archive_point_ledger l where l.user_id=v_user and l.event_key='faction:first-selection');
 if v_profile.selected_faction is not distinct from p_faction then if v_first then perform public.archive_reward_first_faction_internal(v_user,p_faction);end if;return;end if;
 if not v_owner and v_profile.faction_changed_at>now()-interval '1 month' and v_profile.faction_change_archive_level=v_level then raise exception 'Фракцию можно изменить раз в месяц или после изменения уровня Архива' using errcode='42501';end if;
 update public.profiles set selected_faction=p_faction,faction_changed_at=now(),faction_change_archive_level=v_level,updated_at=now() where user_id=v_user;
 if v_first then perform public.archive_reward_first_faction_internal(v_user,p_faction);end if;
end;$$;

create or replace function public.admin_reset_user_faction(p_user_id uuid,p_reason text)
returns void language plpgsql security definer set search_path='' as $$
declare v_actor public.account_access;v_old public.profiles;v_points integer:=0;
begin
 select * into v_actor from public.account_access where user_id=auth.uid() and not is_banned;
 if not found or not (v_actor.is_admin or v_actor.is_author) then raise exception 'Полный сброс фракции доступен только владельцу' using errcode='42501';end if;
 if p_user_id=auth.uid() then raise exception 'Свою фракцию меняйте в личном кабинете' using errcode='42501';end if;
 if char_length(btrim(coalesce(p_reason,''))) not between 5 and 500 then raise exception 'Укажите причину от 5 до 500 символов' using errcode='22023';end if;
 select * into v_old from public.profiles where user_id=p_user_id for update;
 if not found then raise exception 'Пользователь не найден' using errcode='22023';end if;
 select coalesce(sum(amount),0)::integer into v_points from public.archive_point_ledger where user_id=p_user_id and event_key='faction:first-selection';
 delete from public.faction_leaders where user_id=p_user_id;
 delete from public.faction_leader_notifications where user_id=p_user_id;
 delete from public.faction_read_state where user_id=p_user_id;
 delete from public.archive_notifications where user_id=p_user_id and (achievement_code='FIRST_FACTION_SELECTED' or dedupe_key like 'faction:first-selection%');
 delete from public.user_achievements where user_id=p_user_id and achievement_code='FIRST_FACTION_SELECTED';
 delete from public.archive_point_ledger where user_id=p_user_id and event_key='faction:first-selection';
 update public.profiles set selected_faction=null,faction_changed_at=null,faction_change_archive_level=null,updated_at=now() where user_id=p_user_id;
 update public.archive_progress set points=greatest(0,points-v_points),updated_at=now() where user_id=p_user_id;
 insert into public.archive_audit_log(actor_id,target_user_id,action,object_type,object_key,before_state,after_state,reason,metadata)
 values(auth.uid(),p_user_id,'FACTION_RESET','faction',p_user_id::text,to_jsonb(v_old),jsonb_build_object('selected_faction',null),btrim(p_reason),jsonb_build_object('removed_points',v_points));
end;$$;

revoke all on function public.profile_set_faction(public.todm_faction),public.admin_reset_user_faction(uuid,text) from public,anon,authenticated;
grant execute on function public.profile_set_faction(public.todm_faction),public.admin_reset_user_faction(uuid,text) to authenticated;
commit;
