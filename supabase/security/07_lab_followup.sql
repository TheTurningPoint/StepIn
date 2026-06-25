-- 07_lab_followup.sql
-- Adds structured lab-confirmation follow-up to screenings (drug_tests).
--
-- The instant cup/breath test is presumptive; positives (or disputed results) are
-- often sent to a lab and confirmed days later. These columns record that follow-up:
--   lab_sent_date    date the specimen was sent to the lab (presence = "sent")
--   lab_result       'confirmed' | 'negative' | 'inconclusive' (null = pending)
--   lab_result_date  date the lab result came back
--   lab_name         optional lab name (e.g. Quest)
--   lab_notes        optional confirmation notes (panel, levels, etc.)
--   lab_specimen_id  specimen/sample ID printed on the cup/label (matches lab report)
--   lab_sealed       specimen sealed in the resident's presence (chain-of-custody attestation)
--
-- Safe to run more than once (IF NOT EXISTS). Existing rows get NULLs and render
-- as "Send to lab" with no migration needed.

alter table public.drug_tests
  add column if not exists lab_sent_date   date,
  add column if not exists lab_result      text,
  add column if not exists lab_result_date date,
  add column if not exists lab_name        text,
  add column if not exists lab_notes       text,
  add column if not exists lab_specimen_id text,
  add column if not exists lab_sealed      boolean;

-- Tell PostgREST to pick up the new columns immediately.
notify pgrst, 'reload schema';
