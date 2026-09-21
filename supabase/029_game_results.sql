-- Stage 9: trusted online-game result contract.
-- The client cannot submit results. The service-role RPC remains disabled until
-- archive_rules.game_backend.verified is explicitly enabled for a real backend.
begin;

alter table public.archive_progress
  add column if not exists current_win_streak integer not null default 0
  check (current_win_streak >= 0);

create table if not exists public.archive_game_results (
  id uuid primary key default gen_random_uuid(),
  provider text not null check (provider ~ '^[a-z0-9_-]{2,40}$'),
  external_match_id text not null check (char_length(external_match_id) between 6 and 160),
  user_id uuid not null references auth.users(id) on delete cascade,
  completed_at timestamptz not null,
  won boolean not null default false,
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata)='object'),
  recorded_at timestamptz not null default now(),
  unique (provider,external_match_id,user_id)
);
create index if not exists archive_game_results_user_completed_idx
  on public.archive_game_results(user_id,completed_at desc);

alter table public.archive_game_results enable row level security;
revoke all on public.archive_game_results from public,anon,authenticated;
grant select on public.archive_game_results to authenticated;

drop policy if exists "read own game results" on public.archive_game_results;
create policy "read own game results" on public.archive_game_results
for select to authenticated
using (user_id=auth.uid() or public.archive_is_staff());

create or replace function public.archive_game_award_milestones_internal(
  p_user_id uuid,p_completed integer,p_won integer,p_best_streak integer
) returns void language plpgsql security definer set search_path='' as $$
declare v_code text;v_threshold integer;
begin
  for v_code,v_threshold in values
    ('GAME_FIRST',1),('GAME_10',10),('GAME_25',25),('GAME_50',50),('GAME_100',100)
  loop
    if p_completed>=v_threshold then
      perform public.archive_award_achievement_internal(
        p_user_id,v_code,'system','game-milestone:'||lower(v_code),
        jsonb_build_object('completed_games',p_completed),null
      );
    end if;
  end loop;
  if p_won>=1 then
    perform public.archive_award_achievement_internal(
      p_user_id,'GAME_FIRST_WIN','system','game:first-win',
      jsonb_build_object('won_games',p_won),null
    );
  end if;
  if p_best_streak>=5 then
    perform public.archive_award_achievement_internal(
      p_user_id,'GAME_WIN_STREAK_5','system','game:win-streak-5',
      jsonb_build_object('best_win_streak',p_best_streak),null
    );
  end if;
end;$$;

create or replace function public.archive_record_game_result(
  p_provider text,
  p_external_match_id text,
  p_user_id uuid,
  p_completed_at timestamptz,
  p_won boolean default false,
  p_metadata jsonb default '{}'::jsonb
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_backend jsonb;v_result_id uuid;v_progress public.archive_progress%rowtype;
  v_reward integer;v_cap integer;v_today date;v_today_points integer;v_ledger uuid;v_awarded integer:=0;
begin
  select value into v_backend from public.archive_rules where rule_key='game_backend';
  if not coalesce((v_backend->>'verified')::boolean,false) then
    raise exception 'WAITING_FOR_GAME_BACKEND' using errcode='55000';
  end if;
  if p_user_id is null or not exists(
    select 1 from public.account_access where user_id=p_user_id and not is_banned
  ) then raise exception 'Активный пользователь не найден' using errcode='22023';end if;
  if p_provider is null or p_provider !~ '^[a-z0-9_-]{2,40}$'
    or char_length(coalesce(p_external_match_id,'')) not between 6 and 160
    or p_completed_at is null or p_completed_at>clock_timestamp()+interval '5 minutes'
    or p_completed_at<clock_timestamp()-interval '30 days'
    or jsonb_typeof(coalesce(p_metadata,'{}'::jsonb))<>'object'
  then raise exception 'Недопустимый результат партии' using errcode='22023';end if;

  insert into public.archive_progress(user_id) values(p_user_id) on conflict(user_id) do nothing;
  perform 1 from public.archive_progress where user_id=p_user_id for update;
  insert into public.archive_game_results(provider,external_match_id,user_id,completed_at,won,metadata)
  values(p_provider,p_external_match_id,p_user_id,p_completed_at,coalesce(p_won,false),coalesce(p_metadata,'{}'::jsonb))
  on conflict(provider,external_match_id,user_id) do nothing returning id into v_result_id;
  if v_result_id is null then
    select * into v_progress from public.archive_progress where user_id=p_user_id;
    return jsonb_build_object('accepted',false,'duplicate',true,'points_awarded',0,
      'completed_games',v_progress.completed_games,'won_games',v_progress.won_games,
      'best_win_streak',v_progress.best_win_streak);
  end if;

  update public.archive_progress set
    completed_games=completed_games+1,
    won_games=won_games+case when coalesce(p_won,false) then 1 else 0 end,
    current_win_streak=case when coalesce(p_won,false) then current_win_streak+1 else 0 end,
    best_win_streak=greatest(best_win_streak,case when coalesce(p_won,false) then current_win_streak+1 else 0 end),
    updated_at=now()
  where user_id=p_user_id returning * into v_progress;

  v_reward:=public.archive_rule_integer('game_reward');
  v_cap:=public.archive_rule_integer('game_daily_cap');
  if v_reward<=0 or v_cap<0 then raise exception 'Invalid game rules';end if;
  -- The cap follows the trusted server-processing day, not a client/provider timestamp.
  v_today:=(clock_timestamp() at time zone 'utc')::date;
  select coalesce(sum(amount),0)::integer into v_today_points
  from public.archive_point_ledger where user_id=p_user_id and source='game'
    and created_at>=(v_today::timestamp at time zone 'utc')
    and created_at<((v_today+1)::timestamp at time zone 'utc');
  if v_today_points+v_reward<=v_cap then
    v_ledger:=public.archive_add_points_internal(
      p_user_id,'GAME_COMPLETED','game:'||p_provider||':'||p_external_match_id,
      v_reward,'game',jsonb_build_object('result_id',v_result_id,'won',coalesce(p_won,false),
      'provider',p_provider,'completed_at',p_completed_at),null,null
    );
    if v_ledger is not null then v_awarded:=v_reward;v_today_points:=v_today_points+v_reward;end if;
  end if;
  perform public.archive_game_award_milestones_internal(
    p_user_id,v_progress.completed_games,v_progress.won_games,v_progress.best_win_streak
  );
  return jsonb_build_object('accepted',true,'duplicate',false,'points_awarded',v_awarded,
    'today_points',v_today_points,'daily_cap',v_cap,'completed_games',v_progress.completed_games,
    'won_games',v_progress.won_games,'current_win_streak',v_progress.current_win_streak,
    'best_win_streak',v_progress.best_win_streak);
end;$$;

create or replace function public.archive_game_status()
returns jsonb language sql security definer stable set search_path='' as $$
  select jsonb_build_object(
    'verified',coalesce((r.value->>'verified')::boolean,false),
    'status',coalesce(r.value->>'status','WAITING_FOR_GAME_BACKEND'),
    'reward',public.archive_rule_integer('game_reward'),
    'daily_cap',public.archive_rule_integer('game_daily_cap')
  ) from public.archive_rules r where r.rule_key='game_backend' and auth.uid() is not null;
$$;

revoke all on function public.archive_game_award_milestones_internal(uuid,integer,integer,integer),
  public.archive_record_game_result(text,text,uuid,timestamptz,boolean,jsonb),
  public.archive_game_status() from public,anon,authenticated;
grant execute on function public.archive_record_game_result(text,text,uuid,timestamptz,boolean,jsonb) to service_role;
grant execute on function public.archive_game_status() to authenticated;

commit;
