begin;

create table if not exists public.faction_leader_notifications(
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  faction public.todm_faction not null,
  created_at timestamptz not null default now(),
  seen_at timestamptz
);
create index if not exists faction_leader_notifications_user_unseen on public.faction_leader_notifications(user_id,seen_at);
alter table public.faction_leader_notifications enable row level security;
drop policy if exists "read own leader notifications" on public.faction_leader_notifications;
create policy "read own leader notifications" on public.faction_leader_notifications for select to authenticated using(user_id=auth.uid());
drop policy if exists "ack own leader notifications" on public.faction_leader_notifications;
create policy "ack own leader notifications" on public.faction_leader_notifications for update to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
grant select,update on public.faction_leader_notifications to authenticated;
revoke insert,delete on public.faction_leader_notifications from anon,authenticated;

create or replace function public.admin_set_faction_leader(p_faction public.todm_faction,p_user_id uuid default null)
returns void language plpgsql security definer set search_path='' as $$
declare previous_leader uuid;
begin
 if not exists(select 1 from public.account_access a where a.user_id=auth.uid() and a.is_admin and not a.is_banned) then raise exception 'Доступ только для администратора' using errcode='42501'; end if;
 select fl.user_id into previous_leader from public.faction_leaders fl where fl.faction=p_faction;
 if p_user_id is not null and not exists(select 1 from public.profiles p join public.account_access a on a.user_id=p.user_id where p.user_id=p_user_id and p.selected_faction=p_faction and not a.is_banned) then raise exception 'Пользователь должен состоять в выбранной фракции'; end if;
 delete from public.faction_leaders where faction=p_faction or (p_user_id is not null and user_id=p_user_id);
 if p_user_id is not null then
  insert into public.faction_leaders(faction,user_id,appointed_by) values(p_faction,p_user_id,auth.uid());
  if previous_leader is distinct from p_user_id then insert into public.faction_leader_notifications(user_id,faction) values(p_user_id,p_faction); end if;
 end if;
end;$$;

insert into public.faction_leader_notifications(user_id,faction)
select fl.user_id,fl.faction from public.faction_leaders fl
where not exists(select 1 from public.faction_leader_notifications n where n.user_id=fl.user_id and n.faction=fl.faction);

commit;
