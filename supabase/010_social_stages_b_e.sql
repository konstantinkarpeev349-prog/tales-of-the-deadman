begin;

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  direct_key text not null unique,
  created_at timestamptz not null default now()
);
create table if not exists public.conversation_members (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  last_read_at timestamptz not null default now(),
  primary key(conversation_id,user_id)
);
create table if not exists public.private_messages (
  id bigint generated always as identity primary key,
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  body text not null check(char_length(btrim(body)) between 1 and 2000),
  created_at timestamptz not null default now()
);
create index if not exists private_messages_conversation_id_desc on public.private_messages(conversation_id,id desc);
create index if not exists conversation_members_user_id on public.conversation_members(user_id,conversation_id);

create table if not exists public.faction_messages (
  id bigint generated always as identity primary key,
  faction public.todm_faction not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  body text not null check(char_length(btrim(body)) between 1 and 2000),
  created_at timestamptz not null default now(),
  deleted_at timestamptz,
  deleted_by uuid references auth.users(id)
);
create index if not exists faction_messages_faction_id_desc on public.faction_messages(faction,id desc);

create table if not exists public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  subject text not null check(char_length(btrim(subject)) between 3 and 120),
  status text not null default 'new' check(status in ('new','in_progress','closed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.support_messages (
  id bigint generated always as identity primary key,
  ticket_id uuid not null references public.support_tickets(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  body text not null check(char_length(btrim(body)) between 1 and 4000),
  created_at timestamptz not null default now()
);
create index if not exists support_tickets_user_updated on public.support_tickets(user_id,updated_at desc);
create index if not exists support_messages_ticket_id on public.support_messages(ticket_id,id);

create table if not exists public.avatar_frames (
  code text primary key,
  title text not null,
  category text not null check(category in ('standard','faction','archive','supporter','todm','author')),
  faction public.todm_faction,
  required_archive_level smallint,
  active boolean not null default true
);
create table if not exists public.user_avatar_frames (
  user_id uuid not null references auth.users(id) on delete cascade,
  frame_code text not null references public.avatar_frames(code) on delete cascade,
  unlocked_at timestamptz not null default now(),
  primary key(user_id,frame_code)
);
alter table public.profiles add column if not exists active_avatar_frame text references public.avatar_frames(code);

insert into public.avatar_frames(code,title,category,faction,required_archive_level) values
('standard','Классическая','standard',null,null),
('faction-dokains','Докаины','faction','dokains',null),('faction-frauster','Фраустер','faction','frauster',null),
('faction-maizervin','Майзервин','faction','maizervin',null),('faction-paladins','Паладины','faction','paladins',null),
('faction-doronto','Культ Доронто','faction','doronto',null),
('archive-i','Архив I','archive',null,1),('archive-ii','Архив II','archive',null,2),('archive-iii','Архив III','archive',null,3),
('supporter','Поддержавший','supporter',null,null),('todm','TODM Team','todm',null,null),('author','Автор','author',null,null)
on conflict(code) do update set title=excluded.title,category=excluded.category,faction=excluded.faction,required_archive_level=excluded.required_archive_level,active=true;
insert into public.user_avatar_frames(user_id,frame_code) select user_id,'standard' from public.profiles on conflict do nothing;

alter table public.conversations enable row level security;
alter table public.conversation_members enable row level security;
alter table public.private_messages enable row level security;
alter table public.faction_messages enable row level security;
alter table public.support_tickets enable row level security;
alter table public.support_messages enable row level security;
alter table public.avatar_frames enable row level security;
alter table public.user_avatar_frames enable row level security;

create or replace function public.is_conversation_member(p_conversation uuid) returns boolean
language sql security definer set search_path='' stable as $$
 select exists(select 1 from public.conversation_members cm where cm.conversation_id=p_conversation and cm.user_id=auth.uid());
$$;

drop policy if exists "members read conversations" on public.conversations;
create policy "members read conversations" on public.conversations for select to authenticated using(public.is_conversation_member(id));
drop policy if exists "members read membership" on public.conversation_members;
create policy "members read membership" on public.conversation_members for select to authenticated using(public.is_conversation_member(conversation_id));
drop policy if exists "members read private messages" on public.private_messages;
create policy "members read private messages" on public.private_messages for select to authenticated using(public.is_conversation_member(conversation_id));
drop policy if exists "own faction reads messages" on public.faction_messages;
create policy "own faction reads messages" on public.faction_messages for select to authenticated using(exists(select 1 from public.profiles p join public.account_access a on a.user_id=p.user_id where p.user_id=auth.uid() and not a.is_banned and (p.selected_faction=faction or a.is_todm_team or a.is_admin)));
drop policy if exists "owners and staff read tickets" on public.support_tickets;
create policy "owners and staff read tickets" on public.support_tickets for select to authenticated using(user_id=auth.uid() or exists(select 1 from public.account_access a where a.user_id=auth.uid() and not a.is_banned and (a.is_todm_team or a.is_admin)));
drop policy if exists "owners and staff read support messages" on public.support_messages;
create policy "owners and staff read support messages" on public.support_messages for select to authenticated using(exists(select 1 from public.support_tickets t where t.id=ticket_id and (t.user_id=auth.uid() or exists(select 1 from public.account_access a where a.user_id=auth.uid() and not a.is_banned and (a.is_todm_team or a.is_admin)))));
drop policy if exists "read active frames" on public.avatar_frames;
create policy "read active frames" on public.avatar_frames for select to authenticated using(active);
drop policy if exists "read own frames" on public.user_avatar_frames;
create policy "read own frames" on public.user_avatar_frames for select to authenticated using(user_id=auth.uid());

grant select on public.conversations,public.conversation_members,public.private_messages,public.faction_messages,public.support_tickets,public.support_messages,public.avatar_frames,public.user_avatar_frames to authenticated;
revoke insert,update,delete on public.conversations,public.conversation_members,public.private_messages,public.faction_messages,public.support_tickets,public.support_messages,public.avatar_frames,public.user_avatar_frames from anon,authenticated;

create or replace function public.assert_active_user() returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not exists(select 1 from public.account_access a where a.user_id=auth.uid() and not a.is_banned) then raise exception 'Нет доступа' using errcode='42501'; end if;
end;$$;

create or replace function public.conversation_open(p_other uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid; v_key text;
begin
 perform public.assert_active_user();
 if p_other is null or p_other=auth.uid() then raise exception 'Нельзя открыть диалог с самим собой'; end if;
 if not exists(select 1 from public.account_access a where a.user_id=p_other and not a.is_banned) then raise exception 'Пользователь недоступен'; end if;
 v_key:=least(auth.uid()::text,p_other::text)||':'||greatest(auth.uid()::text,p_other::text);
 insert into public.conversations(direct_key) values(v_key) on conflict(direct_key) do update set direct_key=excluded.direct_key returning id into v_id;
 insert into public.conversation_members(conversation_id,user_id) values(v_id,auth.uid()),(v_id,p_other) on conflict do nothing;
 return v_id;
end;$$;

create or replace function public.conversation_list()
returns table(conversation_id uuid,other_user_id uuid,display_name text,avatar_url text,frame_code text,selected_faction text,archive_level smallint,is_todm_team boolean,is_author boolean,is_supporter boolean,last_message text,last_message_at timestamptz,unread_count bigint)
language plpgsql security definer set search_path='' stable as $$
begin
 perform public.assert_active_user();
 return query select cm.conversation_id,other.user_id,p.display_name::text,p.avatar_url,p.active_avatar_frame,p.selected_faction::text,a.archive_level,a.is_todm_team,a.is_author,a.is_supporter,
   lm.body,lm.created_at,(select count(*) from public.private_messages unread where unread.conversation_id=cm.conversation_id and unread.sender_id<>auth.uid() and unread.created_at>cm.last_read_at)
 from public.conversation_members cm join public.conversation_members other on other.conversation_id=cm.conversation_id and other.user_id<>auth.uid()
 join public.profiles p on p.user_id=other.user_id join public.account_access a on a.user_id=other.user_id
 left join lateral(select m.body,m.created_at from public.private_messages m where m.conversation_id=cm.conversation_id order by m.id desc limit 1) lm on true
 where cm.user_id=auth.uid() order by lm.created_at desc nulls last;
end;$$;

create or replace function public.message_list(p_conversation uuid,p_before bigint default null)
returns table(id text,sender_id uuid,body text,created_at timestamptz,display_name text,avatar_url text,frame_code text,archive_level smallint,is_todm_team boolean,is_author boolean,is_supporter boolean) language plpgsql security definer set search_path='' stable as $$
begin
 perform public.assert_active_user();
 if not exists(select 1 from public.conversation_members cm where cm.conversation_id=p_conversation and cm.user_id=auth.uid()) then raise exception 'Чужой диалог недоступен' using errcode='42501'; end if;
 return query select m.id::text,m.sender_id,m.body,m.created_at,p.display_name::text,p.avatar_url,p.active_avatar_frame,a.archive_level,a.is_todm_team,a.is_author,a.is_supporter from public.private_messages m join public.profiles p on p.user_id=m.sender_id join public.account_access a on a.user_id=m.sender_id where m.conversation_id=p_conversation and (p_before is null or m.id<p_before) order by m.id desc limit 50;
end;$$;
create or replace function public.message_send(p_conversation uuid,p_body text) returns void language plpgsql security definer set search_path='' as $$
begin
 perform public.assert_active_user();
 if not exists(select 1 from public.conversation_members cm where cm.conversation_id=p_conversation and cm.user_id=auth.uid()) then raise exception 'Чужой диалог недоступен' using errcode='42501'; end if;
 if p_body is null or char_length(btrim(p_body)) not between 1 and 2000 then raise exception 'Сообщение должно содержать от 1 до 2000 символов'; end if;
 if exists(select 1 from public.private_messages m where m.sender_id=auth.uid() and m.created_at>clock_timestamp()-interval '1 second') then raise exception 'Не отправляйте сообщения так быстро'; end if;
 insert into public.private_messages(conversation_id,sender_id,body) values(p_conversation,auth.uid(),btrim(p_body));
end;$$;
create or replace function public.message_mark_read(p_conversation uuid) returns void language sql security definer set search_path='' as $$ update public.conversation_members set last_read_at=now() where conversation_id=p_conversation and user_id=auth.uid(); $$;

create or replace function public.faction_message_list(p_before bigint default null)
returns table(id text,user_id uuid,body text,created_at timestamptz,deleted boolean,display_name text,avatar_url text,frame_code text,archive_level smallint,is_todm_team boolean,is_author boolean,is_supporter boolean)
language plpgsql security definer set search_path='' stable as $$
declare v_faction public.todm_faction;
begin
 perform public.assert_active_user(); select p.selected_faction into v_faction from public.profiles p where p.user_id=auth.uid();
 if v_faction is null then raise exception 'Сначала выберите фракцию'; end if;
 return query select m.id::text,m.user_id,case when m.deleted_at is null then m.body else null end,m.created_at,m.deleted_at is not null,p.display_name::text,p.avatar_url,p.active_avatar_frame,a.archive_level,a.is_todm_team,a.is_author,a.is_supporter
 from public.faction_messages m join public.profiles p on p.user_id=m.user_id join public.account_access a on a.user_id=m.user_id
 where m.faction=v_faction and (p_before is null or m.id<p_before) order by m.id desc limit 50;
end;$$;
create or replace function public.faction_message_send(p_body text) returns void language plpgsql security definer set search_path='' as $$
declare v_faction public.todm_faction;
begin
 perform public.assert_active_user(); select p.selected_faction into v_faction from public.profiles p where p.user_id=auth.uid();
 if v_faction is null then raise exception 'Сначала выберите фракцию'; end if;
 if p_body is null or char_length(btrim(p_body)) not between 1 and 2000 then raise exception 'Сообщение должно содержать от 1 до 2000 символов'; end if;
 if exists(select 1 from public.faction_messages m where m.user_id=auth.uid() and m.created_at>clock_timestamp()-interval '2 seconds') then raise exception 'Подождите две секунды'; end if;
 insert into public.faction_messages(faction,user_id,body) values(v_faction,auth.uid(),btrim(p_body));
end;$$;
create or replace function public.faction_message_delete(p_id bigint) returns void language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from public.account_access a where a.user_id=auth.uid() and not a.is_banned and (a.is_todm_team or a.is_admin)) then raise exception 'Доступ только для TODM' using errcode='42501'; end if;
 update public.faction_messages set deleted_at=now(),deleted_by=auth.uid() where id=p_id and deleted_at is null;
end;$$;

create or replace function public.support_ticket_create(p_subject text,p_body text) returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid;
begin
 perform public.assert_active_user();
 if p_subject is null or char_length(btrim(p_subject)) not between 3 and 120 then raise exception 'Тема должна содержать от 3 до 120 символов'; end if;
 if p_body is null or char_length(btrim(p_body)) not between 1 and 4000 then raise exception 'Сообщение должно содержать от 1 до 4000 символов'; end if;
 insert into public.support_tickets(user_id,subject) values(auth.uid(),btrim(p_subject)) returning id into v_id;
 insert into public.support_messages(ticket_id,sender_id,body) values(v_id,auth.uid(),btrim(p_body)); return v_id;
end;$$;
create or replace function public.support_ticket_list(p_staff boolean default false)
returns table(id uuid,user_id uuid,subject text,status text,created_at timestamptz,updated_at timestamptz,display_name text) language plpgsql security definer set search_path='' stable as $$
declare v_staff boolean;
begin
 perform public.assert_active_user(); select (a.is_todm_team or a.is_admin) into v_staff from public.account_access a where a.user_id=auth.uid();
 if p_staff and not v_staff then raise exception 'Доступ только для TODM' using errcode='42501'; end if;
 return query select t.id,t.user_id,t.subject,t.status,t.created_at,t.updated_at,p.display_name::text from public.support_tickets t join public.profiles p on p.user_id=t.user_id where (p_staff and v_staff) or t.user_id=auth.uid() order by t.updated_at desc limit 100;
end;$$;
create or replace function public.support_message_list(p_ticket uuid)
returns table(id text,sender_id uuid,body text,created_at timestamptz,staff boolean) language plpgsql security definer set search_path='' stable as $$
begin
 perform public.assert_active_user();
 if not exists(select 1 from public.support_tickets t where t.id=p_ticket and (t.user_id=auth.uid() or exists(select 1 from public.account_access a where a.user_id=auth.uid() and (a.is_todm_team or a.is_admin) and not a.is_banned))) then raise exception 'Обращение недоступно' using errcode='42501'; end if;
 return query select m.id::text,m.sender_id,m.body,m.created_at,(a.is_todm_team or a.is_admin) from public.support_messages m join public.account_access a on a.user_id=m.sender_id where m.ticket_id=p_ticket order by m.id;
end;$$;
create or replace function public.support_message_send(p_ticket uuid,p_body text) returns void language plpgsql security definer set search_path='' as $$
declare v_staff boolean; v_owner uuid; v_status text;
begin
 perform public.assert_active_user(); select (a.is_todm_team or a.is_admin) into v_staff from public.account_access a where a.user_id=auth.uid();
 select t.user_id,t.status into v_owner,v_status from public.support_tickets t where t.id=p_ticket for update;
 if v_owner is null or (v_owner<>auth.uid() and not v_staff) then raise exception 'Обращение недоступно' using errcode='42501'; end if;
 if v_status='closed' then raise exception 'Обращение закрыто'; end if;
 if p_body is null or char_length(btrim(p_body)) not between 1 and 4000 then raise exception 'Сообщение должно содержать от 1 до 4000 символов'; end if;
 insert into public.support_messages(ticket_id,sender_id,body) values(p_ticket,auth.uid(),btrim(p_body));
 update public.support_tickets set updated_at=now(),status=case when v_staff then 'in_progress' else status end where id=p_ticket;
end;$$;
create or replace function public.support_ticket_status(p_ticket uuid,p_status text) returns void language plpgsql security definer set search_path='' as $$
begin
 if p_status not in ('new','in_progress','closed') then raise exception 'Неизвестный статус'; end if;
 if not exists(select 1 from public.account_access a where a.user_id=auth.uid() and not a.is_banned and (a.is_todm_team or a.is_admin)) then raise exception 'Доступ только для TODM' using errcode='42501'; end if;
 update public.support_tickets set status=p_status,updated_at=now() where id=p_ticket;
end;$$;

create or replace function public.avatar_frame_list()
returns table(code text,title text,category text,unlocked boolean,active boolean) language plpgsql security definer set search_path='' stable as $$
begin
 perform public.assert_active_user();
 return query select f.code,f.title,f.category,
 (uf.user_id is not null or f.category='standard' or (f.category='faction' and f.faction=p.selected_faction) or (f.category='archive' and a.archive_level>=f.required_archive_level) or (f.category='supporter' and a.is_supporter) or (f.category='todm' and a.is_todm_team) or (f.category='author' and a.is_author)),
 p.active_avatar_frame=f.code
 from public.avatar_frames f cross join public.profiles p join public.account_access a on a.user_id=p.user_id left join public.user_avatar_frames uf on uf.user_id=p.user_id and uf.frame_code=f.code
 where p.user_id=auth.uid() and f.active order by f.category,f.code;
end;$$;
create or replace function public.avatar_frame_set(p_code text) returns void language plpgsql security definer set search_path='' as $$
declare v_ok boolean;
begin
 perform public.assert_active_user();
 select (uf.user_id is not null or f.category='standard' or (f.category='faction' and f.faction=p.selected_faction) or (f.category='archive' and a.archive_level>=f.required_archive_level) or (f.category='supporter' and a.is_supporter) or (f.category='todm' and a.is_todm_team) or (f.category='author' and a.is_author)) into v_ok
 from public.avatar_frames f cross join public.profiles p join public.account_access a on a.user_id=p.user_id left join public.user_avatar_frames uf on uf.user_id=p.user_id and uf.frame_code=f.code where p.user_id=auth.uid() and f.code=p_code and f.active;
 if not coalesce(v_ok,false) then raise exception 'Рамка недоступна' using errcode='42501'; end if;
 insert into public.user_avatar_frames(user_id,frame_code) values(auth.uid(),p_code) on conflict do nothing;
 update public.profiles set active_avatar_frame=p_code,updated_at=now() where user_id=auth.uid();
end;$$;

drop function if exists public.social_profile(uuid);
drop function if exists public.social_profiles(uuid[]);
create function public.social_profile(p_user_id uuid)
returns table(user_id uuid,display_name text,avatar_url text,frame_code text,selected_faction text,archive_level smallint,is_todm_team boolean,is_author boolean,is_supporter boolean)
language plpgsql security definer set search_path='' stable as $$ begin perform public.assert_active_user(); return query select p.user_id,p.display_name::text,p.avatar_url,p.active_avatar_frame,p.selected_faction::text,a.archive_level,a.is_todm_team,a.is_author,a.is_supporter from public.profiles p join public.account_access a on a.user_id=p.user_id where p.user_id=p_user_id and not a.is_banned; end;$$;
create function public.social_profiles(p_user_ids uuid[])
returns table(user_id uuid,display_name text,avatar_url text,frame_code text,selected_faction text,archive_level smallint,is_todm_team boolean,is_author boolean,is_supporter boolean)
language plpgsql security definer set search_path='' stable as $$ begin perform public.assert_active_user(); return query select p.user_id,p.display_name::text,p.avatar_url,p.active_avatar_frame,p.selected_faction::text,a.archive_level,a.is_todm_team,a.is_author,a.is_supporter from public.profiles p join public.account_access a on a.user_id=p.user_id where p.user_id=any(coalesce(p_user_ids,array[]::uuid[])) and not a.is_banned order by p.display_name; end;$$;

revoke all on function public.is_conversation_member(uuid),public.assert_active_user(),public.conversation_open(uuid),public.conversation_list(),public.message_list(uuid,bigint),public.message_send(uuid,text),public.message_mark_read(uuid),public.faction_message_list(bigint),public.faction_message_send(text),public.faction_message_delete(bigint),public.support_ticket_create(text,text),public.support_ticket_list(boolean),public.support_message_list(uuid),public.support_message_send(uuid,text),public.support_ticket_status(uuid,text),public.avatar_frame_list(),public.avatar_frame_set(text),public.social_profile(uuid),public.social_profiles(uuid[]) from public,anon;
grant execute on function public.conversation_open(uuid),public.conversation_list(),public.message_list(uuid,bigint),public.message_send(uuid,text),public.message_mark_read(uuid),public.faction_message_list(bigint),public.faction_message_send(text),public.faction_message_delete(bigint),public.support_ticket_create(text,text),public.support_ticket_list(boolean),public.support_message_list(uuid),public.support_message_send(uuid,text),public.support_ticket_status(uuid,text),public.avatar_frame_list(),public.avatar_frame_set(text),public.social_profile(uuid),public.social_profiles(uuid[]) to authenticated;

do $$ begin
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='private_messages') then alter publication supabase_realtime add table public.private_messages; end if;
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='faction_messages') then alter publication supabase_realtime add table public.faction_messages; end if;
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='support_messages') then alter publication supabase_realtime add table public.support_messages; end if;
end $$;
commit;
