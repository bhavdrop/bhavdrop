# BhavDrop owner console

The owner console supports site maintenance mode, product CRUD with stock/visibility, homepage sections, reverse-auction configuration, order status management, coupons, review moderation, aggregate analytics, and configurable brand/contact settings.

Run `BhavDrop_Complete_Features_Setup.sql` after backing up your project. It adds columns/tables/policies and a verified review submission RPC; it does not reset existing data. Admin access requires a Supabase user with server-managed `app_metadata.role = admin`.

Important: coupon calculation in this static client is not payment-grade security; use an Edge Function/server to calculate totals and create orders before accepting online payments. Payment processing is not configured. The maintenance switch is a public-page gate, not a network-level shutdown. Auction settlement/concurrency must be separately secured and tested. Fill out the starter policy pages with your actual business terms before launch.
