-- REVERT house isolation: restore authenticated-all (any logged-in user, any house).
-- Strangers stay locked out (this only loosens the per-house rule, not the login gate).
-- Run in the Supabase SQL Editor if isolation breaks legitimate access.

drop policy if exists residents_auth on residents;            create policy residents_auth on residents for all to authenticated using (true) with check (true);
drop policy if exists checkins_auth on checkins;              create policy checkins_auth on checkins for all to authenticated using (true) with check (true);
drop policy if exists curfew_log_auth on curfew_log;          create policy curfew_log_auth on curfew_log for all to authenticated using (true) with check (true);
drop policy if exists chores_auth on chores;                  create policy chores_auth on chores for all to authenticated using (true) with check (true);
drop policy if exists drug_tests_auth on drug_tests;          create policy drug_tests_auth on drug_tests for all to authenticated using (true) with check (true);
drop policy if exists incidents_auth on incidents;            create policy incidents_auth on incidents for all to authenticated using (true) with check (true);
drop policy if exists resident_documents_auth on resident_documents; create policy resident_documents_auth on resident_documents for all to authenticated using (true) with check (true);
drop policy if exists grievances_auth on grievances;          create policy grievances_auth on grievances for all to authenticated using (true) with check (true);
drop policy if exists events_authenticated on events;         create policy events_authenticated on events for all to authenticated using (true) with check (true);
drop policy if exists announcements_auth on announcements;    create policy announcements_auth on announcements for all to authenticated using (true) with check (true);
