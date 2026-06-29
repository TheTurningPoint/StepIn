-- 19_app_errors.sql  —  lightweight in-app error log (so the owner/vendor can see breakage)
--
-- The app's global error handler best-effort writes uncaught JS errors here (real logins only, never
-- demo). It's a diagnostic aid, not compliance data: no PII, just the message, a trimmed stack, the
-- page URL, and the browser string. Any logged-in user may INSERT a row for THEIR OWN org (so the
-- handler works for residents/managers too); only owners can READ their org's errors.
--
-- Safe to run more than once.

create table if not exists public.app_errors (
  id          bigint generated always as identity primary key,
  org         text,
  role        text,                  -- urole of the user who hit it
  user_id     text,                  -- residents.id (best effort)
  msg         text,                  -- error message (trimmed)
  stack       text,                  -- stack / source (trimmed)
  url         text,                  -- page URL
  ua          text,                  -- user agent
  created_at  timestamptz not null default now()
);
alter table public.app_errors enable row level security;
create index if not exists app_errors_org_idx on public.app_errors(org, created_at desc);

-- Any logged-in user can record an error for their own org (the handler runs as resident/manager/owner).
drop policy if exists app_errors_insert on public.app_errors;
create policy app_errors_insert on public.app_errors for insert to authenticated
  with check ((auth.jwt()->>'org') = org);

-- Only owners read their own org's errors.
drop policy if exists app_errors_read on public.app_errors;
create policy app_errors_read on public.app_errors for select to authenticated
  using ((auth.jwt()->>'org') = org and (auth.jwt()->>'urole') = 'owner');

notify pgrst, 'reload schema';
