begin;

create table if not exists public.faction_leaders(
  faction public.todm_faction primary key,
  user_id uuid not null unique references auth.users(id) on delete cascade,
  appointed_by uuid references auth.users(id),
  appointed_at timestamptz not null default now()
);
alter table public.faction_leaders enable row level security;
drop policy if exists "active users read faction leaders" on public.faction_leaders;
create policy "active users read faction leaders" on public.faction_leaders for select to authenticated
using(exists(select 1 from public.account_access a where a.user_id=auth.uid() and not a.is_banned));
grant select on public.faction_leaders to authenticated;
revoke insert,update,delete on public.faction_leaders from anon,authenticated;

create table if not exists public.faction_read_state(
  user_id uuid not null references auth.users(id) on delete cascade,
  faction public.todm_faction not null,
  read_at timestamptz not null default now(),
  primary key(user_id,faction)
);
alter table public.faction_read_state enable row level security;
drop policy if exists "read own faction state" on public.faction_read_state;
create policy "read own faction state" on public.faction_read_state for select to authenticated using(user_id=auth.uid());
grant select on public.faction_read_state to authenticated;
revoke insert,update,delete on public.faction_read_state from anon,authenticated;

create or replace function public.faction_can_access(p_faction public.todm_faction)
returns boolean language sql security definer set search_path='' stable as $$
 select exists(select 1 from public.account_access a join public.profiles p on p.user_id=a.user_id
 where a.user_id=auth.uid() and not a.is_banned and (a.is_todm_team or a.is_admin or p.selected_faction=p_faction));
$$;

drop function if exists public.faction_message_list(bigint);
create function public.faction_message_list(p_before bigint default null,p_faction public.todm_faction default null)
returns table(id text,user_id uuid,body text,created_at timestamptz,deleted boolean,display_name text,avatar_url text,frame_code text,archive_level smallint,is_todm_team boolean,is_author boolean,is_supporter boolean,is_leader boolean)
language plpgsql security definer set search_path='' stable as $$
declare v_faction public.todm_faction;
begin
 perform public.assert_active_user();
 select case when (a.is_todm_team or a.is_admin) and p_faction is not null then p_faction else p.selected_faction end
 into v_faction from public.profiles p join public.account_access a on a.user_id=p.user_id where p.user_id=auth.uid();
 if v_faction is null then raise exception 'Сначала выберите фракцию'; end if;
 if not public.faction_can_access(v_faction) then raise exception 'Чат фракции недоступен' using errcode='42501'; end if;
 return query select m.id::text,m.user_id,case when m.deleted_at is null then m.body else null end,m.created_at,m.deleted_at is not null,
 p.display_name::text,p.avatar_url,p.active_avatar_frame,a.archive_level,a.is_todm_team,a.is_author,a.is_supporter,(fl.user_id is not null)
 from public.faction_messages m join public.profiles p on p.user_id=m.user_id join public.account_access a on a.user_id=m.user_id
 left join public.faction_leaders fl on fl.faction=m.faction and fl.user_id=m.user_id
 where m.faction=v_faction and (p_before is null or m.id<p_before) order by m.id desc limit 50;
end;$$;

drop function if exists public.faction_message_send(text);
create function public.faction_message_send(p_body text,p_faction public.todm_faction default null) returns void language plpgsql security definer set search_path='' as $$
declare v_faction public.todm_faction;
begin
 perform public.assert_active_user();
 select case when (a.is_todm_team or a.is_admin) and p_faction is not null then p_faction else p.selected_faction end
 into v_faction from public.profiles p join public.account_access a on a.user_id=p.user_id where p.user_id=auth.uid();
 if v_faction is null then raise exception 'Сначала выберите фракцию'; end if;
 if not public.faction_can_access(v_faction) then raise exception 'Чат фракции недоступен' using errcode='42501'; end if;
 if char_length(btrim(coalesce(p_body,''))) not between 1 and 2000 then raise exception 'Сообщение должно содержать от 1 до 2000 символов'; end if;
 if exists(select 1 from public.faction_messages m where m.user_id=auth.uid() and m.created_at>clock_timestamp()-interval '2 seconds') then raise exception 'Подождите две секунды'; end if;
 insert into public.faction_messages(faction,user_id,body) values(v_faction,auth.uid(),btrim(p_body));
end;$$;

drop function if exists public.faction_mark_read();
create function public.faction_mark_read(p_faction public.todm_faction default null) returns void language plpgsql security definer set search_path='' as $$
declare v_faction public.todm_faction;
begin
 perform public.assert_active_user();
 select case when (a.is_todm_team or a.is_admin) and p_faction is not null then p_faction else p.selected_faction end
 into v_faction from public.profiles p join public.account_access a on a.user_id=p.user_id where p.user_id=auth.uid();
 if v_faction is null or not public.faction_can_access(v_faction) then raise exception 'Чат фракции недоступен' using errcode='42501'; end if;
 insert into public.faction_read_state(user_id,faction,read_at) values(auth.uid(),v_faction,clock_timestamp())
 on conflict(user_id,faction) do update set read_at=excluded.read_at;
end;$$;

create or replace function public.social_notification_counts()
returns table(private_unread bigint,faction_unread bigint,support_unread bigint)
language plpgsql security definer set search_path='' stable as $$
declare v_faction public.todm_faction;v_support_read timestamptz;v_staff boolean;
begin
 perform public.assert_active_user();
 select p.selected_faction,(a.is_todm_team or a.is_admin) into v_faction,v_staff from public.profiles p join public.account_access a on a.user_id=p.user_id where p.user_id=auth.uid();
 select s.support_read_at into v_support_read from public.social_read_state s where s.user_id=auth.uid();
 return query select
  (select count(*) from public.private_messages m join public.conversation_members cm on cm.conversation_id=m.conversation_id and cm.user_id=auth.uid() where m.sender_id<>auth.uid() and m.created_at>cm.last_read_at),
  (select count(*) from public.faction_messages m left join public.faction_read_state r on r.user_id=auth.uid() and r.faction=m.faction where m.user_id<>auth.uid() and m.deleted_at is null and (v_staff or m.faction=v_faction) and m.created_at>coalesce(r.read_at,'epoch'::timestamptz)),
  (select count(*) from public.support_messages m join public.support_tickets t on t.id=m.ticket_id where t.user_id=auth.uid() and m.sender_id<>auth.uid() and m.created_at>coalesce(v_support_read,'epoch'::timestamptz));
end;$$;

create or replace function public.admin_set_faction_leader(p_faction public.todm_faction,p_user_id uuid default null)
returns void language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from public.account_access a where a.user_id=auth.uid() and a.is_admin and not a.is_banned) then raise exception 'Доступ только для администратора' using errcode='42501'; end if;
 delete from public.faction_leaders where faction=p_faction or (p_user_id is not null and user_id=p_user_id);
 if p_user_id is not null then
  if not exists(select 1 from public.profiles p join public.account_access a on a.user_id=p.user_id where p.user_id=p_user_id and p.selected_faction=p_faction and not a.is_banned) then raise exception 'Пользователь должен состоять в выбранной фракции'; end if;
  insert into public.faction_leaders(faction,user_id,appointed_by) values(p_faction,p_user_id,auth.uid());
 end if;
end;$$;

update public.profiles set selected_faction='dokains',updated_at=now()
where lower(display_name::text)=lower('Deker33');
delete from public.faction_leaders where user_id in(select user_id from public.profiles where lower(display_name::text)=lower('Deker33'));
insert into public.faction_leaders(faction,user_id,appointed_by)
select 'dokains',p.user_id,null from public.profiles p join public.account_access a on a.user_id=p.user_id
where lower(p.display_name::text)=lower('Deker33') and p.selected_faction='dokains' and not a.is_banned
on conflict(faction) do update set user_id=excluded.user_id,appointed_by=null,appointed_at=now();

revoke all on function public.faction_can_access(public.todm_faction),public.faction_message_list(bigint,public.todm_faction),public.faction_message_send(text,public.todm_faction),public.faction_mark_read(public.todm_faction),public.admin_set_faction_leader(public.todm_faction,uuid) from public,anon;
grant execute on function public.faction_message_list(bigint,public.todm_faction),public.faction_message_send(text,public.todm_faction),public.faction_mark_read(public.todm_faction),public.admin_set_faction_leader(public.todm_faction,uuid) to authenticated;
commit;
