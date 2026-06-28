-- 12_house_coords.sql
-- Stores each house's physical location so curfew sign-ins can be checked against it.
-- Sign-in already captures the resident's GPS on every check-in (curfew_log.lat/lng), but
-- nothing compared it to the house, so "I'm home" was trusted from anywhere. With a house
-- location on file, the app soft-flags sign-ins that happen far from the house (it never
-- blocks, and with no location set it never flags — so no false alarms).
--
-- house_coords is a JSON map keyed by house name: {"Unity House":{"lat":"39.7","lng":"-104.9"}}
-- One row (settings is the singleton id=1), same pattern as house_name.
--
-- Safe to run more than once.

alter table public.settings
  add column if not exists house_coords jsonb;

notify pgrst, 'reload schema';
