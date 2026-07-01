-- 22_document_files.sql  —  store the ACTUAL document file (not just an external link)
--
-- Adds a Supabase Storage bucket for uploaded documents + the columns to reference the stored file,
-- so the exact version a resident signed is preserved (closes the "we only kept a link" gap). Files
-- are foldered by org (`<org>/<file>`) and Storage RLS isolates them by the login token's org claim,
-- same boundary as the rest of the app. Owners/managers upload; any signed-in user of that org can read.
--
-- Safe to run more than once.

-- 1) Columns to hold the stored file path (external `url` stays supported as a fallback).
alter table public.document_templates  add column if not exists file_path          text;
alter table public.resident_documents  add column if not exists template_file_path text;

-- 2) Private bucket for the files.
insert into storage.buckets (id, name, public) values ('documents', 'documents', false)
  on conflict (id) do nothing;

-- 3) Storage RLS: isolate by org (the first path segment must equal the token's org claim).
drop policy if exists documents_read on storage.objects;
create policy documents_read on storage.objects for select to authenticated
  using (bucket_id = 'documents' and (storage.foldername(name))[1] = (auth.jwt()->>'org'));

drop policy if exists documents_write on storage.objects;
create policy documents_write on storage.objects for insert to authenticated
  with check (bucket_id = 'documents'
    and (storage.foldername(name))[1] = (auth.jwt()->>'org')
    and (auth.jwt()->>'urole') in ('owner','manager'));

drop policy if exists documents_delete on storage.objects;
create policy documents_delete on storage.objects for delete to authenticated
  using (bucket_id = 'documents'
    and (storage.foldername(name))[1] = (auth.jwt()->>'org')
    and (auth.jwt()->>'urole') in ('owner','manager'));

notify pgrst, 'reload schema';
