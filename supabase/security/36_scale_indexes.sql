-- 36_scale_indexes.sql  —  indexes for 50+ orgs / many houses
--
-- Every staff query filters by org + house (via RLS) and sorts by time; residents filter by
-- resident_id. These keep those lookups fast as tables grow. Safe to run more than once.
create index if not exists checkins_org_house_ts on public.checkins (org, house, ts desc);
create index if not exists curfew_org_house_ts on public.curfew_log (org, house, ts desc);
create index if not exists drug_tests_org_house_created on public.drug_tests (org, house, created_at desc);
create index if not exists drug_tests_resident on public.drug_tests (resident_id);
create index if not exists incidents_org_house_created on public.incidents (org, house, created_at desc);
create index if not exists grievances_org_house_created on public.grievances (org, house, created_at desc);
create index if not exists grievances_resident on public.grievances (resident_id);
create index if not exists resdocs_resident on public.resident_documents (resident_id);
create index if not exists resdocs_org_house on public.resident_documents (org, house);
create index if not exists residents_org_role on public.residents (org, role, house);
create index if not exists chores_org_house_week on public.chores (org, house, week_start);
create index if not exists acks_announcement on public.announcement_acks (announcement_id);
create index if not exists audit_log_org_changed on public.audit_log (org, changed_at desc);
