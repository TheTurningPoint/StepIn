-- audit_schema.sql  (READ-ONLY — safe to run; changes nothing)
--
-- Reconciles the live database with the columns the app actually reads/writes.
-- Run QUERY 2 first: it lists ONLY the columns the code expects but your DB is
-- missing. Ideally it returns 0 rows. Anything it returns is a real gap to fix.
-- QUERY 1 is the full dump if you want to eyeball everything.
--
-- (Most app reads use select('*'), so a missing column usually shows up as a blank
--  field rather than an error — except where a column is named explicitly, e.g. the
--  reminders function, which is why we audit.)

-- ─────────────────────────────────────────────────────────────────────────────
-- QUERY 2 — MISSING columns the code depends on  (run this one; paste the result)
-- ─────────────────────────────────────────────────────────────────────────────
with expected(table_name, column_name) as (values
  -- residents
  ('residents','id'),('residents','name'),('residents','pin'),('residents','role'),
  ('residents','house'),('residents','phase'),('residents','move_in_date'),
  ('residents','sobriety_date'),('residents','status'),('residents','discharge_date'),
  ('residents','discharge_reason'),('residents','phone'),('residents','email'),
  ('residents','emergency_name'),('residents','emergency_phone'),
  ('residents','emergency_relation'),('residents','medical_notes'),('residents','notify_opt_in'),
  -- orgs (name/subdomain/logo required; accent_color/primary_color are optional reads)
  ('orgs','subdomain'),('orgs','name'),('orgs','logo_url'),
  -- settings
  ('settings','id'),('settings','required'),('settings','house_name'),('settings','lab_policy'),
  -- checkins
  ('checkins','id'),('checkins','resident_id'),('checkins','resident_name'),
  ('checkins','meeting_type'),('checkins','meeting_name'),('checkins','address'),
  ('checkins','ts'),('checkins','signer_name'),('checkins','sig_data_url'),
  ('checkins','lat'),('checkins','lng'),('checkins','house'),
  -- curfew_log
  ('curfew_log','id'),('curfew_log','resident_id'),('curfew_log','resident_name'),
  ('curfew_log','action'),('curfew_log','ts'),('curfew_log','lat'),('curfew_log','lng'),
  ('curfew_log','late'),('curfew_log','excused'),('curfew_log','destination'),('curfew_log','house'),
  -- chores
  ('chores','id'),('chores','resident_id'),('chores','resident_name'),('chores','title'),
  ('chores','completed_date'),('chores','week_start'),('chores','house'),
  -- events
  ('events','id'),('events','title'),('events','event_date'),('events','event_time'),
  ('events','notes'),('events','house'),
  -- drug_tests
  ('drug_tests','id'),('drug_tests','resident_id'),('drug_tests','resident_name'),
  ('drug_tests','test_date'),('drug_tests','test_time'),('drug_tests','created_at'),
  ('drug_tests','test_types'),('drug_tests','result'),('drug_tests','notes'),
  ('drug_tests','administered_by'),('drug_tests','admin_sig'),('drug_tests','resident_sig'),
  ('drug_tests','house'),('drug_tests','lab_sent_date'),('drug_tests','lab_result'),
  ('drug_tests','lab_result_date'),('drug_tests','lab_name'),('drug_tests','lab_notes'),
  ('drug_tests','lab_specimen_id'),('drug_tests','lab_sealed'),
  -- incidents
  ('incidents','id'),('incidents','incident_type'),('incidents','incident_date'),
  ('incidents','incident_time'),('incidents','description'),('incidents','action_taken'),
  ('incidents','authorities_notified'),('incidents','resident_id'),('incidents','resident_name'),
  ('incidents','reported_by'),('incidents','house'),('incidents','created_at'),
  -- announcements
  ('announcements','id'),('announcements','message'),('announcements','created_by'),
  ('announcements','house'),('announcements','is_global'),('announcements','archived'),
  ('announcements','created_at'),
  -- announcement_acks
  ('announcement_acks','id'),('announcement_acks','announcement_id'),
  ('announcement_acks','resident_id'),('announcement_acks','resident_name'),
  -- document_templates
  ('document_templates','id'),('document_templates','name'),('document_templates','description'),
  ('document_templates','url'),('document_templates','required'),('document_templates','created_at'),
  -- resident_documents (the table that bit us — template_name was missing)
  ('resident_documents','id'),('resident_documents','resident_id'),
  ('resident_documents','resident_name'),('resident_documents','template_id'),
  ('resident_documents','template_name'),('resident_documents','template_desc'),
  ('resident_documents','template_url'),('resident_documents','status'),
  ('resident_documents','resident_sig'),('resident_documents','resident_signed_at'),
  ('resident_documents','manager_sig'),('resident_documents','manager_signed_at'),
  ('resident_documents','manager_name'),('resident_documents','house'),
  ('resident_documents','created_at'),
  -- grievances
  ('grievances','id'),('grievances','filed_by'),('grievances','resident_id'),
  ('grievances','category'),('grievances','description'),('grievances','status'),
  ('grievances','grievance_date'),('grievances','house'),('grievances','resolution'),
  ('grievances','resolved_by'),('grievances','resolved_at'),('grievances','created_at'),
  -- reminders_log
  ('reminders_log','id'),('reminders_log','resident_id'),('reminders_log','kind'),
  ('reminders_log','ref'),('reminders_log','sent_at')
)
select e.table_name, e.column_name as missing_column
from expected e
left join information_schema.columns c
  on c.table_schema = 'public'
 and c.table_name   = e.table_name
 and c.column_name  = e.column_name
where c.column_name is null
order by e.table_name, e.column_name;

-- ─────────────────────────────────────────────────────────────────────────────
-- QUERY 1 — full column dump (optional; for eyeballing)
-- ─────────────────────────────────────────────────────────────────────────────
-- select table_name, column_name, data_type
-- from information_schema.columns
-- where table_schema='public'
--   and table_name in ('residents','orgs','settings','checkins','curfew_log','chores',
--     'events','drug_tests','incidents','announcements','announcement_acks',
--     'document_templates','resident_documents','grievances','reminders_log')
-- order by table_name, ordinal_position;
