-- Grievance log table. Residents and staff file grievances; staff resolve them.
-- Locked to logged-in (authenticated) users, consistent with the other tables.
create table if not exists public.grievances (
  id text primary key,
  filed_by text,
  resident_id text,                    -- the filer's resident id (null = staff-filed or anonymous)
  category text,
  description text,
  status text default 'open',          -- 'open' | 'resolved'
  grievance_date date,
  house text,
  resolution text,
  resolved_by text,
  resolved_at timestamptz,
  created_at timestamptz default now()
);

alter table public.grievances enable row level security;
drop policy if exists grievances_auth on public.grievances;
create policy grievances_auth on public.grievances
  for all to authenticated using (true) with check (true);
