-- 34_staff_verified_meetings.sql  —  meetings recorded by staff on a resident's behalf
--
-- When a resident can't check in themselves (no phone, dead battery, …) a manager or owner can
-- record a meeting they verified. Those rows have no GPS and no witness signature; instead they
-- carry who verified it and how:
--   verified_by_id / verified_by_name  — the staff member (a residents row with a staff role)
--   verification_note                  — how it was verified, e.g. "Paper sign-in sheet — …"
--   verified_at                        — set by the database on insert (when the entry was made,
--                                        as opposed to ts, the meeting time staff entered)
-- Resident check-ins leave all four null.
--
-- RLS is unchanged: checkins_auth already lets staff insert rows for residents in their house
-- (owners: any house) within their org.
--
-- Additive and safe to run more than once.

alter table public.checkins
  add column if not exists verified_by_id text,
  add column if not exists verified_by_name text,
  add column if not exists verification_note text,
  add column if not exists verified_at timestamptz;

-- Default only applies to staff-verified rows; resident check-ins keep verified_at null.
create or replace function public.checkins_set_verified_at() returns trigger language plpgsql as $$
begin
  if new.verified_by_name is not null then new.verified_at := now(); end if;
  return new;
end $$;
drop trigger if exists checkins_verified_at on public.checkins;
create trigger checkins_verified_at before insert on public.checkins for each row execute function public.checkins_set_verified_at();

notify pgrst, 'reload schema';
