-- EMERGENCY REVERT: reopen every table to anonymous access (the original,
-- insecure-but-working state). Use only if lockdown breaks the live app.
-- Run in the Supabase SQL Editor.

DROP POLICY IF EXISTS residents_auth ON residents;            CREATE POLICY open_residents ON residents FOR ALL USING (true);
DROP POLICY IF EXISTS checkins_auth ON checkins;              CREATE POLICY open_checkins ON checkins FOR ALL USING (true);
DROP POLICY IF EXISTS curfew_log_auth ON curfew_log;          CREATE POLICY open_curfew_log ON curfew_log FOR ALL USING (true);
DROP POLICY IF EXISTS chores_auth ON chores;                  CREATE POLICY open_chores ON chores FOR ALL USING (true);
DROP POLICY IF EXISTS drug_tests_auth ON drug_tests;          CREATE POLICY open_drug_tests ON drug_tests FOR ALL USING (true);
DROP POLICY IF EXISTS incidents_auth ON incidents;            CREATE POLICY open_incidents ON incidents FOR ALL USING (true);
DROP POLICY IF EXISTS announcements_auth ON announcements;    CREATE POLICY open_announcements ON announcements FOR ALL USING (true);
DROP POLICY IF EXISTS announcement_acks_auth ON announcement_acks; CREATE POLICY open_announcement_acks ON announcement_acks FOR ALL USING (true);
DROP POLICY IF EXISTS document_templates_auth ON document_templates; CREATE POLICY open_document_templates ON document_templates FOR ALL USING (true);
DROP POLICY IF EXISTS resident_documents_auth ON resident_documents; CREATE POLICY open_resident_documents ON resident_documents FOR ALL USING (true);
DROP POLICY IF EXISTS settings_auth ON settings;              CREATE POLICY open_settings ON settings FOR ALL USING (true);
DROP POLICY IF EXISTS events_authenticated ON events;         CREATE POLICY open_events ON events FOR ALL USING (true);
