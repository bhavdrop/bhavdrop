-- BHAVDROP DATABASE REFERENCE FOR A NEW/EMPTY SUPABASE PROJECT ONLY.
-- If you already have data/tables, DO NOT blindly run this file: inspect your schema first.
-- These are the columns expected by the current frontend pages.

create extension if not exists pgcrypto;

create table if not exists public.products (
  id text primary key,
  title text not null,
  subtitle text,
  category text not null check (category in ('her','him','jewels')),
  price numeric(12,2) not null default 0 check (price >= 0),
  original_price numeric(12,2),
  image text,
  images text[] not null default '{}',
  description text,
  badge text,
  sizes text[] not null default '{}',
  colors text[] not null default '{}',
  created_at timestamptz not null default now()
);

create table if not exists public.orders (
  id text primary key,
  name text not null,
  phone text not null,
  address text not null,
  items jsonb not null default '[]'::jsonb,
  total numeric(12,2) not null check (total >= 0),
  status text not null default 'PENDING_PAYMENT_VERIFICATION',
  upi_ref text,
  created_at timestamptz not null default now()
);

create table if not exists public.auctions (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  image_url text,
  start_price numeric(12,2) not null check (start_price >= 0),
  floor_price numeric(12,2) not null check (floor_price >= 0),
  step_amount numeric(12,2) not null default 1 check (step_amount > 0),
  step_seconds integer not null default 3 check (step_seconds > 0),
  starts_at timestamptz not null default now(),
  status text not null default 'live' check (status in ('upcoming','live','locked','sold','paused')),
  locked_at timestamptz,
  locked_price numeric(12,2),
  locked_by text,
  created_at timestamptz not null default now()
);

create index if not exists orders_created_at_idx on public.orders (created_at desc);
create index if not exists products_category_idx on public.products (category);

-- This atomic function is required by vault.html. It ignores the client-supplied price
-- and calculates the current price from the database clock. It does NOT mark an item paid/sold.
create or replace function public.claim_auction_item(
  target_id uuid,
  user_tag text,
  claimed_price numeric default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  a public.auctions%rowtype;
  current_price numeric(12,2);
begin
  if coalesce(length(trim(user_tag)), 0) < 3 or length(trim(user_tag)) > 80 then
    return jsonb_build_object('success', false, 'message', 'Invalid session tag');
  end if;

  select * into a from public.auctions where id = target_id for update;
  if not found then
    return jsonb_build_object('success', false, 'message', 'Auction item not found');
  end if;
  if a.status not in ('live','locked') then
    return jsonb_build_object('success', false, 'message', 'Auction is not available');
  end if;
  if a.status = 'locked' and a.locked_at is not null and a.locked_at > now() - interval '180 seconds' then
    return jsonb_build_object('success', false, 'message', 'Item is currently reserved');
  end if;

  current_price := greatest(a.floor_price, a.start_price -
    floor(greatest(0, extract(epoch from (now() - a.starts_at))) / a.step_seconds) * a.step_amount);

  update public.auctions
    set status = 'locked', locked_at = now(), locked_price = current_price, locked_by = trim(user_tag)
    where id = target_id;

  return jsonb_build_object('success', true, 'message', 'Item reserved for 180 seconds', 'locked_price', current_price);
end;
$$;

revoke all on function public.claim_auction_item(uuid, text, numeric) from public;
grant execute on function public.claim_auction_item(uuid, text, numeric) to anon, authenticated;

-- RLS policies are intentionally in supabase_security_setup.sql. Review schema and policy
-- changes before applying to a populated project. Never expose a service-role key in frontend code.
