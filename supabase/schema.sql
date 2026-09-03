-- TODM account foundation. Run in Supabase SQL Editor as the project owner.
create extension if not exists citext;

create type public.todm_faction as enum ('paladins','frauster','maizervin','doronto','dokains');
create type public.entitlement_source as enum ('purchase','support_reward','admin_grant');

create table public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name citext not null unique check (char_length(display_name::text) between 3 and 32),
  avatar_url text,
  selected_faction public.todm_faction,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.account_access (
  user_id uuid primary key references auth.users(id) on delete cascade,
  archive_level smallint not null default 0 check (archive_level between 0 and 3),
  full_access boolean not null default false,
  is_admin boolean not null default false,
  is_author boolean not null default false,
  is_todm_team boolean not null default false,
  is_supporter boolean not null default false,
  is_banned boolean not null default false,
  updated_at timestamptz not null default now()
);

create table public.archive_content (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  title text not null,
  body jsonb not null default '{}'::jsonb,
  registration_required boolean not null default true,
  required_archive_level smallint not null default 0 check (required_archive_level between 0 and 3),
  published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.entitlement_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  archive_level smallint not null check (archive_level between 1 and 3),
  source public.entitlement_source not null,
  source_reference uuid,
  granted_at timestamptz not null default now(),
  granted_by uuid references auth.users(id)
);

create table public.support_payments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  provider text not null,
  provider_payment_id text unique,
  amount bigint not null check (amount between 1000 and 500000000),
  currency text not null default 'RUB' check (currency = 'RUB'),
  status text not null default 'pending' check (status in ('pending','succeeded','canceled','refunded')),
  created_at timestamptz not null default now(),
  paid_at timestamptz,
  metadata jsonb not null default '{}'::jsonb
);

create table public.archive_thresholds (
  archive_level smallint primary key check (archive_level between 1 and 3),
  support_threshold bigint not null check (support_threshold > 0),
  discount_percent numeric(5,2) not null check (discount_percent between 0 and 100),
  active boolean not null default true,
  updated_at timestamptz not null default now()
);

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict,
  total_amount bigint not null check (total_amount >= 0),
  currency text not null default 'RUB',
  status text not null default 'pending',
  created_at timestamptz not null default now()
);

create table public.content_reads (
  user_id uuid not null references auth.users(id) on delete cascade,
  content_id uuid not null references public.archive_content(id) on delete cascade,
  first_opened_at timestamptz not null default now(),
  last_opened_at timestamptz not null default now(),
  primary key (user_id, content_id)
);

create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path = '' as $$
declare base_name text; candidate text;
begin
  base_name := left(regexp_replace(coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email,'@',1), 'reader'), '[^A-Za-zА-Яа-яЁё0-9 _.-]', '', 'g'), 24);
  if char_length(base_name) < 3 then base_name := 'reader'; end if;
  candidate := base_name;
  while exists(select 1 from public.profiles where display_name = candidate::public.citext) loop candidate := left(base_name,24) || '-' || substr(new.id::text,1,6); end loop;
  insert into public.profiles(user_id,display_name) values(new.id,candidate);
  insert into public.account_access(user_id) values(new.id);
  return new;
end;$$;

create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.account_access enable row level security;
alter table public.archive_content enable row level security;
alter table public.entitlement_events enable row level security;
alter table public.support_payments enable row level security;
alter table public.archive_thresholds enable row level security;
alter table public.orders enable row level security;
alter table public.content_reads enable row level security;

create policy "read own profile" on public.profiles for select to authenticated using (auth.uid() = user_id);
create policy "update own profile" on public.profiles for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "read own access" on public.account_access for select to authenticated using (auth.uid() = user_id);
create policy "read permitted archive" on public.archive_content for select to authenticated using (
  published and exists(select 1 from public.account_access a where a.user_id=auth.uid() and not a.is_banned and (a.full_access or a.archive_level >= required_archive_level))
);
create policy "read own entitlement history" on public.entitlement_events for select to authenticated using (auth.uid() = user_id);
create policy "read own support" on public.support_payments for select to authenticated using (auth.uid() = user_id);
create policy "read own orders" on public.orders for select to authenticated using (auth.uid() = user_id);
create policy "read own content history" on public.content_reads for select to authenticated using (auth.uid() = user_id);
create policy "insert own content history" on public.content_reads for insert to authenticated with check (auth.uid() = user_id);
create policy "update own content history" on public.content_reads for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

grant select,update on public.profiles to authenticated;
grant select on public.account_access,public.archive_content,public.entitlement_events,public.support_payments,public.orders to authenticated;
grant select,insert,update on public.content_reads to authenticated;
revoke all on public.archive_thresholds from anon,authenticated;

insert into public.archive_thresholds(archive_level,support_threshold,discount_percent,active) values
  (1,1,10,false),(2,2,20,false),(3,3,25,false)
on conflict do nothing;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values
  ('avatars','avatars',true,5242880,array['image/jpeg','image/png','image/webp'])
on conflict(id) do update set file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

create policy "upload own avatar" on storage.objects for insert to authenticated with check (bucket_id='avatars' and (storage.foldername(name))[1]=auth.uid()::text);
create policy "update own avatar" on storage.objects for update to authenticated using (bucket_id='avatars' and owner_id=auth.uid()::text) with check (bucket_id='avatars' and (storage.foldername(name))[1]=auth.uid()::text);
create policy "delete own avatar" on storage.objects for delete to authenticated using (bucket_id='avatars' and owner_id=auth.uid()::text);

-- Run only after registering the author's account.
-- update public.account_access set is_admin=true,is_author=true,is_todm_team=true,full_access=true,archive_level=3
-- where user_id=(select id from auth.users where email='konstantinkarpeev349@gmail.com');
