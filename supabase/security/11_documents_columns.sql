-- 11_documents_columns.sql
-- Backfill the document columns the app writes but the live tables lacked (found by the
-- schema audit). Without these, adding a document template and sending documents to
-- residents both error, and the auto-send of required docs on new-resident-add fails silently.
--
--   document_templates.url        link to the document/PDF
--   document_templates.required   auto-send to every new resident when true
--   resident_documents.template_name / template_desc / template_url
--                                 denormalized copy of the template at send time
--
-- Safe to run more than once.

alter table public.document_templates
  add column if not exists url text,
  add column if not exists required boolean default false;

alter table public.resident_documents
  add column if not exists template_name text,
  add column if not exists template_desc text,
  add column if not exists template_url text;

notify pgrst, 'reload schema';
