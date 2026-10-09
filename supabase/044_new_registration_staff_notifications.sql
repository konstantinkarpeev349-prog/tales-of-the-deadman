-- Notify TODM IV/V accounts once for every newly created profile.
create or replace function public.notify_staff_new_registration()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  recipient record;
begin
  for recipient in
    select a.user_id
    from public.account_access a
    where (a.is_todm_team or a.is_author)
      and not a.is_banned
      and a.user_id <> new.user_id
  loop
    perform public.archive_queue_notification_internal(
      recipient.user_id,
      'system',
      'new-registration:' || new.user_id::text,
      'НОВЫЙ ПОЛЬЗОВАТЕЛЬ TODM',
      'В Архиве зарегистрирован пользователь «' || new.display_name::text || '».',
      null, null, null,
      jsonb_build_object('registered_user_id', new.user_id)
    );
  end loop;
  return new;
end;
$$;

drop trigger if exists notify_staff_new_registration on public.profiles;
create trigger notify_staff_new_registration
after insert on public.profiles
for each row execute function public.notify_staff_new_registration();

revoke all on function public.notify_staff_new_registration() from public, anon, authenticated;
