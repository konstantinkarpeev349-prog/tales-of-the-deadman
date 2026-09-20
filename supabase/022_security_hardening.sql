-- Security audit 2026-09-15. Review and test before production deployment.
-- No user rows are removed. Public-site deployment is a separate step.
begin;

-- Supabase default table grants can make a column-only GRANT ineffective.
revoke update on public.user_warnings,public.faction_leader_notifications,public.rank_promotion_notifications from public,anon,authenticated;
do $$ declare t text; c text; begin
 foreach t in array array['user_warnings','faction_leader_notifications','rank_promotion_notifications','profiles'] loop
  for c in select column_name from information_schema.columns where table_schema='public' and table_name=t loop
   execute format('revoke update (%I) on public.%I from public,anon,authenticated',c,t);
  end loop;
 end loop;
end $$;
grant update(seen_at) on public.user_warnings,public.faction_leader_notifications,public.rank_promotion_notifications to authenticated;
revoke insert,update,delete,truncate,references,trigger on public.profiles,public.account_access,public.archive_content,public.entitlement_events,public.support_payments,public.orders from public,anon,authenticated;
revoke all on public.admin_access_log,public.avatar_moderation_backup from public,anon,authenticated;

-- Preserve the existing one-month rule even when the caller passes NULL.
create or replace function public.profile_set_faction(p_faction public.todm_faction)
returns void language plpgsql security definer set search_path='' as $$
declare v_level smallint; v_profile public.profiles;
begin
 select a.archive_level into v_level from public.account_access a where a.user_id=auth.uid() and not a.is_banned for update;
 if not found then raise exception 'Нет доступа' using errcode='42501'; end if;
 if p_faction is null then raise exception 'Выберите фракцию' using errcode='22023'; end if;
 select * into v_profile from public.profiles where user_id=auth.uid() for update;
 if v_profile.selected_faction is not distinct from p_faction then return; end if;
 if v_profile.faction_changed_at>now()-interval '1 month' and v_profile.faction_change_archive_level=v_level then
  raise exception 'Фракцию можно изменить раз в месяц или после изменения уровня Архива' using errcode='42501';
 end if;
 update public.profiles set selected_faction=p_faction,faction_changed_at=now(),faction_change_archive_level=v_level,updated_at=now() where user_id=auth.uid();
end;$$;

-- Ban must also apply to direct table reads, including Realtime SELECT checks.
create or replace function public.is_conversation_member(p_conversation uuid) returns boolean
language sql security definer set search_path='' stable as $$
 select exists(select 1 from public.conversation_members cm join public.account_access a on a.user_id=cm.user_id
 where cm.conversation_id=p_conversation and cm.user_id=auth.uid() and not a.is_banned);
$$;

-- External avatar URLs allow third-party tracking. Accept only the user's own
-- existing object on the configured project, while retaining the current client API.
create or replace function public.profile_set_avatar(p_avatar_url text)
returns void language plpgsql security definer set search_path='' as $$
declare prefix text; object_path text;
begin
 perform 1 from public.account_access a where a.user_id=auth.uid() and not a.is_banned and not a.avatar_hidden for update;
 if not found then raise exception 'Портрет недоступен для изменения' using errcode='42501'; end if;
 prefix:='https://wfivgzoiepldxddewvqf.supabase.co/storage/v1/object/public/avatars/';
 if p_avatar_url is null or char_length(p_avatar_url)>2048 or left(p_avatar_url,length(prefix))<>prefix then raise exception 'Недопустимый адрес аватара' using errcode='22023'; end if;
 object_path:=split_part(substr(p_avatar_url,length(prefix)+1),'?',1);
 if object_path !~ ('^'||auth.uid()::text||'/[A-Za-z0-9_-]+\.(jpg|jpeg|png|webp)$') or not exists(select 1 from storage.objects o where o.bucket_id='avatars' and o.name=object_path) then
  raise exception 'Изображение не найдено в вашем хранилище' using errcode='22023';
 end if;
 update public.profiles set avatar_url=p_avatar_url,updated_at=now() where user_id=auth.uid();
end;$$;

-- A restrictive policy adds ban/moderation checks to all existing avatar write policies.
drop policy if exists "active avatar owner writes" on storage.objects;
create policy "active avatar owner writes" on storage.objects as restrictive for all to authenticated
using(bucket_id<>'avatars' or exists(select 1 from public.account_access a where a.user_id=auth.uid() and not a.is_banned and not a.avatar_hidden))
with check(bucket_id<>'avatars' or exists(select 1 from public.account_access a where a.user_id=auth.uid() and not a.is_banned and not a.avatar_hidden));

revoke all on function public.profile_set_faction(public.todm_faction),public.profile_set_avatar(text),public.is_conversation_member(uuid) from public,anon;
grant execute on function public.profile_set_faction(public.todm_faction),public.profile_set_avatar(text),public.is_conversation_member(uuid) to authenticated;

-- Serialize per-sender writes so concurrent requests cannot pass the same timer.
create or replace function public.message_send(p_conversation uuid,p_body text) returns void
language plpgsql security definer set search_path='' as $$
begin
 perform 1 from public.account_access where user_id=auth.uid() and not is_banned for update;
 if not found or not public.is_conversation_member(p_conversation) then raise exception 'Диалог недоступен' using errcode='42501'; end if;
 if char_length(btrim(coalesce(p_body,''))) not between 1 and 2000 then raise exception 'Недопустимая длина сообщения' using errcode='22023'; end if;
 if exists(select 1 from public.private_messages where sender_id=auth.uid() and created_at>clock_timestamp()-interval '1 second') then raise exception 'Подождите перед следующим сообщением' using errcode='P0001'; end if;
 insert into public.private_messages(conversation_id,sender_id,body,created_at) values(p_conversation,auth.uid(),btrim(p_body),clock_timestamp());
end;$$;

create or replace function public.support_ticket_create(p_subject text,p_body text) returns uuid
language plpgsql security definer set search_path='' as $$
declare v_id uuid;
begin
 perform 1 from public.account_access where user_id=auth.uid() and not is_banned for update;
 if not found then raise exception 'Нет доступа' using errcode='42501'; end if;
 if char_length(btrim(coalesce(p_subject,''))) not between 3 and 120 or char_length(btrim(coalesce(p_body,''))) not between 1 and 4000 then raise exception 'Недопустимая длина обращения' using errcode='22023'; end if;
 if exists(select 1 from public.support_tickets where user_id=auth.uid() and created_at>clock_timestamp()-interval '1 minute')
 or (select count(*) from public.support_tickets where user_id=auth.uid() and created_at>clock_timestamp()-interval '1 hour')>=5 then raise exception 'Слишком много обращений. Повторите позднее' using errcode='P0001'; end if;
 insert into public.support_tickets(user_id,subject,created_at) values(auth.uid(),btrim(p_subject),clock_timestamp()) returning id into v_id;
 insert into public.support_messages(ticket_id,sender_id,body) values(v_id,auth.uid(),btrim(p_body));
 return v_id;
end;$$;

create or replace function public.support_message_send(p_ticket uuid,p_body text) returns void
language plpgsql security definer set search_path='' as $$
declare v_staff boolean;v_owner uuid;v_status text;
begin
 select (is_todm_team or is_admin) into v_staff from public.account_access where user_id=auth.uid() and not is_banned for update;
 if not found then raise exception 'Нет доступа' using errcode='42501'; end if;
 select user_id,status into v_owner,v_status from public.support_tickets where id=p_ticket for update;
 if v_owner is null or (v_owner<>auth.uid() and not v_staff) then raise exception 'Обращение недоступно' using errcode='42501'; end if;
 if v_status='closed' then raise exception 'Обращение закрыто'; end if;
 if char_length(btrim(coalesce(p_body,''))) not between 1 and 4000 then raise exception 'Недопустимая длина сообщения' using errcode='22023'; end if;
 if exists(select 1 from public.support_messages where sender_id=auth.uid() and created_at>clock_timestamp()-interval '2 seconds') then raise exception 'Подождите перед следующим сообщением'; end if;
 insert into public.support_messages(ticket_id,sender_id,body,created_at) values(p_ticket,auth.uid(),btrim(p_body),clock_timestamp());
 update public.support_tickets set updated_at=now(),status=case when v_staff then 'in_progress' else status end where id=p_ticket;
end;$$;

revoke all on function public.message_send(uuid,text),public.support_ticket_create(text,text),public.support_message_send(uuid,text) from public,anon;
grant execute on function public.message_send(uuid,text),public.support_ticket_create(text,text),public.support_message_send(uuid,text) to authenticated;
commit;
