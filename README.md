# BhavDrop website bundle

This bundle contains the existing BhavDrop storefront plus the owner console and a homepage usability update.

## What's included
- Premium, responsive homepage styling and category navigation.
- Homepage product search and sorting (featured/newest, price low-high, price high-low).
- Browser-local wishlist buttons and wishlist filter.
- Product cards with clear prices, genuine computed discount labels when original prices are available, and Add to Bag actions.
- Owner console in `admin.html`: site maintenance mode, product CRUD, homepage promotional sections, reverse auction configuration, and order status management.
- `site-control.js` and `site-sections.js` for storefront maintenance display and homepage sections.
- Supabase setup SQL and audit/reference documents.

## Deploy
1. Back up the current GitHub repository and keep your existing Supabase project.
2. Upload the contents of the `bhavdrop-main` folder to the repository root (the HTML files should be at the root, not nested inside another `bhavdrop-main` folder if your host expects `index.html` at root).
3. In Supabase SQL Editor, run `BhavDrop_Admin_Panel_Setup.sql` once if you have not already done so. Do not run reset SQL on a live database.
4. Ensure the existing `products`, `orders`, and `auctions` tables have appropriate row-level security (RLS) policies. Only trusted admin accounts with server-managed `app_metadata.role = admin` should have write access.
5. Test the public homepage, product detail, add-to-cart, checkout submission, order tracking, auction flow, and admin CRUD in a private browser window before promoting the update.

## Important notes
- The wishlist is saved in the current browser's local storage; it is not synced across devices or accounts.
- Checkout currently submits an order marked `PENDING_PAYMENT_VERIFICATION`; payment processing is not enabled by this bundle. Do not mark an order paid until payment has been independently verified.
- The maintenance screen is a public-page gate, not a network-level shutdown. Supabase RLS must protect database operations.
- Never add a Supabase service-role key to client-side files. The public/publishable key is expected in the browser.
- Configure a real support phone/WhatsApp channel before advertising direct customer support.
- The admin console edits auction configuration/status; test the existing auction claim/settlement flow separately.
