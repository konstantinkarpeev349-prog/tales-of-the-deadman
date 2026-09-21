-- Confirmed reader-progression reset. Accounts and non-progression data stay intact.
begin;
create schema if not exists archive_backup;
revoke all on schema archive_backup from public,anon,authenticated;
create table if not exists archive_backup.reset_20260921_account_access as select * from public.account_access where user_id<>'8cd4aa8b-a90a-4e67-9112-9dbc170c27bc'::uuid;
create table if not exists archive_backup.reset_20260921_archive_progress as select * from public.archive_progress where user_id<>'8cd4aa8b-a90a-4e67-9112-9dbc170c27bc'::uuid;
create table if not exists archive_backup.reset_20260921_archive_point_ledger as select * from public.archive_point_ledger where user_id<>'8cd4aa8b-a90a-4e67-9112-9dbc170c27bc'::uuid;
create table if not exists archive_backup.reset_20260921_user_achievements as select * from public.user_achievements where user_id<>'8cd4aa8b-a90a-4e67-9112-9dbc170c27bc'::uuid;
create table if not exists archive_backup.reset_20260921_archive_notifications as select * from public.archive_notifications where user_id<>'8cd4aa8b-a90a-4e67-9112-9dbc170c27bc'::uuid;
create table if not exists archive_backup.reset_20260921_achievement_favorites as select * from public.archive_achievement_favorites where user_id<>'8cd4aa8b-a90a-4e67-9112-9dbc170c27bc'::uuid;
create table if not exists archive_backup.reset_20260921_reading_sessions as select * from public.archive_reading_sessions where user_id<>'8cd4aa8b-a90a-4e67-9112-9dbc170c27bc'::uuid;
create table if not exists archive_backup.reset_20260921_reading_clock as select * from public.archive_reading_clock where user_id<>'8cd4aa8b-a90a-4e67-9112-9dbc170c27bc'::uuid;
create table if not exists archive_backup.reset_20260921_quiz_attempts as select * from public.archive_quiz_attempts where user_id<>'8cd4aa8b-a90a-4e67-9112-9dbc170c27bc'::uuid;
create table if not exists archive_backup.reset_20260921_activity_state as select * from public.archive_activity_state where user_id<>'8cd4aa8b-a90a-4e67-9112-9dbc170c27bc'::uuid;
create table if not exists archive_backup.reset_20260921_game_results as select * from public.archive_game_results where user_id<>'8cd4aa8b-a90a-4e67-9112-9dbc170c27bc'::uuid;

delete from public.archive_achievement_favorites where user_id<>'8cd4aa8b-a90a-4e67-9112-9dbc170c27bc'::uuid;
delete from public.archive_notifications where user_id<>'8cd4aa8b-a90a-4e67-9112-9dbc170c27bc'::uuid;
delete from public.user_achievements where user_id<>'8cd4aa8b-a90a-4e67-9112-9dbc170c27bc'::uuid;
delete from public.archive_point_ledger where user_id<>'8cd4aa8b-a90a-4e67-9112-9dbc170c27bc'::uuid;
delete from public.archive_reading_sessions where user_id<>'8cd4aa8b-a90a-4e67-9112-9dbc170c27bc'::uuid;
delete from public.archive_reading_clock where user_id<>'8cd4aa8b-a90a-4e67-9112-9dbc170c27bc'::uuid;
delete from public.archive_quiz_attempts where user_id<>'8cd4aa8b-a90a-4e67-9112-9dbc170c27bc'::uuid;
delete from public.archive_activity_state where user_id<>'8cd4aa8b-a90a-4e67-9112-9dbc170c27bc'::uuid;
delete from public.archive_game_results where user_id<>'8cd4aa8b-a90a-4e67-9112-9dbc170c27bc'::uuid;
update public.archive_progress set points=0,archive_i_test_passed=false,best_archive_i_test_score=0,active_seconds=0,completed_games=0,won_games=0,current_win_streak=0,best_win_streak=0,calculated_archive_level=0,level_review_required=false,level_review_reason=null,level_calculated_at=now(),updated_at=now() where user_id<>'8cd4aa8b-a90a-4e67-9112-9dbc170c27bc'::uuid;
update public.account_access set archive_level=0,updated_at=now() where user_id<>'8cd4aa8b-a90a-4e67-9112-9dbc170c27bc'::uuid and not coalesce(is_todm_team,false) and not coalesce(is_author,false) and archive_level between 1 and 3;

create or replace function public.profile_set_faction(p_faction public.todm_faction)
returns void language plpgsql security definer set search_path='' as $$
declare v_user constant uuid:=auth.uid();v_owner constant uuid:='8cd4aa8b-a90a-4e67-9112-9dbc170c27bc'::uuid;v_level smallint;v_profile public.profiles;v_first boolean;
begin
 select a.archive_level into v_level from public.account_access a where a.user_id=v_user and not a.is_banned for update;
 if not found then raise exception 'Нет доступа' using errcode='42501';end if;
 if p_faction is null then raise exception 'Выберите фракцию' using errcode='22023';end if;
 select * into v_profile from public.profiles where user_id=v_user for update;
 v_first:=not exists(select 1 from public.archive_point_ledger l where l.user_id=v_user and l.event_key='faction:first-selection');
 if v_profile.selected_faction is not distinct from p_faction then if v_first then perform public.archive_reward_first_faction_internal(v_user,p_faction);end if;return;end if;
 if v_user<>v_owner and v_profile.faction_changed_at>now()-interval '1 month' and v_profile.faction_change_archive_level=v_level then raise exception 'Фракцию можно изменить раз в месяц или после изменения уровня Архива' using errcode='42501';end if;
 update public.profiles set selected_faction=p_faction,faction_changed_at=now(),faction_change_archive_level=v_level,updated_at=now() where user_id=v_user;
 if v_first then perform public.archive_reward_first_faction_internal(v_user,p_faction);end if;
end;$$;
revoke all on function public.profile_set_faction(public.todm_faction) from public,anon,authenticated;
grant execute on function public.profile_set_faction(public.todm_faction) to authenticated;
insert into public.archive_audit_log(actor_id,action,object_type,object_key,reason,metadata) values('8cd4aa8b-a90a-4e67-9112-9dbc170c27bc'::uuid,'ARCHIVE_READER_RESET','system','reset-2026-09-21','Подтверждённый владельцем сброс прогрессии читателей; аккаунты и непрогрессионные данные сохранены',jsonb_build_object('owner_excluded',true,'backup_schema','archive_backup'));
commit;
