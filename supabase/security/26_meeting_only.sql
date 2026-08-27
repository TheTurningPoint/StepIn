-- 26_meeting_only.sql  —  per-org "meeting-only mode" temporary master switch
--
-- Adds settings.meeting_only (default false — behavior unchanged for every existing org). When true,
-- the app strips down to just meeting check-in/finder, the resident Me tab, and manager resident
-- management + the attendance report; it overrides feature_curfew/feature_chores while on. Flip the
-- column back to false whenever full functionality should return — no redeploy needed.
--
-- Turns it on for The Turning Point (subdomain theturningpoint) per their request to run meeting-only
-- for now. To revert later, run:
--   update public.settings set meeting_only = false where org = 'theturningpoint';
--
-- Additive and safe to run more than once.

alter table public.settings
  add column if not exists meeting_only boolean default false;

update public.settings
  set meeting_only = true
  where org = 'theturningpoint';

notify pgrst, 'reload schema';
