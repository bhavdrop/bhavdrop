-- BHAVDROP ADMIN PANEL EXTENSION
-- Run in Supabase Dashboard > SQL Editor after the existing products/orders/auctions setup.
-- Safe for existing data: adds two tables and policies; does not drop your tables.

create table if not exists public.site_settings (
  id integer primary key check (id = 1),
  site_open boolean not null default true,
  maintenance_message text not null default 'We are making the store better. Please check back soon.',
  updated_at timestamptz not null default now()
);
insert into public.site_settings (id, site_open, maintenance_message)
values (1, true, 'We are making the store better. Please check back soon.')
on conflict (id) do nothing;

create table if not exists public.site_sections (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  eyebrow text,
  body text,
  image_url text,
  button_label text,
  button_url text,
  sort_order integer not null default 100,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists site_sections_order_idx on public.site_sections(sort_order, created_at);

alter table public.site_settings enable row level security;
alter table public.site_sections enable row level security;

drop policy if exists site_settings_public_read on public.site_settings;
create policy site_settings_public_read on public.site_settings
for select to anon, authenticated using (true);
drop policy if exists site_settings_admin_write on public.site_settings;
create policy site_settings_admin_write on public.site_settings
for all to authenticated
using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin')
with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

drop policy if exists site_sections_public_read_active on public.site_sections;
create policy site_sections_public_read_active on public.site_sections
for select to anon, authenticated using (is_active = true);
drop policy if exists site_sections_admin_read_all on public.site_sections;
create policy site_sections_admin_read_all on public.site_sections
for select to authenticated
using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');
drop policy if exists site_sections_admin_write on public.site_sections;
create policy site_sections_admin_write on public.site_sections
for all to authenticated
using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin')
with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

grant select on public.site_settings to anon, authenticated;
grant insert, update, delete on public.site_settings to authenticated;
grant select on public.site_sections to anon, authenticated;
grant insert, update, delete on public.site_sections to authenticated;

-- The existing products/orders/auctions tables must already have admin-only write policies.
-- Confirm their policies before using the admin panel. Never add a service_role key to frontend files.
