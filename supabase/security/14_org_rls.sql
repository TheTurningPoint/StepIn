-- 14_org_rls.sql  —  STAGE 3 of multi-org isolation (ENFORCEMENT; run LAST)
--
-- Requires the login token to carry an `org` claim, which it only does AFTER Stage 2 (the updated
-- login2 function) is deployed and users have logged in again. RUN THIS ONLY AFTER:
--   1) 13_org_isolation.sql has been run (every table has `org`, backfilled), AND
--   2) the new login2 (issues the `org` claim) is deployed, AND
--   3) the new app build (sends `org` on login + stamps `org` on writes) is live.
--
-- IMPORTANT: tokens minted before Stage 2 have no `org` claim and will be DENIED by these policies.
-- That's expected — everyone signs in once more after this runs (old saved sessions get a one-time
-- "please sign in again"). Re-runnable. Revert: re-run 05_house_isolation.sql to drop back to
-- house-only scoping.
--
-- Shape: house-scoped tables require org match AND (owner OR same house). Org-wide tables
-- (settings, document_templates, announcement_acks) require org match only.

-- ---- house-scoped tables ----
drop policy if exists residents_auth on residents;
create policy residents_auth on residents for all to authenticated
  using ((auth.jwt()->>'org')=org and ((auth.jwt()->>'urole')='owner' or house=(auth.jwt()->>'house')))
  with check ((auth.jwt()->>'org')=org and ((auth.jwt()->>'urole')='owner' or house=(auth.jwt()->>'house')));

drop policy if exists checkins_auth on checkins;
create policy checkins_auth on checkins for all to authenticated
  using ((auth.jwt()->>'org')=org and ((auth.jwt()->>'urole')='owner' or house=(auth.jwt()->>'house')))
  with check ((auth.jwt()->>'org')=org and ((auth.jwt()->>'urole')='owner' or house=(auth.jwt()->>'house')));

drop policy if exists curfew_log_auth on curfew_log;
create policy curfew_log_auth on curfew_log for all to authenticated
  using ((auth.jwt()->>'org')=org and ((auth.jwt()->>'urole')='owner' or house=(auth.jwt()->>'house')))
  with check ((auth.jwt()->>'org')=org and ((auth.jwt()->>'urole')='owner' or house=(auth.jwt()->>'house')));

drop policy if exists chores_auth on chores;
create policy chores_auth on chores for all to authenticated
  using ((auth.jwt()->>'org')=org and ((auth.jwt()->>'urole')='owner' or house=(auth.jwt()->>'house')))
  with check ((auth.jwt()->>'org')=org and ((auth.jwt()->>'urole')='owner' or house=(auth.jwt()->>'house')));

drop policy if exists drug_tests_auth on drug_tests;
create policy drug_tests_auth on drug_tests for all to authenticated
  using ((auth.jwt()->>'org')=org and ((auth.jwt()->>'urole')='owner' or house=(auth.jwt()->>'house')))
  with check ((auth.jwt()->>'org')=org and ((auth.jwt()->>'urole')='owner' or house=(auth.jwt()->>'house')));

drop policy if exists incidents_auth on incidents;
create policy incidents_auth on incidents for all to authenticated
  using ((auth.jwt()->>'org')=org and ((auth.jwt()->>'urole')='owner' or house=(auth.jwt()->>'house')))
  with check ((auth.jwt()->>'org')=org and ((auth.jwt()->>'urole')='owner' or house=(auth.jwt()->>'house')));

drop policy if exists resident_documents_auth on resident_documents;
create policy resident_documents_auth on resident_documents for all to authenticated
  using ((auth.jwt()->>'org')=org and ((auth.jwt()->>'urole')='owner' or house=(auth.jwt()->>'house')))
  with check ((auth.jwt()->>'org')=org and ((auth.jwt()->>'urole')='owner' or house=(auth.jwt()->>'house')));

drop policy if exists grievances_auth on grievances;
create policy grievances_auth on grievances for all to authenticated
  using ((auth.jwt()->>'org')=org and ((auth.jwt()->>'urole')='owner' or house=(auth.jwt()->>'house')))
  with check ((auth.jwt()->>'org')=org and ((auth.jwt()->>'urole')='owner' or house=(auth.jwt()->>'house')));

-- events: house IS NULL = global within the org
drop policy if exists events_authenticated on events;
create policy events_authenticated on events for all to authenticated
  using ((auth.jwt()->>'org')=org and ((auth.jwt()->>'urole')='owner' or house=(auth.jwt()->>'house') or house is null))
  with check ((auth.jwt()->>'org')=org and ((auth.jwt()->>'urole')='owner' or house=(auth.jwt()->>'house') or house is null));

-- announcements: is_global = true visible to the whole org
drop policy if exists announcements_auth on announcements;
create policy announcements_auth on announcements for all to authenticated
  using ((auth.jwt()->>'org')=org and ((auth.jwt()->>'urole')='owner' or house=(auth.jwt()->>'house') or is_global=true))
  with check ((auth.jwt()->>'org')=org and ((auth.jwt()->>'urole')='owner' or house=(auth.jwt()->>'house')));

-- ---- org-wide tables (no house dimension) ----
drop policy if exists settings_auth on settings;
create policy settings_auth on settings for all to authenticated
  using ((auth.jwt()->>'org')=org) with check ((auth.jwt()->>'org')=org);

drop policy if exists document_templates_auth on document_templates;
create policy document_templates_auth on document_templates for all to authenticated
  using ((auth.jwt()->>'org')=org) with check ((auth.jwt()->>'org')=org);

drop policy if exists announcement_acks_auth on announcement_acks;
create policy announcement_acks_auth on announcement_acks for all to authenticated
  using ((auth.jwt()->>'org')=org) with check ((auth.jwt()->>'org')=org);

-- orgs stays anon-readable (login-screen branding); login_attempts/reminders_log stay
-- service-role only (no policies). Unchanged here.

notify pgrst, 'reload schema';
