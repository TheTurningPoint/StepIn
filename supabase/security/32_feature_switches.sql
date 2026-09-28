-- 32_feature_switches.sql  —  an on/off switch for every optional feature
--
-- Extends 21_feature_flags.sql (curfew, chores) and 31_medications.sql (meds) so each organization can
-- run only the parts of InStep it uses. All default ON (meds stays default OFF), so running this changes
-- nothing for existing orgs. Set at provisioning (admin.html -> provisionorg) or by Beecon Works on
-- request; not exposed in owner Settings.
--
-- Deliberately NOT switchable: meeting check-ins (the core of the app) and the resident grievance
-- process (a resident's right to raise a concern is part of NARR resident rights).
--
-- The existing settings.meeting_only master switch still overrides all of these. Safe to run more than once.

alter table public.settings
  add column if not exists feature_screenings    boolean default true,
  add column if not exists feature_incidents     boolean default true,
  add column if not exists feature_documents     boolean default true,
  add column if not exists feature_events        boolean default true,
  add column if not exists feature_announcements boolean default true;

update public.settings set
  feature_screenings    = coalesce(feature_screenings, true),
  feature_incidents     = coalesce(feature_incidents, true),
  feature_documents     = coalesce(feature_documents, true),
  feature_events        = coalesce(feature_events, true),
  feature_announcements = coalesce(feature_announcements, true);

notify pgrst, 'reload schema';
