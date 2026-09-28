-- 31_medications.sql  —  optional medication tracking (per-org switch, OFF by default)
--
-- Two tables:
--   medications — a resident's medication list (name, dose, scheduled times), maintained by staff.
--   med_logs    — one row per dose logged (taken / not taken), by the resident or by staff.
--
-- Privacy (stricter than the other house-scoped tables): a RESIDENT can only ever see their OWN
-- medication rows — never another resident's, even in the same house. Staff (manager/owner) see rows
-- for their house (owners: their whole org). Only staff can add/change a medication list; a resident
-- can only ADD dose logs for themselves (not edit or delete them). Changes are in the activity log.
--
-- Data minimization: medication name, dose, schedule, and dose times only. No diagnoses, prescribers,
-- or pharmacy data. The app never puts medication names in reminders/emails/notifications.
--
-- Rows are removed with the resident (on delete cascade) so medication data never outlives the person
-- it describes. The feature is invisible until an owner turns on settings.feature_meds.
--
-- Requires 14_org_rls.sql (org claim) and 18/22 audit scripts. Additive and safe to run more than once.

alter table public.settings add column if not exists feature_meds boolean default false;

create table if not exists public.medications (
  id            text primary key,
  org           text not null,
  house         text,
  resident_id   text not null references public.residents(id) on delete cascade,
  resident_name text,
  name          text not null,
  dose          text,
  times         text[] not null default '{}',   -- 'HH:MM' local times; empty = as needed
  instructions  text,
  active        boolean not null default true,
  created_by    text,
  created_at    timestamptz not null default now()
);
create index if not exists medications_res_idx on public.medications(org, resident_id);

create table if not exists public.med_logs (
  id              text primary key,
  org             text not null,
  house           text,
  resident_id     text not null references public.residents(id) on delete cascade,
  resident_name   text,
  medication_id   text references public.medications(id) on delete set null,
  med_name        text,
  dose            text,
  dose_date       date not null,                -- resident's local date
  scheduled_time  text,                         -- 'HH:MM', or null for an as-needed dose
  status          text not null check (status in ('taken','not_taken')),
  logged_by       text not null check (logged_by in ('resident','staff')),
  witness_name    text,                         -- staff member who logged/observed it
  notes           text,
  ts              timestamptz not null default now()
);
create index if not exists med_logs_res_idx on public.med_logs(org, resident_id, dose_date desc);

alter table public.medications enable row level security;
alter table public.med_logs    enable row level security;

-- Helper predicates (inline, matching the style of 14_org_rls.sql).
--   staff in scope: org match AND role is staff AND (owner OR same house)
--   self:           org match AND the row is the logged-in resident's own

drop policy if exists medications_read on public.medications;
create policy medications_read on public.medications for select to authenticated
  using ((auth.jwt()->>'org')=org and (
    ((auth.jwt()->>'urole') in ('owner','manager') and ((auth.jwt()->>'urole')='owner' or house=(auth.jwt()->>'house')))
    or resident_id=(auth.jwt()->>'sub')));

drop policy if exists medications_staff_write on public.medications;
create policy medications_staff_write on public.medications for all to authenticated
  using ((auth.jwt()->>'org')=org and (auth.jwt()->>'urole') in ('owner','manager')
         and ((auth.jwt()->>'urole')='owner' or house=(auth.jwt()->>'house')))
  with check ((auth.jwt()->>'org')=org and (auth.jwt()->>'urole') in ('owner','manager')
         and ((auth.jwt()->>'urole')='owner' or house=(auth.jwt()->>'house')));

drop policy if exists med_logs_read on public.med_logs;
create policy med_logs_read on public.med_logs for select to authenticated
  using ((auth.jwt()->>'org')=org and (
    ((auth.jwt()->>'urole') in ('owner','manager') and ((auth.jwt()->>'urole')='owner' or house=(auth.jwt()->>'house')))
    or resident_id=(auth.jwt()->>'sub')));

-- Residents may add a dose log for themselves only (in their own house), marked as self-logged.
drop policy if exists med_logs_self_insert on public.med_logs;
create policy med_logs_self_insert on public.med_logs for insert to authenticated
  with check ((auth.jwt()->>'org')=org and resident_id=(auth.jwt()->>'sub')
              and house is not distinct from (auth.jwt()->>'house') and logged_by='resident');

drop policy if exists med_logs_staff_write on public.med_logs;
create policy med_logs_staff_write on public.med_logs for all to authenticated
  using ((auth.jwt()->>'org')=org and (auth.jwt()->>'urole') in ('owner','manager')
         and ((auth.jwt()->>'urole')='owner' or house=(auth.jwt()->>'house')))
  with check ((auth.jwt()->>'org')=org and (auth.jwt()->>'urole') in ('owner','manager')
         and ((auth.jwt()->>'urole')='owner' or house=(auth.jwt()->>'house')));

-- Activity log, with who did it: every change to a medication list; edits/removals of dose logs
-- (each dose log is already its own timestamped record, as with check-ins in 30_audit_attendance.sql).
drop trigger if exists audit_t on public.medications;
create trigger audit_t after insert or update or delete on public.medications for each row execute function public.audit_row();
drop trigger if exists audit_t on public.med_logs;
create trigger audit_t after update or delete on public.med_logs for each row execute function public.audit_row();

notify pgrst, 'reload schema';
