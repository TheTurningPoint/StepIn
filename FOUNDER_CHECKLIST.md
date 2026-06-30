# InStep — Founder Checklist

Everything left to do, in priority order. The **product is built, hardened, and deployed** — this list
is your-side actions only (Supabase, payments, sales). Tick off what's done; skip anything you've
already handled. Internal doc — not served publicly.

---

## 1. Unblock what's already built  ·  ~15 min, in Supabase  ·  do when you're at a keyboard

- [ ] **Run `supabase/security/19_app_errors.sql`** — turns on the owner-only App Errors log
      (Settings → 🔌 App errors). Harmless until run; the error handler just no-ops without it.
- [ ] **Run the hardened `verify_login` block** (the standalone block from `15_pin_hash.sql` I gave
      you — *not* the whole file; the file's backfill references the dropped `pin` column). Closes the
      cross-tenant login check at the DB layer. **Not urgent** — the deployed `login2`/`pinreset`
      already enforce it.
- [ ] **Set Edge Function secret `ADMIN_SECRET`** (a long random string, e.g. `openssl rand -base64 32`
      or any password generator) in Supabase → Project Settings → Edge Functions → Secrets. Required
      for `admin.html` / new-customer provisioning to work. Save the value in your password manager.
- [ ] *(Optional)* Repo secret `TEST_ORG = theturningpoint` so the CI token test keeps running.
- [ ] *(Optional)* Free **UptimeRobot** monitor on `instepapp.com` — see ADMIN_GUIDE "Monitoring &
      uptime." Tells you about an outage before a customer does.

## 2. Before you provision the complex (or any new customer)

- [ ] **Run `supabase/security/21_feature_flags.sql`** — adds the per-org curfew/chores/unit-label
      columns that provisioning writes. Additive and safe. **Not needed for The Turning Point** or
      everyday use; only needed before you create a *new* org via `admin.html`.

## 3. Get paid  ·  no code  ·  this is what stands between you and revenue

- [ ] **Stripe account** — sign up as a sole proprietor (your name + SSN is fine to start; no LLC
      needed for the first dollar).
- [ ] **Connect your bank** for payouts.
- [ ] **Create a Payment Link** — product "InStep — house subscription," **$99/mo recurring**. Share
      the `buy.stripe.com/…` link when a house says yes. For founding pricing, add a coupon or a second
      $49 link.
- [ ] **LLC track (do once, clean — recommended before any real volume; not blocking):** form the LLC
      (your state's site), get a free **EIN** (irs.gov), open a **business bank account**, then switch
      Stripe's payout bank to it. We discussed: if the LLC is quick in your state, do it *first* and
      create Stripe under it to skip a later migration; otherwise start sole-prop and switch later (one
      customer = trivial migration).

## 4. Sales — the actual leverage now

- [ ] **Close The Turning Point (Tanya).** Your first paying house *and* your reference for everyone
      after. Use the demo + the closing line in **SALES.md** §4. One yes here unlocks the rest.
- [ ] **Complex recon.** Send your staff/resident contact the forwardable blurb + the **5 recon
      questions** (in our chat, and the demo flow is in **CALL_SHEET.md**). Goal: learn what they use
      now, the #1 pain, and *who decides* — then get the warm intro.
- [ ] **Complex pilot.** Once you're introduced: propose **one wing/building, 30 days**, you set it up,
      priced **per head** ($3–5/head = $600–1,000/mo for 200). Provision them as *curfew off, label =
      Building* in ~2 minutes (after step 2's migration).

## 5. Only when it applies — don't do early

- [ ] **100+ resident scale-hardening.** Documented in **ADMIN_GUIDE.md** "Scaling to a large
      facility." A 20–30-resident pilot needs none of it; do the ~half-day fix during/after the pilot,
      before full 200-rollout.

---

### Where things stand (so you can trust this list)
- ✅ App: feature-complete, security-swept (5 reviewers + adversarial re-review), multi-org isolation
  verified live, per-org feature config shipped.
- ✅ Live on `instepapp.com` (site auto-deploys on push to `main`); Edge Functions deploy via the
  GitHub Action.
- 📌 The frontier is **sales + payments**, not code. Highest-value next click: **talk to a customer.**

*Reference docs: SALES.md (sales kit), CALL_SHEET.md (live-demo map), ADMIN_GUIDE.md (onboarding +
monitoring + scaling), SCHEMA.md (data model).*
