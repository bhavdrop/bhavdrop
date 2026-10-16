-- READ-ONLY: run in Supabase SQL Editor to inspect your existing schema/policies.
-- These queries do not change data.

-- 1) Columns/types/defaults for the tables used by the site.
select table_name, column_name, data_type, udt_name, is_nullable, column_default
from information_schema.columns
where table_schema = 'public'
  and table_name in ('products', 'orders', 'auctions', 'admin_config')
order by table_name, ordinal_position;

-- 2) Whether RLS is enabled/forced.
select n.nspname as schema_name, c.relname as table_name,
       c.relrowsecurity as rls_enabled, c.relforcerowsecurity as rls_forced
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname in ('products', 'orders', 'auctions', 'admin_config')
order by c.relname;

-- 3) Existing policies. Review broad policies before adding new ones.
select schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
from pg_policies
where schemaname = 'public'
  and tablename in ('products', 'orders', 'auctions', 'admin_config')
order by tablename, policyname;

-- 4) Relevant functions (names/signatures only; does not execute them).
select n.nspname as schema_name, p.proname as function_name,
       pg_get_function_identity_arguments(p.oid) as arguments,
       pg_get_function_result(p.oid) as return_type
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('claim_auction_item', 'track_order', 'verify_admin_pin')
order by p.proname;
