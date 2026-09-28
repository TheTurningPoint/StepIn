-- 30_audit_attendance.sql  —  put attendance records in the activity log
--
-- Meeting check-ins (`checkins`) and curfew sign in/out (`curfew_log`) were not covered by the
-- activity log (18_audit_log.sql), so an edited or removed attendance record left no trace. This
-- attaches the existing audit_row() trigger to both tables.
--
-- UPDATE and DELETE only: every check-in and curfew entry is already its own timestamped record, and
-- logging each insert would bury the edits/removals the log exists to surface. What matters for the
-- record is that a change to attendance after the fact is captured, with who did it.
--
-- Requires 18_audit_log.sql and 22_audit_actor_name.sql. Safe to run more than once.

drop trigger if exists audit_t on public.checkins;
create trigger audit_t after update or delete on public.checkins for each row execute function public.audit_row();
drop trigger if exists audit_t on public.curfew_log;
create trigger audit_t after update or delete on public.curfew_log for each row execute function public.audit_row();

notify pgrst, 'reload schema';
