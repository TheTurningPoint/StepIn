-- 09_resident_contact.sql
-- Resident contact + emergency info, and an email-reminder opt-in.
--
--   phone               resident's own phone
--   email               resident's email (used for reminders)
--   emergency_name      emergency contact name
--   emergency_phone     emergency contact phone
--   emergency_relation  relationship (e.g. mother, sponsor)
--   medical_notes       allergies / meds / naloxone (free text)
--   notify_opt_in       consent to receive email reminders (default false)
--
-- Safe to run more than once.

alter table public.residents
  add column if not exists phone text,
  add column if not exists email text,
  add column if not exists emergency_name text,
  add column if not exists emergency_phone text,
  add column if not exists emergency_relation text,
  add column if not exists medical_notes text,
  add column if not exists notify_opt_in boolean default false;

notify pgrst, 'reload schema';
