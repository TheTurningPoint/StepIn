-- 18_audit_log.sql  —  tamper-evident activity log (who changed/deleted what)
--
-- A database trigger records every insert/update/delete on the compliance-sensitive tables
-- (drug_tests, incidents, grievances, residents, resident_documents) into `audit_log`, capturing the
-- acting user from their login token. Because it's a trigger, it can't be bypassed by the app and even
-- catches direct DB edits (logged as "system" when there's no logged-in user). Owners/managers can
-- read their own org's log; nobody can write or alter it except the trigger.
--
-- Safe to run more than once.

create table if not exists public.audit_log (
  id           bigint generated always as identity primary key,
  org          text,
  table_name   text not null,
  op           text not null,          -- INSERT | UPDATE | DELETE
  row_id       text,
  label        text,                   -- human hint (resident/name/type)
  changed_cols text[],                 -- columns that changed (UPDATE only)
  actor_sub    text,                   -- residents.id of the acting user (null = system/SQL)
  actor_role   text,                   -- owner | manager | resident
  changed_at   timestamptz not null default now()
);
alter table public.audit_log enable row level security;
create index if not exists audit_log_org_idx on public.audit_log(org, changed_at desc);

-- Owners/managers read their own org's log. No write policy => only the trigger writes it.
drop policy if exists audit_log_read on public.audit_log;
create policy audit_log_read on public.audit_log for select to authenticated
  using ((auth.jwt()->>'org') = org and (auth.jwt()->>'urole') in ('owner','manager'));

-- Trigger: capture actor from JWT claims + a concise summary (no signatures/secrets).
create or replace function public.audit_row()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  claims json; a_sub text; a_role text; rec jsonb; oldj jsonb; cols text[];
begin
  claims := nullif(current_setting('request.jwt.claims', true), '')::json;
  a_sub := claims->>'sub';
  a_role := claims->>'urole';
  if (TG_OP = 'DELETE') then rec := to_jsonb(OLD); else rec := to_jsonb(NEW); end if;
  if (TG_OP = 'UPDATE') then
    oldj := to_jsonb(OLD);
    select array_agg(k) into cols from jsonb_each(to_jsonb(NEW)) as e(k, v)
      where e.v is distinct from (oldj -> e.k)
        and e.k not in ('admin_sig','resident_sig','manager_sig','sig_data_url','pin','pin_hash');
  end if;
  insert into public.audit_log(org, table_name, op, row_id, label, changed_cols, actor_sub, actor_role)
    values(
      rec->>'org',
      TG_TABLE_NAME,
      TG_OP,
      rec->>'id',
      coalesce(rec->>'resident_name', rec->>'name', rec->>'incident_type', rec->>'category', rec->>'template_name', ''),
      cols,
      a_sub,
      a_role
    );
  if (TG_OP = 'DELETE') then return OLD; else return NEW; end if;
end;
$$;

-- Attach to the compliance-sensitive tables.
drop trigger if exists audit_t on public.drug_tests;
create trigger audit_t after insert or update or delete on public.drug_tests for each row execute function public.audit_row();
drop trigger if exists audit_t on public.incidents;
create trigger audit_t after insert or update or delete on public.incidents for each row execute function public.audit_row();
drop trigger if exists audit_t on public.grievances;
create trigger audit_t after insert or update or delete on public.grievances for each row execute function public.audit_row();
drop trigger if exists audit_t on public.residents;
create trigger audit_t after insert or update or delete on public.residents for each row execute function public.audit_row();
drop trigger if exists audit_t on public.resident_documents;
create trigger audit_t after insert or update or delete on public.resident_documents for each row execute function public.audit_row();

notify pgrst, 'reload schema';
