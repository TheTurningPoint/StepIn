-- 37_vendor_accounts.sql  —  vendor-only billing + sales-rep record per customer org
--
-- Beecon Works' own bookkeeping for each customer: who sold it (for commission), the per-house rate,
-- account status, and the Stripe reference. Customers never see this: RLS is on with NO policies and
-- the API roles have no grants, so only the service role (the secret-gated `accounts` / `provisionorg`
-- Edge Functions) can read or write it. Kept out of `settings`, which owners can read and edit.
-- Safe to run more than once.

create table if not exists public.vendor_accounts (
  org            text primary key,                  -- = orgs.subdomain
  sales_rep      text,                              -- who closed it (commission)
  rate_per_house numeric(10,2) not null default 99, -- monthly price per house
  status         text not null default 'trial'
                 check (status in ('trial','active','paused','cancelled')),
  billing_ref    text,                              -- Stripe customer / subscription id
  signed_on      date,
  notes          text,
  updated_at     timestamptz not null default now()
);
alter table public.vendor_accounts enable row level security;
revoke all on public.vendor_accounts from anon, authenticated;

-- Existing customers: one row each (rep/status filled in from the Accounts page).
insert into public.vendor_accounts (org, status)
  select subdomain, case when subdomain = 'demo' then 'paused' else 'active' end from public.orgs
  on conflict (org) do nothing;
