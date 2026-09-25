-- 29_online_meetings.sql  —  online meeting check-ins
--
-- Adds checkins.is_online (boolean, default false) and checkins.topic_description (text).
-- Online meetings have no one present to sign, so instead of a witness signature the resident
-- describes what the meeting covered. Those rows are saved with is_online = true and
-- topic_description set, and with no signer_name / sig_data_url — so both are made nullable
-- here in case they were ever created NOT NULL.
--
-- Additive and safe to run more than once.

alter table public.checkins
  add column if not exists is_online boolean not null default false,
  add column if not exists topic_description text;

alter table public.checkins alter column signer_name drop not null;
alter table public.checkins alter column sig_data_url drop not null;

notify pgrst, 'reload schema';
