-- 33_inquiries.sql  —  website inquiries (beeconworks.com/inquire.html and friends)
--
-- Written only by the `inquiry` Edge Function (service role). RLS is on with NO policies, so the public
-- anon key can neither read nor write this table directly — the function validates, rate-limits, stores
-- the row, and emails hello@beeconworks.com. Additive and safe to run more than once.

create table if not exists public.inquiries (
  id           bigint generated always as identity primary key,
  created_at   timestamptz not null default now(),
  name         text not null,
  email        text not null,
  phone        text,
  organization text,
  interest     text,          -- InStep / Continuum Compliance Group / Both / Other
  houses       text,
  message      text,
  source       text,          -- page the inquiry came from
  ip_hash      text,          -- SHA-256 of the sender IP, for rate limiting only
  emailed      boolean not null default false
);
alter table public.inquiries enable row level security;
create index if not exists inquiries_ip_idx on public.inquiries(ip_hash, created_at desc);
