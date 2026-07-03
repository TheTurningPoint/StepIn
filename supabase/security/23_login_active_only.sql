-- 23_login_active_only.sql  —  archived/discharged accounts can no longer sign in
--
-- verify_login previously matched on name + org + pin_hash only, with no status check, so a discharged
-- resident (or an archived manager/owner, once staff are archived instead of hard-deleted) could still
-- authenticate. This adds a status guard so only active accounts can log in. Rows with a null status are
-- treated as active (existing managers/owners never had the column set).
--
-- Safe to run more than once. (Re-creates the function only; nothing else changes.)

create or replace function public.verify_login(p_name text, p_pin text, p_org text)
returns setof public.residents
language sql
security definer
set search_path = public, extensions
as $$
  select * from public.residents
  where lower(trim(name)) = lower(trim(p_name))
    and p_org is not null and p_org <> '' and org = p_org  -- require an explicit org; empty must never match all tenants
    and status is distinct from 'discharged'               -- archived/discharged accounts cannot sign in
    and pin_hash is not null
    and pin_hash = extensions.crypt(p_pin, pin_hash);
$$;
revoke all on function public.verify_login(text,text,text) from public, anon, authenticated;
grant execute on function public.verify_login(text,text,text) to service_role;

notify pgrst, 'reload schema';
