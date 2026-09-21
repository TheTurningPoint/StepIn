-- 29_online_meetings.sql  —  online/virtual meeting check-ins
--
-- Adds settings.feature_online_meetings (default false — off for every existing org until a house
-- asks for it; no redeploy needed to turn on, same pattern as feature_curfew/feature_chores in
-- 21_feature_flags.sql). When on, the resident check-in flow offers an "online/virtual meeting"
-- checkbox instead of requiring an in-person witness signature.
--
-- Adds checkins.is_online (bool, default false) and checkins.platform (nullable text, e.g. "Zoom")
-- so online check-ins can be told apart from in-person ones in reports and compliance PDFs.
--
-- Additive and safe to run more than once.

alter table public.settings
  add column if not exists feature_online_meetings boolean default false;

alter table public.checkins
  add column if not exists is_online boolean default false,
  add column if not exists platform text;

notify pgrst, 'reload schema';
