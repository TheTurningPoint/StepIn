-- HOUSE ISOLATION: scope each data table to the user's own house.
-- Owners (urole='owner') see/manage everything; managers & residents are limited
-- to their own house. Relies on the login token's claims:
--   auth.jwt()->>'urole'  = resident | manager | owner
--   auth.jwt()->>'house'  = the user's house (null for owners)
--
-- DB-only change; the app already sets `house` on inserts and filters in-memory.
-- Roll out the `grievances` block first as a canary (see chat), then run the rest.
-- Re-runnable. Revert with 06_revert_house_isolation.sql.

-- helper shape repeated below:
--   using/with check: (auth.jwt()->>'urole')='owner' OR house = (auth.jwt()->>'house')

-- residents
drop policy if exists residents_auth on residents;
create policy residents_auth on residents for all to authenticated
  using ((auth.jwt()->>'urole')='owner' or house = (auth.jwt()->>'house'))
  with check ((auth.jwt()->>'urole')='owner' or house = (auth.jwt()->>'house'));

-- checkins
drop policy if exists checkins_auth on checkins;
create policy checkins_auth on checkins for all to authenticated
  using ((auth.jwt()->>'urole')='owner' or house = (auth.jwt()->>'house'))
  with check ((auth.jwt()->>'urole')='owner' or house = (auth.jwt()->>'house'));

-- curfew_log
drop policy if exists curfew_log_auth on curfew_log;
create policy curfew_log_auth on curfew_log for all to authenticated
  using ((auth.jwt()->>'urole')='owner' or house = (auth.jwt()->>'house'))
  with check ((auth.jwt()->>'urole')='owner' or house = (auth.jwt()->>'house'));

-- chores
drop policy if exists chores_auth on chores;
create policy chores_auth on chores for all to authenticated
  using ((auth.jwt()->>'urole')='owner' or house = (auth.jwt()->>'house'))
  with check ((auth.jwt()->>'urole')='owner' or house = (auth.jwt()->>'house'));

-- drug_tests
drop policy if exists drug_tests_auth on drug_tests;
create policy drug_tests_auth on drug_tests for all to authenticated
  using ((auth.jwt()->>'urole')='owner' or house = (auth.jwt()->>'house'))
  with check ((auth.jwt()->>'urole')='owner' or house = (auth.jwt()->>'house'));

-- incidents
drop policy if exists incidents_auth on incidents;
create policy incidents_auth on incidents for all to authenticated
  using ((auth.jwt()->>'urole')='owner' or house = (auth.jwt()->>'house'))
  with check ((auth.jwt()->>'urole')='owner' or house = (auth.jwt()->>'house'));

-- resident_documents
drop policy if exists resident_documents_auth on resident_documents;
create policy resident_documents_auth on resident_documents for all to authenticated
  using ((auth.jwt()->>'urole')='owner' or house = (auth.jwt()->>'house'))
  with check ((auth.jwt()->>'urole')='owner' or house = (auth.jwt()->>'house'));

-- grievances (CANARY: run this block first)
drop policy if exists grievances_auth on grievances;
create policy grievances_auth on grievances for all to authenticated
  using ((auth.jwt()->>'urole')='owner' or house = (auth.jwt()->>'house'))
  with check ((auth.jwt()->>'urole')='owner' or house = (auth.jwt()->>'house'));

-- events (house IS NULL = global, visible to all)
drop policy if exists events_authenticated on events;
create policy events_authenticated on events for all to authenticated
  using ((auth.jwt()->>'urole')='owner' or house = (auth.jwt()->>'house') or house is null)
  with check ((auth.jwt()->>'urole')='owner' or house = (auth.jwt()->>'house') or house is null);

-- announcements (is_global = true visible to all; only owners post global)
drop policy if exists announcements_auth on announcements;
create policy announcements_auth on announcements for all to authenticated
  using ((auth.jwt()->>'urole')='owner' or house = (auth.jwt()->>'house') or is_global = true)
  with check ((auth.jwt()->>'urole')='owner' or house = (auth.jwt()->>'house'));

-- NOTE: settings (singleton), document_templates (org-wide), announcement_acks
-- (no house column) intentionally remain authenticated-all. orgs and login_attempts
-- are unchanged.
