-- Let readers take Archive I without on-site reading markers and retry without limits.
begin;

create or replace function public.archive_i_quiz_status() returns jsonb language plpgsql security definer stable set search_path='' as $$
declare v_user uuid:=auth.uid();v_version public.archive_quiz_versions%rowtype;v_read integer:=0;v_best smallint:=0;v_passed boolean:=false;
begin
 if v_user is not null then
  select count(*) into v_read from public.user_achievements where user_id=v_user and is_active and achievement_code in('READ_PROLOGUE','READ_CHAPTER_1','READ_CHAPTER_2','READ_CHAPTER_3');
  select best_archive_i_test_score,archive_i_test_passed into v_best,v_passed from public.archive_progress where user_id=v_user;
 end if;
 select * into v_version from public.archive_quiz_versions where quiz_key='archive-i' order by version desc limit 1;
 return jsonb_build_object('authenticated',v_user is not null,'available',v_user is not null and v_version.published and v_version.status='PUBLISHED',
  'content_status',coalesce(v_version.status,'CONTENT_REQUIRED'),'reading_complete',v_read=4,'reading_required',false,'read_parts',v_read,'required_parts',0,
  'question_count',coalesce(v_version.question_count,12),'pass_score',coalesce(v_version.pass_score,8),'best_score',coalesce(v_best,0),'passed',coalesce(v_passed,false),'unlimited_retries',true);
end;$$;

create or replace function public.archive_i_quiz_start() returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_version public.archive_quiz_versions%rowtype;v_count integer;v_attempt uuid;v_order uuid[];v_questions jsonb;
begin
 if v_user is null then raise exception 'Требуется авторизация' using errcode='42501';end if;
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
 return jsonb_build_object('attempt_id',v_attempt,'questions',v_questions,'question_count',12,'pass_score',v_version.pass_score,'unlimited_retries',true);
end;$$;

revoke all on function public.archive_i_quiz_status(),public.archive_i_quiz_start() from public,anon,authenticated;
grant execute on function public.archive_i_quiz_status() to anon,authenticated;
grant execute on function public.archive_i_quiz_start() to authenticated;

commit;
