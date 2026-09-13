-- Protected book content. Lore rows are inserted directly into Supabase and are
-- deliberately not stored in this public repository.
create table if not exists public.tome_content (
  id uuid primary key default gen_random_uuid(),
  volume smallint not null check (volume > 0),
  slug text not null,
  title text not null,
  body jsonb not null default '{}'::jsonb,
  required_archive_level smallint not null default 3 check (required_archive_level between 0 and 5),
  is_published boolean not null default false,
  updated_at timestamptz not null default now(),
  unique (volume, slug)
);

alter table public.tome_content enable row level security;
revoke all on table public.tome_content from anon, authenticated;
grant select on table public.tome_content to authenticated;

drop policy if exists "read permitted tome content" on public.tome_content;
create policy "read permitted tome content"
on public.tome_content
for select
to authenticated
using (
  is_published
  and exists (
    select 1
    from public.account_access access
    where access.user_id = auth.uid()
      and coalesce(access.is_banned, false) = false
      and (
        coalesce(access.full_access, false) = true
        or coalesce(access.archive_level, 0) >= tome_content.required_archive_level
      )
  )
);

create index if not exists tome_content_lookup_idx
  on public.tome_content (volume, slug)
  where is_published;

create or replace function public.set_tome_content_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists tome_content_updated_at on public.tome_content;
create trigger tome_content_updated_at
before update on public.tome_content
for each row execute function public.set_tome_content_updated_at();
