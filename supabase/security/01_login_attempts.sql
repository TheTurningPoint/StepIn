-- Tiny table backing the login rate-limiter in the login2 Edge Function.
-- Only the service role (the function) touches it; no public access.
create table if not exists public.login_attempts (
  name text primary key,
  attempts int not null default 0,
  window_start timestamptz not null default now()
);

alter table public.login_attempts enable row level security;
-- No anon/public policies on purpose: only the service role may read/write it.
