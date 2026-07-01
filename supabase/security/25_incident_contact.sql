-- 25_incident_contact.sql  —  record whether next-of-kin was notified on an incident
--
-- When something serious happens (a medical emergency / overdose, a hospitalization, a death),
-- "did you notify the family, and when?" is a liability question the record should be able to answer.
-- These two columns capture that on an incident: a yes/no, plus a free note for who + when.
-- Both are OPTIONAL (unlike "authorities notified"), so they never block logging an incident.
-- The app writes them best-effort (a separate update after the insert), so incident logging keeps
-- working even if this migration hasn't been run yet.
--
-- Additive and safe to run more than once.

alter table public.incidents
  add column if not exists contact_notified      boolean,
  add column if not exists contact_notified_note text;

notify pgrst, 'reload schema';
