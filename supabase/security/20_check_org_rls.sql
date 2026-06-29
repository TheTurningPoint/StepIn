-- 20_check_org_rls.sql  (READ-ONLY — safe; changes nothing)
--
-- Answers ONE question: is multi-org isolation actually enforced, i.e. was 14_org_rls.sql run?
-- The existing audit_security.sql tells you RLS is ON and strangers are locked out, but it can't tell
-- org-isolation apart from the older house-only scoping (05_house_isolation.sql). This does.
--
-- Run it and read the `status` column per table:
--   'org-isolated (14 applied)'        -> GOOD. The policy checks the JWT `org` claim. Safe for
--                                         independent customer #2.
--   'house-only (05; 14 NOT applied)'  -> WARNING. Isolation is by house name only. Two orgs with a
--                                         same-named house could leak. Run 14_org_rls.sql, then have
--                                         everyone sign in once more, BEFORE onboarding a second org.
--   'authenticated-all / other'        -> a policy exists but scopes by neither org nor house.
--   'NO POLICIES'                      -> table has RLS but no policy (check audit_security.sql).
--
-- Every house-scoped table — especially residents, drug_tests, incidents, grievances,
-- resident_documents — should read 'org-isolated (14 applied)'. settings, document_templates, and
-- announcement_acks should too (org-wide match).

select t.tablename,
  case
    when bool_or(p.qual ilike '%''org''%' or coalesce(p.with_check, '') ilike '%''org''%')
      then 'org-isolated (14 applied)'
    when bool_or(p.qual ilike '%''house''%' or coalesce(p.with_check, '') ilike '%''house''%')
      then 'house-only (05; 14 NOT applied)'
    when count(p.policyname) = 0 then 'NO POLICIES'
    else 'authenticated-all / other'
  end as status,
  count(p.policyname) as policies
from pg_tables t
left join pg_policies p
  on p.schemaname = t.schemaname and p.tablename = t.tablename
where t.schemaname = 'public'
  and t.tablename in ('residents', 'checkins', 'curfew_log', 'chores', 'events', 'drug_tests',
    'incidents', 'announcements', 'announcement_acks', 'document_templates', 'resident_documents',
    'grievances', 'settings')
group by t.tablename
order by t.tablename;
