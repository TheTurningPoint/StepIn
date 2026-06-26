-- 08_lab_policy.sql
-- Per-house policy for the "send screenings to a lab" dashboard reminder.
--
--   lab_policy  'all'      remind for every screening not yet sent to a lab (default)
--               'positive' remind only for Positive screenings not yet sent
--               'off'      no lab reminder
--
-- Stored on the singleton settings row (id=1). Null is treated as 'all' in the app.
-- Safe to run more than once.

alter table public.settings
  add column if not exists lab_policy text;

notify pgrst, 'reload schema';
