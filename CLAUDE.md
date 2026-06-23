# CLAUDE.md

Guidance for AI assistants (Claude Code and others) working in this repository.

## Project overview

**InStep** (repo name `StepIn`, marketed at `instepapp.com`) is a digital management
platform for **sober living / recovery residences** (transitional recovery housing).
It is oriented around NARR (National Association of Recovery Residences) compliance —
attendance tracking, drug-test logs, incident records, and signed documents.

The app serves three user roles, each with a distinct experience:

- **Resident** — recovery-day tracking, curfew sign in/out, GPS-verified meeting
  check-ins with witness signatures, chores, events, document signing, PIN reset.
- **Manager** — house dashboard (live in/out status), screening (drug-test) logs,
  incident logging, resident management, chores/events, announcements, printable
  compliance reports.
- **Owner** — multi-house overview, org settings/branding, manager management; can
  act across houses.

Multitenancy is by subdomain (e.g. `theturningpoint.instepapp.com`), with org name,
colors, and logo loaded from the backend.

## Repository layout

This repo **is** the entire codebase. There is no `src/` and no build step (a static
site served as-is). Everything below lives at the repo root.

| File | What it is |
| --- | --- |
| `index.html` | **The whole application.** ~308KB / ~2,275 lines. Single-page app with embedded CSS + JS. This is where ~all work happens. |
| `demo.html` | Static marketing/landing page (~29KB). Phone-frame mockup, feature list, pricing. Tiny JS only (`setRole`, `launchDemo`). No backend. The app redirects the root domain here, so the lowercase filename matters (Cloudflare is case-sensitive). |
| `README.md` | Project overview and quick start for humans. |
| `SCHEMA.md` | Reverse-engineered Supabase table reference. |
| `wrangler.toml` | Cloudflare Workers static-assets config (serves the repo as the website). |
| `.assetsignore` | Files Cloudflare must **not** serve publicly (SQL, docs, function source). |
| `supabase/` | Edge function source (`functions/login2`) and RLS/security SQL migrations (`security/*.sql`). Not served publicly. |
| `.github/workflows/` | `deploy-functions.yml` — deploys the `login2` Edge Function via CI. |
| `CNAME` | Legacy GitHub-Pages artifact (`instepapp.com`); ignored by Cloudflare, kept harmlessly. |

There is **no** `package.json`, lockfile, or front-end build configuration — the site
is plain static files.

## Tech stack

- **Vanilla JavaScript** — no framework (no React/Vue), no bundler, no transpiler.
- **Supabase** (Postgres + JS client) is the backend. The only external dependency,
  loaded by CDN at `index.html:4`:
  `<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>`.
- **Hand-written CSS** with a `:root` design-token system (no Tailwind/Bootstrap).
- **Browser APIs:** Canvas (signature capture), Geolocation (GPS check-in).
- **Nominatim** (OpenStreetMap) for address → lat/lng geocoding.

There is **nothing to install, compile, or bundle.** Open the HTML file in a browser
and it runs.

## Architecture of `index.html`

Single-file layout, top to bottom:

1. **Head / PWA meta** (lines ~1–4) — viewport, apple-mobile-web-app tags, a
   base64 apple-touch-icon, and the Supabase CDN `<script>`.
2. **CSS** (`<style>` from ~line 5) — a readable `:root` design-token block followed
   by component styles, organized by section, ending with `@media print` rules.
3. **HTML** — screen containers and modals.
4. **JavaScript** (`<script>` from ~line 954) — state, Supabase init, router, and
   feature handlers.

Key anchors:

- **Supabase client** — `index.html:955` `SUPABASE_URL`; `:957`
  `const sb = supabase.createClient(...)` with a **no-op fallback stub** when the CDN
  client is unavailable (so the UI doesn't crash offline; DB calls just resolve to
  `{data:null,error:null}`).
- **Global mutable state** (no reactive store): `currentUser`, `isDemoMode`,
  `allResidents`, `allCheckins`, `allManagers`, `selectedHouse`, plus `cached*`
  arrays. Data is loaded into these globals, filtered in-memory, and re-rendered
  manually after mutations. Note: `allManagers` is populated from the **`residents`**
  table filtered by `role` — managers/owners are residents, not a separate table.
- **Role helpers:** `isOwner()`, `isStaff()`, `myHouse()`, `residents()`,
  `checkins()` — predicates/derived views used throughout for access control and
  house scoping.
- **Screen router:** `show(screenId)` toggles the `.screen.active` class. Screens:
  `screen-login`, `screen-resident`, `screen-checkin`, `screen-manager`.
- **Persistence:** the logged-in user is stored in `localStorage` under key `si_user`
  and restored on reload.
- **Demo mode:** URL param `?demo=resident|manager|owner` loads sample data and
  **blocks DB writes** (`isDemoMode = true`). Use this to exercise the UI without a
  backend.

## Data model (Supabase)

Full per-column details are in **[SCHEMA.md](SCHEMA.md)** (reverse-engineered from the
`sb.from(...)` calls; verify against the live schema before relying on exact columns).

Tables: `residents` (also holds managers/owners via `role`), `orgs` (subdomain
branding), `settings` (singleton, `id=1`), `checkins`, `curfew_log`, `chores`,
`events`, `drug_tests`, `incidents`, `announcements`, `announcement_acks`,
`document_templates`, `resident_documents`. There is **no `managers` table** — staff
are rows in `residents`. `house` is the primary scoping field on operational tables;
signatures are stored inline as JPEG data URLs.

The Supabase **anon key is client-side and public by design** — security is enforced
by Supabase Row Level Security (RLS), not by hiding the key. Do **not** "fix" this and
do **not** add any new secrets to the file.

## Conventions

- **Function-name prefixes:**
  - `render*` — populate/redraw DOM (e.g. `renderResidentHome`, `renderManagerDashboard`).
  - `open*` — open a modal (e.g. `openDrugTest`, `openAddChore`).
  - `save*` — async DB write (e.g. `saveIncident`, `saveNewResident`).
  - `on*` — event handler.
  - `is*` / `get*` — predicates / helpers.
- **Modals:** a `.modal-bg.open` overlay wrapping a `.modal` card; `closeModal(id)`
  removes `.open`.
- **Async write pattern:** validate → disable the button (`Saving...`) →
  `await sb.from(...)` → on error toast + re-enable → on success mutate the local
  global array → call the relevant `render*()` → close modal → toast success.
- **CSS design tokens (`:root`) & color semantics:** pink (`--pink #C0397A`) is the
  primary action color; **gold = owner-only** features; green = success/on-track,
  yellow/orange = pending/out, red = danger/late. Reuse the tokens — avoid hardcoded
  colors.
- **Responsive:** mobile-first (~360px base), centered max-width container on wider
  screens. **Print:** `@media print` hides nav/buttons and formats the compliance
  reports for PDF export (`window.print()`).
- **Multitenancy:** org branding/config is resolved from the subdomain at load.

## Development workflow

- **No front-end build / test / lint steps exist.** Don't look for `npm` or a test
  runner. (The only CI is `deploy-functions.yml`, which deploys the Edge Function —
  it does not build the site.)
- **Preview:** open `index.html` in a browser. Supabase calls need network access and
  valid credentials; otherwise the fallback stub no-ops and data-driven screens stay
  empty.
- **Exercise the UI without a backend:** append `?demo=resident`, `?demo=manager`, or
  `?demo=owner` to the URL.
- **Make changes by editing `index.html` directly** (CSS, HTML, and JS are all in
  that one file). Keep `demo.html` in sync only for branding/marketing — it has no
  backend logic.

## Deployment

Hosted on **Cloudflare Workers (static assets)** at `instepapp.com`; org tenants are
reached through subdomains, each added as a Worker custom domain. `wrangler.toml`
declares the repo root as the asset directory and `.assetsignore` keeps non-site
files (SQL, docs, function source) from being served. There is no build step —
**pushing to `main` auto-deploys the site** (Cloudflare rebuilds on push, same as the
old Netlify flow). Treat changes to `index.html` as production changes.

The **`login2` Edge Function** (`supabase/functions/login2`) is deployed separately
via the `.github/workflows/deploy-functions.yml` GitHub Action (Supabase CLI). DNS +
email (MX/SPF/DKIM/DMARC) for the domain live in Cloudflare; the registrar is IONOS.

## Gotchas for AI assistants

- **`index.html` is large and written compactly** (many statements per line, minimal
  whitespace in the HTML/JS). Use targeted `Grep`/`Read` with line ranges instead of
  reading the whole file, and make **surgical edits** that match the surrounding
  compact style.
- **Never reformat or reflow the whole file** — it produces massive, unreviewable
  diffs and risks breaking string literals/templates.
- **The Supabase anon key is public by design** (see Data model). Don't remove it,
  don't treat it as a leaked secret, and don't introduce any new secrets.
- **Keep `demo.html` purely presentational** — it intentionally has no backend. Keep
  the filename **lowercase** (the root-domain redirect targets `/demo.html`, and the
  host is case-sensitive).
- **RLS is the security boundary.** Data tables are locked to logged-in (token-bearing)
  users via Supabase RLS; `login2` issues the token (claims `urole`/`house`). Don't
  loosen policies back to anonymous. See `supabase/security/*.sql`.
