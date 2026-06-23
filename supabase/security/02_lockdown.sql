-- LOCKDOWN: remove anonymous/public access from data tables; allow only
-- logged-in (token-bearing) users. Run in the Supabase SQL Editor.
--
-- Notes:
--   * orgs keeps anon SELECT (login-screen branding) + authenticated SELECT.
--   * login_attempts stays service-role only (no policy).
--   * events is already locked (canary).
--   * Re-runnable: drops the authenticated policy before recreating it.

-- residents
DROP POLICY IF EXISTS open_residents ON residents;
DROP POLICY IF EXISTS anon_all_residents ON residents;
DROP POLICY IF EXISTS "allow all" ON residents;
DROP POLICY IF EXISTS residents_auth ON residents;
CREATE POLICY residents_auth ON residents FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- checkins
DROP POLICY IF EXISTS open_checkins ON checkins;
DROP POLICY IF EXISTS anon_all_checkins ON checkins;
DROP POLICY IF EXISTS "allow all" ON checkins;
DROP POLICY IF EXISTS checkins_auth ON checkins;
CREATE POLICY checkins_auth ON checkins FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- curfew_log
DROP POLICY IF EXISTS open_curfew_log ON curfew_log;
DROP POLICY IF EXISTS anon_all_curfew_log ON curfew_log;
DROP POLICY IF EXISTS "allow all" ON curfew_log;
DROP POLICY IF EXISTS curfew_log_auth ON curfew_log;
CREATE POLICY curfew_log_auth ON curfew_log FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- chores
DROP POLICY IF EXISTS open_chores ON chores;
DROP POLICY IF EXISTS anon_all_chores ON chores;
DROP POLICY IF EXISTS "allow all" ON chores;
DROP POLICY IF EXISTS chores_auth ON chores;
CREATE POLICY chores_auth ON chores FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- drug_tests
DROP POLICY IF EXISTS open_drug_tests ON drug_tests;
DROP POLICY IF EXISTS anon_all_drug_tests ON drug_tests;
DROP POLICY IF EXISTS "allow all" ON drug_tests;
DROP POLICY IF EXISTS drug_tests_auth ON drug_tests;
CREATE POLICY drug_tests_auth ON drug_tests FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- incidents
DROP POLICY IF EXISTS open_incidents ON incidents;
DROP POLICY IF EXISTS anon_all_incidents ON incidents;
DROP POLICY IF EXISTS "allow all" ON incidents;
DROP POLICY IF EXISTS incidents_auth ON incidents;
CREATE POLICY incidents_auth ON incidents FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- announcements
DROP POLICY IF EXISTS open_announcements ON announcements;
DROP POLICY IF EXISTS anon_all_announcements ON announcements;
DROP POLICY IF EXISTS "allow all" ON announcements;
DROP POLICY IF EXISTS announcements_auth ON announcements;
CREATE POLICY announcements_auth ON announcements FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- announcement_acks
DROP POLICY IF EXISTS open_announcement_acks ON announcement_acks;
DROP POLICY IF EXISTS anon_all_announcement_acks ON announcement_acks;
DROP POLICY IF EXISTS "allow all" ON announcement_acks;
DROP POLICY IF EXISTS announcement_acks_auth ON announcement_acks;
CREATE POLICY announcement_acks_auth ON announcement_acks FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- document_templates
DROP POLICY IF EXISTS open_document_templates ON document_templates;
DROP POLICY IF EXISTS anon_all_document_templates ON document_templates;
DROP POLICY IF EXISTS "allow all" ON document_templates;
DROP POLICY IF EXISTS document_templates_auth ON document_templates;
CREATE POLICY document_templates_auth ON document_templates FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- resident_documents
DROP POLICY IF EXISTS open_resident_documents ON resident_documents;
DROP POLICY IF EXISTS anon_all_resident_documents ON resident_documents;
DROP POLICY IF EXISTS "allow all" ON resident_documents;
DROP POLICY IF EXISTS resident_documents_auth ON resident_documents;
CREATE POLICY resident_documents_auth ON resident_documents FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- settings
DROP POLICY IF EXISTS open_settings ON settings;
DROP POLICY IF EXISTS anon_all_settings ON settings;
DROP POLICY IF EXISTS "allow all" ON settings;
DROP POLICY IF EXISTS settings_auth ON settings;
CREATE POLICY settings_auth ON settings FOR ALL TO authenticated USING (true) WITH CHECK (true);
