-- BhavDrop complete storefront features (non-destructive migration)
-- BACK UP Supabase first. Run after your existing BhavDrop schema and admin setup.
-- Does not drop existing tables or order/product data.

alter table public.products add column if not exists stock_quantity integer check (stock_quantity >= 0); -- NULL means legacy/untracked stock; set a real count in Admin
alter table public.products add column if not exists is_active boolean not null default true;
alter table public.products add column if not exists updated_at timestamptz not null default now();

alter table public.orders add column if not exists coupon_code text;
alter table public.orders add column if not exists discount_amount numeric(10,2) not null default 0;
alter table public.orders add column if not exists inventory_deducted boolean not null default false;

alter table public.site_settings add column if not exists whatsapp_number text;
alter table public.site_settings add column if not exists support_email text;
alter table public.site_settings add column if not exists announcement_text text default 'Free shipping on orders above ₹1,499';
alter table public.site_settings add column if not exists hero_title text default 'Discover your next favourite';
alter table public.site_settings add column if not exists hero_subtitle text default 'Thoughtfully selected pieces for everyday expression.';
alter table public.site_settings add column if not exists hero_image_url text;

create table if not exists public.coupons (
 id uuid primary key default gen_random_uuid(),
 code text not null unique,
 discount_type text not null check (discount_type in ('percent','fixed')),
 discount_value numeric(10,2) not null check (discount_value > 0),
 min_order numeric(10,2) not null default 0 check (min_order >= 0),
 max_discount numeric(10,2),
 starts_at timestamptz,
 expires_at timestamptz,
 usage_limit integer,
 usage_count integer not null default 0,
 is_active boolean not null default true,
 created_at timestamptz not null default now(),
 check (discount_type <> 'percent' or discount_value <= 100)
);

create table if not exists public.product_reviews (
 id uuid primary key default gen_random_uuid(),
 product_id text not null references public.products(id) on delete cascade,
 order_id text not null,
 customer_name text not null,
 rating integer not null check (rating between 1 and 5),
 review_text text not null,
 status text not null default 'pending' check (status in ('pending','approved','rejected')),
 created_at timestamptz not null default now(),
 unique(order_id, product_id)
);

create table if not exists public.analytics_events (
 id bigint generated always as identity primary key,
 event_name text not null check (event_name in ('page_view','product_view','add_to_cart','checkout_started','order_submitted')),
 page_path text,
 product_id text,
 session_id text,
 created_at timestamptz not null default now()
);
create index if not exists analytics_events_created_idx on public.analytics_events(created_at desc);
create index if not exists analytics_events_name_idx on public.analytics_events(event_name, created_at desc);

alter table public.products enable row level security;
alter table public.coupons enable row level security;
alter table public.product_reviews enable row level security;
alter table public.analytics_events enable row level security;

-- Public catalog reads only active products; admin sees all. Existing admin policies may remain.
drop policy if exists products_public_read on public.products;
drop policy if exists "products_public_read" on public.products;
drop policy if exists products_public_active_read on public.products;
create policy products_public_active_read on public.products for select to anon, authenticated using (is_active = true);
drop policy if exists products_admin_all on public.products;
create policy products_admin_all on public.products for all to authenticated
 using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin')
 with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

-- Public can read only active, in-date coupons; only admins can mutate.
drop policy if exists coupons_public_active_read on public.coupons;
create policy coupons_public_active_read on public.coupons for select to anon, authenticated
 using (is_active = true and (starts_at is null or starts_at <= now()) and (expires_at is null or expires_at > now()) and (usage_limit is null or usage_count < usage_limit));
drop policy if exists coupons_admin_all on public.coupons;
create policy coupons_admin_all on public.coupons for all to authenticated
 using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin')
 with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

-- Approved reviews are public; admins moderate. Reviews are submitted only through RPC below.
drop policy if exists reviews_public_approved_read on public.product_reviews;
create policy reviews_public_approved_read on public.product_reviews for select to anon, authenticated using (status = 'approved');
drop policy if exists reviews_admin_read on public.product_reviews;
create policy reviews_admin_read on public.product_reviews for select to authenticated using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');
drop policy if exists reviews_admin_update on public.product_reviews;
create policy reviews_admin_update on public.product_reviews for update to authenticated
 using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin') with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');
drop policy if exists reviews_admin_delete on public.product_reviews;
create policy reviews_admin_delete on public.product_reviews for delete to authenticated using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

-- Event insert is intentionally narrow; analytics rows contain no name, phone, address or payment data.
drop policy if exists analytics_public_insert on public.analytics_events;
create policy analytics_public_insert on public.analytics_events for insert to anon, authenticated with check (event_name in ('page_view','product_view','add_to_cart','checkout_started','order_submitted'));
drop policy if exists analytics_admin_read on public.analytics_events;
create policy analytics_admin_read on public.analytics_events for select to authenticated using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

grant select on public.products to anon, authenticated;
grant insert, update, delete on public.products to authenticated;
grant select on public.coupons to anon, authenticated;
grant insert, update, delete on public.coupons to authenticated;
grant select on public.product_reviews to anon, authenticated;
grant update, delete on public.product_reviews to authenticated;
grant insert on public.analytics_events to anon, authenticated;
grant select on public.analytics_events to authenticated;

-- Customer review submission requires a delivered order, matching last 4 phone digits,
-- and the product must exist in that order's items JSON. No raw order table read is exposed.
create or replace function public.submit_product_review(
 p_order_id text, p_phone_last4 text, p_product_id text, p_customer_name text, p_rating integer, p_review_text text
) returns uuid language plpgsql security definer set search_path = public as $$
declare v_order public.orders%rowtype; v_review_id uuid;
begin
 if length(coalesce(p_phone_last4,'')) <> 4 or p_phone_last4 !~ '^[0-9]{4}$' then raise exception 'Enter the last four digits of the order phone number.'; end if;
 if p_rating < 1 or p_rating > 5 then raise exception 'Rating must be between 1 and 5.'; end if;
 if length(trim(coalesce(p_customer_name,''))) < 2 or length(trim(coalesce(p_review_text,''))) < 5 then raise exception 'Please enter a name and a review of at least 5 characters.'; end if;
 select * into v_order from public.orders where id = p_order_id and right(regexp_replace(coalesce(phone,''),'[^0-9]','','g'),4) = p_phone_last4 limit 1;
 if not found then raise exception 'Order could not be verified. Check the order ID and phone digits.'; end if;
 if upper(coalesce(v_order.status,'')) <> 'DELIVERED' then raise exception 'Reviews are available after the order is marked delivered.'; end if;
 if not exists (select 1 from jsonb_array_elements(coalesce(v_order.items,'[]'::jsonb)) item where coalesce(item->>'id',item->>'product_id','') = p_product_id) then raise exception 'This product was not found in that order.'; end if;
 insert into public.product_reviews(product_id,order_id,customer_name,rating,review_text,status)
 values(p_product_id,p_order_id,trim(p_customer_name),p_rating,trim(p_review_text),'pending') returning id into v_review_id;
 return v_review_id;
end; $$;
revoke all on function public.submit_product_review(text,text,text,text,integer,text) from public;
grant execute on function public.submit_product_review(text,text,text,text,integer,text) to anon, authenticated;

-- Note: coupon discounts are displayed client-side in this static build. Before accepting online
-- payments, move coupon validation, stock reservation, totals and order creation into a trusted
-- server/Edge Function so browser requests cannot forge totals or redeem coupons concurrently.


-- Decrement tracked stock once when an order is marked paid/verified. Legacy products with
-- NULL stock_quantity are untracked and are not decremented until the owner sets a real count.
create or replace function public.bhavdrop_deduct_inventory_on_paid() returns trigger
language plpgsql security definer set search_path = public as $$
declare item jsonb; pid text; qty integer; changed integer;
begin
 if lower(coalesce(new.status,'')) in ('paid_verified','paid','processing','dispatched','delivered','completed')
    and lower(coalesce(old.status,'')) not in ('paid_verified','paid','processing','dispatched','delivered','completed')
    and coalesce(new.inventory_deducted,false)=false then
   for item in select value from jsonb_array_elements(coalesce(new.items,'[]'::jsonb)) loop
     pid := coalesce(item->>'id',item->>'product_id','');
     qty := greatest(1,coalesce(nullif(item->>'qty','')::integer,nullif(item->>'quantity','')::integer,1));
     if pid <> '' then
       update public.products set stock_quantity = stock_quantity - qty, updated_at = now()
        where id = pid and stock_quantity is not null and stock_quantity >= qty;
       get diagnostics changed = row_count;
       if changed = 0 and exists(select 1 from public.products where id=pid and stock_quantity is not null) then
         raise exception 'Insufficient stock for product %; verify inventory before marking this order paid.', pid;
       end if;
     end if;
   end loop;
   new.inventory_deducted := true;
 end if;
 return new;
end; $$;
drop trigger if exists bhavdrop_deduct_inventory_on_paid_trigger on public.orders;
create trigger bhavdrop_deduct_inventory_on_paid_trigger before update of status on public.orders
for each row execute function public.bhavdrop_deduct_inventory_on_paid();


-- Count coupon usage when an order first becomes paid/verified (not when a pending order is created).
create or replace function public.bhavdrop_count_coupon_use_on_paid() returns trigger
language plpgsql security definer set search_path = public as $$
declare c public.coupons%rowtype;
begin
 if lower(coalesce(new.status,'')) in ('paid_verified','paid','processing','dispatched','delivered','completed')
    and lower(coalesce(old.status,'')) not in ('paid_verified','paid','processing','dispatched','delivered','completed')
    and nullif(trim(coalesce(new.coupon_code,'')),'') is not null then
   select * into c from public.coupons where code=upper(trim(new.coupon_code)) for update;
   if not found or not c.is_active then raise exception 'Coupon is no longer active.'; end if;
   if c.starts_at is not null and c.starts_at > now() then raise exception 'Coupon is not active yet.'; end if;
   if c.expires_at is not null and c.expires_at <= now() then raise exception 'Coupon has expired.'; end if;
   if c.usage_limit is not null and c.usage_count >= c.usage_limit then raise exception 'Coupon usage limit has been reached.'; end if;
   update public.coupons set usage_count=usage_count+1 where id=c.id;
 end if;
 return new;
end; $$;
drop trigger if exists bhavdrop_count_coupon_use_on_paid_trigger on public.orders;
create trigger bhavdrop_count_coupon_use_on_paid_trigger before update of status on public.orders
for each row execute function public.bhavdrop_count_coupon_use_on_paid();
