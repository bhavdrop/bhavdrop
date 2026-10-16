# BhavDrop storefront + owner console

This static HTML/JavaScript package uses Supabase for products, orders, auctions, site settings, sections, coupons, verified review submissions and aggregate analytics.

## Deploy
1. Back up your current GitHub repository and Supabase project.
2. Upload the contents of `bhavdrop-main/` to the repository root (so `index.html` is at the root).
3. Run `BhavDrop_Complete_Features_Setup.sql` in Supabase SQL Editor after reviewing it and backing up data. It is an additive migration and does not reset the database.
4. Ensure the Supabase admin account has server-managed `app_metadata.role = admin`; sign out and back in after changing it. Never expose the service-role key.
5. In Admin → Brand & Support, set the real WhatsApp number and support email.
6. In Admin → Products, set correct stock and visibility. Legacy products with blank stock remain untracked/available until you enter a real quantity; do not guess stock counts. Create coupons only after testing checkout.
7. Fill in real shipping/return/privacy terms in the policy pages before accepting orders.
8. Test on a private browser and a phone.

## Features in this package
- Premium editorial storefront, categories, search, sort, product detail gallery, size/color selection, cart, wishlist, guest checkout and order tracking.
- Product visibility and stock quantity, editable products and homepage sections, site maintenance gate, auction configuration, order status management.
- Coupons, review moderation, verified-review submission via delivered order ID and phone last four digits, approximate aggregate analytics with an event-based conversion estimate, configurable WhatsApp support and brand copy.
- About, Contact, Policies and Privacy pages.

## Critical limitations before real sales
- This is a static frontend, not a hosted backend application. The maintenance gate hides storefront pages but does not disable Supabase APIs. RLS remains essential.
- Coupon validation and totals in this static build are client-side convenience only. Before taking online payments, move price, stock, coupon, order creation and payment verification into a trusted Supabase Edge Function/server and a payment provider.
- The checkout currently submits orders as `PENDING_PAYMENT_VERIFICATION`; no payment gateway is configured.
- Auction configuration UI is not a complete secure auction settlement system. Test/secure atomic claiming, payment deadlines and race conditions separately.
- Analytics are approximate browser event counts and may be blocked by browser/network settings. They are not audited conversion metrics.
- Policy pages contain starter copy. Replace with your actual policies/business details before launch.
- Test the SQL against your current schema; it expects `orders.items` JSON and `orders.phone` and `orders.status` fields as used by the existing project.


## BhavDrop V2 additions
- `BhavDrop_V2_Security_Review.md`: source-level findings, limitations and pre-launch checks.
- `BhavDrop_Security_Audit_ReadOnly.sql`: read-only queries for RLS, table grants, function grants, SECURITY DEFINER functions and relevant order columns. Review results; it is not an automated certification.
- `BhavDrop_V2_Migration.sql`: additive tables and policies for staff roles, audit log, customer profiles/preferences, order timeline, drops/signups, support tickets and returns. Back up first and review live policies before applying.
- `account.html`: customer auth, profile/preferences, account-linked order history and return-request list.
- `drops.html`: premium editorial drop calendar and signup experience.
- `support.html`: support-ticket and signed-in return-request forms.
- `admin-operations.html`: staff workbench for audit history, support inbox, return statuses, drop management and CSV exports.

### V2 deployment notes
1. Run `BhavDrop_Security_Audit_ReadOnly.sql` first and inspect broad permissive policies. This is mandatory before assuming the database is safe.
2. Back up the project and review `BhavDrop_V2_Migration.sql`, then run it in Supabase SQL Editor. The migration does not remove unknown old policies. Since PostgreSQL policies combine permissively by default, explicitly remove any broad conflicting policies identified by the audit.
3. In Supabase Auth, find your own user UUID and run the owner bootstrap statement at the bottom of the V2 migration. Do not let users assign their own roles. Role assignment for additional staff should be done by a trusted owner-only server function or controlled SQL operation, not a public browser form.
4. New account-linked order history applies to orders placed while signed in; guest orders remain trackable using the existing ID + phone-last-four flow.
5. Existing guest checkout still creates a pending order from browser-supplied values. Before live sales, move order creation, authoritative pricing/coupon validation, stock reservation and payment verification into a trusted Edge Function/server. The V2 pages do not configure a payment gateway.
6. `admin-operations.html` exports customer/order data: restrict access, store exports securely, and export only for legitimate business purposes.
7. The drop signup uses the public anon key and basic RLS validation; production marketing email should use double opt-in and a privacy-compliant mailing provider.
8. Customer order tracking timeline requires an order to have `user_id` set. Old guest orders remain private and are not automatically assigned to accounts.
