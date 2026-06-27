-- 10_reminders_log.sql
-- Dedupe ledger for the `reminders` Edge Function so a given reminder isn't
-- re-sent more than once every few days. Written only by the function (service
-- role). RLS is enabled with NO policies, so anon/authenticated clients can't
-- read or write it — only the service role (which bypasses RLS) can.

create table if not exists public.reminders_log (
  id          bigserial primary key,
  resident_id text not null,
  kind        text not null,   -- 'doc' (announcements later)
  ref         text not null,   -- the document / item id this reminder was about
  sent_at     timestamptz not null default now()
);

create index if not exists reminders_log_sent_at_idx on public.reminders_log (sent_at);
create index if not exists reminders_log_lookup_idx  on public.reminders_log (resident_id, kind, ref);

alter table public.reminders_log enable row level security;
-- intentionally NO policies → only the service role can touch this table.

notify pgrst, 'reload schema';
