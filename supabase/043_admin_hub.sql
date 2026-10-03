-- Admin hub: reasoned bans, bounded manual OA and per-user history.
-- Apply before using the new local Admin.html. Existing records are untouched.
begin;

-- Keep legacy access editing, but route every ban change through the reasoned RPC.
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
  if v_limited and (old_row.is_todm_team or old_row.archive_level>=4) then raise exception 'TODM IV не может изменять другого сотрудника IV' using errcode='42501';end if;
  if p_updated_at is null or old_row.updated_at<>p_updated_at then raise exception 'Данные изменились. Обновите список и повторите.';end if;
  if p_level is null or p_team is null or p_full is null or p_banned is null then raise exception 'Недопустимые параметры' using errcode='22023';end if;
  if p_banned is distinct from old_row.is_banned then raise exception 'Для блокировки используйте действие с обязательной причиной' using errcode='42501';end if;
  if v_limited and (p_level not between 0 and 3 or p_team) then raise exception 'TODM IV не может назначать уровень TODM IV' using errcode='42501';end if;
  if not v_limited and p_level not between 0 and 4 then raise exception 'Недопустимый уровень' using errcode='22023';end if;
  if p_team<>(p_level=4) or (p_level=4 and not p_full) then raise exception 'Уровень IV требует плашку TODM и полный доступ';end if;
  update public.account_access set archive_level=p_level,is_todm_team=p_team,full_access=p_full,updated_at=now() where user_id=p_user_id;
  update public.account_access set full_access=p_full where user_id=p_user_id returning * into new_row;
  insert into public.admin_access_log(actor,target,before_state,after_state) values(auth.uid(),p_user_id,to_jsonb(old_row),to_jsonb(new_row));
  insert into public.archive_audit_log(actor_id,target_user_id,action,object_type,object_key,before_state,after_state,reason) values(auth.uid(),p_user_id,'ACCESS_UPDATED','access',p_user_id::text,to_jsonb(old_row),to_jsonb(new_row),'Изменение через панель TODM');
end;$$;

create or replace function public.archive_staff_adjust_points(p_user_id uuid,p_amount integer,p_reason text)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_actor public.account_access;v_target public.account_access;v_id uuid;v_key text;
begin
  select * into v_actor from public.account_access where user_id=auth.uid() and not is_banned;
  if not found or not (v_actor.is_admin or v_actor.is_author or (v_actor.is_todm_team and v_actor.archive_level>=4)) then raise exception 'Недостаточно прав' using errcode='42501';end if;
  select * into v_target from public.account_access where user_id=p_user_id;
  if not found then raise exception 'Пользователь не найден' using errcode='22023';end if;
  if not (v_actor.is_admin or v_actor.is_author) and (p_user_id=auth.uid() or v_target.is_admin or v_target.is_author or v_target.is_todm_team or v_target.archive_level>=4) then raise exception 'TODM IV не может изменять прогресс сотрудника' using errcode='42501';end if;
  if p_amount not in (-20,20) or char_length(btrim(coalesce(p_reason,''))) not between 5 and 500 then raise exception 'Допустимо только +20 или -20 ОА с причиной' using errcode='22023';end if;
  v_key:='staff-adjustment:'||gen_random_uuid()::text;
  v_id:=public.archive_add_points_internal(p_user_id,'STAFF_ADJUSTMENT',v_key,p_amount,'staff_adjustment',jsonb_build_object('actor_id',auth.uid()),auth.uid(),p_reason);
  insert into public.archive_audit_log(actor_id,target_user_id,action,object_type,object_key,after_state,reason) values(auth.uid(),p_user_id,'POINTS_ADJUSTED','archive_points',v_id::text,jsonb_build_object('amount',p_amount),btrim(p_reason));
  perform public.archive_queue_notification_internal(p_user_id,'points_adjusted','points-adjusted:'||v_id::text,'АРХИВ СКОРРЕКТИРОВАЛ ПРОГРЕСС',case when p_amount>0 then '+'||p_amount::text||' ОА' else p_amount::text||' ОА' end,null,p_amount,null,jsonb_build_object('reason',btrim(p_reason)));
  return v_id;
end;$$;

create or replace function public.admin_set_ban_reasoned(p_user_id uuid,p_banned boolean,p_reason text,p_updated_at timestamptz)
returns void language plpgsql security definer set search_path='' as $$
declare v_actor public.account_access;v_old public.account_access;v_new public.account_access;
begin
  select * into v_actor from public.account_access where user_id=auth.uid() and not is_banned;
  if not found or not (v_actor.is_admin or v_actor.is_author or (v_actor.is_todm_team and v_actor.archive_level>=4)) then raise exception 'Недостаточно прав' using errcode='42501';end if;
  if p_user_id=auth.uid() then raise exception 'Нельзя блокировать себя' using errcode='42501';end if;
  select * into v_old from public.account_access where user_id=p_user_id for update;
  if not found then raise exception 'Пользователь не найден' using errcode='22023';end if;
  if p_user_id='8cd4aa8b-a90a-4e67-9112-9dbc170c27bc'::uuid or v_old.is_admin or v_old.is_author then raise exception 'Владелец и администраторы защищены' using errcode='42501';end if;
  if not (v_actor.is_admin or v_actor.is_author) and (v_old.is_todm_team or v_old.archive_level>=4) then raise exception 'TODM IV не может блокировать сотрудника IV' using errcode='42501';end if;
  if p_updated_at is null or v_old.updated_at<>p_updated_at then raise exception 'Данные изменились. Обновите карточку.';end if;
  if p_banned is null or p_banned=v_old.is_banned or char_length(btrim(coalesce(p_reason,''))) not between 5 and 500 then raise exception 'Укажите новый статус и причину от 5 до 500 символов' using errcode='22023';end if;
  update public.account_access set is_banned=p_banned,updated_at=now() where user_id=p_user_id returning * into v_new;
  insert into public.admin_access_log(actor,target,before_state,after_state) values(auth.uid(),p_user_id,to_jsonb(v_old),to_jsonb(v_new));
  insert into public.archive_audit_log(actor_id,target_user_id,action,object_type,object_key,before_state,after_state,reason) values(auth.uid(),p_user_id,case when p_banned then 'USER_BANNED' else 'USER_UNBANNED' end,'ban',p_user_id::text,to_jsonb(v_old),to_jsonb(v_new),btrim(p_reason));
  perform public.archive_queue_notification_internal(p_user_id,'system','ban-status:'||gen_random_uuid()::text,case when p_banned then 'ДОСТУП ОГРАНИЧЕН' else 'ДОСТУП ВОССТАНОВЛЕН' end,btrim(p_reason),null,null,null,jsonb_build_object('banned',p_banned));
end;$$;

create or replace function public.archive_staff_user_history(p_user_id uuid,p_offset integer default 0)
returns jsonb language plpgsql security definer stable set search_path='' as $$
declare v_rows jsonb;
begin
  perform public.archive_staff_assert_target(p_user_id);
  select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb) into v_rows from (
    select l.action,l.reason,l.created_at,coalesce(ap.display_name,au.email::text,'Система') actor_name,coalesce(tp.display_name,tu.email::text,'Пользователь') target_name
    from public.archive_audit_log l left join auth.users au on au.id=l.actor_id left join public.profiles ap on ap.user_id=l.actor_id left join auth.users tu on tu.id=l.target_user_id left join public.profiles tp on tp.user_id=l.target_user_id
    where l.target_user_id=p_user_id
    union all
    select 'WARNING_SENT'::text,w.reason,w.created_at,coalesce(ap.display_name,au.email::text,'TODM')::text,coalesce(tp.display_name,tu.email::text,'Пользователь')::text
    from public.user_warnings w left join auth.users au on au.id=w.issued_by left join public.profiles ap on ap.user_id=w.issued_by left join auth.users tu on tu.id=w.user_id left join public.profiles tp on tp.user_id=w.user_id
    where w.user_id=p_user_id
    order by created_at desc limit 50 offset greatest(coalesce(p_offset,0),0)
  ) x;
  return v_rows;
end;$$;

create or replace function public.admin_support_ticket_list()
returns table(id uuid,user_id uuid,subject text,status text,created_at timestamptz,updated_at timestamptz,display_name text,last_message text,last_message_at timestamptz)
language plpgsql security definer stable set search_path='' as $$
begin
  if not public.archive_is_staff() then raise exception 'Недостаточно прав' using errcode='42501';end if;
  return query select t.id,t.user_id,t.subject,t.status,t.created_at,t.updated_at,p.display_name::text,m.body,m.created_at
  from public.support_tickets t join public.profiles p on p.user_id=t.user_id
  left join lateral (select sm.body,sm.created_at from public.support_messages sm where sm.ticket_id=t.id order by sm.id desc limit 1) m on true
  order by t.updated_at desc limit 100;
end;$$;

create or replace function public.archive_staff_audit_search(p_filter text default 'ALL',p_actor uuid default null,p_target uuid default null,p_from date default null,p_to date default null,p_offset integer default 0)
returns jsonb language plpgsql security definer stable set search_path='' as $$
declare v_filter text:=upper(coalesce(p_filter,'ALL'));
begin
  if not public.archive_is_staff() then raise exception 'Недостаточно прав' using errcode='42501';end if;
  if p_from is not null and p_to is not null and p_from>p_to then raise exception 'Некорректный период' using errcode='22023';end if;
  return coalesce((select jsonb_agg(to_jsonb(x) order by x.created_at desc) from (
    select l.id,l.action,l.object_type,l.object_key,l.reason,l.created_at,l.actor_id,l.target_user_id,
      coalesce(ap.display_name,au.email::text,'Система') actor_name,coalesce(tp.display_name,tu.email::text,'Пользователь') target_name
    from public.archive_audit_log l left join auth.users au on au.id=l.actor_id left join public.profiles ap on ap.user_id=l.actor_id left join auth.users tu on tu.id=l.target_user_id left join public.profiles tp on tp.user_id=l.target_user_id
    where (p_actor is null or l.actor_id=p_actor) and (p_target is null or l.target_user_id=p_target)
      and (p_from is null or l.created_at>=p_from::timestamptz) and (p_to is null or l.created_at<(p_to+1)::timestamptz)
      and (v_filter='ALL' or (v_filter='ACHIEVEMENTS' and l.object_type='achievement') or (v_filter='POINTS' and l.object_type='archive_points') or (v_filter='MODERATION' and l.object_type in('moderation','warning','ban','chat_restriction','avatar')) or (v_filter='RANKS' and l.object_type in('archive_level','rank','access')) or (v_filter='SYSTEM' and l.object_type='system'))
    order by l.created_at desc limit 50 offset greatest(coalesce(p_offset,0),0)
  ) x),'[]'::jsonb);
end;$$;

revoke all on function public.admin_update_access(uuid,integer,boolean,boolean,boolean,timestamptz),public.archive_staff_adjust_points(uuid,integer,text),public.admin_set_ban_reasoned(uuid,boolean,text,timestamptz),public.archive_staff_user_history(uuid,integer),public.admin_support_ticket_list(),public.archive_staff_audit_search(text,uuid,uuid,date,date,integer) from public,anon,authenticated;
grant execute on function public.admin_update_access(uuid,integer,boolean,boolean,boolean,timestamptz),public.archive_staff_adjust_points(uuid,integer,text),public.admin_set_ban_reasoned(uuid,boolean,text,timestamptz),public.archive_staff_user_history(uuid,integer),public.admin_support_ticket_list(),public.archive_staff_audit_search(text,uuid,uuid,date,date,integer) to authenticated;
commit;
