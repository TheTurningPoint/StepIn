-- 30_online_meeting_screenshot.sql  —  mandatory screenshot on online/virtual meeting check-ins
--
-- Adds checkins.screenshot_url (nullable text — a compressed JPEG data URL, same inline pattern as
-- sig_data_url; the client resizes to a 1000px long edge and re-encodes at ~55% quality before
-- storing it, so a multi-MB phone photo lands as a small text value). Only ever set on checkins where
-- is_online is true (see 29_online_meetings.sql).
--
-- Adds settings.online_screenshot_required (bool, default true) — mandatory for every org that turns
-- online meetings on. A house that wants the screenshot optional instead can flip this to false later,
-- no redeploy needed (same opt-out pattern as feature_curfew/feature_chores in 21_feature_flags.sql).
--
-- Additive and safe to run more than once.

alter table public.checkins
  add column if not exists screenshot_url text;

alter table public.settings
  add column if not exists online_screenshot_required boolean default true;

notify pgrst, 'reload schema';
