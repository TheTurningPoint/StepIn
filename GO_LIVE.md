# InStep — Go-Live Runbook (Tanya / Monday)

**You're basically done. This is the exact path to *live + paid*. Do the parts in order; each says how long.**
Internal doc — not served publicly (`*.md` is excluded).

> Status right now: app is **feature-complete and live on `instepapp.com`** (Cloudflare hosts it — DNS
> confirmed `104.21.x` / `172.67.x`). Everything from this week shipped. Nothing is broken.
> The only things left are a few *your-side* setup steps below. Deeper detail lives in `FOUNDER_CHECKLIST.md`.

---

## Part 1 — 10 minutes at a keyboard (technical)

**1a. Run the one pending SQL** in Supabase → SQL Editor (idempotent; safe to run once). This makes the new
incident & discharge **signatures** save. Until it's run, signing still works but the signature isn't stored
(you'll see a warning toast).
```sql
-- 24_incident_discharge_sig.sql
alter table public.incidents  add column if not exists incident_sig        text;
alter table public.residents  add column if not exists discharge_sig       text;
alter table public.residents  add column if not exists discharge_signed_by text;
notify pgrst, 'reload schema';
```
Already run this session (no need to repeat): `22_audit_actor_name.sql`, `23_login_active_only.sql`.

**1b. If you haven't already** (from `FOUNDER_CHECKLIST.md` §1): run `19_app_errors.sql` (owner-only error
log) and set the Edge Function secret **`ADMIN_SECRET`** (only needed for `admin.html` / new-customer
provisioning — *not* for Tanya's day-to-day). `21_feature_flags.sql` is only needed before you provision a
*new* org, so skip it for Monday.
> Don't bulk-run every file in `supabase/security/` — a couple are lockdown/revert tools. Run only what's named
> here.

**1c. Turn off GitHub Pages** (confirmed safe — Cloudflare is the host): repo **Settings → Pages → Build and
deployment → Source → "None"** (or "Unpublish site"). Stops the failing-deploy emails. Your site stays up.

**1d. (Optional, 5 min)** Free **UptimeRobot** monitor on `instepapp.com` — tells you about an outage before a
customer does. (`ADMIN_GUIDE.md` → Monitoring.)

## Part 2 — Set up Tanya's house for real (~15 min, in the app)

Sign in as the owner (Tanya or Ron) at `https://theturningpoint.instepapp.com`.
1. **Settings → Organization & managers:** confirm the org name; add the house(s); add each **manager by their
   full name** (that name is their sign-in *and* what shows on records).
2. **Each staffer:** Settings → *My account* → set their **full name + title** (appears on signed documents and
   screenings).
3. **Add residents** — one by one, or use the CSV import (Settings → Manage). Set move-in / recovery dates.
4. *(Optional)* Documents: upload the house's real policy PDFs as templates (Documents → **+ Add**) and send
   them to residents to sign.

That turns Monday into a real house, not the demo.

## Part 3 — Get paid (your #1 — cash flow)

From `FOUNDER_CHECKLIST.md` §3:
1. **Stripe account** — sole proprietor is fine to start (your name + SSN; no LLC needed for the first dollar).
2. **Connect your bank** for payouts.
3. **Create a Payment Link** — product "InStep — house subscription," **$99/mo recurring**; send Tanya the
   `buy.stripe.com/…` link. (Founding pricing = add a coupon or a second $49 link.)

**Bridge so payment never blocks Monday:** if Stripe isn't ready, just **invoice Tanya directly** (check /
Venmo / Zelle) for month one and wire up Stripe right after. Cash flow doesn't require perfect infra — it
requires a *yes* and a way to receive money.

## Part 4 — Go-live check (5 min — do this before you tell Tanya it's ready)

Log in as **owner, manager, and a test resident**, and confirm the loop works end-to-end:
- Resident: do a **meeting check-in** (GPS + witness signature) and a **curfew sign in/out**.
- Manager: log a **screening** (dual signature) and an **incident** (now asks for your signature) → both save.
- Owner: open **Settings → Activity log** → entries show **real names** (not "A user").
- Discharge a test resident → **Print discharge notice** → it shows the signature + right-to-appeal, then
  **Reinstate** them.
If those work, you're live. ✅

## Part 5 — After Max: operate mode + working with me

- **The app needs no developer to run.** Managers/residents just use it. Losing Max doesn't touch the live
  product.
- **Downgrade to Claude Pro (~$20/mo)** — keeps Claude Code for occasional tweaks/bugfixes (lower limits than
  Max, plenty for maintenance). *Verify current pricing at claude.ai/pricing.*
- **No lock-in:** everything is in your GitHub repo. Any future Claude session (Pro, Max later, fresh) picks up
  exactly where we are — this repo *is* the memory.
- **If something breaks:** check owner **Settings → 🔌 App errors** first; then start a Claude Code session and
  point it at the repo — it has all the context (CLAUDE.md, SCHEMA.md, this runbook).
- **Stretch Pro:** batch requests into fewer, bigger sessions; plan in the free web app; use Claude Code only
  for the actual edits.

## Part 6 — This week, money first (from the checklist)
1. **Close Tanya** — first paying house *and* your reference. (`SALES.md` §4 closing line.)
2. **Stripe live** — so the money can actually arrive.
3. **Then the complex** — recon questions → warm intro → 30-day per-head pilot. (`FOUNDER_CHECKLIST.md` §4.)

---

*You built a real, secure, live product and hardened it. The remaining work is money and sales, not code —
which is exactly where a founder's time should go. Get some sleep; this list will be here in the morning.*
