# BhavDrop source audit and setup checklist

## What this package is
This archive contains all original storefront pages plus source-level repairs. The live Supabase database was not accessible from the ZIP, so database schema, RLS, deployed behavior, real order creation, and auction concurrency cannot be confirmed from source inspection alone.

## Included pages and purpose

- `index.html` — home page and featured catalog.
- `collection.html` — full catalog and category filters.
- `new.html` — newest products.
- `her.html` — women's collection.
- `him.html` — men's collection.
- `jewels.html` — jewelry collection.
- `sale.html` — discounted items; expects `original_price`.
- `product.html` — product details and size selection.
- `checkout.html` — order form. Payment integration is deliberately deferred; orders are submitted with pending status.
- `track.html` — order tracking requires order ID plus the last four digits of the phone number, using the `track_order` RPC.
- `vault.html` — reverse-auction UI; requires the `auctions` schema and `claim_auction_item` RPC.
- `admin.html` — Supabase Auth admin login and read-only order/product dashboard. It is NOT a product CRUD manager yet.
- `test.html` — read-only connection/table diagnostic. Do not link it publicly on production; use it only when troubleshooting.
- `data.js` — shared browser cart functions.
- `store.js` — legacy/local demo store code. Current pages do not load it; do not include it alongside `data.js` because it defines duplicate global cart functions.
- `supabase.js` — public Supabase client config.
- `supabase_security_setup.sql` — RLS/security starter plus order tracking RPC.
- `DATABASE_SCHEMA_REFERENCE.sql` — expected table structure and auction RPC for a new project; do not blindly run on a populated database.

## Source-level repairs in this package

1. Cart key normalized to `bd_cart`, with legacy `bd_cart_items` migration and compatibility for `image`/`images`, `qty`/`quantity`.
2. Product-card Add-to-Bag attributes use URL-encoded product JSON rather than raw JSON embedded in an HTML attribute.
3. Catalog images tolerate either `images[0]` or legacy `image` fields.
4. Collection category filtering no longer relies on an implicit global `event` variable.
5. Checkout is a plain order-submission flow for now. It does not show a fake QR/UTR payment flow and creates pending orders only.
6. Tracking does not query the full orders table from an anonymous browser. It calls `track_order` and requires order ID plus phone last four digits.
7. `test.html` is read-only; it no longer tests a hardcoded PIN or inserts/deletes test products.
8. Admin page no longer uses the hardcoded PIN/browser-session flag and requires Supabase Auth with server-managed `app_metadata.role = admin`.

## Database requirements

The storefront expects:

- `products`: `id`, `title`, `subtitle`, `category`, `price`, `original_price`, `image` and/or `images`, `description`, `badge`, `sizes`, `colors`, `created_at`.
- `orders`: `id`, `name`, `phone`, `address`, `items`, `total`, `status`, `upi_ref`, `created_at`.
- `auctions`: `id`, `title`, `description`, `image_url`, `start_price`, `floor_price`, `step_amount`, `step_seconds`, `starts_at`, `status`, `locked_at`, `locked_price`, `locked_by`.

The current admin dashboard expects `products` and `orders`; the tracking page expects the `track_order(text,text)` function; the vault expects `claim_auction_item(uuid,text,numeric)` and the auction columns above. `admin_config` and `verify_admin_pin` are obsolete and should not be used for login.

## What to do in Supabase (manual)

1. Make a backup before changing a populated database.
2. In SQL Editor, inspect actual tables/columns and current policies first. Use `DATABASE_SCHEMA_REFERENCE.sql` only for a new/empty project or adapt it manually to your existing schema.
3. Review `supabase_security_setup.sql`, align table/column names, then apply the policies/functions. Drop obsolete broad policies only after you understand what they allow. A permissive old policy can override the intended protection.
4. In Authentication → Users, create the admin account. Assign `app_metadata.role = admin` server-side only; never set it in browser code or user-editable metadata. Sign out/in after role assignment.
5. Ensure public users can read catalog products, but only admins can insert/update/delete products and read/manage orders. Public order creation is currently allowed for compatibility, but it must force pending status. Do not create public order SELECT or UPDATE policies.
6. Seed at least one product and one auction row with the expected columns, then test each page on a local HTTP server.
7. Keep `admin.html` and `test.html` out of public navigation. `admin.html` still relies on database RLS; hiding a link is not security.

## Page/file removal or addition

- Keep all storefront pages listed above; they each have a specific route.
- Do not load `store.js` on pages that already load `data.js`. Since it is not referenced by the current pages, you can remove `store.js` from deployment after confirming no other page imports it. Keep it in your backup/source archive.
- Keep `test.html` only in your development/staging copy; remove it from the production deployment after checks.
- No additional page is required to get the current routes working. Recommended future additions: `contact.html`, `privacy.html`, `terms.html`, and a polished `order-success.html`.
- Admin product add/edit/delete UI is not currently implemented; the current admin page shows stats and orders only. Add this after the live product table schema is confirmed.

## Validation performed here

- Checked JavaScript syntax for inline scripts in all HTML files using Node.js.
- Checked local `href` targets for missing local pages.
- These checks do not simulate a browser, call the live Supabase project, validate SQL against the live schema, or test mobile layout and checkout end-to-end.
