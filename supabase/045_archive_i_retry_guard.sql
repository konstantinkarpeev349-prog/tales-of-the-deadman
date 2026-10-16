-- Archive I retry protection. Apply only after verifying the active quiz version.
-- This migration does not alter existing attempts, scores, awards or access levels.
begin;

create or replace function public.archive_i_quiz_retry_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_retry_at timestamptz;
begin
  if new.status <> 'STARTED' then
    raise exception 'Некорректное состояние попытки' using errcode = '22023';
  end if;

  -- A concurrent submission can still be STARTED in this transaction's snapshot.
  -- Deny a second insert in both the old and newly submitted states.
  if exists (
    select 1 from public.archive_quiz_attempts
    where user_id = new.user_id
      and quiz_version_id = new.quiz_version_id
      and status = 'STARTED'
  ) then
    raise exception 'У вас уже есть незавершённая попытка' using errcode = '55000';
  end if;

  select max(submitted_at) + interval '24 hours'
    into v_retry_at
  from public.archive_quiz_attempts
  where user_id = new.user_id
    and quiz_version_id = new.quiz_version_id
    and status = 'SUBMITTED';

  if v_retry_at > now() then
    raise exception 'Повторная попытка доступна через 24 часа после предыдущей'
      using errcode = '55000';
  end if;
  return new;
end;
$$;

revoke all on function public.archive_i_quiz_retry_guard() from public, anon, authenticated;
drop trigger if exists archive_i_quiz_retry_guard on public.archive_quiz_attempts;
create trigger archive_i_quiz_retry_guard
  before insert on public.archive_quiz_attempts
  for each row execute function public.archive_i_quiz_retry_guard();

create or replace function public.archive_i_quiz_status()
returns jsonb
language plpgsql
security definer
stable
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_version public.archive_quiz_versions%rowtype;
  v_read integer := 0;
  v_best smallint := 0;
  v_passed boolean := false;
  v_has_open boolean := false;
  v_retry_at timestamptz;
begin
  if v_user is not null then
    select count(*) into v_read
    from public.user_achievements
    where user_id = v_user and is_active
      and achievement_code in ('READ_PROLOGUE', 'READ_CHAPTER_1', 'READ_CHAPTER_2', 'READ_CHAPTER_3');
    select best_archive_i_test_score, archive_i_test_passed
      into v_best, v_passed
    from public.archive_progress where user_id = v_user;
  end if;

  select * into v_version
  from public.archive_quiz_versions
  where quiz_key = 'archive-i'
  order by version desc limit 1;

  if v_user is not null and v_version.id is not null then
    select exists (
      select 1 from public.archive_quiz_attempts
      where user_id = v_user and quiz_version_id = v_version.id and status = 'STARTED'
    ) into v_has_open;
    if not v_has_open then
      select max(submitted_at) + interval '24 hours' into v_retry_at
      from public.archive_quiz_attempts
      where user_id = v_user and quiz_version_id = v_version.id and status = 'SUBMITTED';
      if v_retry_at <= now() then v_retry_at := null; end if;
    end if;
  end if;

  return jsonb_build_object(
    'authenticated', v_user is not null,
    'available', v_user is not null and v_version.published and v_version.status = 'PUBLISHED' and v_retry_at is null,
    'content_status', coalesce(v_version.status, 'CONTENT_REQUIRED'),
    'reading_complete', v_read = 4,
    'reading_required', false,
    'read_parts', v_read,
    'required_parts', 0,
    'question_count', coalesce(v_version.question_count, 10),
    'pass_score', coalesce(v_version.pass_score, 7),
    'best_score', least(coalesce(v_best, 0), 10),
    'passed', coalesce(v_passed, false),
    'unlimited_retries', true,
    'retry_at', v_retry_at
  );
end;
$$;

create or replace function public.archive_i_quiz_start()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_version public.archive_quiz_versions%rowtype;
  v_count integer;
  v_attempt uuid;
  v_order uuid[];
  v_started_at timestamptz;
  v_questions jsonb;
begin
  if v_user is null then
    raise exception 'Требуется авторизация' using errcode = '42501';
  end if;

  select * into v_version
  from public.archive_quiz_versions
  where quiz_key = 'archive-i' and published and status = 'PUBLISHED'
  order by version desc limit 1;
  if not found then
    raise exception 'CONTENT REQUIRED' using errcode = '55000';
  end if;

  select count(*) into v_count
  from public.archive_quiz_questions
  where quiz_version_id = v_version.id and published;
  if v_count <> v_version.question_count then
    raise exception 'CONTENT REQUIRED' using errcode = '55000';
  end if;

  select id, question_order, started_at
    into v_attempt, v_order, v_started_at
  from public.archive_quiz_attempts
  where user_id = v_user and quiz_version_id = v_version.id and status = 'STARTED'
  for update;

  if v_attempt is not null and v_started_at < now() - interval '2 hours' then
    update public.archive_quiz_attempts
    set status = 'EXPIRED'
    where id = v_attempt;
    v_attempt := null;
  end if;

  if v_attempt is null then
    select array_agg(id order by random()) into v_order
    from public.archive_quiz_questions
    where quiz_version_id = v_version.id and published;
    -- The INSERT trigger enforces a 24-hour delay after a submitted attempt.
    insert into public.archive_quiz_attempts(user_id, quiz_version_id, question_order)
    values (v_user, v_version.id, v_order)
    returning id into v_attempt;
  end if;

  select jsonb_agg(
    jsonb_build_object('id', q.id, 'position', o.ordinality, 'prompt', q.prompt, 'options', q.options)
    order by o.ordinality
  ) into v_questions
  from unnest(v_order) with ordinality o(id, ordinality)
  join public.archive_quiz_questions q on q.id = o.id;

  return jsonb_build_object(
    'attempt_id', v_attempt,
    'questions', v_questions,
    'question_count', v_version.question_count,
    'pass_score', v_version.pass_score,
    'unlimited_retries', true
  );
end;
$$;

revoke all on function public.archive_i_quiz_status(), public.archive_i_quiz_start() from public, anon, authenticated;
grant execute on function public.archive_i_quiz_status() to anon, authenticated;
grant execute on function public.archive_i_quiz_start() to authenticated;

commit;
