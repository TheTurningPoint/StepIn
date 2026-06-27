# `reminders` Edge Function — email nudges

Sends each opted-in resident a single daily email covering what's waiting on them:
documents still pending their signature, and active announcements they haven't
acknowledged. De-duped via `reminders_log` (won't re-nag the same document within 3 days,
or the same announcement within 7). Cron-only; guarded by a shared `CRON_SECRET` header.

## One-time setup

1. **Run the SQL** (Supabase → SQL editor): `supabase/security/09_resident_contact.sql`
   (adds `email` / `notify_opt_in` to residents) and `10_reminders_log.sql` (dedupe table).

2. **Resend account** (the email provider):
   - Sign up at resend.com, **add and verify the domain `instepapp.com`** (Resend shows the
     DKIM/SPF records to add in Cloudflare — you already manage DNS there).
   - Create an API key.

3. **Set Edge Function secrets** (Supabase → Edge Functions → Secrets, or CLI):
   ```
   supabase secrets set CRON_SECRET="<a long random string>" --project-ref vhxswxilkuwsxwpsdjxl
   supabase secrets set RESEND_API_KEY="re_..."             --project-ref vhxswxilkuwsxwpsdjxl
   ```
   Without `RESEND_API_KEY` the function still runs but in **dry-run** mode (sends nothing,
   just reports what it would send) — handy for a first test.

4. **Deploy** — happens automatically via `.github/workflows/deploy-functions.yml` when this
   folder changes on the dev branch, or trigger it manually (Actions → Deploy Edge Functions
   → Run workflow).

5. **Schedule it daily** (Supabase → Database → Cron, or pg_cron + pg_net). Example pg_cron job
   that calls the function each morning with the secret header:
   ```sql
   select cron.schedule('instep-reminders','0 14 * * *', $$
     select net.http_post(
       url := 'https://vhxswxilkuwsxwpsdjxl.supabase.co/functions/v1/reminders',
       headers := jsonb_build_object('x-cron-secret','<same CRON_SECRET>')
     );
   $$);
   ```
   (`0 14 * * *` is 14:00 UTC ≈ morning in US time zones; adjust to taste.)

## Test it

```
curl -i -X POST "https://vhxswxilkuwsxwpsdjxl.supabase.co/functions/v1/reminders" \
  -H "x-cron-secret: <CRON_SECRET>"
```
Expect JSON like `{"ok":true,"dryRun":true,"residents_emailed":N,...}`. Set an opted-in
resident with an email + a pending document, run again with `RESEND_API_KEY` set, and they
should get exactly one email; a second run within 3 days sends nothing (dedupe).

A request without the correct `x-cron-secret` returns `401` — that's the guard working.
