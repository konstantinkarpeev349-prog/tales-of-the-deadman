-- Unique views of existing public encyclopaedia dossiers. No OA is awarded.
begin;

create table if not exists public.archive_public_dossiers (
  path text primary key check (path ~ '^[A-Za-z0-9_]+\.html$')
);

insert into public.archive_public_dossiers(path) values
('Dan.html'),('Darius_Tom_I.html'),('Harvos.html'),('Milena.html'),
('Filk.html'),('Morgeus.html'),('Morell.html'),('Galdvin.html'),
('Sann.html'),('Forell.html'),('Hoffit.html'),('Gas.html'),
('Rogan.html'),('Ranor.html'),('Soren.html'),('Sorgen.html'),
('Erl.html'),('Karn.html'),('Konos.html'),('Norta.html'),
('Arkon.html'),('Anrirn.html'),('Adamantriy.html'),('Lienna.html'),
('Dorgus.html'),('Garaniy.html'),('Frauster_Kingdom.html'),
('Maizervin_Kingdom.html'),('Cult_Doronto.html')
on conflict (path) do nothing;

create table if not exists public.archive_public_dossier_views (
  user_id uuid not null references auth.users(id) on delete cascade,
  path text not null references public.archive_public_dossiers(path),
  first_opened_at timestamptz not null default now(),
  last_opened_at timestamptz not null default now(),
  primary key (user_id,path)
);

alter table public.archive_public_dossiers enable row level security;
alter table public.archive_public_dossier_views enable row level security;
revoke all on public.archive_public_dossiers,public.archive_public_dossier_views from public,anon,authenticated;
grant select on public.archive_public_dossier_views to authenticated;
drop policy if exists "read own public dossier views" on public.archive_public_dossier_views;
create policy "read own public dossier views" on public.archive_public_dossier_views
for select to authenticated using (user_id=auth.uid());

create or replace function public.archive_record_public_dossier(p_path text)
returns void language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();
begin
  if v_user is null then raise exception 'Требуется авторизация' using errcode='42501'; end if;
  if not exists(select 1 from public.account_access where user_id=v_user and not is_banned) then
    raise exception 'Аккаунт недоступен' using errcode='42501';
  end if;
  if not exists(select 1 from public.archive_public_dossiers where path=p_path) then
    raise exception 'Неизвестное досье' using errcode='22023';
  end if;
  insert into public.archive_public_dossier_views(user_id,path) values(v_user,p_path)
  on conflict(user_id,path) do update set last_opened_at=now();
end;$$;
revoke all on function public.archive_record_public_dossier(text) from public,anon,authenticated;
grant execute on function public.archive_record_public_dossier(text) to authenticated;
commit;
