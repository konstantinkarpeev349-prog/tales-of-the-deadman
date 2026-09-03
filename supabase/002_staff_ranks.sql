-- Run after schema.sql. Rank V is bound to the existing owner's UUID,
-- never to an editable nickname or email. No admin permissions are granted here.
begin;

alter table public.account_access drop constraint if exists account_access_archive_level_check;
alter table public.account_access add constraint account_access_archive_level_check
  check (archive_level between 0 and 5);

create or replace function public.enforce_staff_rank()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.archive_level = 5 and new.user_id <> '8cd4aa8b-a90a-4e67-9112-9dbc170c27bc'::uuid then
    raise exception 'Rank V is reserved for the project owner' using errcode = '23514';
  end if;
  if new.user_id = '8cd4aa8b-a90a-4e67-9112-9dbc170c27bc'::uuid then
    new.archive_level := 5;
  elsif tg_op = 'UPDATE' then
    if new.archive_level < 4 and old.archive_level >= 4 then
      new.is_todm_team := false;
      new.full_access := false;
    elsif new.is_todm_team and new.archive_level < 4 then
      new.archive_level := 4;
    end if;
  elsif new.is_todm_team and new.archive_level < 4 then
    new.archive_level := 4;
  end if;
  if new.archive_level >= 4 then
    new.is_todm_team := true;
    new.full_access := true;
  end if;
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists enforce_staff_rank on public.account_access;
create trigger enforce_staff_rank before insert or update on public.account_access
for each row execute function public.enforce_staff_rank();

update public.account_access
set archive_level = case when user_id = '8cd4aa8b-a90a-4e67-9112-9dbc170c27bc'::uuid then 5 else 4 end
where is_todm_team or user_id = '8cd4aa8b-a90a-4e67-9112-9dbc170c27bc'::uuid;

alter table public.account_access drop constraint if exists account_access_owner_rank_check;
alter table public.account_access add constraint account_access_owner_rank_check
check ((archive_level = 5) = (user_id = '8cd4aa8b-a90a-4e67-9112-9dbc170c27bc'::uuid));
alter table public.account_access drop constraint if exists account_access_staff_rank_check;
alter table public.account_access add constraint account_access_staff_rank_check
check (is_todm_team = (archive_level >= 4) and (archive_level < 4 or full_access));

-- Purchase/support thresholds intentionally remain limited to I–III.
-- Existing RLS still rejects banned accounts, including staff and the owner.
commit;
