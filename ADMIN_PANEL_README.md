# BhavDrop Owner Console upgrade

## Included controls
- Site open/close switch with a custom maintenance message. Public storefront pages show a maintenance screen when closed; `admin.html` remains available to reopen the site.
- Product create/edit/delete, including category, prices, badge, image URL(s), sizes, colors and description.
- Homepage-managed promotional sections: add/edit, sort order, show/hide and delete. Active sections render on `index.html`.
- Reverse auction create/edit/delete with start price, floor price, decrement amount, interval, start time and status.
- Order review and status updates, plus dashboard counts and status-based revenue estimate.

## Setup
1. Keep a backup of your current project.
2. In Supabase Dashboard → SQL Editor, run `BhavDrop_Admin_Panel_Setup.sql` after your existing database setup. It adds `site_settings` and `site_sections`; it does not reset products/orders/auctions.
3. Verify the existing `products`, `orders`, and `auctions` tables have admin-only write policies. Existing user login must have server-managed `app_metadata.role = admin`.
4. Upload/deploy the full contents of this folder together. Keep the new `site-control.js` and `site-sections.js` alongside the HTML files.
5. Open `admin.html`, sign in, and test product CRUD, section rendering, auction settings, order status updates, and site close/open.
6. Test the site close/open switch in a private/guest browser window. When closed, the storefront shows the maintenance screen, while the owner console remains accessible.

## Important limitations
- The site-close feature is a frontend maintenance gate, not a network-level shutdown. Database APIs remain governed by Supabase RLS.
- The auction editor manages auction configuration/status only. It does not implement a new atomic claim/payment/settlement workflow; keep using the project's existing `claim_auction_item` flow and test concurrency separately.
- Payment processing is not included. Only mark an order paid/verified after independently confirming payment.
- Product delete is permanent and may make old order line items point to a removed product; consider retaining products when order history matters.
- The public Supabase publishable/anon key is expected in frontend code; never expose the service-role key.
