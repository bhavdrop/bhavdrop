# BhavDrop

Static storefront built with HTML, Tailwind CDN, JavaScript modules, and Supabase.

## Start locally

Run from this folder:

```bash
python -m http.server 8000
```

Open `http://localhost:8000`.

## Before deployment

Read `AUDIT_REPORT.md` and `SETUP_AND_REPAIR.md`. Inspect the live Supabase schema and RLS policies before applying SQL. `DATABASE_SCHEMA_REFERENCE.sql` is for a new/empty database; `supabase_security_setup.sql` must be reviewed against the actual schema first.

Payments are intentionally not integrated in this version. Checkout only submits an order with pending status. Do not treat an order as paid until a real payment is verified.
