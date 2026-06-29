-- 16_drop_pin_plaintext.sql  —  STAGE C of auth hardening (run LAST)
--
-- Removes the plaintext PIN column once Stage B is live and verified: logins work via the hashed
-- path (verify_login) and all PIN changes go through set_pin (which writes pin_hash and nulls pin).
--
-- Do NOT run this until you've confirmed on the live app:
--   * you can sign in,
--   * you can change your own PIN (wrong current rejected, right current accepted),
--   * a manager/owner can reset someone's PIN.
--
-- After this, plaintext PINs no longer exist anywhere. Safe to run more than once.

alter table public.residents drop column if exists pin;

notify pgrst, 'reload schema';
