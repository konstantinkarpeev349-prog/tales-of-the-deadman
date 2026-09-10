begin;

create table if not exists public.user_warnings(
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  issued_by uuid not null references auth.users(id),
  reason text not null check(char_length(reason) between 3 and 2000),
  created_at timestamptz not null default now(),
  seen_at timestamptz
);
create index if not exists user_warnings_recipient_unseen on public.user_warnings(user_id,seen_at,created_at);
alter table public.user_warnings enable row level security;
drop policy if exists "read own warnings" on public.user_warnings;
create policy "read own warnings" on public.user_warnings for select to authenticated using(user_id=auth.uid());
drop policy if exists "ack own warnings" on public.user_warnings;
create policy "ack own warnings" on public.user_warnings for update to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
grant select,update on public.user_warnings to authenticated;
revoke insert,delete on public.user_warnings from anon,authenticated;

create or replace function public.admin_warning_users(p_search text default '')
returns table(user_id uuid,display_name text,archive_level smallint,selected_faction text,is_todm_team boolean,is_banned boolean)
language plpgsql security definer set search_path='' stable as $$
begin
 if not exists(select 1 from public.account_access a where a.user_id=auth.uid() and a.is_admin and not a.is_banned) then raise exception 'Доступ только для администратора' using errcode='42501'; end if;
 return query select p.user_id,p.display_name::text,a.archive_level,p.selected_faction::text,a.is_todm_team,a.is_banned
 from public.profiles p join public.account_access a on a.user_id=p.user_id
 where p.user_id<>auth.uid() and p.display_name::text ilike '%'||left(btrim(coalesce(p_search,'')),100)||'%'
 order by p.display_name limit 50;
end;$$;

create or replace function public.admin_warning_send(p_user_id uuid,p_reason text)
returns void language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from public.account_access a where a.user_id=auth.uid() and a.is_admin and not a.is_banned) then raise exception 'Доступ только для администратора' using errcode='42501'; end if;
 if p_user_id=auth.uid() then raise exception 'Нельзя отправить предупреждение самому себе'; end if;
 if not exists(select 1 from public.account_access a where a.user_id=p_user_id) then raise exception 'Пользователь не найден'; end if;
 if char_length(btrim(coalesce(p_reason,''))) not between 3 and 2000 then raise exception 'Укажите причину от 3 до 2000 символов'; end if;
 insert into public.user_warnings(user_id,issued_by,reason) values(p_user_id,auth.uid(),btrim(p_reason));
end;$$;

revoke all on function public.admin_warning_users(text),public.admin_warning_send(uuid,text) from public,anon;
grant execute on function public.admin_warning_users(text),public.admin_warning_send(uuid,text) to authenticated;
commit;
