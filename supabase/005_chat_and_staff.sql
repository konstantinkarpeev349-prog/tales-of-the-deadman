begin;
create table public.chat_messages (
 id bigint generated always as identity primary key,
 user_id uuid not null references auth.users(id),
 body text not null check(char_length(btrim(body)) between 1 and 2000),
 created_at timestamptz not null default now(),
 deleted_at timestamptz, deleted_by uuid references auth.users(id)
);
alter table public.chat_messages enable row level security;
revoke all on public.chat_messages from anon,authenticated;
create index chat_messages_user_created on public.chat_messages(user_id,created_at desc);

create or replace function public.chat_list(p_before bigint default null)
returns table(id text,user_id uuid,body text,created_at timestamptz,deleted boolean,display_name text,avatar_url text,selected_faction text,archive_level smallint,is_todm_team boolean,is_author boolean)
language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from public.account_access a where a.user_id=auth.uid() and not a.is_banned) then raise exception 'Войдите в аккаунт. Заблокированным пользователям чат недоступен.' using errcode='42501'; end if;
 return query select m.id::text,m.user_id,case when m.deleted_at is null then m.body else null end,m.created_at,m.deleted_at is not null,p.display_name::text,p.avatar_url,p.selected_faction::text,a.archive_level,a.is_todm_team,a.is_author
 from public.chat_messages m left join public.profiles p on p.user_id=m.user_id left join public.account_access a on a.user_id=m.user_id
 where p_before is null or m.id<p_before order by m.id desc limit 60;
end;$$;

create or replace function public.chat_send(p_body text)
returns void language plpgsql security definer set search_path='' as $$
begin
 perform 1 from public.account_access where user_id=auth.uid() and not is_banned for update;
 if not found then raise exception 'Нет доступа к чату' using errcode='42501'; end if;
 if p_body is null or char_length(btrim(p_body)) not between 1 and 2000 then raise exception 'Сообщение должно содержать от 1 до 2000 символов'; end if;
 if exists(select 1 from public.chat_messages where user_id=auth.uid() and created_at>clock_timestamp()-interval '2 seconds') then raise exception 'Подождите две секунды перед следующим сообщением'; end if;
 insert into public.chat_messages(user_id,body) values(auth.uid(),btrim(p_body));
end;$$;

create or replace function public.chat_delete(p_id bigint)
returns void language plpgsql security definer set search_path='' as $$
begin
 perform 1 from public.account_access where user_id=auth.uid() and not is_banned and (is_admin or is_todm_team) for update;
 if not found then raise exception 'Удалять сообщения могут только администратор и TODM' using errcode='42501'; end if;
 update public.chat_messages set deleted_at=now(),deleted_by=auth.uid() where id=p_id and deleted_at is null;
end;$$;

create or replace function public.staff_list_users(p_search text default '',p_offset integer default 0)
returns table(user_id uuid,display_name text,archive_level smallint,protected boolean,updated_at timestamptz)
language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from public.account_access a where a.user_id=auth.uid() and not a.is_banned and (a.is_admin or a.is_todm_team)) then raise exception 'Доступ только для TODM' using errcode='42501'; end if;
 return query select a.user_id,coalesce(p.display_name::text,'Читатель'),a.archive_level,(a.is_admin or a.is_author or a.is_todm_team or a.archive_level>=4),a.updated_at
 from public.account_access a left join public.profiles p on p.user_id=a.user_id
 where coalesce(p.display_name::text,'') ilike '%'||left(coalesce(p_search,''),100)||'%'
 order by p.created_at desc,a.user_id limit 50 offset greatest(coalesce(p_offset,0),0);
end;$$;

create or replace function public.staff_set_rank(p_user_id uuid,p_level integer,p_updated_at timestamptz)
returns void language plpgsql security definer set search_path='' as $$
declare old_row public.account_access; new_row public.account_access;
begin
 perform 1 from public.account_access where user_id=auth.uid() and not is_banned and (is_admin or is_todm_team) for update;
 if not found then raise exception 'Доступ только для TODM' using errcode='42501'; end if;
 if p_level is null or p_level not between 0 and 3 then raise exception 'Разрешены только уровни 0–III'; end if;
 select * into old_row from public.account_access where user_id=p_user_id for update;
 if not found then raise exception 'Пользователь не найден'; end if;
 if old_row.is_admin or old_row.is_author or old_row.is_todm_team or old_row.archive_level>=4 then raise exception 'Изменение сотрудников и владельца недоступно'; end if;
 if p_updated_at is null or p_updated_at<>old_row.updated_at then raise exception 'Данные изменились. Обновите список.'; end if;
 update public.account_access set archive_level=p_level,updated_at=now() where user_id=p_user_id returning * into new_row;
 insert into public.admin_access_log(actor,target,before_state,after_state) values(auth.uid(),p_user_id,to_jsonb(old_row),to_jsonb(new_row));
end;$$;

revoke all on function public.chat_list(bigint),public.chat_send(text),public.chat_delete(bigint),public.staff_list_users(text,integer),public.staff_set_rank(uuid,integer,timestamptz) from public,anon;
grant execute on function public.chat_list(bigint),public.chat_send(text),public.chat_delete(bigint),public.staff_list_users(text,integer),public.staff_set_rank(uuid,integer,timestamptz) to authenticated;
commit;
