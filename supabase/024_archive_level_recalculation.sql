-- Stage 4: trusted Archive I-III level recalculation.
-- Automatic promotion is enabled. A calculated downgrade is held for staff
-- review and never silently removes access. TODM IV/V are outside this flow.
begin;

alter table public.archive_progress
  add column if not exists calculated_archive_level smallint not null default 0,
  add column if not exists level_review_required boolean not null default false,
  add column if not exists level_review_reason text,
  add column if not exists level_calculated_at timestamptz;

alter table public.archive_progress drop constraint if exists archive_progress_calculated_level_check;
alter table public.archive_progress add constraint archive_progress_calculated_level_check
  check (calculated_archive_level between 0 and 3);

create index if not exists archive_progress_level_review_idx
  on public.archive_progress(level_review_required,updated_at desc)
  where level_review_required;

create or replace function public.archive_calculate_reader_level(
  p_points bigint,
  p_archive_i_test_passed boolean
) returns smallint
language plpgsql
immutable
set search_path = ''
as $$
begin
  -- Archive I is the entry prerequisite for every reader level.
  if not coalesce(p_archive_i_test_passed,false) or coalesce(p_points,0) < 120 then
    return 0;
  elsif p_points >= 500 then
    return 3;
  elsif p_points >= 300 then
    return 2;
  else
    return 1;
  end if;
end;
$$;

create or replace function public.archive_recalculate_level_internal(p_user_id uuid)
returns smallint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_access public.account_access%rowtype;
  v_progress public.archive_progress%rowtype;
  v_calculated smallint;
  v_previous smallint;
begin
  if p_user_id is null then
    raise exception 'Пользователь не указан' using errcode='22023';
  end if;

  insert into public.archive_progress(user_id) values(p_user_id)
  on conflict(user_id) do nothing;

  select * into v_access from public.account_access where user_id=p_user_id for update;
  if not found then
    raise exception 'Профиль доступа не найден' using errcode='22023';
  end if;
  select * into v_progress from public.archive_progress where user_id=p_user_id for update;

  v_calculated := public.archive_calculate_reader_level(v_progress.points,v_progress.archive_i_test_passed);
  v_previous := v_access.archive_level;

  -- IV/V are staff/author statuses and cannot be earned or removed by OA.
  if coalesce(v_access.is_todm_team,false)
     or coalesce(v_access.is_author,false)
     or v_access.archive_level >= 4 then
    update public.archive_progress
       set calculated_archive_level=v_calculated,
           level_review_required=false,
           level_review_reason=null,
           level_calculated_at=now(),updated_at=now()
     where user_id=p_user_id;
    return v_calculated;
  end if;

  if v_calculated > v_previous then
    update public.account_access
       set archive_level=v_calculated,updated_at=now()
     where user_id=p_user_id;

    update public.archive_progress
       set calculated_archive_level=v_calculated,
           level_review_required=false,
           level_review_reason=null,
           level_calculated_at=now(),updated_at=now()
     where user_id=p_user_id;

    perform public.archive_queue_notification_internal(
      p_user_id,'archive_level','archive-level-'||v_calculated::text,
      'Новый уровень Архива',
      'Ваш уровень доступа повышен до Архива '||v_calculated::text||'.',
      null,null,v_calculated,
      jsonb_build_object('previous_level',v_previous,'source','automatic_recalculation')
    );

    insert into public.archive_audit_log(actor_id,target_user_id,action,object_type,object_key,before_state,after_state,reason,metadata)
    values(null,p_user_id,'ARCHIVE_LEVEL_AUTO_PROMOTED','account_access',p_user_id::text,
      jsonb_build_object('archive_level',v_previous),jsonb_build_object('archive_level',v_calculated),
      'Автоматический пересчёт по ОА и Испытанию Архива I',
      jsonb_build_object('points',v_progress.points,'archive_i_test_passed',v_progress.archive_i_test_passed));
  elsif v_calculated < v_previous then
    -- Never revoke reader access automatically: queue it for a later staff decision.
    update public.archive_progress
       set calculated_archive_level=v_calculated,
           level_review_required=true,
           level_review_reason='Расчётный уровень ниже действующего; требуется проверка сотрудником TODM',
           level_calculated_at=now(),updated_at=now()
     where user_id=p_user_id;
  else
    update public.archive_progress
       set calculated_archive_level=v_calculated,
           level_review_required=false,
           level_review_reason=null,
           level_calculated_at=now(),updated_at=now()
     where user_id=p_user_id;
  end if;

  return v_calculated;
end;
$$;

create or replace function public.archive_recalculate_level_on_progress()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.archive_recalculate_level_internal(new.user_id);
  return new;
end;
$$;

drop trigger if exists archive_recalculate_level_after_progress on public.archive_progress;
create trigger archive_recalculate_level_after_progress
after insert or update of points,archive_i_test_passed on public.archive_progress
for each row execute function public.archive_recalculate_level_on_progress();

-- Establish the calculated state without changing any existing access level.
-- Legacy reader levels that do not match current verified progress are marked
-- for the separately approved reset/review stage.
update public.archive_progress p
   set calculated_archive_level=public.archive_calculate_reader_level(p.points,p.archive_i_test_passed),
       level_review_required=case
         when not (coalesce(a.is_todm_team,false) or coalesce(a.is_author,false) or a.archive_level>=4)
          and public.archive_calculate_reader_level(p.points,p.archive_i_test_passed) < a.archive_level
         then true else false end,
       level_review_reason=case
         when not (coalesce(a.is_todm_team,false) or coalesce(a.is_author,false) or a.archive_level>=4)
          and public.archive_calculate_reader_level(p.points,p.archive_i_test_passed) < a.archive_level
         then 'Наследованный уровень выше подтверждённого прогресса; требуется миграция по утверждённому плану'
         else null end,
       level_calculated_at=now(),updated_at=now()
  from public.account_access a
 where a.user_id=p.user_id;

revoke all on function public.archive_calculate_reader_level(bigint,boolean),
  public.archive_recalculate_level_internal(uuid),
  public.archive_recalculate_level_on_progress()
from public,anon,authenticated;

commit;
