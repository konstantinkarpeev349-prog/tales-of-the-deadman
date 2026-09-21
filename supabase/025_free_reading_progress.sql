-- Stage 5: free reading content and trusted first-read rewards.
-- Canonical text is not included. All four entries remain CONTENT_REQUIRED,
-- so no reading session or reward can start until staff publishes real text.
begin;

create table if not exists public.archive_reading_content (
  content_key text primary key check (content_key in ('prologue','chapter-1','chapter-2','chapter-3')),
  title text not null,
  body jsonb not null default '{}'::jsonb check (jsonb_typeof(body)='object'),
  status text not null default 'CONTENT_REQUIRED' check (status in ('CONTENT_REQUIRED','DRAFT','PUBLISHED')),
  minimum_active_seconds integer not null default 180 check (minimum_active_seconds between 30 and 7200),
  published boolean not null default false,
  updated_at timestamptz not null default now(),
  check (not published or status='PUBLISHED')
);
create table if not exists public.archive_reading_sessions (
  id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id) on delete cascade,
  content_key text not null references public.archive_reading_content(content_key),started_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),active_seconds integer not null default 0 check (active_seconds>=0),
  max_scroll_percent numeric(5,2) not null default 0 check (max_scroll_percent between 0 and 100),
  reached_end boolean not null default false,completed_at timestamptz,awarded_at timestamptz
);
create table if not exists public.archive_reading_clock (
  user_id uuid primary key references auth.users(id) on delete cascade,last_counted_at timestamptz not null default now()
);
create index if not exists archive_reading_sessions_user_idx on public.archive_reading_sessions(user_id,started_at desc);
create index if not exists archive_reading_sessions_open_idx on public.archive_reading_sessions(user_id,last_seen_at desc) where completed_at is null;
alter table public.archive_reading_content enable row level security;
alter table public.archive_reading_sessions enable row level security;
alter table public.archive_reading_clock enable row level security;
revoke all on public.archive_reading_content,public.archive_reading_sessions,public.archive_reading_clock from public,anon,authenticated;
grant select on public.archive_reading_content to anon,authenticated;
grant select on public.archive_reading_sessions to authenticated;
drop policy if exists "read published free content" on public.archive_reading_content;
create policy "read published free content" on public.archive_reading_content for select to anon,authenticated using (published and status='PUBLISHED');
drop policy if exists "read own reading sessions" on public.archive_reading_sessions;
create policy "read own reading sessions" on public.archive_reading_sessions for select to authenticated using (user_id=auth.uid() or public.archive_is_staff());

insert into public.archive_reading_content(content_key,title,status,published) values
 ('prologue','Пролог','CONTENT_REQUIRED',false),('chapter-1','Глава 1','CONTENT_REQUIRED',false),
 ('chapter-2','Глава 2','CONTENT_REQUIRED',false),('chapter-3','Глава 3','CONTENT_REQUIRED',false)
on conflict(content_key) do update set title=excluded.title;
update public.achievement_definitions set point_reward=0,updated_at=now()
where code in ('READ_PROLOGUE','READ_CHAPTER_1','READ_CHAPTER_2','READ_CHAPTER_3','READ_FREE_PARTS');

create or replace function public.archive_reading_manifest()
returns table(content_key text,title text,status text,minimum_active_seconds integer,published boolean)
language sql security definer stable set search_path='' as $$
 select c.content_key,c.title,c.status,c.minimum_active_seconds,c.published from public.archive_reading_content c
 order by case c.content_key when 'prologue' then 1 when 'chapter-1' then 2 when 'chapter-2' then 3 else 4 end;
$$;

create or replace function public.archive_reading_start(p_content_key text)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid;
begin
 perform 1 from public.account_access a where a.user_id=auth.uid() and not a.is_banned;
 if not found then raise exception 'Требуется активный аккаунт' using errcode='42501'; end if;
 perform 1 from public.archive_reading_content c where c.content_key=p_content_key and c.published and c.status='PUBLISHED' for share;
 if not found then raise exception 'CONTENT REQUIRED' using errcode='55000'; end if;
 select s.id into v_id from public.archive_reading_sessions s where s.user_id=auth.uid() and s.content_key=p_content_key
  and s.completed_at is null and s.last_seen_at>clock_timestamp()-interval '10 minutes' order by s.started_at desc limit 1;
 if v_id is null then insert into public.archive_reading_sessions(user_id,content_key) values(auth.uid(),p_content_key) returning id into v_id; end if;
 insert into public.archive_reading_clock(user_id) values(auth.uid()) on conflict(user_id) do nothing;
 return v_id;
end;$$;

create or replace function public.archive_reading_heartbeat(
 p_session_id uuid,p_scroll_percent numeric,p_visible boolean,p_interacted boolean,p_reached_end boolean default false
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_session public.archive_reading_sessions%rowtype;v_clock public.archive_reading_clock%rowtype;
 v_now timestamptz:=clock_timestamp();v_elapsed integer:=0;v_scroll numeric;
begin
 select * into v_session from public.archive_reading_sessions where id=p_session_id and user_id=auth.uid() and completed_at is null for update;
 if not found then raise exception 'Сессия чтения недоступна' using errcode='42501'; end if;
 perform 1 from public.account_access a where a.user_id=auth.uid() and not a.is_banned;
 if not found then raise exception 'Аккаунт недоступен' using errcode='42501'; end if;
 perform 1 from public.archive_reading_content c where c.content_key=v_session.content_key and c.published and c.status='PUBLISHED';
 if not found then raise exception 'CONTENT REQUIRED' using errcode='55000'; end if;
 insert into public.archive_reading_clock(user_id) values(auth.uid()) on conflict(user_id) do nothing;
 select * into v_clock from public.archive_reading_clock where user_id=auth.uid() for update;
 v_scroll:=least(greatest(coalesce(p_scroll_percent,0),0),100);
 if coalesce(p_visible,false) and coalesce(p_interacted,false) and v_now-v_session.last_seen_at<=interval '45 seconds' then
  v_elapsed:=least(20,greatest(0,floor(extract(epoch from (v_now-greatest(v_session.last_seen_at,v_clock.last_counted_at))))::integer));
  update public.archive_reading_clock set last_counted_at=v_now where user_id=auth.uid();
 end if;
 update public.archive_reading_sessions set last_seen_at=v_now,active_seconds=active_seconds+v_elapsed,
  max_scroll_percent=greatest(max_scroll_percent,v_scroll),reached_end=reached_end or coalesce(p_reached_end,false)
 where id=p_session_id returning * into v_session;
 return jsonb_build_object('active_seconds',v_session.active_seconds,'max_scroll_percent',v_session.max_scroll_percent,'reached_end',v_session.reached_end);
end;$$;

create or replace function public.archive_reading_complete(p_session_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_session public.archive_reading_sessions%rowtype;v_content public.archive_reading_content%rowtype;
 v_code text;v_reward integer;v_ledger uuid;v_awarded boolean;v_all boolean;
begin
 select * into v_session from public.archive_reading_sessions where id=p_session_id and user_id=auth.uid() for update;
 if not found then raise exception 'Сессия чтения недоступна' using errcode='42501'; end if;
 select * into v_content from public.archive_reading_content where content_key=v_session.content_key and published and status='PUBLISHED';
 if not found then raise exception 'CONTENT REQUIRED' using errcode='55000'; end if;
 if v_session.active_seconds<v_content.minimum_active_seconds or v_session.max_scroll_percent<95 or not v_session.reached_end then
  raise exception 'Условия чтения ещё не выполнены' using errcode='55000'; end if;
 v_code:=case v_session.content_key when 'prologue' then 'READ_PROLOGUE' when 'chapter-1' then 'READ_CHAPTER_1' when 'chapter-2' then 'READ_CHAPTER_2' when 'chapter-3' then 'READ_CHAPTER_3' end;
 select (value #>> '{}')::integer into v_reward from public.archive_rules where rule_key='read_reward';
 if v_reward is null or v_reward<0 then raise exception 'Правило награды чтения не настроено' using errcode='55000'; end if;
 v_ledger:=public.archive_add_points_internal(auth.uid(),'READ_'||upper(replace(v_session.content_key,'-','_')),
  'reading:'||v_session.content_key,v_reward,'reading',jsonb_build_object('content_key',v_session.content_key),null,null);
 v_awarded:=public.archive_award_achievement_internal(auth.uid(),v_code,'system','reading:'||v_session.content_key,jsonb_build_object('content_key',v_session.content_key),null);
 update public.archive_reading_sessions set completed_at=coalesce(completed_at,now()),awarded_at=case when v_ledger is not null then now() else awarded_at end where id=p_session_id;
 select count(*)=4 into v_all from public.user_achievements where user_id=auth.uid() and is_active
  and achievement_code in ('READ_PROLOGUE','READ_CHAPTER_1','READ_CHAPTER_2','READ_CHAPTER_3');
 if v_all then perform public.archive_award_achievement_internal(auth.uid(),'READ_FREE_PARTS','system','reading:all-free-parts','{}'::jsonb,null); end if;
 return jsonb_build_object('completed',true,'points_awarded',coalesce(v_ledger is not null,false),'achievement_awarded',coalesce(v_awarded,false));
end;$$;

revoke all on function public.archive_reading_manifest(),public.archive_reading_start(text),
 public.archive_reading_heartbeat(uuid,numeric,boolean,boolean,boolean),public.archive_reading_complete(uuid) from public,anon,authenticated;
grant execute on function public.archive_reading_manifest() to anon,authenticated;
grant execute on function public.archive_reading_start(text),public.archive_reading_heartbeat(uuid,numeric,boolean,boolean,boolean),
 public.archive_reading_complete(uuid) to authenticated;
commit;
