# InStep — Admin / Onboarding Guide

Internal. Not served publicly (`.assetsignore` excludes `*.md`). How to stand up a customer and run
the backend. Read the **Multi-tenancy status** section before onboarding a *second, independent* org.

---

## How a customer is structured

- Each org gets a **subdomain**: `theturningpoint.instepapp.com`. Add it as a Cloudflare Worker
  custom domain (same as the existing ones).
- Branding (name, logo, colors) comes from the **`orgs`** table, matched on `subdomain`.
- People (residents, managers, owners) are all rows in **`residents`**, distinguished by `role`
  (`resident` / `manager` / `owner`) and scoped by `house`.
- Org-level settings (meeting requirement, lab policy, house GPS) live in **`settings`**.

Login = name + 4-digit PIN → the `login2` Edge Function issues a token with the user's `house` and
`urole`. Row-Level Security uses those to wall off each house's data.

---

## Onboard a new customer (the easy way)

Use the provisioning page instead of SQL:

1. Open **`instepapp.com/admin.html`** (vendor-only; useless without the secret).
2. Enter your **ADMIN_SECRET**, the customer's **subdomain**, **org name**, **owner name**, a 4-digit
   **owner PIN**, and (optional) **owner email**. Tap **Create customer**. This creates the org, the
   first owner (PIN hashed), and the settings row.
3. **Add the subdomain in Cloudflare** as a Worker custom domain (`<subdomain>.instepapp.com`) — the
   one step that can't be automated.
4. Send the owner their URL + name + temporary PIN; they sign in and can change the PIN / add residents.

One-time setup: set **`ADMIN_SECRET`** (a long random string) in Supabase → Edge Functions → secrets.
The `provisionorg` function (deployed by the Actions workflow) reads it.

## Onboard a new house manually (fallback, SQL)

If you'd rather not use the page, run these in the Supabase SQL Editor.

**1. Branding row** (skip if the org already exists):
```sql
insert into orgs (subdomain, name, logo_url)
values ('theturningpoint', 'The Turning Point', null)
on conflict (subdomain) do update set name = excluded.name;
```

**2. First manager/owner login** (so they can get in and add everyone else):
```sql
insert into residents (id, name, pin, role, house, status)
values ('mgr-' || extract(epoch from now())::bigint,
        'Tanya',          -- their name (what they'll type to log in)
        '4729',           -- 4-digit PIN (have them change it in-app after)
        'owner',          -- 'owner' sees all houses; 'manager' sees one
        'Main House',     -- their house
        'active');
```

**3. Settings** — the owner sets meeting requirement, org name, lab policy, and each house's
check-in location **in-app** (Settings → "Organization & managers"). The `settings` row already
exists for the current backend; for the check-in away-flag, run `supabase/security/12_house_coords.sql`
once if it hasn't been, then set the location in-app.

**4. Hand off**: send them `https://<subdomain>.instepapp.com`, their name + temporary PIN, and tell
them to change the PIN under their profile. They add residents from **Actions → Add resident**.

That's it — a house can be live in a few minutes.

---

## Day-to-day backend notes

- **Reminders** (daily resident emails) run via the `reminders` Edge Function on a `pg_cron` schedule,
  authenticated with the `x-cron-secret` header. Confirm the job exists: `select jobname, schedule,
  active from cron.job;`. Manual test: `net.http_post` to the function URL with the secret header.
- **Migrations** live in `supabase/security/*.sql` and are idempotent (`add column if not exists`).
  Run them in order in the SQL Editor when deploying a new backend.
- **Security**: data tables are RLS-locked to logged-in users and isolated by house. `orgs` is
  intentionally anon-readable (login-screen branding). Don't loosen these.

---

## Monitoring & uptime (know when something breaks)

Three layers, cheapest first:

1. **In-app error log.** Run `supabase/security/19_app_errors.sql` once. After that, any uncaught
   JavaScript error a real (signed-in, non-demo) user hits is best-effort written to the `app_errors`
   table — message, trimmed stack, page URL, browser. It's de-duped and capped per session so it can't
   spam. **Owners see it in the app:** Settings → **🔌 App errors** (newest first). Normally empty; if
   the same error keeps appearing, that's your signal to look. No PII is stored there.

2. **Deploy health checks (already running).** The `deploy-functions.yml` Action runs three smoke
   tests on every function deploy: a deliberately-wrong `login2` (expects 401 → proves the function +
   DB + rate-limit table are alive), a real-login token test (optional, needs repo secrets
   `TEST_NAME`/`TEST_PIN`), and a "stranger gets nothing" lockdown check. A red Action = something is
   wrong before users see it.

3. **External uptime monitor (recommended, free).** The above only fire on deploys. To know if the
   live site goes down, add a free monitor — e.g. [UptimeRobot](https://uptimerobot.com):
   - Add an **HTTP(s)** monitor for `https://instepapp.com` (and each tenant subdomain, e.g.
     `https://theturningpoint.instepapp.com`), 5-minute interval.
   - Optionally add a **keyword** monitor for the `login2` function URL that alerts if it stops
     returning a response.
   - Point alerts at your email/phone. This tells you about an outage before a customer does.

---

## Multi-tenancy status — read before independent customer #2

Shared multi-tenancy is **built**. Independent owners can safely share this one backend, isolated by
organization (not just by house name):

- Every scoped table carries an **`org`** column (the subdomain, e.g. `theturningpoint`) —
  `13_org_isolation.sql`.
- **`login2`** puts the user's `org` in the login token (JWT `org` claim).
- **RLS isolates by `org`** — house-scoped tables require `org = auth.jwt()->>'org'` AND (owner OR same
  house); org-wide tables (`settings`, `document_templates`, `announcement_acks`) match on `org` only —
  `14_org_rls.sql`. So two unrelated orgs that both name a house "Main House" can no longer see each
  other's data.
- **`settings` is keyed per-org** (no longer the shared `id = 1` row); a new org's settings row is
  created automatically on its first in-app save.

### Go-live checklist before onboarding an independent customer #2

The isolation is only *enforced* once these are applied in **this** Supabase project, in order:

1. `13_org_isolation.sql` has been run (adds `org` everywhere, backfills existing rows). ✅ done for TTP.
2. The current `login2` (issues the `org` claim) is deployed. ✅ shipped.
3. `14_org_rls.sql` has been run — **this is the enforcement step.** If you haven't run it yet, do it
   before adding a second org. Re-runnable; revert by re-running `05_house_isolation.sql`.
4. **Everyone signs in once more after step 3.** Tokens minted before `14` have no `org` claim and will
   be denied — old saved sessions just get a one-time "please sign in again." Expected, not a bug.

### Verify isolation before relying on it

Provision a throwaway org via `admin.html` (e.g. `testorg`), give it a house with the **same name** as
one of an existing org's houses, then confirm: the `testorg` owner/manager sees only `testorg` data and
The Turning Point sees only its own — the house-name collision no longer leaks. Delete the test rows when
done.

> Fallback (only if you ever want hard physical separation): give a customer their own Supabase project
> and point their subdomain's deployment at it. Rarely needed now that org isolation is in place.

