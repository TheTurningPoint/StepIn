-- 28_signature_location.sql  —  GPS location captured again at signature time
--
-- Adds checkins.sig_lat / checkins.sig_lng (nullable text, same shape as the existing lat/lng
-- captured at check-in). Since a check-in can now sit open through the whole meeting (see
-- 27_checkin_duration.sql's persistence work), the client re-checks GPS at the moment the witness
-- signature is submitted, so both ends of the check-in are location-stamped, not just the start.
-- Existing rows are left null — there's no way to reconstruct a location for something that
-- already happened.
--
-- Additive and safe to run more than once.

alter table public.checkins
  add column if not exists sig_lat text,
  add column if not exists sig_lng text;

notify pgrst, 'reload schema';
