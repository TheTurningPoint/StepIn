-- audit_security.sql  (READ-ONLY — safe; changes nothing)
--
-- Tells you the LIVE security state of every table: is Row Level Security ON, how many
-- policies exist, and whether any policy lets ANONYMOUS (public/anon) in. RLS is the only
-- thing protecting resident PII / screening / medical data, and there are revert scripts in
-- this folder that could have reopened things — so verify the real state, not the files.
--
-- Run QUERY A. How to read each row:
--   rls_on = false                 -> CRITICAL: table is open to anyone with the public key.
--   anon_or_public = true          -> CRITICAL: a policy lets anonymous users in
--                                     (EXCEPT `orgs`, which intentionally allows anon SELECT
--                                      for login-screen branding — that one is expected).
--   rls_on=true, policies>=1, anon_or_public=false -> good: locked to logged-in users.
--   reminders_log / login_attempts: rls_on=true, policies=0 -> good (service-role only).
--
-- If rows look wrong, the fix is to (re-)run 02_lockdown.sql (logged-in only) and then
-- 05_house_isolation.sql (each house sees only its own data). QUERY B shows policy detail so
-- we can tell house-isolation apart from authenticated-all.

-- ───────────── QUERY A — RLS state per table (run this; paste the result) ─────────────
select t.tablename,
       t.rowsecurity                                   as rls_on,
       count(p.policyname)                             as policies,
       coalesce(bool_or(p.roles::text ~ 'anon|public'), false) as anon_or_public
from pg_tables t
left join pg_policies p
  on p.schemaname = t.schemaname and p.tablename = t.tablename
where t.schemaname = 'public'
  and t.tablename in ('residents','orgs','settings','checkins','curfew_log','chores',
    'events','drug_tests','incidents','announcements','announcement_acks',
    'document_templates','resident_documents','grievances','reminders_log','login_attempts')
group by t.tablename, t.rowsecurity
order by t.tablename;

-- ───────────── QUERY B — policy detail (optional; shows house-isolation vs auth-all) ─────────────
-- select tablename, policyname, roles, cmd, qual
-- from pg_policies
-- where schemaname='public'
-- order by tablename, policyname;
