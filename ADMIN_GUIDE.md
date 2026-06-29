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

## ⚠️ Multi-tenancy status — read before independent customer #2

The current backend is safe for **one organization** (one owner, any number of that owner's houses).
It is **not yet safe to put two *independent* owners on the same backend**, for two reasons:

1. **`settings` is a single shared row** (`id = 1`). A second org's manager would overwrite the first
   org's name / meeting requirement / lab policy / house GPS.
2. **Isolation keys on the house *name*** (`house = auth.jwt()->>'house'`). Two unrelated orgs that
   both name a house "Main House" could see each other's residents and records. House names aren't
   globally unique.

**Two ways to fix it (pick before onboarding an unrelated owner):**

- **Simplest now — one backend per customer.** Give each independent customer their own Supabase
  project (run the migrations, set their own `SUPABASE_URL`/anon key for that deployment). Complete
  isolation; the singleton settings and house-name collisions stop mattering. Cost: a per-customer
  setup and a way to point each subdomain's deployment at its own backend.

- **Proper shared multi-tenancy (bigger build).** Add an `org` (or `org_id`) column to every scoped
  table (`residents`, `checkins`, `curfew_log`, `chores`, `drug_tests`, `incidents`,
  `resident_documents`, `grievances`, `announcements`, `events`, `settings`); have `login2` put the
  user's `org` in the JWT; rewrite the RLS policies to `org = auth.jwt()->>'org'` (keep `house` as a
  secondary filter); and key `settings` reads/writes by `org` instead of `id=1`. This lets all
  customers share one backend safely. It's a careful, well-tested change — recovery-resident PII is at
  stake — so plan it as its own project, not a quick patch.

Until one of these is done: **one organization per backend.** The Turning Point is fine as-is.
