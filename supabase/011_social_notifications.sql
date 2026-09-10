begin;
create table if not exists public.social_read_state(
 user_id uuid primary key references auth.users(id) on delete cascade,
 faction_read_at timestamptz not null default now(),
 support_read_at timestamptz not null default now()
);
alter table public.social_read_state enable row level security;
drop policy if exists "read own social state" on public.social_read_state;
create policy "read own social state" on public.social_read_state for select to authenticated using(user_id=auth.uid());
grant select on public.social_read_state to authenticated;
revoke insert,update,delete on public.social_read_state from anon,authenticated;

create or replace function public.social_notification_counts()
returns table(private_unread bigint,faction_unread bigint,support_unread bigint)
language plpgsql security definer set search_path='' stable as $$
declare v_faction public.todm_faction;v_faction_read timestamptz;v_support_read timestamptz;
begin
 perform public.assert_active_user();
 select p.selected_faction into v_faction from public.profiles p where p.user_id=auth.uid();
 select s.faction_read_at,s.support_read_at into v_faction_read,v_support_read from public.social_read_state s where s.user_id=auth.uid();
 return query select
  (select count(*) from public.private_messages m join public.conversation_members cm on cm.conversation_id=m.conversation_id and cm.user_id=auth.uid() where m.sender_id<>auth.uid() and m.created_at>cm.last_read_at),
  (select count(*) from public.faction_messages m where v_faction is not null and m.faction=v_faction and m.user_id<>auth.uid() and m.deleted_at is null and m.created_at>coalesce(v_faction_read,'epoch'::timestamptz)),
  (select count(*) from public.support_messages m join public.support_tickets t on t.id=m.ticket_id where t.user_id=auth.uid() and m.sender_id<>auth.uid() and m.created_at>coalesce(v_support_read,'epoch'::timestamptz));
end;$$;
create or replace function public.faction_mark_read() returns void language plpgsql security definer set search_path='' as $$
begin perform public.assert_active_user();insert into public.social_read_state(user_id,faction_read_at) values(auth.uid(),now()) on conflict(user_id) do update set faction_read_at=excluded.faction_read_at;end;$$;
create or replace function public.support_mark_read() returns void language plpgsql security definer set search_path='' as $$
begin perform public.assert_active_user();insert into public.social_read_state(user_id,support_read_at) values(auth.uid(),now()) on conflict(user_id) do update set support_read_at=excluded.support_read_at;end;$$;
revoke all on function public.social_notification_counts(),public.faction_mark_read(),public.support_mark_read() from public,anon;
grant execute on function public.social_notification_counts(),public.faction_mark_read(),public.support_mark_read() to authenticated;
commit;
