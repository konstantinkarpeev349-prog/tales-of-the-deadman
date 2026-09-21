-- Stage 8: server-timed active-site participation.
begin;

insert into public.archive_rules(rule_key,value,description) values
 ('active_time_heartbeat_max_seconds','60'::jsonb,'Максимум серверных секунд за один heartbeat'),
 ('active_time_heartbeat_gap_seconds','90'::jsonb,'После такого разрыва промежуток не засчитывается'),
 ('active_time_achievement_seconds','{"ACTIVE_1_HOUR":3600,"ACTIVE_10_HOURS":36000,"ACTIVE_50_HOURS":180000,"ACTIVE_100_HOURS":360000,"ACTIVE_250_HOURS":900000}'::jsonb,'Пороги достижений активного времени')
on conflict(rule_key) do update set value=excluded.value,description=excluded.description,updated_at=now();

create table if not exists public.archive_activity_state(
 user_id uuid primary key references auth.users(id) on delete cascade,
 activity_date date not null default (now() at time zone 'utc')::date,
 uncredited_seconds integer not null default 0 check(uncredited_seconds>=0),
 last_heartbeat_at timestamptz not null default now(),
 last_active_at timestamptz,
 updated_at timestamptz not null default now()
);
alter table public.archive_activity_state enable row level security;
revoke all on public.archive_activity_state from public,anon,authenticated;
grant select on public.archive_activity_state to authenticated;
drop policy if exists "read own activity state" on public.archive_activity_state;
create policy "read own activity state" on public.archive_activity_state for select to authenticated
using(user_id=auth.uid() or public.archive_is_staff());

create or replace function public.archive_activity_award_milestones_internal(p_user_id uuid,p_total_seconds bigint)
returns void language plpgsql security definer set search_path='' as $$
declare v_code text;v_threshold bigint;v_rules jsonb;
begin
 select value into v_rules from public.archive_rules where rule_key='active_time_achievement_seconds';
 for v_code,v_threshold in select e.key,e.value::bigint from jsonb_each_text(v_rules) as e loop
  if p_total_seconds>=v_threshold then
   perform public.archive_award_achievement_internal(p_user_id,v_code,'system','active-time:'||lower(v_code),jsonb_build_object('active_seconds',p_total_seconds),null);
  end if;
 end loop;
end;$$;

create or replace function public.archive_activity_heartbeat(p_active boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_state public.archive_activity_state%rowtype;v_now timestamptz:=clock_timestamp();v_today date:=(clock_timestamp() at time zone 'utc')::date;
 v_elapsed integer:=0;v_interval integer;v_reward integer;v_cap integer;v_max integer;v_gap integer;v_today_points integer;v_total bigint;v_ledger uuid;v_awarded integer:=0;
begin
 if v_user is null or not exists(select 1 from public.account_access where user_id=v_user and not is_banned) then raise exception 'Требуется активный аккаунт' using errcode='42501';end if;
 insert into public.archive_progress(user_id) values(v_user) on conflict(user_id) do nothing;
 insert into public.archive_activity_state(user_id,last_heartbeat_at) values(v_user,v_now) on conflict(user_id) do nothing;
 select * into v_state from public.archive_activity_state where user_id=v_user for update;
 v_interval:=public.archive_rule_integer('active_time_interval_seconds');v_reward:=public.archive_rule_integer('active_time_reward');v_cap:=public.archive_rule_integer('active_time_daily_cap');
 v_max:=public.archive_rule_integer('active_time_heartbeat_max_seconds');v_gap:=public.archive_rule_integer('active_time_heartbeat_gap_seconds');
 if v_interval<=0 or v_reward<=0 or v_cap<0 or v_max<=0 or v_gap<=0 then raise exception 'Invalid active-time rules';end if;
 if v_state.activity_date<>v_today then v_state.activity_date:=v_today;v_state.uncredited_seconds:=0;end if;
 if coalesce(p_active,false) and v_now-v_state.last_heartbeat_at<=make_interval(secs=>v_gap) then
  v_elapsed:=least(v_max,greatest(0,floor(extract(epoch from v_now-v_state.last_heartbeat_at))::integer));
 end if;
 update public.archive_progress set active_seconds=active_seconds+v_elapsed,updated_at=v_now where user_id=v_user returning active_seconds into v_total;
 v_state.uncredited_seconds:=v_state.uncredited_seconds+v_elapsed;
 select coalesce(sum(amount),0)::integer into v_today_points from public.archive_point_ledger
  where user_id=v_user and source='active_time' and created_at>=(v_today::timestamp at time zone 'utc') and created_at<((v_today+1)::timestamp at time zone 'utc');
 while v_state.uncredited_seconds>=v_interval and v_today_points+v_reward<=v_cap loop
  v_ledger:=public.archive_add_points_internal(v_user,'ACTIVE_TIME_INTERVAL','active-time:'||v_today::text||':'||(v_today_points/v_reward+1)::text,v_reward,'active_time',jsonb_build_object('interval_seconds',v_interval,'date',v_today),null,null);
  exit when v_ledger is null;
  v_state.uncredited_seconds:=v_state.uncredited_seconds-v_interval;v_today_points:=v_today_points+v_reward;v_awarded:=v_awarded+v_reward;
 end loop;
 if v_today_points>=v_cap then v_state.uncredited_seconds:=least(v_state.uncredited_seconds,v_interval-1);end if;
 update public.archive_activity_state set activity_date=v_state.activity_date,uncredited_seconds=v_state.uncredited_seconds,last_heartbeat_at=v_now,
  last_active_at=case when v_elapsed>0 then v_now else last_active_at end,updated_at=v_now where user_id=v_user;
 perform public.archive_activity_award_milestones_internal(v_user,v_total);
 return jsonb_build_object('credited_seconds',v_elapsed,'total_active_seconds',v_total,'pending_seconds',v_state.uncredited_seconds,
  'points_awarded',v_awarded,'today_points',v_today_points,'daily_cap',v_cap,'interval_seconds',v_interval);
end;$$;

create or replace function public.archive_activity_status()
returns jsonb language plpgsql security definer stable set search_path='' as $$
declare v_user uuid:=auth.uid();v_today date:=(now() at time zone 'utc')::date;v_total bigint;v_pending integer;v_today_points integer;v_interval integer;v_cap integer;
begin
 if v_user is null then raise exception 'Требуется авторизация' using errcode='42501';end if;
 select active_seconds into v_total from public.archive_progress where user_id=v_user;
 select case when activity_date=v_today then uncredited_seconds else 0 end into v_pending from public.archive_activity_state where user_id=v_user;
 select coalesce(sum(amount),0)::integer into v_today_points from public.archive_point_ledger where user_id=v_user and source='active_time'
  and created_at>=(v_today::timestamp at time zone 'utc') and created_at<((v_today+1)::timestamp at time zone 'utc');
 v_interval:=public.archive_rule_integer('active_time_interval_seconds');v_cap:=public.archive_rule_integer('active_time_daily_cap');
 return jsonb_build_object('total_active_seconds',coalesce(v_total,0),'pending_seconds',coalesce(v_pending,0),'today_points',v_today_points,'daily_cap',v_cap,'interval_seconds',v_interval);
end;$$;

revoke all on function public.archive_activity_award_milestones_internal(uuid,bigint),public.archive_activity_heartbeat(boolean),public.archive_activity_status() from public,anon,authenticated;
grant execute on function public.archive_activity_heartbeat(boolean),public.archive_activity_status() to authenticated;
commit;
