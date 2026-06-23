# Supabase Schema (InStep)

This documents the Supabase (Postgres) tables the app uses. It is **reverse-engineered
from the `sb.from(...)` queries, inserts, and updates in `index.html`** — it reflects
how the client uses the data, not an authoritative DDL dump. **Verify column names,
types, and Row Level Security (RLS) policies against the live Supabase project before
relying on them.** Where the client only ever does `select('*')`, columns are inferred
from the objects it reads/writes.

All tables use a **string `id`** generated client-side with a type prefix and a
timestamp (e.g. `ci-…` checkins, `cl-…` curfew, `ch-…` chores, `ev-…` events,
`dt-…` drug tests, `inc-…` incidents, `ann-…` announcements, `ack-…` acks,
`dtp-…` document templates, `rd-…` resident documents, `r-…` residents). The app
does not rely on DB-generated keys.

> **Security note:** the Supabase **anon key is shipped in `index.html` and is public
> by design.** All access control depends on **RLS policies** in Supabase. If RLS is
> loose, any client can read/write across houses. Treat RLS as the real security
> boundary — auditing it is a separate, deliberate task.

---

## `residents`

The central table. **Managers and owners are also rows here**, distinguished by
`role` — there is **no separate `managers` table.** The client loads staff via
`from('residents').select('id,name,role,house')` filtered by role.

| Column | Notes |
| --- | --- |
| `id` | `r-…` string id |
| `name` | display name |
| `pin` | login PIN (plaintext in client flows — see security note) |
| `role` | `'resident'` \| `'manager'` \| `'owner'` |
| `house` | house name; primary tenancy/scoping field |
| `phase` | recovery phase (drives curfew rules) |
| `move_in_date` | date |
| `sobriety_date` | date (drives recovery-day count) |
| `status` | `'active'` \| `'discharged'` |
| `discharge_date` | date or null |
| `discharge_reason` | text or null |

## `orgs`

Per-tenant branding/config, keyed by subdomain. Loaded via
`from('orgs').select('*').eq('subdomain', …).single()`.

| Column | Notes |
| --- | --- |
| `subdomain` | tenant key (e.g. `theturningpoint`) |
| `name` | org display name (login tagline) |
| `logo_url` | org logo; falls back to an embedded logo for known orgs |

## `settings`

**Singleton row** read/written with `.eq('id', 1)`. House-level configuration.

| Column | Notes |
| --- | --- |
| `id` | always `1` |
| `required` | int — required weekly meetings |
| `house_name` | text |

## `checkins`

Meeting check-ins with witness signature.

| Column | Notes |
| --- | --- |
| `id` | `ci-…` |
| `resident_id`, `resident_name` | who checked in |
| `meeting_type`, `meeting_name`, `address` | meeting details |
| `lat`, `lng` | GPS at check-in (or null) |
| `signer_name` | witness name |
| `sig_data_url` | witness signature, JPEG data URL |
| `ts` | ISO timestamp |
| `house` | scoping |

## `curfew_log`

Sign in/out and excused entries.

| Column | Notes |
| --- | --- |
| `id` | `cl-…` |
| `resident_id`, `resident_name` | who |
| `action` | `'in'` \| `'out'` \| `'excused'` |
| `ts` | ISO timestamp |
| `lat`, `lng` | GPS (or null) |
| `late` | bool |
| `excused` | bool |
| `excused_reason` | text (excused entries) |
| `destination` | text or null (sign-out) |
| `house` | scoping |

## `chores`

Weekly chore assignments.

| Column | Notes |
| --- | --- |
| `id` | `ch-…` |
| `resident_id`, `resident_name` | assignee |
| `title` | chore text |
| `completed_date` | date or null |
| `week_start` | week bucket |
| `house` | scoping |

## `events`

House calendar events.

| Column | Notes |
| --- | --- |
| `id` | `ev-…` |
| `title` | event name |
| `event_date`, `event_time` | when (`event_time` nullable) |
| `notes` | text or null |
| `created_by` | staff name |
| `house` | scoping (null = visible to all) |

## `drug_tests`

Screening logs with dual signatures.

| Column | Notes |
| --- | --- |
| `id` | `dt-…` |
| `resident_id`, `resident_name` | subject |
| `test_date`, `test_time` | when |
| `test_types` | joined types (e.g. `"Urine + Breathalyzer"`) |
| `result` | overall result |
| `notes` | composed notes incl. "Observed: Yes/No" |
| `administered_by` | admin name |
| `admin_sig`, `resident_sig` | signatures, JPEG data URLs (nullable) |
| `house` | scoping |
| `created_at` | ISO timestamp |

## `incidents`

NARR-style incident records.

| Column | Notes |
| --- | --- |
| `id` | `inc-…` |
| `incident_type` | category |
| `incident_date`, `incident_time` | when |
| `description` | text |
| `action_taken` | text |
| `authorities_notified` | bool |
| `resident_id`, `resident_name` | involved resident (nullable) |
| `reported_by` | staff name |
| `house` | scoping |
| `created_at` | ISO timestamp |

## `announcements`

Sticky-note announcements.

| Column | Notes |
| --- | --- |
| `id` | `ann-…` |
| `message` | text |
| `created_by` | staff name |
| `house` | target house |
| `is_global` | bool (cross-house) |
| `archived` | bool (queries filter `archived = false`) |
| `created_at` | ISO timestamp |

## `announcement_acks`

Resident acknowledgements of announcements.

| Column | Notes |
| --- | --- |
| `id` | `ack-…` |
| `announcement_id` | FK → `announcements.id` |
| `resident_id`, `resident_name` | who acknowledged |

## `document_templates`

Reusable document templates owners/managers can send.

| Column | Notes |
| --- | --- |
| `id` | `dtp-…` |
| `name` | template title |
| `description` | text |
| `url` | template/source URL (nullable) |
| `required` | bool |
| `created_at` | ISO timestamp |

## `resident_documents`

Per-resident document instances (signing workflow).

| Column | Notes |
| --- | --- |
| `id` | `rd-…` |
| `resident_id`, `resident_name` | recipient |
| `template_id`, `template_name`, `template_desc`, `template_url` | denormalized from template |
| `status` | `'pending'` \| `'resident_signed'` \| `'complete'` |
| `resident_sig` | signature data URL (set on signing) |
| `house` | scoping |
| `created_at` | ISO timestamp |

---

## Conventions across tables

- **`house`** is the primary tenancy/scoping field on most operational tables; the
  client filters in-memory by the current user's house (`myHouse()`).
- **Signatures** are stored inline as JPEG **data URLs** (`*_sig`, `sig_data_url`),
  not as Storage references.
- **Soft-delete / archive:** residents are discharged (`status`), announcements are
  archived (`archived`) rather than hard-deleted, preserving compliance history.
- Timestamps are ISO strings written by the client (`new Date().toISOString()`).
