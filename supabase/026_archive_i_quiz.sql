-- Stage 6: Archive I trial infrastructure. No lore questions are included.
begin;

create table if not exists public.archive_quiz_versions (
 id uuid primary key default gen_random_uuid(),quiz_key text not null default 'archive-i' check(quiz_key='archive-i'),
 version integer not null check(version>0),status text not null default 'CONTENT_REQUIRED' check(status in('CONTENT_REQUIRED','DRAFT','PUBLISHED','RETIRED')),
 question_count smallint not null default 12 check(question_count=12),pass_score smallint not null default 8 check(pass_score between 1 and 12),
 published boolean not null default false,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 unique(quiz_key,version),check(not published or status='PUBLISHED'));
create table if not exists public.archive_quiz_questions (
 id uuid primary key default gen_random_uuid(),quiz_version_id uuid not null references public.archive_quiz_versions(id) on delete cascade,
 position smallint not null check(position between 1 and 12),prompt text not null check(char_length(btrim(prompt)) between 3 and 1000),
 options jsonb not null check(jsonb_typeof(options)='array' and jsonb_array_length(options) between 2 and 6),
 correct_option smallint not null check(correct_option between 0 and 5),published boolean not null default false,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),unique(quiz_version_id,position),
 check(correct_option<jsonb_array_length(options)));
create table if not exists public.archive_quiz_attempts (
 id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id) on delete cascade,
 quiz_version_id uuid not null references public.archive_quiz_versions(id),question_order uuid[] not null check(cardinality(question_order)=12),
 status text not null default 'STARTED' check(status in('STARTED','SUBMITTED','EXPIRED')),score smallint check(score between 0 and 12),passed boolean,
 started_at timestamptz not null default now(),submitted_at timestamptz,answers jsonb,
 check((status='STARTED' and score is null and passed is null and submitted_at is null and answers is null) or status in('SUBMITTED','EXPIRED')));
create index if not exists archive_quiz_attempts_user_idx on public.archive_quiz_attempts(user_id,started_at desc);
create unique index if not exists archive_quiz_one_open_attempt_idx on public.archive_quiz_attempts(user_id,quiz_version_id) where status='STARTED';
alter table public.archive_quiz_versions enable row level security;alter table public.archive_quiz_questions enable row level security;alter table public.archive_quiz_attempts enable row level security;
revoke all on public.archive_quiz_versions,public.archive_quiz_questions,public.archive_quiz_attempts from public,anon,authenticated;
grant select on public.archive_quiz_attempts to authenticated;
drop policy if exists "read own quiz attempts" on public.archive_quiz_attempts;
create policy "read own quiz attempts" on public.archive_quiz_attempts for select to authenticated using(user_id=auth.uid() or public.archive_is_staff());
insert into public.archive_quiz_versions(quiz_key,version,status,question_count,pass_score,published) values('archive-i',1,'CONTENT_REQUIRED',12,8,false) on conflict(quiz_key,version) do nothing;

create or replace function public.archive_i_quiz_status() returns jsonb language plpgsql security definer stable set search_path='' as $$
declare v_user uuid:=auth.uid();v_version public.archive_quiz_versions%rowtype;v_read integer:=0;v_best smallint:=0;v_passed boolean:=false;
begin
 if v_user is not null then
  select count(*) into v_read from public.user_achievements where user_id=v_user and is_active and achievement_code in('READ_PROLOGUE','READ_CHAPTER_1','READ_CHAPTER_2','READ_CHAPTER_3');
  select best_archive_i_test_score,archive_i_test_passed into v_best,v_passed from public.archive_progress where user_id=v_user;
 end if;
 select * into v_version from public.archive_quiz_versions where quiz_key='archive-i' order by version desc limit 1;
 return jsonb_build_object('authenticated',v_user is not null,'available',v_version.published and v_version.status='PUBLISHED' and v_read=4,
  'content_status',coalesce(v_version.status,'CONTENT_REQUIRED'),'reading_complete',v_read=4,'read_parts',v_read,'required_parts',4,
  'question_count',coalesce(v_version.question_count,12),'pass_score',coalesce(v_version.pass_score,8),'best_score',coalesce(v_best,0),'passed',coalesce(v_passed,false));
end;$$;

create or replace function public.archive_i_quiz_start() returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_version public.archive_quiz_versions%rowtype;v_read integer;v_count integer;v_attempt uuid;v_order uuid[];v_questions jsonb;
begin
 if v_user is null then raise exception 'Требуется авторизация' using errcode='42501';end if;
 select count(*) into v_read from public.user_achievements where user_id=v_user and is_active and achievement_code in('READ_PROLOGUE','READ_CHAPTER_1','READ_CHAPTER_2','READ_CHAPTER_3');
 if v_read<>4 then raise exception 'Сначала прочитайте все четыре бесплатные части' using errcode='42501';end if;
 select * into v_version from public.archive_quiz_versions where quiz_key='archive-i' and published and status='PUBLISHED' order by version desc limit 1;
 if not found then raise exception 'CONTENT REQUIRED' using errcode='55000';end if;
 select count(*) into v_count from public.archive_quiz_questions where quiz_version_id=v_version.id and published;
 if v_count<>12 then raise exception 'CONTENT REQUIRED' using errcode='55000';end if;
 select id,question_order into v_attempt,v_order from public.archive_quiz_attempts where user_id=v_user and quiz_version_id=v_version.id and status='STARTED' for update;
 if v_attempt is null then
  select array_agg(id order by random()) into v_order from public.archive_quiz_questions where quiz_version_id=v_version.id and published;
  insert into public.archive_quiz_attempts(user_id,quiz_version_id,question_order) values(v_user,v_version.id,v_order) returning id into v_attempt;
 end if;
 select jsonb_agg(jsonb_build_object('id',q.id,'position',o.ordinality,'prompt',q.prompt,'options',q.options) order by o.ordinality) into v_questions
 from unnest(v_order) with ordinality o(id,ordinality) join public.archive_quiz_questions q on q.id=o.id;
 return jsonb_build_object('attempt_id',v_attempt,'questions',v_questions,'question_count',12,'pass_score',v_version.pass_score);
end;$$;

create or replace function public.archive_i_quiz_submit(p_attempt_id uuid,p_answers jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_attempt public.archive_quiz_attempts%rowtype;v_score smallint;v_pass_score smallint;v_pass boolean;v_best smallint;v_first_pass boolean:=false;
begin
 if v_user is null then raise exception 'Требуется авторизация' using errcode='42501';end if;
 if jsonb_typeof(p_answers)<>'array' or jsonb_array_length(p_answers)<>12 then raise exception 'Нужно ответить на 12 вопросов' using errcode='22023';end if;
 select * into v_attempt from public.archive_quiz_attempts where id=p_attempt_id and user_id=v_user for update;
 if not found then raise exception 'Попытка не найдена' using errcode='22023';end if;
 if v_attempt.status<>'STARTED' then raise exception 'Попытка уже завершена' using errcode='55000';end if;
 if v_attempt.started_at<now()-interval '2 hours' then update public.archive_quiz_attempts set status='EXPIRED' where id=p_attempt_id;raise exception 'Время попытки истекло' using errcode='55000';end if;
 if exists(select 1 from jsonb_array_elements(p_answers) a where not(a?'question_id' and a?'option_index') or (a->>'question_id')::uuid<>all(v_attempt.question_order) or (a->>'option_index')!~'^[0-9]+$')
  or(select count(distinct a->>'question_id') from jsonb_array_elements(p_answers) a)<>12 then raise exception 'Некорректный набор ответов' using errcode='22023';end if;
 select count(*)::smallint into v_score from jsonb_array_elements(p_answers) a join public.archive_quiz_questions q on q.id=(a->>'question_id')::uuid
  where q.quiz_version_id=v_attempt.quiz_version_id and q.published and q.correct_option=(a->>'option_index')::smallint;
 select pass_score into v_pass_score from public.archive_quiz_versions where id=v_attempt.quiz_version_id;
 v_pass:=v_score>=v_pass_score;
 update public.archive_quiz_attempts set status='SUBMITTED',score=v_score,passed=v_pass,submitted_at=now(),answers=p_answers where id=p_attempt_id;
 insert into public.archive_progress(user_id) values(v_user) on conflict(user_id) do nothing;
 update public.archive_progress set best_archive_i_test_score=greatest(best_archive_i_test_score,v_score),archive_i_test_passed=archive_i_test_passed or v_pass,updated_at=now() where user_id=v_user returning best_archive_i_test_score into v_best;
 if v_pass then v_first_pass:=public.archive_award_achievement_internal(v_user,'ARCHIVE_I_TEST_PASSED','system','quiz:archive-i:passed',jsonb_build_object('score',v_score),null);end if;
 if v_score>=10 then perform public.archive_award_achievement_internal(v_user,'ARCHIVE_I_TEST_EXPERT','system','quiz:archive-i:expert',jsonb_build_object('score',v_score),null);end if;
 if v_score=12 then perform public.archive_award_achievement_internal(v_user,'ARCHIVE_I_TEST_PERFECT','system','quiz:archive-i:perfect',jsonb_build_object('score',v_score),null);end if;
 return jsonb_build_object('score',v_score,'total',cardinality(v_attempt.question_order),'pass_score',v_pass_score,'passed',v_pass,'best_score',v_best,'points_awarded',v_first_pass);
end;$$;

revoke all on function public.archive_i_quiz_status(),public.archive_i_quiz_start(),public.archive_i_quiz_submit(uuid,jsonb) from public,anon,authenticated;
grant execute on function public.archive_i_quiz_status() to anon,authenticated;
grant execute on function public.archive_i_quiz_start(),public.archive_i_quiz_submit(uuid,jsonb) to authenticated;
commit;
