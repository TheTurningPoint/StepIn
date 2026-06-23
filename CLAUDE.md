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

This repo **is** the entire codebase. There is no `src/`, no build output, and no
hidden tooling. Everything below lives at the repo root.

| File | What it is |
| --- | --- |
| `index.html` | **The whole application.** ~308KB / ~2,275 lines. Single-page app with embedded CSS + JS. This is where ~all work happens. |
| `Demo.html` | Static marketing/landing page (~29KB). Phone-frame mockup, feature list, pricing. Tiny JS only (`setRole`, `launchDemo`). No backend. |
| `README.md` | One line (`# StepIn`). |
| `CNAME` | `instepapp.com` — GitHub Pages custom domain. |

There is **no** `.github/` workflow, `package.json`, lockfile, or build configuration.

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
  manually after mutations.
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

## Data model (Supabase, inferred)

The following tables are **inferred from queries in `index.html`** — verify against
the live Supabase schema before relying on exact columns:

`residents`, `managers`, `orgs` (subdomain/branding/required-meetings settings),
`checkins`, `curfew_log`, `chores`, `events`, `drug_tests`, `incidents`,
`announcements`, `announcement_acks`, `documents`.

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

- **No build / test / lint steps exist.** Don't look for `npm`, a test runner, or CI.
- **Preview:** open `index.html` in a browser. Supabase calls need network access and
  valid credentials; otherwise the fallback stub no-ops and data-driven screens stay
  empty.
- **Exercise the UI without a backend:** append `?demo=resident`, `?demo=manager`, or
  `?demo=owner` to the URL.
- **Make changes by editing `index.html` directly** (CSS, HTML, and JS are all in
  that one file). Keep `Demo.html` in sync only for branding/marketing — it has no
  backend logic.

## Deployment

GitHub Pages serves the repo at `instepapp.com` via the `CNAME` file; org tenants are
reached through subdomains. There is no build step — **pushing to the published branch
publishes the site.** Treat changes to `index.html` as production changes.

## Gotchas for AI assistants

- **`index.html` is large and written compactly** (many statements per line, minimal
  whitespace in the HTML/JS). Use targeted `Grep`/`Read` with line ranges instead of
  reading the whole file, and make **surgical edits** that match the surrounding
  compact style.
- **Never reformat or reflow the whole file** — it produces massive, unreviewable
  diffs and risks breaking string literals/templates.
- **The Supabase anon key is public by design** (see Data model). Don't remove it,
  don't treat it as a leaked secret, and don't introduce any new secrets.
- **Keep `Demo.html` purely presentational** — it intentionally has no backend.
