# BhavDrop V2 security review notes

## Scope and limitations
This is a source-level review of the static frontend and supplied SQL files. It is **not** a live penetration test, and the Supabase project's actual policies, grants, database functions, Auth configuration, and production deployment have not been queried from this environment. Run `BhavDrop_Security_Audit_ReadOnly.sql` in the live Supabase SQL Editor and review every returned row.

## High-priority findings to verify/fix before accepting payments
1. **Unknown existing RLS policies may be permissive.** PostgreSQL permissive policies combine with OR semantics. A new restrictive policy does not cancel an older `USING (true)` / `WITH CHECK (true)` policy. Inspect all existing `orders`, `products`, `auctions`, `site_settings`, and related policies.
2. **Checkout is still client-originated.** The browser submits product items and total. The order is forced pending by the earlier compatibility trigger, but totals, coupon eligibility, product prices, stock reservation, and payment settlement must be validated in a trusted Edge Function/server before live sales.
3. **Payment verification is manual/not integrated.** Do not treat a UPI reference or browser state as proof of payment. Verify gateway webhooks server-side before marking paid.
4. **Legacy auction RPC requires a code/grant review.** `claim_auction_item` is SECURITY DEFINER and executable by anon/authenticated in the supplied schema. It locks an item, but it is not payment settlement. Confirm rate limiting, safe return data, owner/search_path and abuse behavior in the live database.
5. **Customer order linking is forward-looking.** Orders placed while signed in receive `user_id`; guest orders are not automatically attached to accounts. Guest tracking should return only minimal data after order ID + phone verification.
6. **Staff role bootstrap is privileged.** Add the first owner through SQL Editor. Do not expose a browser-side role assignment form or service-role key. Assign staff roles through controlled SQL or a separately secured owner-only server function.
7. **Support submissions are public by design.** Add rate limiting/bot protection at the edge or gateway before publishing to reduce spam. Guest submitters cannot read their ticket in the account UI; support staff handle follow-up.
8. **Exports contain personal data.** Restrict staff access, use exports only for legitimate business purposes, and delete local copies when no longer needed.

## Implemented V2 components
- Read-only SQL audit for RLS, table grants, function grants and SECURITY DEFINER functions.
- Additive migration for staff roles, minimal audit metadata, customer profile/preferences, account-linked orders, order timeline, drops, signups, support tickets and returns.
- Admin operations workbench for audit logs, order/shipping updates, support tickets, return status, drops and CSV exports.
- Customer sign-in, profile/preferences, linked order history and status timeline.
- Premium drop landing page and support/return forms.

## Validation performed here
Inline JavaScript syntax was checked with Node.js for the modified/new pages. The migration has not been executed against the live Supabase project, and browser/mobile visual QA and RLS role-matrix tests remain required.
