-- 17_pin_reset.sql  —  owner/manager self-serve PIN reset via emailed code (Stage E)
--
-- Backs the `pinreset` Edge Function. A locked-out owner/manager gets a one-time 6-digit code
-- emailed to the address on their resident row, then sets a new PIN with it. Protections: codes are
-- stored hashed, expire (15 min), are single-use, and a 5-try cap stops brute-forcing the 6 digits.
--
-- Safe to run more than once.

create table if not exists public.pin_resets (
  id          bigint generated always as identity primary key,
  resident_id text not null,
  code_hash   text not null,
  expires_at  timestamptz not null,
  used        boolean not null default false,
  attempts    int not null default 0,
  created_at  timestamptz not null default now()
);
-- RLS on with NO policies => only the service role (the Edge Function) can touch it.
alter table public.pin_resets enable row level security;
create index if not exists pin_resets_resident_idx on public.pin_resets(resident_id, used, expires_at);

-- Service-role-only PIN-hash setter, used by the pinreset function AFTER it verifies the code.
-- (set_pin requires a logged-in caller; this one is for the no-JWT reset flow.)
create or replace function public.admin_set_pin_hash(p_id text, p_new_pin text)
returns boolean
language plpgsql security definer set search_path = public, extensions as $$
begin
  if p_new_pin is null or p_new_pin !~ '^[0-9]{4,}$' then
    raise exception 'PIN must be at least 4 digits';
  end if;
  update public.residents set pin_hash = extensions.crypt(p_new_pin, extensions.gen_salt('bf')) where id = p_id;
  return found;
end;
$$;
revoke all on function public.admin_set_pin_hash(text,text) from public, anon, authenticated;
grant execute on function public.admin_set_pin_hash(text,text) to service_role;

notify pgrst, 'reload schema';
