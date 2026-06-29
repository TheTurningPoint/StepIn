-- 13_org_isolation.sql  —  STAGE 1 of multi-org isolation (SAFE; no behavior change)
--
-- Adds an `org` tag (the subdomain string, e.g. 'theturningpoint') to every scoped table and
-- backfills all existing data to the one current real org. This does NOT change RLS, so the running
-- app is unaffected. Stage 2 (app+login start writing/reading `org`) and Stage 3 (14_org_rls.sql,
-- which ENFORCES `org` in RLS) come after.
--
-- Why: isolation today is by house NAME, so two independent orgs with a same-named house could see
-- each other's data. `org` gives a real tenant boundary. Safe to run more than once.

-- 1) Add the column everywhere it's needed.
alter table public.residents           add column if not exists org text;
alter table public.checkins            add column if not exists org text;
alter table public.curfew_log          add column if not exists org text;
alter table public.chores              add column if not exists org text;
alter table public.events              add column if not exists org text;
alter table public.drug_tests          add column if not exists org text;
alter table public.incidents           add column if not exists org text;
alter table public.announcements       add column if not exists org text;
alter table public.announcement_acks   add column if not exists org text;
alter table public.document_templates  add column if not exists org text;
alter table public.resident_documents  add column if not exists org text;
alter table public.grievances          add column if not exists org text;
alter table public.settings            add column if not exists org text;
alter table public.reminders_log       add column if not exists org text;

-- 2) Backfill all existing rows to the only current real org.
--    >>> If your subdomain is not 'theturningpoint', change it here before running. <<<
update public.residents          set org='theturningpoint' where org is null;
update public.checkins           set org='theturningpoint' where org is null;
update public.curfew_log         set org='theturningpoint' where org is null;
update public.chores             set org='theturningpoint' where org is null;
update public.events             set org='theturningpoint' where org is null;
update public.drug_tests         set org='theturningpoint' where org is null;
update public.incidents          set org='theturningpoint' where org is null;
update public.announcements      set org='theturningpoint' where org is null;
update public.announcement_acks  set org='theturningpoint' where org is null;
update public.document_templates set org='theturningpoint' where org is null;
update public.resident_documents set org='theturningpoint' where org is null;
update public.grievances         set org='theturningpoint' where org is null;
update public.settings           set org='theturningpoint' where org is null;
update public.reminders_log      set org='theturningpoint' where org is null;

-- 3) settings becomes per-org: keep the existing id=1 row (now tagged), enforce one row per org.
create unique index if not exists settings_org_idx on public.settings(org);

-- 3b) New orgs create their own settings row on first save, so settings.id must auto-generate
--     (the original singleton may have had a hand-set id=1 with no sequence).
create sequence if not exists settings_id_seq owned by public.settings.id;
select setval('settings_id_seq', coalesce((select max(id) from public.settings), 1));
alter table public.settings alter column id set default nextval('settings_id_seq');

notify pgrst, 'reload schema';
