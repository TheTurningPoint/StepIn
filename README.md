# InStep

**InStep** (`instepapp.com`) is a digital management platform for **sober living and
recovery residences**. It helps houses track attendance, curfews, drug-test
screenings, incidents, chores, and signed documents — oriented around NARR (National
Association of Recovery Residences) compliance.

The app has three roles:

- **Resident** — recovery-day tracking, curfew sign in/out, GPS-verified meeting
  check-ins with witness signatures, chores, events, and document signing.
- **Manager** — house dashboard (live in/out status), screening logs, incident
  logging, resident management, chores/events, announcements, and printable reports.
- **Owner** — multi-house overview, org settings/branding, and staff management.

## Tech stack

- **Vanilla JavaScript** — no framework, no bundler, no build step.
- **[Supabase](https://supabase.com)** (Postgres) backend, loaded via CDN.
- Hand-written CSS with a `:root` design-token system.
- Browser APIs (Canvas signatures, Geolocation) + Nominatim geocoding.

## Project structure

The entire app lives in a single file.

| File | Description |
| --- | --- |
| `index.html` | The complete single-page application (CSS + HTML + JS inline). |
| `Demo.html` | Static marketing/landing page (no backend). |
| `CNAME` | GitHub Pages custom domain (`instepapp.com`). |
| `CLAUDE.md` | Architecture & conventions guide for AI assistants. |
| `SCHEMA.md` | Reverse-engineered Supabase table reference. |

## Running locally

There is nothing to install or build — open `index.html` in a browser.

- Live data requires network access and valid Supabase credentials; otherwise the
  client falls back to a no-op stub and data-driven screens stay empty.
- To exercise the UI **without a backend**, append a demo role to the URL:
  `index.html?demo=resident`, `?demo=manager`, or `?demo=owner` (loads sample data
  and blocks database writes).

## Deployment

Hosted on **GitHub Pages** with the `CNAME` custom domain; org tenants are served via
subdomains (e.g. `theturningpoint.instepapp.com`). There is no build step — **pushing
to the published branch deploys the site.** Treat changes to `index.html` as
production changes.

## Contributing notes

`index.html` is large and written compactly (many statements per line). Make surgical,
targeted edits that match the surrounding style, and avoid reformatting the whole file.
See [CLAUDE.md](CLAUDE.md) for full architecture and conventions.
