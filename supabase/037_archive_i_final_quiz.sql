-- Archive I trial mechanics. The original version-2 answer key was published
-- in Git history and must never be used for a new deployment. Keep question
-- seeds outside the public repository and publish a new private version.
begin;

alter table public.archive_quiz_versions drop constraint if exists archive_quiz_versions_question_count_check;
alter table public.archive_quiz_versions add constraint archive_quiz_versions_question_count_check check(question_count between 1 and 12);
alter table public.archive_quiz_attempts drop constraint if exists archive_quiz_attempts_question_order_check;
alter table public.archive_quiz_attempts add constraint archive_quiz_attempts_question_order_check check(cardinality(question_order) between 1 and 12);

-- Intentionally no INSERT into archive_quiz_versions or archive_quiz_questions.
-- An existing version 2 remains in a previously configured database; this
-- historical migration must not re-publish its compromised question set.

update public.archive_rules set value='10'::jsonb,description='Количество вопросов Испытания I',updated_at=now() where rule_key='archive_i_test_questions';
update public.archive_rules set value='7'::jsonb,description='Минимальный результат Испытания I',updated_at=now() where rule_key='archive_i_test_pass_score';
update public.achievement_definitions set condition_text='Набрать не менее 7 из 10.',updated_at=now() where code='ARCHIVE_I_TEST_PASSED';
update public.achievement_definitions set condition_text='Набрать не менее 9 из 10.',updated_at=now() where code='ARCHIVE_I_TEST_EXPERT';
update public.achievement_definitions set condition_text='Набрать 10 из 10.',updated_at=now() where code='ARCHIVE_I_TEST_PERFECT';

create or replace function public.archive_i_quiz_status() returns jsonb language plpgsql security definer stable set search_path='' as $$
declare v_user uuid:=auth.uid();v_version public.archive_quiz_versions%rowtype;v_read integer:=0;v_best smallint:=0;v_passed boolean:=false;
begin
 if v_user is not null then
  select count(*) into v_read from public.user_achievements where user_id=v_user and is_active and achievement_code in('READ_PROLOGUE','READ_CHAPTER_1','READ_CHAPTER_2','READ_CHAPTER_3');
  select best_archive_i_test_score,archive_i_test_passed into v_best,v_passed from public.archive_progress where user_id=v_user;
 end if;
 select * into v_version from public.archive_quiz_versions where quiz_key='archive-i' order by version desc limit 1;
 return jsonb_build_object('authenticated',v_user is not null,'available',v_user is not null and v_version.published and v_version.status='PUBLISHED','content_status',coalesce(v_version.status,'CONTENT_REQUIRED'),'reading_complete',v_read=4,'reading_required',false,'read_parts',v_read,'required_parts',0,'question_count',coalesce(v_version.question_count,10),'pass_score',coalesce(v_version.pass_score,7),'best_score',least(coalesce(v_best,0),10),'passed',coalesce(v_passed,false),'unlimited_retries',true);
end;$$;

create or replace function public.archive_i_quiz_start() returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_version public.archive_quiz_versions%rowtype;v_count integer;v_attempt uuid;v_order uuid[];v_questions jsonb;
begin
 if v_user is null then raise exception 'Требуется авторизация' using errcode='42501';end if;
 select * into v_version from public.archive_quiz_versions where quiz_key='archive-i' and published and status='PUBLISHED' order by version desc limit 1;
 if not found then raise exception 'CONTENT REQUIRED' using errcode='55000';end if;
 select count(*) into v_count from public.archive_quiz_questions where quiz_version_id=v_version.id and published;
 if v_count<>v_version.question_count then raise exception 'CONTENT REQUIRED' using errcode='55000';end if;
 select id,question_order into v_attempt,v_order from public.archive_quiz_attempts where user_id=v_user and quiz_version_id=v_version.id and status='STARTED' for update;
 if v_attempt is null then
  select array_agg(id order by random()) into v_order from public.archive_quiz_questions where quiz_version_id=v_version.id and published;
  insert into public.archive_quiz_attempts(user_id,quiz_version_id,question_order) values(v_user,v_version.id,v_order) returning id into v_attempt;
 end if;
 select jsonb_agg(jsonb_build_object('id',q.id,'position',o.ordinality,'prompt',q.prompt,'options',q.options) order by o.ordinality) into v_questions from unnest(v_order) with ordinality o(id,ordinality) join public.archive_quiz_questions q on q.id=o.id;
 return jsonb_build_object('attempt_id',v_attempt,'questions',v_questions,'question_count',v_version.question_count,'pass_score',v_version.pass_score,'unlimited_retries',true);
end;$$;

create or replace function public.archive_i_quiz_submit(p_attempt_id uuid,p_answers jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_attempt public.archive_quiz_attempts%rowtype;v_score smallint;v_total smallint;v_pass_score smallint;v_pass boolean;v_best smallint;v_first_pass boolean:=false;v_points bigint;v_level smallint;
begin
 if v_user is null then raise exception 'Требуется авторизация' using errcode='42501';end if;
 select * into v_attempt from public.archive_quiz_attempts where id=p_attempt_id and user_id=v_user for update;
 if not found then raise exception 'Попытка не найдена' using errcode='22023';end if;
 v_total:=cardinality(v_attempt.question_order);
 if jsonb_typeof(p_answers)<>'array' or jsonb_array_length(p_answers)<>v_total then raise exception 'Нужно ответить на все вопросы' using errcode='22023';end if;
 if v_attempt.status<>'STARTED' then raise exception 'Попытка уже завершена' using errcode='55000';end if;
 if v_attempt.started_at<now()-interval '2 hours' then update public.archive_quiz_attempts set status='EXPIRED' where id=p_attempt_id;raise exception 'Время попытки истекло' using errcode='55000';end if;
 if exists(select 1 from jsonb_array_elements(p_answers) a where not(a?'question_id' and a?'option_index') or (a->>'question_id')::uuid<>all(v_attempt.question_order) or (a->>'option_index')!~'^[0-9]+$') or(select count(distinct a->>'question_id') from jsonb_array_elements(p_answers) a)<>v_total then raise exception 'Некорректный набор ответов' using errcode='22023';end if;
 select count(*)::smallint into v_score from jsonb_array_elements(p_answers) a join public.archive_quiz_questions q on q.id=(a->>'question_id')::uuid where q.quiz_version_id=v_attempt.quiz_version_id and q.published and q.correct_option=(a->>'option_index')::smallint;
 select pass_score into v_pass_score from public.archive_quiz_versions where id=v_attempt.quiz_version_id;
 v_pass:=v_score>=v_pass_score;
 update public.archive_quiz_attempts set status='SUBMITTED',score=v_score,passed=v_pass,submitted_at=now(),answers=p_answers where id=p_attempt_id;
 insert into public.archive_progress(user_id) values(v_user) on conflict(user_id) do nothing;
 update public.archive_progress set best_archive_i_test_score=greatest(best_archive_i_test_score,v_score),archive_i_test_passed=archive_i_test_passed or v_pass,updated_at=now() where user_id=v_user returning best_archive_i_test_score into v_best;
 if v_pass then v_first_pass:=public.archive_award_achievement_internal(v_user,'ARCHIVE_I_TEST_PASSED','system','quiz:archive-i:passed',jsonb_build_object('score',v_score),null);end if;
 if v_score>=9 then perform public.archive_award_achievement_internal(v_user,'ARCHIVE_I_TEST_EXPERT','system','quiz:archive-i:expert',jsonb_build_object('score',v_score),null);end if;
 if v_score=10 then perform public.archive_award_achievement_internal(v_user,'ARCHIVE_I_TEST_PERFECT','system','quiz:archive-i:perfect',jsonb_build_object('score',v_score),null);end if;
 select p.points,a.archive_level into v_points,v_level from public.archive_progress p join public.account_access a on a.user_id=p.user_id where p.user_id=v_user;
 return jsonb_build_object('score',v_score,'total',v_total,'pass_score',v_pass_score,'passed',v_pass,'best_score',least(v_best,10),'points_awarded',v_first_pass,'points',v_points,'archive_level',v_level);
end;$$;

revoke all on function public.archive_i_quiz_status(),public.archive_i_quiz_start(),public.archive_i_quiz_submit(uuid,jsonb) from public,anon,authenticated;
grant execute on function public.archive_i_quiz_status() to anon,authenticated;
grant execute on function public.archive_i_quiz_start(),public.archive_i_quiz_submit(uuid,jsonb) to authenticated;

commit;
