# BhavDrop — setup and repair instructions

Read `AUDIT_REPORT.md` first. This project is source-audited, but the live Supabase database and hosting environment have not been tested from this ZIP.

## 1. Files to keep/remove

Keep all storefront routes: `index.html`, `collection.html`, `new.html`, `her.html`, `him.html`, `jewels.html`, `sale.html`, `product.html`, `checkout.html`, `track.html`, `vault.html`, `admin.html`, `data.js`, and `supabase.js`.

- `store.js` is legacy and is not referenced by current pages. Do not load it alongside `data.js`; after checking no external page depends on it, remove it from production deployment.
- `test.html` is a read-only troubleshooting tool. Do not link it publicly; remove it from the production deployment after diagnostics.
- Keep `DATABASE_SCHEMA_REFERENCE.sql` as a reference for a new/empty database only.
- Review `supabase_security_setup.sql` against the real schema before applying it.

## 2. Local run

Use an HTTP server (ES modules do not work reliably from a `file://` URL):

```bash
python -m http.server 8000
```

Then open `http://localhost:8000`.

## 3. Supabase configuration

1. Open the Supabase project matching the URL in `supabase.js`.
2. Back up the database before changing tables or policies.
3. In SQL Editor, run the read-only queries in `DATABASE_INSPECTION.sql` to inspect columns, RLS state, and policies.
4. Compare the live schema with `DATABASE_SCHEMA_REFERENCE.sql`. Do not run the reference schema blindly on an existing/populated database; `CREATE TABLE IF NOT EXISTS` will not repair mismatched columns.
5. If this is a new/empty database, review and run `DATABASE_SCHEMA_REFERENCE.sql` first, then review and run `supabase_security_setup.sql`.
6. If the database already has tables, adapt the SQL to the existing column names and types first. In particular, `products.id` should match product URL IDs, `orders.id` must accept `BD-...` text IDs, and `auctions.id` must match the RPC argument type.
7. Create an admin user under Authentication → Users. Assign `app_metadata.role = admin` server-side (not `user_metadata`, not frontend JS). Sign out and sign in again after the role is assigned.
8. Review every existing RLS policy. A broad, old permissive policy can still allow access even after adding a narrower policy.
9. Add product rows in Table Editor using categories `her`, `him`, or `jewels`. Product cards support `images` (text array) and the legacy `image` field.
10. Add one auction row with `status='live'`, positive `start_price`, `floor_price`, `step_amount`, `step_seconds`, and a `starts_at` timestamp to test `vault.html`.

## 4. Checkout is intentionally payment-free for now

The checkout page currently creates an order with status `PENDING_PAYMENT_VERIFICATION`. It does not generate a QR code or ask for a UTR. Do not mark orders as paid or dispatch them from this state. Payment verification can be integrated later as requested.

Public order INSERT is temporarily allowed by the starter policy for this frontend flow; the trigger forces non-admin inserts to pending status. This does not validate prices or prevent spam. For a production store, move order creation and server-side price calculation into a secured Edge Function before accepting real orders.

## 5. Admin page status

The admin page uses Supabase Auth and requires `app_metadata.role = admin`; it shows product count, order count, pending/paid-status revenue calculation, and recent orders. It does **not** yet include add/edit/delete product forms or full order status editing. Those should be added after confirming the live table schema.

## 6. Verify pages

- Home/catalog pages: check products appear, categories filter correctly, images load, and Add to Bag increments the badge.
- Product page: open a product and add multiple sizes to the cart.
- Checkout: submit a test order; confirm it is pending in the database and appears in admin.
- Tracking: enter the order ID plus last four digits of the order phone. This requires `track_order` function from `supabase_security_setup.sql`.
- Vault: verify `claim_auction_item` exists and locks the auction row for 180 seconds. The included reference RPC expects `auctions.id` to be UUID.
- Admin: logged-out users and ordinary authenticated users must not see data; the admin user must be able to read products/orders.
- Test `test.html` only in development. It is read-only and will not test mutation permissions.

## 7. Current known limits

- No live Supabase schema or policies were available for verification.
- No real browser end-to-end test or payment integration was performed.
- Admin product CRUD and order status editing are not yet implemented.
- Product cards still use template HTML; keep product data controlled/trusted and consider rendering all database values via `textContent`/DOM methods before production.
- `store.js` is legacy; `data.js` is the current cart implementation.
