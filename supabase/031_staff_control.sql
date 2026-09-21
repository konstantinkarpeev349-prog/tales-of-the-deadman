-- Stage 12: TODM Staff Control for archive progress, achievements and audit.
-- Additive and repeatable. Existing users, access levels and rewards are not changed.
begin;

create or replace function public.archive_manual_reward_points(p_code text)
returns integer language sql security definer stable set search_path='' as $$
  select case
    when p_code in ('READ_PROLOGUE','READ_CHAPTER_1','READ_CHAPTER_2','READ_CHAPTER_3') then public.archive_rule_integer('read_reward')
    when p_code='FIRST_FACTION_SELECTED' then public.archive_rule_integer('faction_first_selection_reward')
    when p_code='ARCHIVE_I_TEST_PASSED' then public.archive_rule_integer('archive_i_test_reward')
    when p_code='FIRST_SUPPORT' then public.archive_rule_integer('support_first_reward')
    when p_code='FACTION_LEADER' then public.archive_rule_integer('faction_leader_reward')
    else 0 end;
$$;

create or replace function public.archive_staff_assert_target(p_user_id uuid)
returns void language plpgsql security definer stable set search_path='' as $$
declare v_actor public.account_access;v_target public.account_access;
begin
  select * into v_actor from public.account_access where user_id=auth.uid() and not is_banned;
  if not found or not (v_actor.is_admin or v_actor.is_author or v_actor.is_todm_team) then raise exception 'Недостаточно прав' using errcode='42501';end if;
  select * into v_target from public.account_access where user_id=p_user_id;
  if not found then raise exception 'Пользователь не найден' using errcode='22023';end if;
  if v_target.is_author and not (v_actor.is_author or v_actor.is_admin) then raise exception 'TODM IV не может изменять Автора' using errcode='42501';end if;
  if p_user_id=auth.uid() and not (v_actor.is_author or v_actor.is_admin) then raise exception 'Сотрудник IV не может изменять собственный прогресс' using errcode='42501';end if;
end;$$;

create or replace function public.archive_staff_user_detail(p_user_id uuid,p_ledger_limit integer default 30)
returns jsonb language plpgsql security definer stable set search_path='' as $$
declare v_limit integer:=least(greatest(coalesce(p_ledger_limit,30),1),100);
begin
  perform public.archive_staff_assert_target(p_user_id);
  return jsonb_build_object(
    'profile',(select jsonb_build_object('user_id',a.user_id,'email',u.email,'display_name',p.display_name,'avatar_url',p.avatar_url,'faction',p.selected_faction,'archive_level',a.archive_level,'full_access',a.full_access,'is_todm_team',a.is_todm_team,'is_author',a.is_author,'is_admin',a.is_admin,'is_supporter',a.is_supporter,'is_banned',a.is_banned,'mute_general_chat',a.mute_general_chat,'mute_faction_chat',a.mute_faction_chat,'avatar_hidden',a.avatar_hidden,'updated_at',a.updated_at,'leader_faction',(select fl.faction from public.faction_leaders fl where fl.user_id=a.user_id limit 1)) from public.account_access a join auth.users u on u.id=a.user_id left join public.profiles p on p.user_id=a.user_id where a.user_id=p_user_id),
    'progress',(select to_jsonb(x) from (select coalesce(ap.points,0) points,coalesce(ap.archive_i_test_passed,false) archive_i_test_passed,coalesce(ap.best_archive_i_test_score,0) best_archive_i_test_score,coalesce(ap.active_seconds,0) active_seconds,coalesce(ap.completed_games,0) completed_games,coalesce(ap.won_games,0) won_games,coalesce(ap.best_win_streak,0) best_win_streak from public.archive_progress ap where ap.user_id=p_user_id) x),
    'achievements',coalesce((select jsonb_agg(jsonb_build_object('code',d.code,'title',d.title,'description',d.description,'category',d.category,'rarity',d.rarity,'manual_points',public.archive_manual_reward_points(d.code),'allow_manual_grant',d.allow_manual_grant,'allow_manual_revoke',d.allow_manual_revoke,'owned',coalesce(ua.is_active,false),'awarded_at',ua.awarded_at) order by coalesce(ua.is_active,false) desc,d.category,d.title) from public.achievement_definitions d left join public.user_achievements ua on ua.user_id=p_user_id and ua.achievement_code=d.code where d.is_active),'[]'::jsonb),
    'reading',jsonb_build_object('prologue',exists(select 1 from public.user_achievements where user_id=p_user_id and achievement_code='READ_PROLOGUE' and is_active),'chapter_1',exists(select 1 from public.user_achievements where user_id=p_user_id and achievement_code='READ_CHAPTER_1' and is_active),'chapter_2',exists(select 1 from public.user_achievements where user_id=p_user_id and achievement_code='READ_CHAPTER_2' and is_active),'chapter_3',exists(select 1 from public.user_achievements where user_id=p_user_id and achievement_code='READ_CHAPTER_3' and is_active)),
    'ledger',coalesce((select jsonb_agg(to_jsonb(x) order by x.created_at desc) from (select id,event_code,amount,source,reason,created_at from public.archive_point_ledger where user_id=p_user_id order by created_at desc limit v_limit) x),'[]'::jsonb)
  );
end;$$;

create or replace function public.archive_staff_grant_achievement(p_user_id uuid,p_code text,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_def public.achievement_definitions;v_existing public.user_achievements;v_points integer;v_key text;v_ledger uuid;
begin
  perform public.archive_staff_assert_target(p_user_id);
  if char_length(btrim(coalesce(p_reason,''))) not between 5 and 500 then raise exception 'Укажите причину от 5 до 500 символов' using errcode='22023';end if;
  select * into v_def from public.achievement_definitions where code=p_code and is_active for update;
  if not found or not v_def.allow_manual_grant then raise exception 'Ручная выдача этой награды запрещена' using errcode='42501';end if;
  select * into v_existing from public.user_achievements where user_id=p_user_id and achievement_code=p_code for update;
  if found and v_existing.is_active then raise exception 'Награда уже получена' using errcode='22023';end if;
  v_key:='staff-achievement-grant:'||gen_random_uuid()::text;v_points:=public.archive_manual_reward_points(p_code);
  insert into public.user_achievements(user_id,achievement_code,is_active,grant_count,source,source_key,metadata,awarded_at,awarded_by,revoked_at,revoked_by,revoke_reason)
  values(p_user_id,p_code,true,1,'staff',v_key,jsonb_build_object('reason',btrim(p_reason)),now(),auth.uid(),null,null,null)
  on conflict(user_id,achievement_code) do update set is_active=true,grant_count=public.user_achievements.grant_count+1,source='staff',source_key=excluded.source_key,metadata=excluded.metadata,awarded_at=now(),awarded_by=auth.uid(),revoked_at=null,revoked_by=null,revoke_reason=null;
  if v_points>0 then v_ledger:=public.archive_add_points_internal(p_user_id,'STAFF_ADJUSTMENT',v_key,v_points,'staff_adjustment',jsonb_build_object('achievement_code',p_code),auth.uid(),p_reason);end if;
  insert into public.archive_audit_log(actor_id,target_user_id,action,object_type,object_key,before_state,after_state,reason) values(auth.uid(),p_user_id,'ACHIEVEMENT_GRANTED','achievement',p_code,case when v_existing.user_id is null then null else to_jsonb(v_existing) end,jsonb_build_object('active',true,'points',v_points),btrim(p_reason));
  perform public.archive_queue_notification_internal(p_user_id,'achievement_granted','staff-grant:'||gen_random_uuid()::text,'АРХИВ ОБНОВИЛ ЛИЧНОЕ ДЕЛО',v_def.title||E'\nДостижение добавлено сотрудником TODM.',p_code,case when v_points>0 then v_points else null end,null,jsonb_build_object('reason',btrim(p_reason)));
  return jsonb_build_object('achievement_code',p_code,'points',v_points,'ledger_id',v_ledger);
end;$$;

create or replace function public.archive_staff_revoke_achievement(p_user_id uuid,p_code text,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_def public.achievement_definitions;v_existing public.user_achievements;v_points integer;v_ledger uuid;v_key text;
begin
  perform public.archive_staff_assert_target(p_user_id);
  if char_length(btrim(coalesce(p_reason,''))) not between 5 and 500 then raise exception 'Укажите причину от 5 до 500 символов' using errcode='22023';end if;
  select * into v_def from public.achievement_definitions where code=p_code and is_active for update;
  if not found or not v_def.allow_manual_revoke then raise exception 'Ручной отзыв этой награды запрещён' using errcode='42501';end if;
  select * into v_existing from public.user_achievements where user_id=p_user_id and achievement_code=p_code and is_active for update;
  if not found then raise exception 'Активная награда не найдена' using errcode='22023';end if;
  v_points:=public.archive_manual_reward_points(p_code);v_key:='staff-achievement-revoke:'||gen_random_uuid()::text;
  update public.user_achievements set is_active=false,revoked_at=now(),revoked_by=auth.uid(),revoke_reason=btrim(p_reason) where user_id=p_user_id and achievement_code=p_code;
  if v_points>0 then v_ledger:=public.archive_add_points_internal(p_user_id,'STAFF_ADJUSTMENT',v_key,-v_points,'staff_adjustment',jsonb_build_object('achievement_code',p_code),auth.uid(),p_reason);end if;
  insert into public.archive_audit_log(actor_id,target_user_id,action,object_type,object_key,before_state,after_state,reason) values(auth.uid(),p_user_id,'ACHIEVEMENT_REVOKED','achievement',p_code,to_jsonb(v_existing),jsonb_build_object('active',false,'points',-v_points),btrim(p_reason));
  perform public.archive_queue_notification_internal(p_user_id,'achievement_revoked','staff-revoke:'||gen_random_uuid()::text,'АРХИВ ОБНОВИЛ ЛИЧНОЕ ДЕЛО',v_def.title||E'\nДостижение отозвано сотрудником TODM.',p_code,case when v_points>0 then -v_points else null end,null,jsonb_build_object('reason',btrim(p_reason)));
  return jsonb_build_object('achievement_code',p_code,'points',-v_points,'ledger_id',v_ledger);
end;$$;

create or replace function public.archive_staff_audit(p_filter text default 'ALL',p_offset integer default 0)
returns jsonb language plpgsql security definer stable set search_path='' as $$
declare v_filter text:=upper(coalesce(p_filter,'ALL'));v_offset integer:=greatest(coalesce(p_offset,0),0);
begin
  if not public.archive_is_staff() then raise exception 'Недостаточно прав' using errcode='42501';end if;
  return coalesce((select jsonb_agg(to_jsonb(x) order by x.created_at desc) from (select l.id,l.action,l.object_type,l.object_key,l.reason,l.before_state,l.after_state,l.created_at,l.actor_id,l.target_user_id,coalesce(ap.display_name,au.email::text,'Система') actor_name,coalesce(tp.display_name,tu.email::text,'Пользователь') target_name from public.archive_audit_log l left join auth.users au on au.id=l.actor_id left join public.profiles ap on ap.user_id=l.actor_id left join auth.users tu on tu.id=l.target_user_id left join public.profiles tp on tp.user_id=l.target_user_id where v_filter='ALL' or (v_filter='ACHIEVEMENTS' and l.object_type='achievement') or (v_filter='POINTS' and l.object_type='archive_points') or (v_filter='MODERATION' and l.object_type in('moderation','warning','ban','chat_restriction','avatar')) or (v_filter='RANKS' and l.object_type in('archive_level','rank','access')) or (v_filter='SYSTEM' and l.object_type='system') order by l.created_at desc limit 50 offset v_offset) x),'[]'::jsonb);
end;$$;

revoke all on function public.archive_manual_reward_points(text),public.archive_staff_assert_target(uuid),public.archive_staff_user_detail(uuid,integer),public.archive_staff_grant_achievement(uuid,text,text),public.archive_staff_revoke_achievement(uuid,text,text),public.archive_staff_audit(text,integer) from public,anon,authenticated;
grant execute on function public.archive_staff_user_detail(uuid,integer),public.archive_staff_grant_achievement(uuid,text,text),public.archive_staff_revoke_achievement(uuid,text,text),public.archive_staff_audit(text,integer) to authenticated;

commit;
