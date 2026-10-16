-- BHAVDROP SECURITY AUDIT (READ-ONLY)
-- Run in Supabase SQL Editor. These queries inspect; they do not repair automatically.

-- A. RLS enabled/forced on all application tables
select n.nspname schema_name,c.relname table_name,c.relrowsecurity rls_enabled,c.relforcerowsecurity rls_forced
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relkind='r' order by c.relname;

-- B. All RLS policies. Pay special attention to broad USING(true)/WITH CHECK(true) policies.
select schemaname,tablename,policyname,permissive,roles,cmd,qual,with_check
from pg_policies where schemaname='public' order by tablename,policyname;

-- C. Table grants to browser roles (anon/authenticated); review private tables especially.
select table_schema,table_name,grantee,privilege_type
from information_schema.role_table_grants
where table_schema='public' and grantee in ('anon','authenticated')
order by table_name,grantee,privilege_type;

-- D. Function execute grants and security-definer status.
select n.nspname schema_name,p.proname function_name,pg_get_function_identity_arguments(p.oid) arguments,
       p.prosecdef security_definer,pg_get_userbyid(p.proowner) owner,
       coalesce(array_to_string(array_agg(distinct case when acl.grantee=0 then 'PUBLIC' else grantee.rolname end),', '),'') execute_grantees
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
left join lateral aclexplode(coalesce(p.proacl, acldefault('f',p.proowner))) acl on true
left join pg_roles grantee on grantee.oid=acl.grantee and acl.privilege_type='EXECUTE'
where n.nspname='public' and p.prokind='f'
group by n.nspname,p.proname,p.oid,p.prosecdef,p.proowner order by p.proname;

-- E. Functions with unsafe/missing search_path setting.
select n.nspname,p.proname,pg_get_function_identity_arguments(p.oid) args,
       p.prosecdef security_definer, p.proconfig
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and p.prosecdef and (p.proconfig is null or not exists(select 1 from unnest(p.proconfig) c where c like 'search_path=%'));

-- F. Orders table columns relevant to customer ownership and payment control.
select column_name,data_type,is_nullable,column_default
from information_schema.columns where table_schema='public' and table_name='orders'
 and column_name in ('id','user_id','name','phone','address','items','total','status','upi_ref','created_at','updated_at') order by ordinal_position;

-- G. Security-definer RPCs known to this project (inspect source and exact grants before release).
select p.proname,pg_get_function_identity_arguments(p.oid) args,pg_get_functiondef(p.oid) definition
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and p.proname in ('track_order','claim_auction_item','submit_product_review','bhavdrop_has_role');

-- Interpretation notes:
-- * PostgreSQL policies are permissive by default: a second broad policy can override a narrow policy.
-- * RLS does not compensate for inappropriate table/function grants.
-- * Review each SECURITY DEFINER function for strict input validation, fixed search_path, minimal return data and revoked PUBLIC execute.
-- * This script cannot certify the project safe by itself; inspect every returned row and test with anon, customer and each staff role.
