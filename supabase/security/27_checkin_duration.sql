-- 27_checkin_duration.sql  —  meeting duration on checkins
--
-- Adds checkins.duration_minutes (nullable integer). The client now times each
-- check-in from when the resident finishes entering meeting details (the point
-- they're handed off to get a signature) to the moment the witness signature is
-- submitted, and stores that elapsed time in minutes alongside the record.
-- Existing rows are left null — there's no way to reconstruct their duration.
--
-- Additive and safe to run more than once.

alter table public.checkins
  add column if not exists duration_minutes integer;

notify pgrst, 'reload schema';
