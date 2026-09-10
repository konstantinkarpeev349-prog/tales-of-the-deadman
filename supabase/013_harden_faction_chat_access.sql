begin;

create or replace function public.faction_can_access(p_faction public.todm_faction)
returns boolean language sql security definer set search_path='' stable as $$
 select exists(
  select 1 from public.account_access a join public.profiles p on p.user_id=a.user_id
  where a.user_id=auth.uid() and not a.is_banned
   and (p.selected_faction=p_faction or (a.is_todm_team and a.archive_level>=4) or a.is_admin)
 );
$$;

drop policy if exists "own faction reads messages" on public.faction_messages;
create policy "own faction reads messages" on public.faction_messages for select to authenticated using(
 exists(
  select 1 from public.profiles p join public.account_access a on a.user_id=p.user_id
  where p.user_id=auth.uid() and not a.is_banned
   and (p.selected_faction=faction or (a.is_todm_team and a.archive_level>=4) or a.is_admin)
 )
);

create or replace function public.faction_message_list(p_before bigint default null,p_faction public.todm_faction default null)
returns table(id text,user_id uuid,body text,created_at timestamptz,deleted boolean,display_name text,avatar_url text,frame_code text,archive_level smallint,is_todm_team boolean,is_author boolean,is_supporter boolean,is_leader boolean)
language plpgsql security definer set search_path='' stable as $$
declare v_faction public.todm_faction;
begin
 perform public.assert_active_user();
 select case when (a.is_admin or (a.is_todm_team and a.archive_level>=4)) and p_faction is not null then p_faction else p.selected_faction end
 into v_faction from public.profiles p join public.account_access a on a.user_id=p.user_id where p.user_id=auth.uid();
 if v_faction is null then raise exception 'Сначала выберите фракцию'; end if;
 if not public.faction_can_access(v_faction) then raise exception 'Чат фракции недоступен' using errcode='42501'; end if;
 return query select m.id::text,m.user_id,case when m.deleted_at is null then m.body else null end,m.created_at,m.deleted_at is not null,
 p.display_name::text,p.avatar_url,p.active_avatar_frame,a.archive_level,a.is_todm_team,a.is_author,a.is_supporter,(fl.user_id is not null)
 from public.faction_messages m join public.profiles p on p.user_id=m.user_id join public.account_access a on a.user_id=m.user_id
 left join public.faction_leaders fl on fl.faction=m.faction and fl.user_id=m.user_id
 where m.faction=v_faction and (p_before is null or m.id<p_before) order by m.id desc limit 50;
end;$$;

create or replace function public.faction_message_send(p_body text,p_faction public.todm_faction default null) returns void language plpgsql security definer set search_path='' as $$
declare v_faction public.todm_faction;
begin
 perform public.assert_active_user();
 select case when (a.is_admin or (a.is_todm_team and a.archive_level>=4)) and p_faction is not null then p_faction else p.selected_faction end
 into v_faction from public.profiles p join public.account_access a on a.user_id=p.user_id where p.user_id=auth.uid();
 if v_faction is null then raise exception 'Сначала выберите фракцию'; end if;
 if not public.faction_can_access(v_faction) then raise exception 'Чат фракции недоступен' using errcode='42501'; end if;
 if char_length(btrim(coalesce(p_body,''))) not between 1 and 2000 then raise exception 'Сообщение должно содержать от 1 до 2000 символов'; end if;
 if exists(select 1 from public.faction_messages m where m.user_id=auth.uid() and m.created_at>clock_timestamp()-interval '2 seconds') then raise exception 'Подождите две секунды'; end if;
 insert into public.faction_messages(faction,user_id,body) values(v_faction,auth.uid(),btrim(p_body));
end;$$;

create or replace function public.faction_mark_read(p_faction public.todm_faction default null) returns void language plpgsql security definer set search_path='' as $$
declare v_faction public.todm_faction;
begin
 perform public.assert_active_user();
 select case when (a.is_admin or (a.is_todm_team and a.archive_level>=4)) and p_faction is not null then p_faction else p.selected_faction end
 into v_faction from public.profiles p join public.account_access a on a.user_id=p.user_id where p.user_id=auth.uid();
 if v_faction is null or not public.faction_can_access(v_faction) then raise exception 'Чат фракции недоступен' using errcode='42501'; end if;
 insert into public.faction_read_state(user_id,faction,read_at) values(auth.uid(),v_faction,clock_timestamp())
 on conflict(user_id,faction) do update set read_at=excluded.read_at;
end;$$;

commit;
