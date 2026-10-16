-- BhavDrop security setup STARTER. Review current policies/schema before applying.
-- This does not create missing tables and does not replace payment verification.
-- Admin access depends on server-managed auth.users.raw_app_meta_data.role = 'admin'.

-- 1) Enable RLS on existing tables.
alter table if exists public.products enable row level security;
alter table if exists public.orders enable row level security;
alter table if exists public.auctions enable row level security;

-- 2) Example product policies. Public may read catalog; only admin may write.
-- Review/drop any older permissive policies that grant anonymous writes.
drop policy if exists "products_public_read" on public.products;
create policy "products_public_read" on public.products
  for select to anon, authenticated using (true);
drop policy if exists "products_admin_write" on public.products;
create policy "products_admin_write" on public.products
  for all to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin')
  with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

-- 3) Orders contain private customer data. Admin can read/manage them.
-- Public insert is included only for compatibility with the current frontend.
-- For production, prefer an Edge Function/server endpoint and remove anon insert.
drop policy if exists "orders_admin_read" on public.orders;
create policy "orders_admin_read" on public.orders
  for select to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');
drop policy if exists "orders_admin_update" on public.orders;
create policy "orders_admin_update" on public.orders
  for update to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin')
  with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');
drop policy if exists "orders_customer_insert_compat" on public.orders;
create policy "orders_customer_insert_compat" on public.orders
  for insert to anon, authenticated with check (true);
-- Intentionally no public SELECT or public UPDATE policy for orders.

-- 4) Auction catalog can be read publicly; mutations are admin-only.
-- If your vault needs a customer claim flow, implement it through a secured,
-- atomic RPC/Edge Function rather than broad anonymous UPDATE permission.
drop policy if exists "auctions_public_read" on public.auctions;
create policy "auctions_public_read" on public.auctions
  for select to anon, authenticated using (true);
drop policy if exists "auctions_admin_write" on public.auctions;
create policy "auctions_admin_write" on public.auctions
  for all to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin')
  with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

-- 5) IMPORTANT: inspect and remove any older policies that are broader than these.
-- PostgreSQL policies are permissive by default: another broad policy can still
-- allow access even if the policies above look restrictive. Check Supabase
-- Dashboard > Database > Tables > [table] > Policies before going live.

-- 6) Force browser-created orders to pending even if a modified client sends
-- status='paid'. This trigger is a minimum guard, not full order validation.
create or replace function public.force_customer_order_pending()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') <> 'admin' then
    new.status := 'PENDING_PAYMENT_VERIFICATION';
  end if;
  return new;
end;
$$;

drop trigger if exists force_customer_order_pending_trigger on public.orders;
create trigger force_customer_order_pending_trigger
before insert on public.orders
for each row execute function public.force_customer_order_pending();


-- 7) Privacy-preserving order tracking for the public tracking page.
-- Requires public.orders columns: id, phone, status, created_at.
-- Returns only order ID and status when both order ID and phone last-4 match.
create or replace function public.track_order(p_order_id text, p_phone_last4 text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  matched_order record;
begin
  if p_order_id is null or length(trim(p_order_id)) < 5
     or p_phone_last4 is null or p_phone_last4 !~ '^\d{4}$' then
    return jsonb_build_object('found', false);
  end if;

  select id, status, created_at into matched_order
  from public.orders
  where upper(id::text) = upper(trim(p_order_id))
    and right(regexp_replace(coalesce(phone::text, ''), '\D', '', 'g'), 4) = p_phone_last4
  limit 1;

  if not found then
    return jsonb_build_object('found', false);
  end if;

  return jsonb_build_object(
    'found', true,
    'id', matched_order.id::text,
    'status', coalesce(matched_order.status, 'PROCESSING'),
    'created_at', matched_order.created_at
  );
end;
$$;

revoke all on function public.track_order(text, text) from public;
grant execute on function public.track_order(text, text) to anon, authenticated;
