-- 23_doc_signer.sql  —  full legal name + title on document signatures
--
-- The countersignature on a signed record should identify the signer by full legal name and capacity
-- (e.g. "Kendra Smith, Owner"), not just the account's login first name. These columns feed the
-- signature block without changing the login `name`. Set per staff member in their profile; captured
-- onto the document at countersign time.
--
-- Additive and safe to run more than once.

alter table public.residents
  add column if not exists doc_signer_name  text,
  add column if not exists doc_signer_title text;

alter table public.resident_documents
  add column if not exists manager_title text;

notify pgrst, 'reload schema';
