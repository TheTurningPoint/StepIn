-- 24_signed_file.sql  —  store the merged single-file signed PDF (original + signature page)
--
-- When a PDF document is completed (resident + countersigner both signed), the app can build ONE
-- file: the exact original PDF with a signature page appended (both signatures, full names, titles,
-- dates, attestation). That merged file is uploaded to the same private, org-foldered `documents`
-- bucket and referenced here. Building the merge is best-effort in the browser (pdf-lib) and always
-- falls back to the existing two-artifact model (original on file + HTML signature record), so this
-- column is purely additive — the app reads it and only writes it when a merge succeeds.
--
-- Additive and safe to run more than once.

alter table public.resident_documents
  add column if not exists signed_file_path text;

notify pgrst, 'reload schema';
