-- 22_audit_actor_name.sql  —  preserve WHO acted, permanently
--
-- The activity log stored only the actor's id (actor_sub). Names were resolved live against `residents`,
-- so once a person was removed the entry lost their name ("An owner"/"A manager"). For compliance, the
-- acting person's name must survive on the record even after they leave or are renamed. This adds an
-- immutable `actor_name` captured by the trigger at the moment of the action (a lookup by actor_sub),
-- and backfills existing rows for anyone still in the system.
--
-- Safe to run more than once.

-- 1) New immutable actor-name column.
alter table public.audit_log add column if not exists actor_name text;

-- 2) Re-create the trigger to stamp the actor's name at write time.
--    (security definer + fixed search_path => it can read residents to resolve the name.)
create or replace function public.audit_row()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  claims json; a_sub text; a_role text; a_name text; rec jsonb; oldj jsonb; cols text[];
begin
  claims := nullif(current_setting('request.jwt.claims', true), '')::json;
  a_sub := claims->>'sub';
  a_role := claims->>'urole';
  if a_sub is not null then
    select name into a_name from public.residents where id = a_sub;   -- snapshot who they were at this moment
  end if;
  if (TG_OP = 'DELETE') then rec := to_jsonb(OLD); else rec := to_jsonb(NEW); end if;
  if (TG_OP = 'UPDATE') then
    oldj := to_jsonb(OLD);
    select array_agg(k) into cols from jsonb_each(to_jsonb(NEW)) as e(k, v)
      where e.v is distinct from (oldj -> e.k)
        and e.k not in ('admin_sig','resident_sig','manager_sig','sig_data_url','pin','pin_hash');
  end if;
  insert into public.audit_log(org, table_name, op, row_id, label, changed_cols, actor_sub, actor_role, actor_name)
    values(
      rec->>'org',
      TG_TABLE_NAME,
      TG_OP,
      rec->>'id',
      coalesce(rec->>'resident_name', rec->>'name', rec->>'incident_type', rec->>'category', rec->>'template_name', ''),
      cols,
      a_sub,
      a_role,
      a_name
    );
  if (TG_OP = 'DELETE') then return OLD; else return NEW; end if;
end;
$$;

-- 3) Backfill existing rows from whoever is still in `residents` (rows for people already hard-deleted
--    cannot be recovered; everything from here forward is captured permanently).
update public.audit_log a
  set actor_name = r.name
  from public.residents r
  where a.actor_sub = r.id and a.actor_name is null;

notify pgrst, 'reload schema';
