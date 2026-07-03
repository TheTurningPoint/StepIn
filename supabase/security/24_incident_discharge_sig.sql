-- 24_incident_discharge_sig.sql  —  captured e-signatures on incidents & discharges
--
-- Brings incident reports and discharge records up to the same signed-at-the-moment standard the app already
-- uses for screenings, check-ins, and documents. Signatures are stored as JPEG data URLs (like admin_sig /
-- resident_sig). discharge_signed_by also fills the current gap that discharge didn't record WHO discharged.
--
-- Run BEFORE deploying the matching app update. Safe to run more than once.

alter table public.incidents  add column if not exists incident_sig        text;
alter table public.residents  add column if not exists discharge_sig       text;
alter table public.residents  add column if not exists discharge_signed_by text;

notify pgrst, 'reload schema';
