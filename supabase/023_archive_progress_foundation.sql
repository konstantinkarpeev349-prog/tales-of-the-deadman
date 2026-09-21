-- Stage 3: Archive Points, achievements, notifications and staff audit foundation.
-- Additive and repeatable. This migration does not recalculate archive levels,
-- reset legacy users, award historical points, or trust any frontend event.
begin;

create table if not exists public.archive_rules (
  rule_key text primary key check (rule_key ~ '^[a-z0-9_]+$'),
  value jsonb not null,
  description text not null,
  updated_at timestamptz not null default now()
);

create table if not exists public.archive_progress (
  user_id uuid primary key references auth.users(id) on delete cascade,
  points bigint not null default 0,
  archive_i_test_passed boolean not null default false,
  best_archive_i_test_score smallint not null default 0 check (best_archive_i_test_score between 0 and 12),
  active_seconds bigint not null default 0 check (active_seconds >= 0),
  completed_games integer not null default 0 check (completed_games >= 0),
  won_games integer not null default 0 check (won_games >= 0),
  best_win_streak integer not null default 0 check (best_win_streak >= 0),
  updated_at timestamptz not null default now()
);

create table if not exists public.archive_point_ledger (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  event_code text not null check (event_code ~ '^[A-Z0-9_]+$'),
  event_key text not null check (char_length(event_key) between 3 and 200),
  amount integer not null check (amount <> 0 and amount between -1000000 and 1000000),
  source text not null check (source in ('reading','faction','quiz','active_time','game','support','achievement','staff_adjustment','migration','system')),
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object'),
  created_by uuid references auth.users(id) on delete set null,
  reason text,
  created_at timestamptz not null default now(),
  unique (user_id,event_key),
  check (source <> 'staff_adjustment' or (created_by is not null and char_length(btrim(coalesce(reason,''))) between 5 and 500))
);

create table if not exists public.achievement_definitions (
  code text primary key check (code ~ '^[A-Z0-9_]+$'),
  title text not null,
  description text not null,
  condition_text text not null,
  category text not null check (category in ('reading','lore','archive','activity','games','factions','support','special')),
  icon_key text not null,
  rarity text not null default 'common' check (rarity in ('common','uncommon','rare','epic','legendary')),
  point_reward integer not null default 0 check (point_reward between 0 and 1000000),
  is_secret boolean not null default false,
  allow_manual_grant boolean not null default true,
  allow_manual_revoke boolean not null default true,
  is_active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.user_achievements (
  user_id uuid not null references auth.users(id) on delete cascade,
  achievement_code text not null references public.achievement_definitions(code),
  is_active boolean not null default true,
  grant_count integer not null default 1 check (grant_count > 0),
  source text not null check (source in ('system','staff','migration')),
  source_key text not null check (char_length(source_key) between 3 and 200),
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object'),
  awarded_at timestamptz not null default now(),
  awarded_by uuid references auth.users(id) on delete set null,
  revoked_at timestamptz,
  revoked_by uuid references auth.users(id) on delete set null,
  revoke_reason text,
  primary key (user_id,achievement_code)
);

create table if not exists public.archive_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  notification_type text not null check (notification_type in ('achievement','archive_level','points_adjusted','achievement_granted','achievement_revoked','system')),
  dedupe_key text not null check (char_length(dedupe_key) between 3 and 220),
  title text not null,
  body text not null,
  achievement_code text references public.achievement_definitions(code),
  point_delta integer,
  archive_level smallint check (archive_level between 0 and 3),
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object'),
  created_at timestamptz not null default now(),
  seen_at timestamptz,
  unique (user_id,dedupe_key)
);

create table if not exists public.archive_audit_log (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references auth.users(id) on delete set null,
  target_user_id uuid references auth.users(id) on delete set null,
  action text not null check (action ~ '^[A-Z0-9_]+$'),
  object_type text not null,
  object_key text,
  before_state jsonb,
  after_state jsonb,
  reason text,
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object'),
  created_at timestamptz not null default now()
);

create index if not exists archive_point_ledger_user_created_idx on public.archive_point_ledger(user_id,created_at desc);
create index if not exists user_achievements_user_active_idx on public.user_achievements(user_id,is_active,awarded_at desc);
create index if not exists archive_notifications_user_unseen_idx on public.archive_notifications(user_id,created_at) where seen_at is null;
create index if not exists archive_audit_log_created_idx on public.archive_audit_log(created_at desc);
create index if not exists archive_audit_log_target_idx on public.archive_audit_log(target_user_id,created_at desc);

alter table public.archive_rules enable row level security;
alter table public.archive_progress enable row level security;
alter table public.archive_point_ledger enable row level security;
alter table public.achievement_definitions enable row level security;
alter table public.user_achievements enable row level security;
alter table public.archive_notifications enable row level security;
alter table public.archive_audit_log enable row level security;

revoke all on public.archive_rules,public.archive_progress,public.archive_point_ledger,public.achievement_definitions,public.user_achievements,public.archive_notifications,public.archive_audit_log from public,anon,authenticated;
grant select on public.archive_rules,public.achievement_definitions to authenticated;
grant select on public.archive_progress,public.archive_point_ledger,public.user_achievements,public.archive_notifications,public.archive_audit_log to authenticated;

create or replace function public.archive_is_staff(p_user_id uuid default auth.uid())
returns boolean
language sql
security definer
stable
set search_path = ''
as $$
  select exists(
    select 1 from public.account_access a
    where a.user_id=p_user_id and not coalesce(a.is_banned,false)
      and (coalesce(a.is_admin,false) or coalesce(a.is_author,false) or coalesce(a.is_todm_team,false))
  );
$$;

drop policy if exists "read archive rules" on public.archive_rules;
create policy "read archive rules" on public.archive_rules for select to authenticated using (true);
drop policy if exists "read achievement definitions" on public.achievement_definitions;
create policy "read achievement definitions" on public.achievement_definitions for select to authenticated using (
  public.archive_is_staff()
  or (is_active and (not is_secret or exists(select 1 from public.user_achievements ua where ua.user_id=auth.uid() and ua.achievement_code=code and ua.is_active)))
);
drop policy if exists "read own archive progress" on public.archive_progress;
create policy "read own archive progress" on public.archive_progress for select to authenticated using (user_id=auth.uid() or public.archive_is_staff());
drop policy if exists "read own archive ledger" on public.archive_point_ledger;
create policy "read own archive ledger" on public.archive_point_ledger for select to authenticated using (user_id=auth.uid() or public.archive_is_staff());
drop policy if exists "read own achievements" on public.user_achievements;
create policy "read own achievements" on public.user_achievements for select to authenticated using (user_id=auth.uid() or public.archive_is_staff());
drop policy if exists "read own archive notifications" on public.archive_notifications;
create policy "read own archive notifications" on public.archive_notifications for select to authenticated using (user_id=auth.uid() or public.archive_is_staff());
drop policy if exists "staff read archive audit" on public.archive_audit_log;
create policy "staff read archive audit" on public.archive_audit_log for select to authenticated using (public.archive_is_staff());

insert into public.archive_rules(rule_key,value,description) values
 ('archive_i_points','120'::jsonb,'ОА для Архива I; дополнительно требуется успешное Испытание I'),
 ('archive_ii_points','300'::jsonb,'ОА для Архива II'),
 ('archive_iii_points','500'::jsonb,'ОА для Архива III'),
 ('read_reward','20'::jsonb,'ОА за первое подтверждённое чтение каждой бесплатной части'),
 ('faction_first_selection_reward','20'::jsonb,'ОА за первый выбор фракции'),
 ('archive_i_test_reward','20'::jsonb,'ОА за первое успешное Испытание I'),
 ('archive_i_test_questions','12'::jsonb,'Количество вопросов Испытания I'),
 ('archive_i_test_pass_score','8'::jsonb,'Минимальный результат Испытания I'),
 ('support_first_reward','30'::jsonb,'ОА за первую подтверждённую поддержку'),
 ('faction_leader_reward','50'::jsonb,'ОА за первое подтверждённое лидерство фракции'),
 ('game_reward','5'::jsonb,'ОА за подтверждённую завершённую онлайн-партию'),
 ('game_daily_cap','20'::jsonb,'Дневной лимит ОА через онлайн-игру'),
 ('active_time_interval_seconds','900'::jsonb,'Интервал активного времени для начисления'),
 ('active_time_reward','2'::jsonb,'ОА за интервал активного времени'),
 ('active_time_daily_cap','16'::jsonb,'Дневной лимит ОА за активное время'),
 ('active_time_idle_seconds','300'::jsonb,'После этого бездействия активное время не считается'),
 ('reading_verification','{"enabled":false,"minimum_active_seconds":180,"requires_scroll":true,"requires_end":true,"status":"CONTENT_REQUIRED"}'::jsonb,'Проверка чтения включается после добавления актуального текста'),
 ('game_backend','{"verified":false,"status":"WAITING_FOR_GAME_BACKEND"}'::jsonb,'Начисление за игры отключено до доверенной серверной интеграции')
on conflict(rule_key) do update set value=excluded.value,description=excluded.description,updated_at=now();

insert into public.achievement_definitions(code,title,description,condition_text,category,icon_key,rarity,point_reward,is_secret) values
 ('READ_PROLOGUE','С чего всё началось','Прочитан Пролог.','Подтвердить прочтение Пролога.','reading','scroll-prologue','common',20,false),
 ('READ_CHAPTER_1','Первый шаг','Прочитана Глава 1.','Подтвердить прочтение Главы 1.','reading','scroll-one','common',20,false),
 ('READ_CHAPTER_2','Назад дороги нет','Прочитана Глава 2.','Подтвердить прочтение Главы 2.','reading','scroll-two','common',20,false),
 ('READ_CHAPTER_3','Добро пожаловать в Антамариду','Прочитана Глава 3.','Подтвердить прочтение Главы 3.','reading','scroll-three','uncommon',20,false),
 ('READ_FREE_PARTS','Первые страницы Мертвеца','Прочитаны Пролог и главы 1–3.','Подтвердить прочтение всех четырёх бесплатных частей.','reading','open-book','rare',0,false),
 ('FIRST_FACTION_SELECTED','Я сделал свой выбор','Впервые выбрана фракция TODM.','Выбрать фракцию впервые.','factions','faction-sigil','uncommon',20,false),
 ('ARCHIVE_I_TEST_PASSED','Испытание пройдено','Испытание Архива I пройдено.','Набрать не менее 8 из 12.','archive','archive-seal-one','uncommon',20,false),
 ('ARCHIVE_I_TEST_EXPERT','Знаток','Высокий результат Испытания Архива I.','Набрать не менее 10 из 12.','lore','archive-eye','rare',0,false),
 ('ARCHIVE_I_TEST_PERFECT','Память Мертвеца','Безупречный результат Испытания Архива I.','Набрать 12 из 12.','lore','deadman-memory','epic',0,false),
 ('ACTIVE_1_HOUR','Заглянул ненадолго','Один активный час на сайте.','Накопить 1 активный час.','activity','hourglass-one','common',0,false),
 ('ACTIVE_10_HOURS','Завсегдатай','Десять активных часов на сайте.','Накопить 10 активных часов.','activity','hourglass-ten','uncommon',0,false),
 ('ACTIVE_50_HOURS','Здесь живут люди?','Пятьдесят активных часов на сайте.','Накопить 50 активных часов.','activity','hourglass-fifty','rare',0,false),
 ('ACTIVE_100_HOURS','Архив стал домом','Сто активных часов на сайте.','Накопить 100 активных часов.','activity','archive-home','epic',0,false),
 ('ACTIVE_250_HOURS','Выйди на улицу','Двести пятьдесят активных часов на сайте.','Накопить 250 активных часов.','activity','sealed-hourglass','legendary',0,false),
 ('GAME_FIRST','Первая партия','Завершена первая онлайн-партия.','Завершить 1 подтверждённую партию.','games','game-one','common',0,false),
 ('GAME_10','Освоился','Завершено десять онлайн-партий.','Завершить 10 подтверждённых партий.','games','game-ten','uncommon',0,false),
 ('GAME_25','Ветеран','Завершено двадцать пять онлайн-партий.','Завершить 25 подтверждённых партий.','games','game-veteran','rare',0,false),
 ('GAME_50','Старожил поля боя','Завершено пятьдесят онлайн-партий.','Завершить 50 подтверждённых партий.','games','game-field','epic',0,false),
 ('GAME_100','Это уже личное','Завершено сто онлайн-партий.','Завершить 100 подтверждённых партий.','games','game-hundred','legendary',0,false),
 ('GAME_FIRST_WIN','Первая кровь','Одержана первая победа.','Одержать первую подтверждённую победу.','games','first-blood','rare',0,false),
 ('GAME_WIN_STREAK_5','Серия','Пять побед подряд.','Одержать 5 подтверждённых побед подряд.','games','win-streak','epic',0,false),
 ('FIRST_SUPPORT','Поддержал TODM','Проект TODM получил подтверждённую поддержку.','Впервые подтвердить добровольную поддержку проекта.','support','support-mark','rare',30,false),
 ('FACTION_LEADER','Лидер фракции','Пользователь был лидером фракции TODM.','Получить подтверждённый статус лидера фракции.','factions','leader-crown','legendary',50,false)
on conflict(code) do update set title=excluded.title,description=excluded.description,condition_text=excluded.condition_text,category=excluded.category,icon_key=excluded.icon_key,rarity=excluded.rarity,point_reward=excluded.point_reward,is_secret=excluded.is_secret,updated_at=now();

insert into public.archive_progress(user_id)
select user_id from public.account_access
on conflict(user_id) do nothing;

create or replace function public.archive_initialize_progress()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  insert into public.archive_progress(user_id) values(new.user_id) on conflict(user_id) do nothing;
  return new;
end;$$;
drop trigger if exists archive_initialize_progress_on_access on public.account_access;
create trigger archive_initialize_progress_on_access after insert on public.account_access for each row execute function public.archive_initialize_progress();

create or replace function public.archive_add_points_internal(
  p_user_id uuid,p_event_code text,p_event_key text,p_amount integer,p_source text,
  p_metadata jsonb default '{}'::jsonb,p_created_by uuid default null,p_reason text default null
) returns uuid
language plpgsql security definer set search_path='' as $$
declare v_id uuid;
begin
  if p_user_id is null or p_event_code !~ '^[A-Z0-9_]+$' or char_length(p_event_key) not between 3 and 200
    or p_amount=0 or p_amount not between -1000000 and 1000000
    or p_source not in ('reading','faction','quiz','active_time','game','support','achievement','staff_adjustment','migration','system') then
    raise exception 'Недопустимое событие прогресса' using errcode='22023';
  end if;
  if p_source='staff_adjustment' and (p_created_by is null or char_length(btrim(coalesce(p_reason,''))) not between 5 and 500) then
    raise exception 'Для ручной корректировки требуется причина' using errcode='22023';
  end if;
  insert into public.archive_progress(user_id) values(p_user_id) on conflict(user_id) do nothing;
  perform 1 from public.archive_progress where user_id=p_user_id for update;
  insert into public.archive_point_ledger(user_id,event_code,event_key,amount,source,metadata,created_by,reason)
  values(p_user_id,p_event_code,p_event_key,p_amount,p_source,coalesce(p_metadata,'{}'::jsonb),p_created_by,nullif(btrim(p_reason),''))
  on conflict(user_id,event_key) do nothing returning id into v_id;
  if v_id is not null then
    update public.archive_progress set points=points+p_amount,updated_at=now() where user_id=p_user_id;
  end if;
  return v_id;
end;$$;

create or replace function public.archive_queue_notification_internal(
  p_user_id uuid,p_type text,p_dedupe_key text,p_title text,p_body text,
  p_achievement_code text default null,p_point_delta integer default null,p_archive_level smallint default null,p_metadata jsonb default '{}'::jsonb
) returns uuid
language plpgsql security definer set search_path='' as $$
declare v_id uuid;
begin
  insert into public.archive_notifications(user_id,notification_type,dedupe_key,title,body,achievement_code,point_delta,archive_level,metadata)
  values(p_user_id,p_type,p_dedupe_key,p_title,p_body,p_achievement_code,p_point_delta,p_archive_level,coalesce(p_metadata,'{}'::jsonb))
  on conflict(user_id,dedupe_key) do nothing returning id into v_id;
  return v_id;
end;$$;

create or replace function public.archive_award_achievement_internal(
  p_user_id uuid,p_code text,p_source text,p_source_key text,p_metadata jsonb default '{}'::jsonb,p_awarded_by uuid default null
) returns boolean
language plpgsql security definer set search_path='' as $$
declare v_definition public.achievement_definitions;v_row_count integer;v_ledger uuid;
begin
  select * into v_definition from public.achievement_definitions where code=p_code and is_active for update;
  if not found then raise exception 'Достижение не найдено' using errcode='22023'; end if;
  insert into public.user_achievements(user_id,achievement_code,source,source_key,metadata,awarded_by)
  values(p_user_id,p_code,p_source,p_source_key,coalesce(p_metadata,'{}'::jsonb),p_awarded_by)
  on conflict(user_id,achievement_code) do nothing;
  get diagnostics v_row_count = row_count;
  if v_row_count=0 then return false; end if;
  if v_definition.point_reward>0 then
    v_ledger:=public.archive_add_points_internal(p_user_id,p_code,'achievement:'||p_code,v_definition.point_reward,'achievement',jsonb_build_object('achievement_code',p_code),p_awarded_by,null);
  end if;
  perform public.archive_queue_notification_internal(p_user_id,'achievement','achievement:'||p_code,'АРХИВ ЗАФИКСИРОВАЛ ДОСТИЖЕНИЕ',v_definition.title,p_code,case when v_definition.point_reward>0 then v_definition.point_reward else null end,null,jsonb_build_object('source',p_source));
  return true;
end;$$;

create or replace function public.archive_staff_adjust_points(p_user_id uuid,p_amount integer,p_reason text)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_actor public.account_access;v_target public.account_access;v_id uuid;v_key text;
begin
  select * into v_actor from public.account_access where user_id=auth.uid() and not is_banned;
  if not found or not (v_actor.is_admin or v_actor.is_author or v_actor.is_todm_team) then raise exception 'Недостаточно прав' using errcode='42501'; end if;
  select * into v_target from public.account_access where user_id=p_user_id;
  if not found then raise exception 'Пользователь не найден' using errcode='22023'; end if;
  if v_target.is_author and not (v_actor.is_author or v_actor.is_admin) then raise exception 'TODM IV не может изменять Автора' using errcode='42501'; end if;
  if p_amount=0 or p_amount not between -1000000 and 1000000 or char_length(btrim(coalesce(p_reason,''))) not between 5 and 500 then raise exception 'Укажите корректную сумму и причину' using errcode='22023'; end if;
  v_key:='staff-adjustment:'||gen_random_uuid()::text;
  v_id:=public.archive_add_points_internal(p_user_id,'STAFF_ADJUSTMENT',v_key,p_amount,'staff_adjustment',jsonb_build_object('actor_id',auth.uid()),auth.uid(),p_reason);
  insert into public.archive_audit_log(actor_id,target_user_id,action,object_type,object_key,after_state,reason)
  values(auth.uid(),p_user_id,'POINTS_ADJUSTED','archive_points',v_id::text,jsonb_build_object('amount',p_amount),btrim(p_reason));
  perform public.archive_queue_notification_internal(p_user_id,'points_adjusted','points-adjusted:'||v_id::text,'АРХИВ СКОРРЕКТИРОВАЛ ПРОГРЕСС',case when p_amount>0 then '+'||p_amount::text||' ОА' else p_amount::text||' ОА' end,null,p_amount,null,jsonb_build_object('reason',btrim(p_reason)));
  return v_id;
end;$$;

create or replace function public.archive_notification_mark_seen(p_notification_id uuid)
returns boolean language plpgsql security definer set search_path='' as $$
begin
  update public.archive_notifications set seen_at=coalesce(seen_at,now()) where id=p_notification_id and user_id=auth.uid();
  return found;
end;$$;

create or replace function public.archive_get_my_summary(p_ledger_limit integer default 20)
returns jsonb language plpgsql security definer stable set search_path='' as $$
declare v_user uuid:=auth.uid();v_limit integer:=least(greatest(coalesce(p_ledger_limit,20),1),50);
begin
  if v_user is null then raise exception 'Требуется авторизация' using errcode='42501'; end if;
  return jsonb_build_object(
    'progress',(select to_jsonb(p) from public.archive_progress p where p.user_id=v_user),
    'achievements',coalesce((select jsonb_agg(to_jsonb(x) order by x.awarded_at desc) from (select ua.achievement_code,ua.awarded_at,ua.source,d.title,d.description,d.condition_text,d.category,d.icon_key,d.rarity,d.point_reward from public.user_achievements ua join public.achievement_definitions d on d.code=ua.achievement_code where ua.user_id=v_user and ua.is_active) x),'[]'::jsonb),
    'ledger',coalesce((select jsonb_agg(to_jsonb(x) order by x.created_at desc) from (select l.id,l.event_code,l.amount,l.source,l.metadata,l.reason,l.created_at from public.archive_point_ledger l where l.user_id=v_user order by l.created_at desc limit v_limit) x),'[]'::jsonb),
    'notifications',coalesce((select jsonb_agg(to_jsonb(x) order by x.created_at) from (select n.id,n.notification_type,n.title,n.body,n.achievement_code,n.point_delta,n.archive_level,n.metadata,n.created_at from public.archive_notifications n where n.user_id=v_user and n.seen_at is null order by n.created_at limit 20) x),'[]'::jsonb)
  );
end;$$;

revoke all on function public.archive_is_staff(uuid),public.archive_initialize_progress(),public.archive_add_points_internal(uuid,text,text,integer,text,jsonb,uuid,text),public.archive_queue_notification_internal(uuid,text,text,text,text,text,integer,smallint,jsonb),public.archive_award_achievement_internal(uuid,text,text,text,jsonb,uuid),public.archive_staff_adjust_points(uuid,integer,text),public.archive_notification_mark_seen(uuid),public.archive_get_my_summary(integer) from public,anon,authenticated;
grant execute on function public.archive_is_staff(uuid),public.archive_staff_adjust_points(uuid,integer,text),public.archive_notification_mark_seen(uuid),public.archive_get_my_summary(integer) to authenticated;

commit;
