-- 35_role_based_rls.sql  —  role-aware access: residents see/do only their own things
--
-- WHY: until now every policy checked org + house but never the user's ROLE. A signed-in resident
-- holding their own login token could, outside the app, read every PIN hash in their house, change
-- their own role to owner, and edit or delete screenings, incidents, grievances and curfew records.
-- Tokens also stayed valid for 30 days after a discharge/archive because no policy checked status.
--
-- WHAT THIS DOES
--   1. Role and house come from the residents table (via si_role()/si_house()), not from the token.
--      A discharged/archived account gets null => every policy denies, immediately, even with a
--      still-unexpired token. A role/house change takes effect on the next request.
--   2. Residents: read only their own rows (plus house chores/events/notes and org settings/templates);
--      write only what the app lets them do (check-in, curfew sign in/out, acknowledge a note, mark
--      their chore done, sign their document, file a grievance, set their own recovery date/email).
--   3. Staff (manager = own house, owner = whole org) keep today's access. Deleting compliance
--      records (residents, check-ins, curfew, screenings, incidents, grievances, signed documents)
--      is owner-only. Managers can no longer create/alter manager or owner accounts.
--   4. pin_hash is no longer readable or writable through the API at all (only login2 / set_pin).
--   5. Curfew sign-ins by residents are server-stamped: time = server time, never self-excused, and
--      "late" is computed in the database from the org's curfew settings + time zone (new columns).
--   6. One active account per name per org (login is by name), drops the unused anon-writable
--      `timesheets` table, and tightens set_pin (managers can reset residents only).
--
-- Compatible with the app build already live: every read/write the current index.html performs
-- for each role is still allowed. Re-runnable, and written without DROP statements: existing policies
-- are tightened in place (ALTER POLICY), resident permissions are added as extra policies, and
-- owner-only deletes are RESTRICTIVE policies (they AND with everything else). Revert: 35_revert.sql.

-- ---------------------------------------------------------------- helpers
create or replace function public.si_role() returns text
language sql stable security definer set search_path = public as $$
  select r.role from public.residents r
  where r.id = (auth.jwt()->>'sub') and r.org = (auth.jwt()->>'org')
    and r.status is distinct from 'discharged'
$$;
create or replace function public.si_house() returns text
language sql stable security definer set search_path = public as $$
  select r.house from public.residents r
  where r.id = (auth.jwt()->>'sub') and r.org = (auth.jwt()->>'org')
    and r.status is distinct from 'discharged'
$$;
revoke all on function public.si_role(), public.si_house() from public, anon;
grant execute on function public.si_role(), public.si_house() to authenticated, service_role;

-- ---------------------------------------------------------------- curfew settings (per org)
alter table public.settings
  add column if not exists timezone          text,               -- IANA, e.g. America/Denver
  add column if not exists curfew_p1_weekday text default '21:00',
  add column if not exists curfew_p1_weekend text default '22:00', -- weekend = Fri & Sat nights
  add column if not exists curfew_p2_weekday text default '22:00',
  add column if not exists curfew_p2_weekend text default '23:00';
update public.settings set timezone = 'America/Denver' where org = 'theturningpoint' and timezone is null;

-- Is a sign-in at instant ts late for this phase, under org settings s? Mirrors index.html isCurfewLate.
-- Nights run until 5:00 AM; a curfew before 5:00 AM means "after midnight". Night of = previous day before 5 AM.
create or replace function public.si_curfew_late(s public.settings, phase int, ts timestamptz) returns boolean
language plpgsql stable set search_path = public as $$
declare loc timestamp; mins int; night date; wkend boolean; cur text; c int;
begin
  if s.timezone is null then return null; end if;
  loc := ts at time zone s.timezone;
  mins := extract(hour from loc)::int * 60 + extract(minute from loc)::int;
  night := case when mins < 300 then (loc - interval '1 day')::date else loc::date end;
  wkend := extract(isodow from night) in (5, 6);
  cur := case when coalesce(phase, 1) <= 1
              then case when wkend then s.curfew_p1_weekend else s.curfew_p1_weekday end
              else case when wkend then s.curfew_p2_weekend else s.curfew_p2_weekday end end;
  if cur is null or cur !~ '^\d{1,2}:\d{2}$' then return null; end if;
  c := split_part(cur, ':', 1)::int * 60 + split_part(cur, ':', 2)::int;
  if c < 300 then return mins >= c and mins < 300; end if;   -- after-midnight curfew
  return mins >= c or mins < 300;
end $$;

-- ---------------------------------------------------------------- pin_hash: never via the API
revoke select, insert, update on public.residents from anon, authenticated;
grant select (id,name,role,phase,house,updated_at,move_in_date,sobriety_date,discharge_date,discharge_reason,status,
              phone,email,emergency_name,emergency_phone,emergency_relation,medical_notes,notify_opt_in,org,
              doc_signer_name,doc_signer_title,discharge_sig,discharge_signed_by)
  on public.residents to authenticated;
grant insert (id,name,role,phase,house,updated_at,move_in_date,sobriety_date,discharge_date,discharge_reason,status,
              phone,email,emergency_name,emergency_phone,emergency_relation,medical_notes,notify_opt_in,org,
              doc_signer_name,doc_signer_title,discharge_sig,discharge_signed_by)
  on public.residents to authenticated;
grant update (name,role,phase,house,updated_at,move_in_date,sobriety_date,discharge_date,discharge_reason,status,
              phone,email,emergency_name,emergency_phone,emergency_relation,medical_notes,notify_opt_in,
              doc_signer_name,doc_signer_title,discharge_sig,discharge_signed_by)
  on public.residents to authenticated;
-- NOTE: a NEW residents column must be added to the grants above to be visible to the app.

-- One active account per name per org (sign-in is by name). Discharged rows don't count, so a
-- returning resident can be re-added.
create unique index if not exists residents_active_name_uq on public.residents (org, lower(trim(name)))
  where status is distinct from 'discharged';

-- ---------------------------------------------------------------- column/transition guards
-- Policies decide WHICH rows; these triggers decide WHICH CHANGES a role may make. They only act on
-- requests from the app (current_user = authenticated); service-role and definer functions pass.
create or replace function public.si_guard_residents() returns trigger
language plpgsql set search_path = public as $$
declare me text := auth.jwt()->>'sub'; r text := public.si_role();
begin
  if current_user <> 'authenticated' then return coalesce(new, old); end if;
  if tg_op = 'INSERT' then
    if r = 'manager' and new.role is distinct from 'resident' then raise exception 'Only an owner can add staff accounts'; end if;
    return new;
  end if;
  -- UPDATE
  if new.org is distinct from old.org then raise exception 'Organization cannot be changed'; end if;
  if r = 'resident' then
    if old.id <> me then raise exception 'not authorized'; end if;
    if (to_jsonb(new) - array['sobriety_date','email','updated_at']) <> (to_jsonb(old) - array['sobriety_date','email','updated_at'])
      then raise exception 'Residents can only update their recovery date and email'; end if;
  elsif r = 'manager' then
    if new.role is distinct from old.role then raise exception 'Only an owner can change roles'; end if;
    if old.role <> 'resident' and old.id <> me then raise exception 'Only an owner can change staff accounts'; end if;
    if old.id = me and (new.house is distinct from old.house or new.status is distinct from old.status)
      then raise exception 'Only an owner can change your house or status'; end if;
  end if;
  return new;
end $$;
create or replace trigger si_guard before insert or update on public.residents for each row execute function public.si_guard_residents();

create or replace function public.si_guard_resident_rows() returns trigger
language plpgsql set search_path = public as $$
-- Resident-side writes on chores / resident_documents / curfew_log / checkins.
declare r text := public.si_role(); s public.settings; ph int; t timestamptz;
begin
  if current_user <> 'authenticated' or r is distinct from 'resident' then return new; end if;
  if tg_table_name = 'chores' then
    if (to_jsonb(new) - array['completed','completed_at','completed_date']) <> (to_jsonb(old) - array['completed','completed_at','completed_date'])
      then raise exception 'Residents can only mark their chore done'; end if;
  elsif tg_table_name = 'resident_documents' then
    if (to_jsonb(new) - array['resident_sig','resident_signed_at','status','signed_file_path'])
       <> (to_jsonb(old) - array['resident_sig','resident_signed_at','status','signed_file_path'])
      then raise exception 'Residents can only sign their document'; end if;
    if new.status is distinct from old.status and not (old.status = 'pending' and new.status = 'resident_signed')
      then raise exception 'Document is not awaiting your signature'; end if;
    if old.status <> 'pending' and (new.resident_sig is distinct from old.resident_sig or new.resident_signed_at is distinct from old.resident_signed_at)
      then raise exception 'Document already signed'; end if;
  elsif tg_table_name = 'curfew_log' then
    -- Keep the phone's time only if it's recent (an entry queued during a signal drop and sent within
    -- 20 minutes); otherwise use the server clock, so a sign-in can't be backdated.
    t := case when new.ts between now() - interval '20 minutes' and now() + interval '2 minutes' then new.ts else now() end;
    new.ts := t; new.server_ts := now(); new.excused := false; new.excused_reason := null;
    if new.action = 'in' then
      select * into s from public.settings where org = new.org;
      select phase into ph from public.residents where id = new.resident_id;
      if s.timezone is not null then new.late := coalesce(public.si_curfew_late(s, ph, t), new.late); end if;
    else new.late := false; end if;
  elsif tg_table_name = 'checkins' then
    new.server_ts := now();
    new.verified_by_id := null; new.verified_by_name := null; new.verification_note := null; new.verified_at := null;
  end if;
  return new;
end $$;
create or replace trigger si_guard before update on public.chores for each row execute function public.si_guard_resident_rows();
create or replace trigger si_guard before update on public.resident_documents for each row execute function public.si_guard_resident_rows();
create or replace trigger si_guard before insert on public.curfew_log for each row execute function public.si_guard_resident_rows();
create or replace trigger si_guard before insert on public.checkins for each row execute function public.si_guard_resident_rows();

-- ---------------------------------------------------------------- policies
-- STAFF = owner, or manager of the row's house. Role/house are read from residents once per query.

-- ---- residents: staff manage their house (owner: all); self read/update (trigger limits columns); owner-only delete
alter policy residents_auth on public.residents
  using ((auth.jwt()->>'org') = org and ((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))))
  with check ((auth.jwt()->>'org') = org and ((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))));
do $$ begin
create policy residents_self_read on public.residents for select to authenticated
  using ((auth.jwt()->>'org') = org and (id = (auth.jwt()->>'sub') and (select public.si_role()) is not null));
exception when duplicate_object then null; end $$;
do $$ begin
create policy residents_self_update on public.residents for update to authenticated
  using ((auth.jwt()->>'org') = org and (id = (auth.jwt()->>'sub') and (select public.si_role()) is not null))
  with check ((auth.jwt()->>'org') = org and (id = (auth.jwt()->>'sub') and (select public.si_role()) is not null));
exception when duplicate_object then null; end $$;
do $$ begin
create policy residents_owner_delete on public.residents as restrictive for delete to authenticated
  using ((auth.jwt()->>'org') = org and (select public.si_role()) = 'owner');
exception when duplicate_object then null; end $$;
-- ---- checkins: staff for their house; resident reads + inserts own; corrections/deletes owner-only
alter policy checkins_auth on public.checkins
  using ((auth.jwt()->>'org') = org and ((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))))
  with check ((auth.jwt()->>'org') = org and ((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))));
do $$ begin
create policy checkins_self_read on public.checkins for select to authenticated
  using ((auth.jwt()->>'org') = org and (resident_id = (auth.jwt()->>'sub') and (select public.si_role()) is not null));
exception when duplicate_object then null; end $$;
do $$ begin
create policy checkins_self_insert on public.checkins for insert to authenticated
  with check ((auth.jwt()->>'org') = org and (select public.si_role()) = 'resident' and resident_id = (auth.jwt()->>'sub') and house is not distinct from (select public.si_house()));
exception when duplicate_object then null; end $$;
do $$ begin
create policy checkins_owner_update on public.checkins as restrictive for update to authenticated
  using ((auth.jwt()->>'org') = org and (select public.si_role()) = 'owner');
exception when duplicate_object then null; end $$;
do $$ begin
create policy checkins_owner_delete on public.checkins as restrictive for delete to authenticated
  using ((auth.jwt()->>'org') = org and (select public.si_role()) = 'owner');
exception when duplicate_object then null; end $$;
-- ---- curfew_log: staff for their house; resident reads + inserts own; corrections/deletes owner-only
alter policy curfew_log_auth on public.curfew_log
  using ((auth.jwt()->>'org') = org and ((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))))
  with check ((auth.jwt()->>'org') = org and ((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))));
do $$ begin
create policy curfew_log_self_read on public.curfew_log for select to authenticated
  using ((auth.jwt()->>'org') = org and (resident_id = (auth.jwt()->>'sub') and (select public.si_role()) is not null));
exception when duplicate_object then null; end $$;
do $$ begin
create policy curfew_log_self_insert on public.curfew_log for insert to authenticated
  with check ((auth.jwt()->>'org') = org and (select public.si_role()) = 'resident' and resident_id = (auth.jwt()->>'sub') and house is not distinct from (select public.si_house()));
exception when duplicate_object then null; end $$;
do $$ begin
create policy curfew_log_owner_update on public.curfew_log as restrictive for update to authenticated
  using ((auth.jwt()->>'org') = org and (select public.si_role()) = 'owner');
exception when duplicate_object then null; end $$;
do $$ begin
create policy curfew_log_owner_delete on public.curfew_log as restrictive for delete to authenticated
  using ((auth.jwt()->>'org') = org and (select public.si_role()) = 'owner');
exception when duplicate_object then null; end $$;
-- ---- chores: staff manage; residents see their house's chores and mark their own done
alter policy chores_auth on public.chores
  using ((auth.jwt()->>'org') = org and ((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))))
  with check ((auth.jwt()->>'org') = org and ((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))));
do $$ begin
create policy chores_house_read on public.chores for select to authenticated
  using ((auth.jwt()->>'org') = org and (select public.si_role()) = 'resident' and house = (select public.si_house()));
exception when duplicate_object then null; end $$;
do $$ begin
create policy chores_self_done on public.chores for update to authenticated
  using ((auth.jwt()->>'org') = org and (select public.si_role()) = 'resident' and resident_id = (auth.jwt()->>'sub'))
  with check ((auth.jwt()->>'org') = org and resident_id = (auth.jwt()->>'sub'));
exception when duplicate_object then null; end $$;
-- ---- drug_tests (screenings): staff record/update; resident reads own; owner-only delete
alter policy drug_tests_auth on public.drug_tests
  using ((auth.jwt()->>'org') = org and ((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))))
  with check ((auth.jwt()->>'org') = org and ((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))));
do $$ begin
create policy drug_tests_self_read on public.drug_tests for select to authenticated
  using ((auth.jwt()->>'org') = org and (resident_id = (auth.jwt()->>'sub') and (select public.si_role()) is not null));
exception when duplicate_object then null; end $$;
do $$ begin
create policy drug_tests_owner_delete on public.drug_tests as restrictive for delete to authenticated
  using ((auth.jwt()->>'org') = org and (select public.si_role()) = 'owner');
exception when duplicate_object then null; end $$;
-- ---- incidents: staff only; owner-only delete
alter policy incidents_auth on public.incidents
  using ((auth.jwt()->>'org') = org and ((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))))
  with check ((auth.jwt()->>'org') = org and ((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))));
do $$ begin
create policy incidents_owner_delete on public.incidents as restrictive for delete to authenticated
  using ((auth.jwt()->>'org') = org and (select public.si_role()) = 'owner');
exception when duplicate_object then null; end $$;
-- ---- grievances: resident files (named/anonymous) for own house, reads own; staff resolve; owner-only delete
alter policy grievances_auth on public.grievances
  using ((auth.jwt()->>'org') = org and ((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))))
  with check ((auth.jwt()->>'org') = org and ((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))));
do $$ begin
create policy grievances_self_read on public.grievances for select to authenticated
  using ((auth.jwt()->>'org') = org and (resident_id = (auth.jwt()->>'sub') and (select public.si_role()) is not null));
exception when duplicate_object then null; end $$;
do $$ begin
create policy grievances_self_insert on public.grievances for insert to authenticated
  with check ((auth.jwt()->>'org') = org and (select public.si_role()) = 'resident' and house is not distinct from (select public.si_house()) and (resident_id is null or resident_id = (auth.jwt()->>'sub')) and coalesce(status,'open') = 'open');
exception when duplicate_object then null; end $$;
do $$ begin
create policy grievances_owner_delete on public.grievances as restrictive for delete to authenticated
  using ((auth.jwt()->>'org') = org and (select public.si_role()) = 'owner');
exception when duplicate_object then null; end $$;
-- ---- resident_documents: staff send/countersign; resident reads + signs own (trigger limits columns); owner-only delete
alter policy resident_documents_auth on public.resident_documents
  using ((auth.jwt()->>'org') = org and ((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))))
  with check ((auth.jwt()->>'org') = org and ((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))));
do $$ begin
create policy resident_documents_self_read on public.resident_documents for select to authenticated
  using ((auth.jwt()->>'org') = org and (resident_id = (auth.jwt()->>'sub') and (select public.si_role()) is not null));
exception when duplicate_object then null; end $$;
do $$ begin
create policy resident_documents_self_sign on public.resident_documents for update to authenticated
  using ((auth.jwt()->>'org') = org and (select public.si_role()) = 'resident' and resident_id = (auth.jwt()->>'sub'))
  with check ((auth.jwt()->>'org') = org and (select public.si_role()) = 'resident' and resident_id = (auth.jwt()->>'sub'));
exception when duplicate_object then null; end $$;
do $$ begin
create policy resident_documents_owner_delete on public.resident_documents as restrictive for delete to authenticated
  using ((auth.jwt()->>'org') = org and (select public.si_role()) = 'owner');
exception when duplicate_object then null; end $$;
-- ---- events: staff manage their house + org-wide; everyone active reads own house + org-wide
alter policy events_authenticated on public.events
  using ((auth.jwt()->>'org') = org and (((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))) or (house is null and (select public.si_role()) in ('owner','manager'))))
  with check ((auth.jwt()->>'org') = org and (((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))) or (house is null and (select public.si_role()) in ('owner','manager'))));
do $$ begin
create policy events_read on public.events for select to authenticated
  using ((auth.jwt()->>'org') = org and (select public.si_role()) is not null and ((select public.si_role()) = 'owner' or house = (select public.si_house()) or house is null));
exception when duplicate_object then null; end $$;
-- ---- announcements (sticky notes): staff post/archive; everyone active reads own house + org-wide
alter policy announcements_auth on public.announcements
  using ((auth.jwt()->>'org') = org and ((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))))
  with check ((auth.jwt()->>'org') = org and ((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))));
do $$ begin
create policy announcements_read on public.announcements for select to authenticated
  using ((auth.jwt()->>'org') = org and (select public.si_role()) is not null and ((select public.si_role()) = 'owner' or house = (select public.si_house()) or is_global = true));
exception when duplicate_object then null; end $$;
-- ---- announcement_acks: staff see/clear; resident acks for self and sees own
alter policy announcement_acks_auth on public.announcement_acks
  using ((auth.jwt()->>'org') = org and (select public.si_role()) in ('owner','manager'))
  with check ((auth.jwt()->>'org') = org and (select public.si_role()) in ('owner','manager'));
do $$ begin
create policy announcement_acks_self_read on public.announcement_acks for select to authenticated
  using ((auth.jwt()->>'org') = org and (resident_id = (auth.jwt()->>'sub') and (select public.si_role()) is not null));
exception when duplicate_object then null; end $$;
do $$ begin
create policy announcement_acks_self_insert on public.announcement_acks for insert to authenticated
  with check ((auth.jwt()->>'org') = org and (resident_id = (auth.jwt()->>'sub') and (select public.si_role()) is not null));
exception when duplicate_object then null; end $$;
-- ---- settings: staff change; everyone active reads their org's
alter policy settings_auth on public.settings
  using ((auth.jwt()->>'org') = org and (select public.si_role()) in ('owner','manager'))
  with check ((auth.jwt()->>'org') = org and (select public.si_role()) in ('owner','manager'));
do $$ begin
create policy settings_read on public.settings for select to authenticated
  using ((auth.jwt()->>'org') = org and (select public.si_role()) is not null);
exception when duplicate_object then null; end $$;
-- ---- document_templates: staff change; everyone active reads their org's
alter policy document_templates_auth on public.document_templates
  using ((auth.jwt()->>'org') = org and (select public.si_role()) in ('owner','manager'))
  with check ((auth.jwt()->>'org') = org and (select public.si_role()) in ('owner','manager'));
do $$ begin
create policy document_templates_read on public.document_templates for select to authenticated
  using ((auth.jwt()->>'org') = org and (select public.si_role()) is not null);
exception when duplicate_object then null; end $$;
-- ---- medications / med_logs: same rules as 31_medications.sql, role/house now from the table (revocable)
alter policy medications_read on public.medications
  using ((auth.jwt()->>'org') = org and (((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))) or (resident_id = (auth.jwt()->>'sub') and (select public.si_role()) is not null)));
alter policy medications_staff_write on public.medications
  using ((auth.jwt()->>'org') = org and ((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))))
  with check ((auth.jwt()->>'org') = org and ((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))));
alter policy med_logs_read on public.med_logs
  using ((auth.jwt()->>'org') = org and (((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))) or (resident_id = (auth.jwt()->>'sub') and (select public.si_role()) is not null)));
alter policy med_logs_self_insert on public.med_logs
  with check ((auth.jwt()->>'org') = org and (select public.si_role()) = 'resident' and resident_id = (auth.jwt()->>'sub') and house is not distinct from (select public.si_house()) and logged_by = 'resident');
alter policy med_logs_staff_write on public.med_logs
  using ((auth.jwt()->>'org') = org and ((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))))
  with check ((auth.jwt()->>'org') = org and ((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))));
-- ---- audit + error logs: active staff only (was: any token claiming the role)
alter policy audit_log_read on public.audit_log
  using ((auth.jwt()->>'org') = org and (select public.si_role()) in ('owner','manager'));
alter policy app_errors_read on public.app_errors
  using ((auth.jwt()->>'org') = org and (select public.si_role()) = 'owner');

-- ---------------------------------------------------------------- document files (storage)
-- Staff: any file in their org. Residents: only template files and their own signed documents.
alter policy documents_read on storage.objects
  using (bucket_id = 'documents' and (storage.foldername(name))[1] = (auth.jwt()->>'org')
    and ((select public.si_role()) in ('owner','manager')
      or ((select public.si_role()) = 'resident' and (
            exists (select 1 from public.document_templates t where t.org = (auth.jwt()->>'org') and t.file_path = storage.objects.name)
         or exists (select 1 from public.resident_documents d where d.resident_id = (auth.jwt()->>'sub')
                      and storage.objects.name in (d.template_file_path, d.signed_file_path))))));
alter policy documents_write on storage.objects
  with check (bucket_id = 'documents' and (storage.foldername(name))[1] = (auth.jwt()->>'org')
    and (select public.si_role()) in ('owner','manager'));
alter policy documents_delete on storage.objects
  using (bucket_id = 'documents' and (storage.foldername(name))[1] = (auth.jwt()->>'org')
    and (select public.si_role()) in ('owner','manager'));

-- ---------------------------------------------------------------- set_pin: tighter staff rule
-- Self-change needs the current PIN. Owners reset anyone in their org; managers reset residents of
-- their own house only (not other managers or the owner). Caller must be an active account.
create or replace function public.set_pin(p_id text, p_new_pin text, p_current_pin text default null)
returns boolean language plpgsql security definer set search_path = public, extensions as $$
declare caller_sub text := auth.jwt()->>'sub'; caller_org text := auth.jwt()->>'org';
        caller_role text := public.si_role(); caller_house text := public.si_house(); target public.residents;
begin
  if p_new_pin is null or p_new_pin !~ '^[0-9]{4,}$' then raise exception 'PIN must be at least 4 digits'; end if;
  if caller_role is null then raise exception 'not authorized'; end if;
  select * into target from public.residents where id = p_id;
  if not found then raise exception 'no such user'; end if;
  if caller_sub = p_id then
    if target.pin_hash is null or target.pin_hash <> extensions.crypt(coalesce(p_current_pin,''), target.pin_hash) then
      raise exception 'current PIN incorrect'; end if;
  else
    if target.org is distinct from caller_org then raise exception 'not authorized'; end if;
    if caller_role = 'owner' then null;
    elsif caller_role = 'manager' and target.role = 'resident' and target.house is not distinct from caller_house then null;
    else raise exception 'not authorized'; end if;
  end if;
  update public.residents set pin_hash = extensions.crypt(p_new_pin, extensions.gen_salt('bf')) where id = p_id;
  return true;
end $$;
revoke all on function public.set_pin(text,text,text) from public, anon;
grant execute on function public.set_pin(text,text,text) to authenticated;

-- ---------------------------------------------------------------- housekeeping
-- timesheets: unused and was readable/writable by anyone. Locked shut here (0 rows; drop by hand later).
revoke all on public.timesheets from anon, authenticated;
alter policy anon_all_timesheets on public.timesheets using (false) with check (false);
revoke execute on function public.audit_row() from public, anon, authenticated;
alter function public.checkins_set_verified_at() set search_path = public;
revoke execute on function public.si_guard_residents(), public.si_guard_resident_rows() from public, anon;

notify pgrst, 'reload schema';
