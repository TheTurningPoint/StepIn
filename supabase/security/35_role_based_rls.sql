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
-- for each role is still allowed. Re-runnable. Revert: 35_revert.sql (restores 14_org_rls policies).

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
-- true when the caller is active staff with authority over rows of house h (owner: any house).
create or replace function public.si_staff_for(h text) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(public.si_role() = 'owner' or (public.si_role() = 'manager' and h = public.si_house()), false)
$$;
revoke all on function public.si_role(), public.si_house(), public.si_staff_for(text) from public, anon;
grant execute on function public.si_role(), public.si_house(), public.si_staff_for(text) to authenticated, service_role;

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
drop trigger if exists si_guard on public.residents;
create trigger si_guard before insert or update on public.residents for each row execute function public.si_guard_residents();

create or replace function public.si_guard_resident_rows() returns trigger
language plpgsql set search_path = public as $$
-- Resident-side writes on chores / resident_documents / curfew_log / checkins.
declare r text := public.si_role(); s public.settings; ph int;
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
    new.ts := now(); new.server_ts := now(); new.excused := false; new.excused_reason := null;
    if new.action = 'in' then
      select * into s from public.settings where org = new.org;
      select phase into ph from public.residents where id = new.resident_id;
      if s.timezone is not null then new.late := coalesce(public.si_curfew_late(s, ph, now()), new.late); end if;
    else new.late := false; end if;
  elsif tg_table_name = 'checkins' then
    new.server_ts := now();
    new.verified_by_id := null; new.verified_by_name := null; new.verification_note := null; new.verified_at := null;
  end if;
  return new;
end $$;
drop trigger if exists si_guard on public.chores;
create trigger si_guard before update on public.chores for each row execute function public.si_guard_resident_rows();
drop trigger if exists si_guard on public.resident_documents;
create trigger si_guard before update on public.resident_documents for each row execute function public.si_guard_resident_rows();
drop trigger if exists si_guard on public.curfew_log;
create trigger si_guard before insert on public.curfew_log for each row execute function public.si_guard_resident_rows();
drop trigger if exists si_guard on public.checkins;
create trigger si_guard before insert on public.checkins for each row execute function public.si_guard_resident_rows();

-- ---------------------------------------------------------------- policies
-- Shorthands used below:  ORG  = (auth.jwt()->>'org') = org
-- STAFF = owner, or manager of the row's house.   ME = resident_id = (auth.jwt()->>'sub')
-- (select ...) wrappers let Postgres evaluate the helper once per query instead of once per row.

-- residents
drop policy if exists residents_auth on public.residents;
drop policy if exists residents_read on public.residents;
drop policy if exists residents_insert on public.residents;
drop policy if exists residents_update on public.residents;
drop policy if exists residents_delete on public.residents;
create policy residents_read on public.residents for select to authenticated
  using ((auth.jwt()->>'org') = org and (((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))) or (id = (auth.jwt()->>'sub') and (select public.si_role()) is not null)));
create policy residents_insert on public.residents for insert to authenticated
  with check ((auth.jwt()->>'org') = org and ((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))));
create policy residents_update on public.residents for update to authenticated
  using ((auth.jwt()->>'org') = org and (((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))) or (id = (auth.jwt()->>'sub') and (select public.si_role()) is not null)))
  with check ((auth.jwt()->>'org') = org and (((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))) or (id = (auth.jwt()->>'sub') and (select public.si_role()) is not null)));
create policy residents_delete on public.residents for delete to authenticated
  using ((auth.jwt()->>'org') = org and (select public.si_role()) = 'owner');

-- checkins: residents insert/read their own; staff read/insert for their house; owner corrects/deletes
drop policy if exists checkins_auth on public.checkins;
drop policy if exists checkins_read on public.checkins;
drop policy if exists checkins_insert on public.checkins;
drop policy if exists checkins_owner on public.checkins;
drop policy if exists checkins_owner_delete on public.checkins;
create policy checkins_read on public.checkins for select to authenticated
  using ((auth.jwt()->>'org') = org and (((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))) or (resident_id = (auth.jwt()->>'sub') and (select public.si_role()) is not null)));
create policy checkins_insert on public.checkins for insert to authenticated
  with check ((auth.jwt()->>'org') = org and (((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house())))
    or ((select public.si_role()) = 'resident' and resident_id = (auth.jwt()->>'sub') and house is not distinct from (select public.si_house()))));
create policy checkins_owner on public.checkins for update to authenticated
  using ((auth.jwt()->>'org') = org and (select public.si_role()) = 'owner');
create policy checkins_owner_delete on public.checkins for delete to authenticated
  using ((auth.jwt()->>'org') = org and (select public.si_role()) = 'owner');

-- curfew_log: same shape as checkins
drop policy if exists curfew_log_auth on public.curfew_log;
drop policy if exists curfew_read on public.curfew_log;
drop policy if exists curfew_insert on public.curfew_log;
drop policy if exists curfew_owner on public.curfew_log;
drop policy if exists curfew_owner_delete on public.curfew_log;
create policy curfew_read on public.curfew_log for select to authenticated
  using ((auth.jwt()->>'org') = org and (((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))) or (resident_id = (auth.jwt()->>'sub') and (select public.si_role()) is not null)));
create policy curfew_insert on public.curfew_log for insert to authenticated
  with check ((auth.jwt()->>'org') = org and (((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house())))
    or ((select public.si_role()) = 'resident' and resident_id = (auth.jwt()->>'sub') and house is not distinct from (select public.si_house()))));
create policy curfew_owner on public.curfew_log for update to authenticated
  using ((auth.jwt()->>'org') = org and (select public.si_role()) = 'owner');
create policy curfew_owner_delete on public.curfew_log for delete to authenticated
  using ((auth.jwt()->>'org') = org and (select public.si_role()) = 'owner');

-- chores: residents see their house's chores and mark their own done; staff manage
drop policy if exists chores_auth on public.chores;
drop policy if exists chores_read on public.chores;
drop policy if exists chores_staff on public.chores;
drop policy if exists chores_resident_done on public.chores;
create policy chores_read on public.chores for select to authenticated
  using ((auth.jwt()->>'org') = org and (((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))) or ((select public.si_role()) = 'resident' and house = (select public.si_house()))));
create policy chores_staff on public.chores for all to authenticated
  using ((auth.jwt()->>'org') = org and ((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))))
  with check ((auth.jwt()->>'org') = org and ((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))));
create policy chores_resident_done on public.chores for update to authenticated
  using ((auth.jwt()->>'org') = org and (select public.si_role()) = 'resident' and resident_id = (auth.jwt()->>'sub'))
  with check ((auth.jwt()->>'org') = org and resident_id = (auth.jwt()->>'sub'));

-- drug_tests (screenings): resident reads own; staff record/update; owner deletes
drop policy if exists drug_tests_auth on public.drug_tests;
drop policy if exists drug_tests_read on public.drug_tests;
drop policy if exists drug_tests_staff_insert on public.drug_tests;
drop policy if exists drug_tests_staff_update on public.drug_tests;
drop policy if exists drug_tests_owner_delete on public.drug_tests;
create policy drug_tests_read on public.drug_tests for select to authenticated
  using ((auth.jwt()->>'org') = org and (((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))) or (resident_id = (auth.jwt()->>'sub') and (select public.si_role()) is not null)));
create policy drug_tests_staff_insert on public.drug_tests for insert to authenticated
  with check ((auth.jwt()->>'org') = org and ((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))));
create policy drug_tests_staff_update on public.drug_tests for update to authenticated
  using ((auth.jwt()->>'org') = org and ((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))))
  with check ((auth.jwt()->>'org') = org and ((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))));
create policy drug_tests_owner_delete on public.drug_tests for delete to authenticated
  using ((auth.jwt()->>'org') = org and (select public.si_role()) = 'owner');

-- incidents: staff only; owner deletes
drop policy if exists incidents_auth on public.incidents;
drop policy if exists incidents_staff on public.incidents;
drop policy if exists incidents_staff_insert on public.incidents;
drop policy if exists incidents_staff_update on public.incidents;
drop policy if exists incidents_owner_delete on public.incidents;
create policy incidents_staff on public.incidents for select to authenticated
  using ((auth.jwt()->>'org') = org and ((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))));
create policy incidents_staff_insert on public.incidents for insert to authenticated
  with check ((auth.jwt()->>'org') = org and ((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))));
create policy incidents_staff_update on public.incidents for update to authenticated
  using ((auth.jwt()->>'org') = org and ((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))))
  with check ((auth.jwt()->>'org') = org and ((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))));
create policy incidents_owner_delete on public.incidents for delete to authenticated
  using ((auth.jwt()->>'org') = org and (select public.si_role()) = 'owner');

-- grievances: resident files (named or anonymous) for their own house and reads their own named ones;
-- staff read/resolve; only an owner can delete (a manager can't remove a grievance about themselves).
drop policy if exists grievances_auth on public.grievances;
drop policy if exists grievances_read on public.grievances;
drop policy if exists grievances_insert on public.grievances;
drop policy if exists grievances_staff_update on public.grievances;
drop policy if exists grievances_owner_delete on public.grievances;
create policy grievances_read on public.grievances for select to authenticated
  using ((auth.jwt()->>'org') = org and (((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))) or (resident_id = (auth.jwt()->>'sub') and (select public.si_role()) is not null)));
create policy grievances_insert on public.grievances for insert to authenticated
  with check ((auth.jwt()->>'org') = org and (((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house())))
    or ((select public.si_role()) = 'resident' and house is not distinct from (select public.si_house())
        and (resident_id is null or resident_id = (auth.jwt()->>'sub')) and coalesce(status, 'open') = 'open')));
create policy grievances_staff_update on public.grievances for update to authenticated
  using ((auth.jwt()->>'org') = org and ((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))))
  with check ((auth.jwt()->>'org') = org and ((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))));
create policy grievances_owner_delete on public.grievances for delete to authenticated
  using ((auth.jwt()->>'org') = org and (select public.si_role()) = 'owner');

-- resident_documents: resident reads + signs own; staff send/countersign; owner deletes
drop policy if exists resident_documents_auth on public.resident_documents;
drop policy if exists resdocs_read on public.resident_documents;
drop policy if exists resdocs_staff_insert on public.resident_documents;
drop policy if exists resdocs_update on public.resident_documents;
drop policy if exists resdocs_owner_delete on public.resident_documents;
create policy resdocs_read on public.resident_documents for select to authenticated
  using ((auth.jwt()->>'org') = org and (((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))) or (resident_id = (auth.jwt()->>'sub') and (select public.si_role()) is not null)));
create policy resdocs_staff_insert on public.resident_documents for insert to authenticated
  with check ((auth.jwt()->>'org') = org and ((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))));
create policy resdocs_update on public.resident_documents for update to authenticated
  using ((auth.jwt()->>'org') = org and (((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))) or ((select public.si_role()) = 'resident' and resident_id = (auth.jwt()->>'sub'))))
  with check ((auth.jwt()->>'org') = org and (((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))) or ((select public.si_role()) = 'resident' and resident_id = (auth.jwt()->>'sub'))));
create policy resdocs_owner_delete on public.resident_documents for delete to authenticated
  using ((auth.jwt()->>'org') = org and (select public.si_role()) = 'owner');

-- events: everyone active reads their house + org-wide; staff manage
drop policy if exists events_authenticated on public.events;
drop policy if exists events_read on public.events;
drop policy if exists events_staff on public.events;
create policy events_read on public.events for select to authenticated
  using ((auth.jwt()->>'org') = org and (select public.si_role()) is not null
         and ((select public.si_role()) = 'owner' or house = (select public.si_house()) or house is null));
create policy events_staff on public.events for all to authenticated
  using ((auth.jwt()->>'org') = org and (((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))) or (house is null and (select public.si_role()) in ('owner','manager'))))
  with check ((auth.jwt()->>'org') = org and (((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))) or (house is null and (select public.si_role()) in ('owner','manager'))));

-- announcements (sticky notes): read own house + org-wide; staff post/archive
drop policy if exists announcements_auth on public.announcements;
drop policy if exists announcements_read on public.announcements;
drop policy if exists announcements_staff on public.announcements;
create policy announcements_read on public.announcements for select to authenticated
  using ((auth.jwt()->>'org') = org and (select public.si_role()) is not null
         and ((select public.si_role()) = 'owner' or house = (select public.si_house()) or is_global = true));
create policy announcements_staff on public.announcements for all to authenticated
  using ((auth.jwt()->>'org') = org and ((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))))
  with check ((auth.jwt()->>'org') = org and ((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))));

-- announcement_acks: resident acks for themselves and sees their own; staff see all and clear
drop policy if exists announcement_acks_auth on public.announcement_acks;
drop policy if exists acks_read on public.announcement_acks;
drop policy if exists acks_insert on public.announcement_acks;
drop policy if exists acks_staff_delete on public.announcement_acks;
create policy acks_read on public.announcement_acks for select to authenticated
  using ((auth.jwt()->>'org') = org and ((select public.si_role()) in ('owner','manager')
         or (resident_id = (auth.jwt()->>'sub') and (select public.si_role()) is not null)));
create policy acks_insert on public.announcement_acks for insert to authenticated
  with check ((auth.jwt()->>'org') = org and resident_id = (auth.jwt()->>'sub') and (select public.si_role()) is not null);
create policy acks_staff_delete on public.announcement_acks for delete to authenticated
  using ((auth.jwt()->>'org') = org and (select public.si_role()) in ('owner','manager'));

-- settings + document templates: everyone active reads their org's; staff change them
drop policy if exists settings_auth on public.settings;
drop policy if exists settings_read on public.settings;
drop policy if exists settings_staff on public.settings;
create policy settings_read on public.settings for select to authenticated
  using ((auth.jwt()->>'org') = org and (select public.si_role()) is not null);
create policy settings_staff on public.settings for all to authenticated
  using ((auth.jwt()->>'org') = org and (select public.si_role()) in ('owner','manager'))
  with check ((auth.jwt()->>'org') = org and (select public.si_role()) in ('owner','manager'));

drop policy if exists document_templates_auth on public.document_templates;
drop policy if exists templates_read on public.document_templates;
drop policy if exists templates_staff on public.document_templates;
create policy templates_read on public.document_templates for select to authenticated
  using ((auth.jwt()->>'org') = org and (select public.si_role()) is not null);
create policy templates_staff on public.document_templates for all to authenticated
  using ((auth.jwt()->>'org') = org and (select public.si_role()) in ('owner','manager'))
  with check ((auth.jwt()->>'org') = org and (select public.si_role()) in ('owner','manager'));

-- medications / med_logs: same rules as 31_medications.sql, but role/house from the table (revocable)
drop policy if exists medications_read on public.medications;
drop policy if exists medications_staff_write on public.medications;
create policy medications_read on public.medications for select to authenticated
  using ((auth.jwt()->>'org') = org and (((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))) or (resident_id = (auth.jwt()->>'sub') and (select public.si_role()) is not null)));
create policy medications_staff_write on public.medications for all to authenticated
  using ((auth.jwt()->>'org') = org and ((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))))
  with check ((auth.jwt()->>'org') = org and ((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))));
drop policy if exists med_logs_read on public.med_logs;
drop policy if exists med_logs_self_insert on public.med_logs;
drop policy if exists med_logs_staff_write on public.med_logs;
create policy med_logs_read on public.med_logs for select to authenticated
  using ((auth.jwt()->>'org') = org and (((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))) or (resident_id = (auth.jwt()->>'sub') and (select public.si_role()) is not null)));
create policy med_logs_self_insert on public.med_logs for insert to authenticated
  with check ((auth.jwt()->>'org') = org and (select public.si_role()) = 'resident' and resident_id = (auth.jwt()->>'sub')
              and house is not distinct from (select public.si_house()) and logged_by = 'resident');
create policy med_logs_staff_write on public.med_logs for all to authenticated
  using ((auth.jwt()->>'org') = org and ((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))))
  with check ((auth.jwt()->>'org') = org and ((select public.si_role()) = 'owner' or ((select public.si_role()) = 'manager' and house = (select public.si_house()))));

-- audit log + error log: active staff only (was: any token claiming manager/owner)
drop policy if exists audit_log_read on public.audit_log;
create policy audit_log_read on public.audit_log for select to authenticated
  using ((auth.jwt()->>'org') = org and (select public.si_role()) in ('owner','manager'));
drop policy if exists app_errors_read on public.app_errors;
create policy app_errors_read on public.app_errors for select to authenticated
  using ((auth.jwt()->>'org') = org and (select public.si_role()) = 'owner');

-- ---------------------------------------------------------------- document files (storage)
-- Staff: any file in their org. Residents: only template files and their own signed documents.
drop policy if exists documents_read on storage.objects;
create policy documents_read on storage.objects for select to authenticated
  using (bucket_id = 'documents' and (storage.foldername(name))[1] = (auth.jwt()->>'org')
    and ((select public.si_role()) in ('owner','manager')
      or ((select public.si_role()) = 'resident' and (
            exists (select 1 from public.document_templates t where t.org = (auth.jwt()->>'org') and t.file_path = storage.objects.name)
         or exists (select 1 from public.resident_documents d where d.resident_id = (auth.jwt()->>'sub')
                      and storage.objects.name in (d.template_file_path, d.signed_file_path))))));
drop policy if exists documents_write on storage.objects;
create policy documents_write on storage.objects for insert to authenticated
  with check (bucket_id = 'documents' and (storage.foldername(name))[1] = (auth.jwt()->>'org')
    and (select public.si_role()) in ('owner','manager'));
drop policy if exists documents_delete on storage.objects;
create policy documents_delete on storage.objects for delete to authenticated
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
drop table if exists public.timesheets;          -- unused, was readable/writable by anyone
revoke execute on function public.audit_row() from public, anon, authenticated;
alter function public.checkins_set_verified_at() set search_path = public;
revoke execute on function public.si_guard_residents(), public.si_guard_resident_rows() from public, anon;

notify pgrst, 'reload schema';
