-- 15_pin_hash.sql  —  STAGE A of auth hardening (SAFE; app unchanged)
--
-- Stores PINs as bcrypt hashes instead of plaintext, and adds server-side functions to verify a
-- login and to set a PIN with proper authorization. Hashing stays in Postgres (pgcrypto), so the
-- client never sees a hash. Plaintext `pin` is left intact here so the current app keeps working;
-- Stage B switches the app to the hashed path, Stage C drops the plaintext column.
--
-- Safe to run more than once.

create extension if not exists pgcrypto with schema extensions;

-- Hash column + backfill existing plaintext PINs.
alter table public.residents add column if not exists pin_hash text;
update public.residents
  set pin_hash = extensions.crypt(pin, extensions.gen_salt('bf'))
  where pin_hash is null and pin is not null;

-- verify_login: returns the matching resident row when name (+org) and PIN match the hash.
-- Called ONLY by the login2 Edge Function (service role). Not exposed to the browser.
create or replace function public.verify_login(p_name text, p_pin text, p_org text)
returns setof public.residents
language sql
security definer
set search_path = public, extensions
as $$
  select * from public.residents
  where lower(trim(name)) = lower(trim(p_name))
    and (p_org is null or p_org = '' or org = p_org)
    and pin_hash is not null
    and pin_hash = extensions.crypt(p_pin, pin_hash);
$$;
revoke all on function public.verify_login(text,text,text) from public, anon, authenticated;
grant execute on function public.verify_login(text,text,text) to service_role;

-- set_pin: change a PIN with authorization checked from the caller's JWT.
--   * self-change: caller is the target, and must supply the correct current PIN.
--   * admin reset: caller is an owner/manager in the SAME org, and (owner OR same house as target).
-- Stores a fresh bcrypt hash and clears any plaintext. Callable by logged-in users (browser).
create or replace function public.set_pin(p_id text, p_new_pin text, p_current_pin text default null)
returns boolean
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  claims json;
  caller_sub text;
  caller_role text;
  caller_house text;
  caller_org text;
  target public.residents;
begin
  if p_new_pin is null or p_new_pin !~ '^[0-9]{4,}$' then
    raise exception 'PIN must be at least 4 digits';
  end if;

  claims := nullif(current_setting('request.jwt.claims', true), '')::json;
  caller_sub  := claims->>'sub';
  caller_role := claims->>'urole';
  caller_house:= claims->>'house';
  caller_org  := claims->>'org';

  select * into target from public.residents where id = p_id;
  if not found then raise exception 'no such user'; end if;

  if caller_sub = p_id then
    -- self change: verify current PIN
    if target.pin_hash is null or target.pin_hash <> extensions.crypt(coalesce(p_current_pin,''), target.pin_hash) then
      raise exception 'current PIN incorrect';
    end if;
  else
    -- admin reset: same org, owner (any house) or manager of the same house
    if caller_role not in ('owner','manager') then raise exception 'not authorized'; end if;
    if target.org is distinct from caller_org then raise exception 'not authorized'; end if;
    if caller_role <> 'owner' and (target.house is distinct from caller_house) then
      raise exception 'not authorized';
    end if;
  end if;

  update public.residents
    set pin_hash = extensions.crypt(p_new_pin, extensions.gen_salt('bf'))
    where id = p_id;
  return true;
end;
$$;
revoke all on function public.set_pin(text,text,text) from public, anon;
grant execute on function public.set_pin(text,text,text) to authenticated;

notify pgrst, 'reload schema';
