-- 35_revert.sql  —  emergency undo of 35_role_based_rls.sql
--
-- Puts access back to the 14_org_rls.sql shape (org + house, token claims) so the app keeps working if
-- 35 ever blocks something it shouldn't. Leaves the harmless parts in place (helper functions, curfew
-- settings columns, unique-name index, dropped timesheets). After running this, run 14_org_rls.sql
-- and 31_medications.sql and 22_document_files.sql again to restore their original policies.

do $$ declare p record; begin
  for p in select schemaname, tablename, policyname from pg_policies
           where schemaname = 'public' and tablename in ('residents','checkins','curfew_log','chores','drug_tests','incidents',
             'grievances','resident_documents','events','announcements','announcement_acks','settings','document_templates',
             'medications','med_logs')
  loop execute format('drop policy if exists %I on %I.%I', p.policyname, p.schemaname, p.tablename); end loop;
end $$;

drop trigger if exists si_guard on public.residents;
drop trigger if exists si_guard on public.chores;
drop trigger if exists si_guard on public.resident_documents;
drop trigger if exists si_guard on public.curfew_log;
drop trigger if exists si_guard on public.checkins;

grant select, insert, update on public.residents to authenticated;

notify pgrst, 'reload schema';
