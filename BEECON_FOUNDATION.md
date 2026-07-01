# The Beecon Foundation

*What building InStep taught us — the playbook for everything next.*

---

## Why we exist

Beecon builds software that guides people home. Second chances, third, fifth — as
many as it takes. Every product answers one question: *does this help someone find
their way back?* If not, we don't build it.

*Beecon. The light that guides you home.*

---

## How we build (principles)

- **Lived experience is the moat.** We build where we know the pain from the inside.
  That's the one thing no funded team can fake — it's why InStep is real.
- **Design for the worst day, not the demo.** In our world, the edge cases *are* the
  product — relapse, overdose, a resident who doesn't come home, a discharge, a death.
  The happy path is table stakes; the hard moments are where trust is won.
- **Trust is a feature.** Privacy, isolation, honest claims. We say exactly what the
  software does — never "tamper-proof" when we mean "timestamped and signed."
  Overclaiming is how you lose the people who need you most.
- **Radical simplicity.** One file, no build step, no framework churn. Boring, legible
  tech ships faster and breaks less. Reach for complexity only when the problem demands it.
- **Fail safe, always.** Every feature degrades gracefully. Nothing new is ever allowed
  to break the core.

---

## The technical playbook (reusable across products)

- **Supabase as the spine:** Postgres + Row-Level Security *as the security boundary*
  (not hidden keys), Edge Functions for anything privileged, Storage for files.
- **Security lives on the server.** The client is public by design. Hash secrets, verify
  server-side, enforce isolation in RLS by a JWT claim. Assume the front end is readable
  by anyone.
- **Migration-first, staged, never lock out the live tenant.** Additive, idempotent SQL.
  Write code that's safe *before* the migration runs.
- **Verify before you ship.** Headless checks, zero JS errors across every role, then
  branch → main. Deploy is one boring push.
- **Demo mode is gold** — sample data, writes blocked. It sells the product *and* lets
  you test without a backend. Build it into everything.

---

## The product playbook (our domain)

- **Meet people where they are.** No smartphone? Staff can do it for them. Never make
  your hardest-hit user your blocker.
- **Roles are experiences.** Same system, different apps in feel for different users.
- **Config over fork.** One codebase, per-customer flags to serve different shapes of the
  same need. Never maintain two copies.
- **Records that hold up.** Retain the original, capture intent + identity + timestamps,
  and be honest about what that is legally.

---

## The business playbook

- **The frontier is people, not code.** The hardest, highest-value work is a conversation
  — a customer, a yes. Building can quietly become avoidance of that.
- **Revenue products fund mission products.** The paid product earns so the mission
  product can be free to the people who can't pay. Know which is which.
- **One product earns its keep before the next begins.** Two half-built things with no
  revenue is weaker than one shipped thing with one customer. Focus is the scarce resource.
- **Let real users pull the next product out of you.** Ship, listen, and build what they
  tell you is missing — don't guess in the dark.

---

## The disciplines (hard-won)

- **Name the chase.** The pull to reach for the next shiny thing before finishing the
  current one is the same wiring we fight elsewhere. Catching it *is* the skill.
- **Ship, then harden.** Feature-complete first; the security sweeps and polish come after
  there's something real to protect.
- **Interim beats perfect.** A raster logo now, the vector later. Don't let "perfect" hold
  the door shut.
- **Consolidate decisions into docs** so a solo founder never stalls in fog. (This one is
  that.)

---

*Born from InStep. Built to guide people home.*
