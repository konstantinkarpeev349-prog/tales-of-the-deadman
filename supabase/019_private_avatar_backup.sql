begin;
create table if not exists public.avatar_moderation_backup(
 user_id uuid primary key references auth.users(id) on delete cascade,
 avatar_url text not null,
 hidden_at timestamptz not null default now(),
 hidden_by uuid not null references auth.users(id)
);
alter table public.avatar_moderation_backup enable row level security;
revoke all on public.avatar_moderation_backup from anon,authenticated;
insert into public.avatar_moderation_backup(user_id,avatar_url,hidden_by)
select p.user_id,p.hidden_avatar_url,auth.uid() from public.profiles p
where p.hidden_avatar_url is not null
on conflict(user_id) do update set avatar_url=excluded.avatar_url,hidden_at=now(),hidden_by=excluded.hidden_by;
alter table public.profiles drop column if exists hidden_avatar_url;

create or replace function public.admin_set_avatar_hidden(p_user_id uuid,p_hidden boolean)
returns void language plpgsql security definer set search_path='' as $$
declare old_row public.account_access;new_row public.account_access;stored_url text;
begin
 if not exists(select 1 from public.account_access a where a.user_id=auth.uid() and not a.is_banned and (a.is_admin or (a.is_todm_team and a.archive_level>=4))) then raise exception 'Доступ только для администратора или сотрудника IV ранга' using errcode='42501'; end if;
 select * into old_row from public.account_access where user_id=p_user_id for update;
 if not found then raise exception 'Пользователь не найден'; end if;
 if old_row.is_admin or p_user_id=auth.uid() then raise exception 'Скрытие портрета администратора или самого себя запрещено'; end if;
 if coalesce(p_hidden,false) then
  select avatar_url into stored_url from public.profiles where user_id=p_user_id for update;
  if stored_url is not null then insert into public.avatar_moderation_backup(user_id,avatar_url,hidden_by) values(p_user_id,stored_url,auth.uid()) on conflict(user_id) do update set avatar_url=excluded.avatar_url,hidden_at=now(),hidden_by=excluded.hidden_by; end if;
  update public.profiles set avatar_url=null,updated_at=now() where user_id=p_user_id;
 else
  select avatar_url into stored_url from public.avatar_moderation_backup where user_id=p_user_id;
  if stored_url is not null then update public.profiles set avatar_url=stored_url,updated_at=now() where user_id=p_user_id; delete from public.avatar_moderation_backup where user_id=p_user_id; end if;
 end if;
 update public.account_access set avatar_hidden=coalesce(p_hidden,false),updated_at=now() where user_id=p_user_id returning * into new_row;
 insert into public.admin_access_log(actor,target,before_state,after_state) values(auth.uid(),p_user_id,to_jsonb(old_row),to_jsonb(new_row));
end;$$;
commit;
