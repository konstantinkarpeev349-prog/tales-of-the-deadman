-- Book prices are public; only the existing Author flag may change them.
create table if not exists public.shop_book_prices (
  slug text primary key check (slug in ('tome_1_standard', 'tome_1_deluxe')),
  price_rub integer not null check (price_rub between 1 and 999999),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id)
);

insert into public.shop_book_prices (slug, price_rub) values
  ('tome_1_standard', 1490), ('tome_1_deluxe', 3490)
on conflict (slug) do nothing;

alter table public.shop_book_prices enable row level security;
drop policy if exists shop_book_prices_read on public.shop_book_prices;
create policy shop_book_prices_read on public.shop_book_prices for select to anon, authenticated using (true);
revoke all on public.shop_book_prices from public, anon, authenticated;
grant select on public.shop_book_prices to anon, authenticated;

create or replace function public.shop_update_book_prices(p_standard integer, p_deluxe integer)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if auth.uid() is null or not exists (
    select 1 from public.account_access a
    where a.user_id = auth.uid() and a.is_author = true and coalesce(a.is_banned, false) = false
  ) then
    raise exception 'Недостаточно прав для изменения цен';
  end if;
  if p_standard is null or p_deluxe is null
     or p_standard not between 1 and 999999 or p_deluxe not between 1 and 999999 then
    raise exception 'Цена должна быть целым числом от 1 до 999999 рублей';
  end if;
  update public.shop_book_prices set price_rub = p_standard, updated_at = now(), updated_by = auth.uid()
    where slug = 'tome_1_standard';
  update public.shop_book_prices set price_rub = p_deluxe, updated_at = now(), updated_by = auth.uid()
    where slug = 'tome_1_deluxe';
  if (select count(*) from public.shop_book_prices where slug in ('tome_1_standard','tome_1_deluxe')) <> 2 then
    raise exception 'Каталог книг не инициализирован';
  end if;
end;
$$;
revoke all on function public.shop_update_book_prices(integer, integer) from public, anon;
grant execute on function public.shop_update_book_prices(integer, integer) to authenticated;
