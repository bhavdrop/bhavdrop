-- BHAVDROP V2: staff RBAC, audit log, customer accounts, drops, support, returns, reports.
-- Additive migration. Back up first. Review against your live schema before applying.
-- Never place the Supabase service-role key in the frontend.

create extension if not exists pgcrypto;

-- Account-linked order history. Guest checkout remains supported; old orders stay unlinked.
alter table public.orders add column if not exists user_id uuid references auth.users(id) on delete set null;
alter table public.orders add column if not exists shipping_carrier text;
alter table public.orders add column if not exists tracking_number text;
alter table public.orders add column if not exists tracking_url text;
alter table public.orders add column if not exists updated_at timestamptz not null default now();
create index if not exists orders_user_created_idx on public.orders(user_id, created_at desc);

create table if not exists public.staff_roles (
 user_id uuid primary key references auth.users(id) on delete cascade,
 role text not null check (role in ('owner','admin','order_manager','product_manager','support_agent','analyst')),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);

create or replace function public.bhavdrop_has_role(allowed_roles text[])
returns boolean language sql stable security definer set search_path=public,auth as $$
 select coalesce(
   (select sr.role = any(allowed_roles) or sr.role in ('owner','admin')
    from public.staff_roles sr where sr.user_id=auth.uid()),
   (auth.jwt()->'app_metadata'->>'role'='admin' and 'admin'=any(allowed_roles))
 , false)
$$;
revoke all on function public.bhavdrop_has_role(text[]) from public;
grant execute on function public.bhavdrop_has_role(text[]) to anon, authenticated;

create table if not exists public.admin_audit_log (
 id bigint generated always as identity primary key,
 actor_id uuid,
 actor_email text,
 action text not null,
 table_name text not null,
 record_id text,
 changed_fields text[] not null default '{}',
 created_at timestamptz not null default now()
);
create index if not exists admin_audit_created_idx on public.admin_audit_log(created_at desc);

create table if not exists public.customer_profiles (
 user_id uuid primary key references auth.users(id) on delete cascade,
 display_name text,
 phone text,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create table if not exists public.customer_preferences (
 user_id uuid primary key references auth.users(id) on delete cascade,
 marketing_opt_in boolean not null default false,
 preferred_category text check (preferred_category in ('her','him','jewels') or preferred_category is null),
 updated_at timestamptz not null default now()
);

create table if not exists public.order_events (
 id bigint generated always as identity primary key,
 order_id text not null references public.orders(id) on delete cascade,
 status text not null,
 note text,
 visible_to_customer boolean not null default true,
 actor_id uuid,
 created_at timestamptz not null default now()
);
create index if not exists order_events_order_idx on public.order_events(order_id,created_at);

create table if not exists public.bhavdrop_drops (
 id uuid primary key default gen_random_uuid(),
 slug text not null unique,
 title text not null,
 eyebrow text,
 description text,
 hero_image_url text,
 starts_at timestamptz not null,
 ends_at timestamptz,
 status text not null default 'scheduled' check (status in ('draft','scheduled','live','ended','cancelled')),
 cta_label text not null default 'Explore drop',
 cta_url text not null default 'collection.html',
 sort_order integer not null default 100,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create table if not exists public.drop_signups (
 id bigint generated always as identity primary key,
 drop_id uuid not null references public.bhavdrop_drops(id) on delete cascade,
 email text not null,
 user_id uuid references auth.users(id) on delete set null,
 created_at timestamptz not null default now(),
 unique(drop_id,email)
);

create table if not exists public.support_tickets (
 id uuid primary key default gen_random_uuid(),
 user_id uuid references auth.users(id) on delete set null,
 order_id text references public.orders(id) on delete set null,
 customer_name text not null,
 customer_email text,
 customer_phone text,
 topic text not null check (topic in ('order','delivery','payment','return','product','account','other')),
 subject text not null,
 message text not null,
 status text not null default 'open' check (status in ('open','in_progress','waiting_customer','resolved','closed')),
 staff_note text,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create index if not exists support_tickets_created_idx on public.support_tickets(status,created_at desc);

create table if not exists public.return_requests (
 id uuid primary key default gen_random_uuid(),
 order_id text not null references public.orders(id) on delete cascade,
 user_id uuid references auth.users(id) on delete set null,
 reason text not null check (reason in ('damaged','wrong_item','size_fit','changed_mind','other')),
 details text,
 status text not null default 'requested' check (status in ('requested','approved','rejected','item_received','refunded','exchanged','closed')),
 staff_note text,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create index if not exists return_requests_created_idx on public.return_requests(status,created_at desc);

-- RLS for new private tables. Public policies are deliberately not created for audit logs or customer profiles.
alter table public.staff_roles enable row level security;
alter table public.admin_audit_log enable row level security;
alter table public.customer_profiles enable row level security;
alter table public.customer_preferences enable row level security;
alter table public.order_events enable row level security;
alter table public.bhavdrop_drops enable row level security;
alter table public.drop_signups enable row level security;
alter table public.support_tickets enable row level security;
alter table public.return_requests enable row level security;

drop policy if exists staff_roles_owner_manage on public.staff_roles;
create policy staff_roles_owner_manage on public.staff_roles for all to authenticated
 using (public.bhavdrop_has_role(array['owner'])) with check (public.bhavdrop_has_role(array['owner']));
drop policy if exists staff_roles_self_read on public.staff_roles;
create policy staff_roles_self_read on public.staff_roles for select to authenticated using (user_id=auth.uid());

drop policy if exists audit_owner_admin_read on public.admin_audit_log;
create policy audit_owner_admin_read on public.admin_audit_log for select to authenticated using (public.bhavdrop_has_role(array['owner','admin']));
-- No direct client inserts/updates/deletes to audit log; trusted triggers write it.

drop policy if exists customer_profile_self_all on public.customer_profiles;
create policy customer_profile_self_all on public.customer_profiles for all to authenticated using (user_id=auth.uid()) with check (user_id=auth.uid());
drop policy if exists customer_preferences_self_all on public.customer_preferences;
create policy customer_preferences_self_all on public.customer_preferences for all to authenticated using (user_id=auth.uid()) with check (user_id=auth.uid());

drop policy if exists order_events_customer_read on public.order_events;
create policy order_events_customer_read on public.order_events for select to authenticated using (
 visible_to_customer and exists(select 1 from public.orders o where o.id=order_events.order_id and o.user_id=auth.uid())
);
drop policy if exists order_events_staff_read on public.order_events;
create policy order_events_staff_read on public.order_events for select to authenticated using (public.bhavdrop_has_role(array['owner','admin','order_manager','support_agent']));
drop policy if exists order_events_staff_insert on public.order_events;
create policy order_events_staff_insert on public.order_events for insert to authenticated with check (public.bhavdrop_has_role(array['owner','admin','order_manager','support_agent']));

drop policy if exists drops_public_read on public.bhavdrop_drops;
create policy drops_public_read on public.bhavdrop_drops for select to anon,authenticated using (status in ('scheduled','live','ended') and (status <> 'scheduled' or starts_at <= now() + interval '180 days'));
drop policy if exists drops_staff_manage on public.bhavdrop_drops;
create policy drops_staff_manage on public.bhavdrop_drops for all to authenticated using (public.bhavdrop_has_role(array['owner','admin','product_manager'])) with check (public.bhavdrop_has_role(array['owner','admin','product_manager']));
drop policy if exists drop_signups_insert on public.drop_signups;
create policy drop_signups_insert on public.drop_signups for insert to anon,authenticated with check (length(trim(email)) between 5 and 254 and position('@' in email)>1 and (user_id is null or user_id=auth.uid()));
drop policy if exists drop_signups_staff_read on public.drop_signups;
create policy drop_signups_staff_read on public.drop_signups for select to authenticated using (public.bhavdrop_has_role(array['owner','admin','product_manager','analyst']));

drop policy if exists support_customer_insert on public.support_tickets;
create policy support_customer_insert on public.support_tickets for insert to anon,authenticated with check (status='open' and staff_note is null and (user_id is null or user_id=auth.uid()));
drop policy if exists support_customer_read_own on public.support_tickets;
create policy support_customer_read_own on public.support_tickets for select to authenticated using (user_id=auth.uid());
drop policy if exists support_staff_read on public.support_tickets;
create policy support_staff_read on public.support_tickets for select to authenticated using (public.bhavdrop_has_role(array['owner','admin','support_agent','order_manager']));
drop policy if exists support_staff_update on public.support_tickets;
create policy support_staff_update on public.support_tickets for update to authenticated using (public.bhavdrop_has_role(array['owner','admin','support_agent','order_manager'])) with check (public.bhavdrop_has_role(array['owner','admin','support_agent','order_manager']));

drop policy if exists returns_customer_insert on public.return_requests;
create policy returns_customer_insert on public.return_requests for insert to authenticated with check (user_id=auth.uid() and status='requested' and staff_note is null and exists(select 1 from public.orders o where o.id=return_requests.order_id and o.user_id=auth.uid()));
drop policy if exists returns_customer_read_own on public.return_requests;
create policy returns_customer_read_own on public.return_requests for select to authenticated using (user_id=auth.uid());
drop policy if exists returns_staff_read on public.return_requests;
create policy returns_staff_read on public.return_requests for select to authenticated using (public.bhavdrop_has_role(array['owner','admin','support_agent','order_manager']));
drop policy if exists returns_staff_update on public.return_requests;
create policy returns_staff_update on public.return_requests for update to authenticated using (public.bhavdrop_has_role(array['owner','admin','support_agent','order_manager'])) with check (public.bhavdrop_has_role(array['owner','admin','support_agent','order_manager']));

-- Link orders to signed-in users only if created in their own session. Existing guest checkout remains supported.
drop policy if exists orders_customer_read_own on public.orders;
create policy orders_customer_read_own on public.orders for select to authenticated using (user_id=auth.uid());
-- Existing broad permissive policies must be audited and removed separately; policies combine permissively by default.

-- Generic, privacy-minimizing audit trigger logs only operation, row ID, and changed field names (not values/addresses/phone).
create or replace function public.bhavdrop_write_audit_log()
returns trigger language plpgsql security definer set search_path=public,auth as $$
declare oldj jsonb; newj jsonb; rid text; fields text[];
begin
 oldj:=case when tg_op='INSERT' then '{}'::jsonb else to_jsonb(old) end;
 newj:=case when tg_op='DELETE' then '{}'::jsonb else to_jsonb(new) end;
 rid:=coalesce(newj->>'id',oldj->>'id',newj->>'slug',oldj->>'slug','unknown');
 select coalesce(array_agg(k order by k),'{}'::text[]) into fields from (
  select key as k from jsonb_each(newj) n where oldj->key is distinct from n.value
  union select key as k from jsonb_each(oldj) o where newj->key is distinct from o.value
 ) q;
 insert into public.admin_audit_log(actor_id,actor_email,action,table_name,record_id,changed_fields)
 values(auth.uid(),nullif(auth.jwt()->>'email',''),tg_op,tg_table_name,rid,fields);
 return case when tg_op='DELETE' then old else new end;
end $$;
revoke all on function public.bhavdrop_write_audit_log() from public;

do $$ declare t text; begin
 foreach t in array array['products','orders','auctions','coupons','site_settings','bhavdrop_drops','support_tickets','return_requests','staff_roles'] loop
  if to_regclass('public.'||t) is not null then
   execute format('drop trigger if exists bhavdrop_audit_trigger on public.%I',t);
   execute format('create trigger bhavdrop_audit_trigger after insert or update or delete on public.%I for each row execute function public.bhavdrop_write_audit_log()',t);
  end if;
 end loop;
end $$;

-- Append a customer-visible order timeline event when an order status changes.
create or replace function public.bhavdrop_order_status_event()
returns trigger language plpgsql security definer set search_path=public,auth as $$
begin
 if tg_op='INSERT' then
  insert into public.order_events(order_id,status,note,visible_to_customer,actor_id) values(new.id,new.status,'Order received',true,auth.uid());
 elsif new.status is distinct from old.status then
  insert into public.order_events(order_id,status,note,visible_to_customer,actor_id) values(new.id,new.status,'Order status updated',true,auth.uid());
 end if;
 return new;
end $$;
revoke all on function public.bhavdrop_order_status_event() from public;
drop trigger if exists bhavdrop_order_status_event_trigger on public.orders;
create trigger bhavdrop_order_status_event_trigger after insert or update of status on public.orders for each row execute function public.bhavdrop_order_status_event();

-- Restrict direct table grants for newly introduced private tables. RLS remains the row-level gate.
revoke all on public.admin_audit_log from anon,authenticated;
grant select on public.admin_audit_log to authenticated;
revoke all on public.staff_roles from anon;
grant select,insert,update,delete on public.staff_roles to authenticated;
revoke all on public.customer_profiles,public.customer_preferences from anon;
grant select,insert,update,delete on public.customer_profiles,public.customer_preferences to authenticated;
revoke all on public.order_events from anon;
grant select,insert on public.order_events to authenticated;
revoke all on public.bhavdrop_drops from anon;
grant select on public.bhavdrop_drops to anon,authenticated;
grant insert,update,delete on public.bhavdrop_drops to authenticated;
revoke all on public.drop_signups from anon;
grant insert on public.drop_signups to anon,authenticated;
grant select on public.drop_signups to authenticated;
revoke all on public.support_tickets from anon;
grant insert on public.support_tickets to anon,authenticated;
grant select,update on public.support_tickets to authenticated;
revoke all on public.return_requests from anon;
grant select,insert on public.return_requests to authenticated;
grant update on public.return_requests to authenticated;

-- BOOTSTRAP: after this migration, insert your own Auth user's UUID as owner using SQL Editor:
-- insert into public.staff_roles(user_id,role) values ('YOUR-AUTH-USER-UUID','owner')
-- on conflict(user_id) do update set role='owner',updated_at=now();
-- Never let a browser client set its own role. Only a trusted owner / SQL editor can assign roles.
-- Existing app_metadata.role='admin' remains accepted as a compatibility fallback.
