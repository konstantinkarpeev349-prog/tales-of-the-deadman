-- Stage 7: trusted one-time rewards for faction choice, confirmed support and faction leadership.
-- Existing historical rows are deliberately not backfilled.
begin;

-- A confirmed payment is trusted only when written by the payment backend.
revoke insert,update,delete,truncate,references,trigger on public.support_payments from public,anon,authenticated;

-- Points belong to the trusted event. Achievements remain visual and must not
-- duplicate the same OA through their own point_reward.
update public.achievement_definitions set point_reward=0,updated_at=now()
where code in('FIRST_FACTION_SELECTED','FIRST_SUPPORT','FACTION_LEADER');

create or replace function public.archive_rule_integer(p_rule_key text)
returns integer language plpgsql security definer stable set search_path='' as $$
declare v_value integer;
begin
 select (r.value #>> '{}')::integer into v_value from public.archive_rules r where r.rule_key=p_rule_key;
 if v_value is null or v_value<0 then raise exception 'Правило Архива не настроено: %',p_rule_key using errcode='55000';end if;
 return v_value;
end;$$;

create or replace function public.archive_reward_first_faction_internal(p_user_id uuid,p_faction public.todm_faction)
returns boolean language plpgsql security definer set search_path='' as $$
declare v_points integer;v_ledger uuid;v_awarded boolean;
begin
 if p_user_id is null or p_faction is null then raise exception 'Некорректное событие фракции' using errcode='22023';end if;
 v_points:=public.archive_rule_integer('faction_first_selection_reward');
 v_ledger:=public.archive_add_points_internal(p_user_id,'FIRST_FACTION_SELECTED','faction:first-selection',v_points,'faction',jsonb_build_object('faction',p_faction),null,null);
 v_awarded:=public.archive_award_achievement_internal(p_user_id,'FIRST_FACTION_SELECTED','system','faction:first-selection',jsonb_build_object('faction',p_faction),null);
 return v_ledger is not null or v_awarded;
end;$$;

create or replace function public.archive_reward_first_support_internal(p_user_id uuid,p_payment_id uuid)
returns boolean language plpgsql security definer set search_path='' as $$
declare v_points integer;v_ledger uuid;v_awarded boolean;
begin
 if p_user_id is null or p_payment_id is null then return false;end if;
 v_points:=public.archive_rule_integer('support_first_reward');
 v_ledger:=public.archive_add_points_internal(p_user_id,'FIRST_SUPPORT','support:first-confirmed',v_points,'support',jsonb_build_object('payment_id',p_payment_id),null,null);
 v_awarded:=public.archive_award_achievement_internal(p_user_id,'FIRST_SUPPORT','system','support:first-confirmed',jsonb_build_object('payment_id',p_payment_id),null);
 update public.account_access set is_supporter=true,updated_at=now() where user_id=p_user_id and not is_supporter;
 return v_ledger is not null or v_awarded;
end;$$;

create or replace function public.archive_reward_first_leadership_internal(p_user_id uuid,p_faction public.todm_faction,p_actor uuid)
returns boolean language plpgsql security definer set search_path='' as $$
declare v_points integer;v_ledger uuid;v_awarded boolean;
begin
 if p_user_id is null or p_faction is null then return false;end if;
 v_points:=public.archive_rule_integer('faction_leader_reward');
 v_ledger:=public.archive_add_points_internal(p_user_id,'FACTION_LEADER','faction:leader:first',v_points,'faction',jsonb_build_object('faction',p_faction),p_actor,null);
 v_awarded:=public.archive_award_achievement_internal(p_user_id,'FACTION_LEADER','system','faction:leader:first',jsonb_build_object('faction',p_faction),p_actor);
 return v_ledger is not null or v_awarded;
end;$$;

-- Preserve all current cooldown and ban checks. Only a transition from no
-- faction to a faction is the first-selection event.
create or replace function public.profile_set_faction(p_faction public.todm_faction)
returns void language plpgsql security definer set search_path='' as $$
declare v_level smallint;v_profile public.profiles;v_first boolean;
begin
 select a.archive_level into v_level from public.account_access a where a.user_id=auth.uid() and not a.is_banned for update;
 if not found then raise exception 'Нет доступа' using errcode='42501';end if;
 if p_faction is null then raise exception 'Выберите фракцию' using errcode='22023';end if;
 select * into v_profile from public.profiles where user_id=auth.uid() for update;
 if v_profile.selected_faction is not distinct from p_faction then return;end if;
 if v_profile.faction_changed_at>now()-interval '1 month' and v_profile.faction_change_archive_level=v_level then
  raise exception 'Фракцию можно изменить раз в месяц или после изменения уровня Архива' using errcode='42501';
 end if;
 v_first:=v_profile.selected_faction is null;
 update public.profiles set selected_faction=p_faction,faction_changed_at=now(),faction_change_archive_level=v_level,updated_at=now() where user_id=auth.uid();
 if v_first then perform public.archive_reward_first_faction_internal(auth.uid(),p_faction);end if;
end;$$;

-- This trigger fires only for a newly confirmed payment or a transition into
-- succeeded. Direct browser writes to support_payments remain revoked.
create or replace function public.archive_support_payment_reward_trigger()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.status='succeeded' and new.user_id is not null and (tg_op='INSERT' or old.status is distinct from 'succeeded' or old.user_id is distinct from new.user_id) then
  perform public.archive_reward_first_support_internal(new.user_id,new.id);
 end if;
 return new;
end;$$;
drop trigger if exists archive_support_payment_reward on public.support_payments;
create trigger archive_support_payment_reward after insert or update of status,user_id on public.support_payments
for each row execute function public.archive_support_payment_reward_trigger();

-- Preserve leader validation and the existing congratulation notification.
create or replace function public.admin_set_faction_leader(p_faction public.todm_faction,p_user_id uuid default null)
returns void language plpgsql security definer set search_path='' as $$
declare previous_leader uuid;
begin
 if not exists(select 1 from public.account_access a where a.user_id=auth.uid() and a.is_admin and not a.is_banned) then raise exception 'Доступ только для администратора' using errcode='42501';end if;
 select fl.user_id into previous_leader from public.faction_leaders fl where fl.faction=p_faction;
 if p_user_id is not null and not exists(select 1 from public.profiles p join public.account_access a on a.user_id=p.user_id where p.user_id=p_user_id and p.selected_faction=p_faction and not a.is_banned) then raise exception 'Пользователь должен состоять в выбранной фракции';end if;
 delete from public.faction_leaders where faction=p_faction or(p_user_id is not null and user_id=p_user_id);
 if p_user_id is not null then
  insert into public.faction_leaders(faction,user_id,appointed_by) values(p_faction,p_user_id,auth.uid());
  if previous_leader is distinct from p_user_id then
   insert into public.faction_leader_notifications(user_id,faction) values(p_user_id,p_faction);
   perform public.archive_reward_first_leadership_internal(p_user_id,p_faction,auth.uid());
   insert into public.archive_audit_log(actor_id,target_user_id,action,object_type,object_key,after_state,reason)
   values(auth.uid(),p_user_id,'FACTION_LEADER_APPOINTED','faction_leader',p_faction::text,jsonb_build_object('faction',p_faction),'Назначение лидера фракции');
  end if;
 end if;
end;$$;

revoke all on function public.archive_rule_integer(text),public.archive_reward_first_faction_internal(uuid,public.todm_faction),
 public.archive_reward_first_support_internal(uuid,uuid),public.archive_reward_first_leadership_internal(uuid,public.todm_faction,uuid),
 public.archive_support_payment_reward_trigger() from public,anon,authenticated;
revoke all on function public.profile_set_faction(public.todm_faction),public.admin_set_faction_leader(public.todm_faction,uuid) from public,anon,authenticated;
grant execute on function public.profile_set_faction(public.todm_faction),public.admin_set_faction_leader(public.todm_faction,uuid) to authenticated;

commit;
