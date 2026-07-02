# Beecon — Business Plan

**Studio:** Beecon · Denver, Colorado · solo founder, bootstrapped
**Product #1:** InStep (instepapp.com) — management software for sober living & recovery residences
**Date:** July 2026 · **Status:** product live in production; pre/early-revenue

---

## 1. Executive summary

Recovery residences — sober living homes — run on paper binders and goodwill. They are accountable to the NARR Standard (attendance, screenings, incidents, grievances, signed documents) but most have no software fit for how a house actually works: small staff, tight budgets, everything happening on a phone at 10pm.

**InStep** is that software, and it is live. Residents check in to meetings with GPS and a witness signature, sign in and out for curfew, and e-sign house documents from their phone. Managers log screenings and incidents, track grievances to resolution, and print NARR-ready PDF reports in one tap. Owners get a multi-house roll-up. It is multi-tenant (subdomain per organization, database-enforced isolation), self-serve to provision, and costs almost nothing to run.

**Price:** $99 per house per month, unlimited residents and staff, no contract. Founding houses: $49/month locked in.

**Stage:** feature-complete, security-reviewed, deployed. First customer (The Turning Point, multi-house) is at the close; one ~200-bed transitional complex is in early recon for a per-bed pilot.

**The goal for the next 12 months:** 15–25 paying houses plus one complex pilot converted — roughly $2,500–4,000 MRR — proving the referral-driven motion, funding the founder's time at better than break-even on business costs, and earning the right to start Beecon's mission products (Porchlight, for families of people in addiction).

**The ask:** none, financially. This plan is the operating document for a bootstrapped business. The open decisions it flags — entity formation timing, whether to ever raise — belong to the founder.

---

## 2. The problem

A recovery residence lives and dies on records. NARR certification (and increasingly, state funding and referral relationships) requires documented meeting attendance, drug/alcohol screening logs, incident reports, a resident grievance process, and signed resident agreements. Today the typical house does this with paper forms, a spreadsheet, and a binder.

That costs them three ways:

- **Audit pain.** When the affiliate reviewer or a funder asks for six months of screening logs, someone spends days reconstructing them — or can't.
- **Disputes.** "I was at the meeting." "You never told me about curfew." Without timestamped, signed records, every conflict is word against word.
- **Manager time.** House managers are often in recovery themselves, underpaid, and doing data entry at midnight. Paper doubles the work: do the thing, then write it down.

The existing software either serves licensed clinical treatment centers (heavy, expensive, mostly irrelevant to a sober-living house) or prices per-user with onboarding fees that a 10-bed house can't stomach.

## 3. Solution & product

InStep is the whole house on a phone — no install, a branded web address (`yourhouse.instepapp.com`), three roles that feel like three different apps:

- **Residents:** recovery-day counter, GPS + witness-signed meeting check-ins that count toward the weekly requirement, curfew sign in/out with location, document e-signing, anonymous grievance filing. Deliberately a daily companion, not a surveillance tool. No smartphone? Staff can do everything on a resident's behalf.
- **Managers:** a "needs attention" home screen (open grievances, screenings awaiting lab results, documents to countersign, away-from-house sign-ins), a live in/out board, screening logs (urine and/or breathalyzer, dual signatures, split-result flagging, lab follow-up), incidents, chores, events, announcements — and one-tap PDF or CSV compliance reports for attendance, screening, incidents, and grievances.
- **Owners:** multi-house roll-up, org branding and settings, manager administration, a tamper-evident activity log, and an app-errors view.

Behind the scenes: daily reminder emails to residents, a weekly summary email to staff, per-org feature flags (e.g., curfew off, "Building" instead of "House" for complexes).

**What's live vs. near-term.** Everything above is shipped and verified in production, including org-level data isolation. Two known items are documented and scheduled, not hidden: (1) a half-day client-side optimization before any single org exceeds ~100 residents (signature payloads and query windows — the backend already handles the scale); (2) in-app rent billing is on the roadmap; rent is handled by payment link today.

**Trust posture.** Data is login-gated, isolated per house and per organization by database-level rules, PINs stored as one-way hashes, encrypted in transit and at rest. The marketing says exactly what the product does — "timestamped and signed," never "tamper-proof." E-signed documents follow the retain-the-original-plus-signature-page approach standard e-sign tools use, framed honestly. The privacy policy names the operator's own obligations (42 CFR Part 2 / HIPAA where applicable) rather than pretending them away.

## 4. Market

**Who buys:** owner-operators of 1–5 houses (the core), small regional chains, and transitional/step-down complexes (a different shape of the same need — the ~200-bed prospect is this).

**Sizing, honestly labeled.** NARR's state affiliates certify residences on the order of the low thousands nationally — call it 2,500–4,000 certified homes — with total US sober-living homes (certified plus not-yet-certified) plausibly in the 10,000–18,000 range. These are order-of-magnitude figures from public statements, not audited counts. At $99/house/month, certified homes alone represent roughly a $3–5M ARR ceiling; the uncertified majority — who buy precisely *because* they're pursuing certification — expands it several-fold. This is a real, durable niche, not a venture-scale story, and that's fine: it's the right size for a bootstrapped solo business with near-total gross margins, and NARR-driven professionalization is a tailwind, not a fad.

**Why now:** states are increasingly tying funding and referrals to NARR certification. Documentation pressure on small operators is rising while their budgets aren't.

## 5. Business model & unit economics

- **Pricing:** $99/house/month (unlimited residents, unlimited staff logins, no setup fee, no contract). Founding houses $49/month locked in. Complexes: per-bed pilot pricing at $3–5/bed/month (~$600–1,000/month for 200 beds).
- **Cost to serve:** effectively zero marginal. The entire stack is a static site on Cloudflare plus Supabase (Postgres, edge functions) plus Resend for email — roughly $50–150/month *total* across all customers at current scale, plus ~3% Stripe fees. Gross margin above 90% from the first customer.
- **What MRR looks like** (assuming an honest mix of founding-$49 and full-$99 houses, blended ~$75):
  - **10 houses:** ~$750/month — covers every business cost several times over.
  - **50 houses:** ~$3,700–4,500/month — a real part-time income; infra still under $200.
  - **150 houses:** ~$11,000–14,000/month — a full solo living with room to hire help, still on the same stack.
- No paid acquisition is assumed anywhere in this plan. Growth is referral and affiliate-channel driven; CAC is the founder's time.

## 6. Go-to-market

The motion already exists in writing (the sales kit's rule: **you don't pitch, you show**):

1. **Close The Turning Point.** First paying customer, multi-house, and the reference for everyone after. One yes unlocks the rest.
2. **The demo does the selling.** `instepapp.com/?demo=manager` is a full, safe, sample-data walkthrough — three minutes, ending with the price and silence. No sales team, no deck.
3. **Founding-price wedge.** $49 locked in for early houses converts fence-sitters and builds the reference base fast; it sunsets once references carry the close.
4. **The complex pilot.** One wing/building, 30 days, founder-provisioned, per-bed pricing. Success converts to a $600–1,000/month account and a second, very different reference.
5. **NARR affiliate channel.** Once 3–5 houses are live and happy, approach the state affiliate: their entire membership shares the same documentation pain, and InStep is built around their standard. One affiliate newsletter mention beats months of cold outreach.
6. **Light content:** the existing comparison one-pager, printable and honest, plus the demo link. Nothing more until the above is saturated.

Onboarding is a moat-lite: same-day setup, founder does it personally, resident phones optional. "You can be live today" is a true sentence very few competitors can say.

## 7. Competition & differentiation

- **One Step** — built for licensed treatment centers: EMR, e-prescribing, medical billing. Powerful and quote-only priced. For a sober-living house, most of it is weight they'll never use.
- **Sobriety Hub** — closest in scope; has built-in rent payments today. Prices at $75/month per full user + $25/month per manager + $250 onboarding — an owner plus one manager runs ~$100/month *plus* $250 to start, and grows with headcount. InStep is flat $99, everyone included, nothing to pay to get in the door.

**Why InStep wins the small/mid operator:** flat, transparent pricing; genuinely mobile-first for residents (the check-in and grievance features residents actually use daily — the resident-voice piece NARR looks for); same-day setup; a human answers the email; and it was built by someone with lived recovery experience who designed for the worst day — a relapse, a split screening result, a resident who doesn't come home — not the demo. That last one cannot be copied by a funded team, and it shows in the product's priorities.

**Honest gap:** in-app rent billing (Sobriety Hub has it; InStep bridges with a payment link, roadmapped).

## 8. The studio & roadmap

Beecon builds software that guides people home. Its written operating principles: lived experience is the moat; design for the worst day; trust is a feature (no overclaiming, ever); radical simplicity; revenue products fund mission products; and **one product earns its keep before the next begins**.

- **InStep** (now) — the revenue product.
- **Porchlight** (next) — an app for families of people in addiction. Begins only when InStep sustains it.
- **A resident-facing recovery companion** (later) — free to the people who can't pay, funded by InStep.

The sequencing is a discipline, not a wish list: no Porchlight code until InStep hits its milestones.

## 9. Traction & 12-month milestones

**Today:** product live and security-swept; multi-org isolation verified; The Turning Point at close; complex in recon; provisioning is a 2-minute admin page plus one DNS entry.

| Quarter | Milestones |
|---|---|
| **Q3 2026** | Stripe live; The Turning Point paying; 3–5 founding houses; complex recon → warm intro; entity decision made. |
| **Q4 2026** | 8–12 paying houses; complex pilot running (one building, 30 days); first referral-sourced customer; scale-hardening done during pilot. |
| **Q1 2027** | 15–20 houses; complex converted or a clear no with lessons; NARR affiliate conversation opened; founding price sunset for new customers. |
| **Q2 2027** | 20–25 houses + complex ≈ **$2,500–4,000 MRR**; churn measured (target <3%/mo); go/no-go on starting Porchlight design. |

Business break-even (infra + tools) happens at customer #2. The meaningful threshold — MRR covering a defined share of the founder's living costs — is a number the founder sets, not this plan.

## 10. Financials (12-month view, all assumptions labeled)

**Assumptions:** solo founder takes no salary from the business initially; no paid marketing; no hires; blended revenue $75/house/month; complex pilot converts in Q1 2027 at $800/month.

| | Q3 '26 | Q4 '26 | Q1 '27 | Q2 '27 |
|---|---|---|---|---|
| Paying houses (avg) | 4 | 10 | 17 | 23 |
| House MRR (exit) | $375 | $750 | $1,275 | $1,725 |
| Complex MRR | — | pilot | $800 | $800 |
| **Exit MRR** | **~$375** | **~$750–1,000** | **~$2,100** | **~$2,500–3,300** |
| Costs/mo (infra, tools, domain, Stripe fees) | ~$100 | ~$125 | ~$175 | ~$200 |

Cumulative year-one revenue on this path: roughly $15–20K against under $2K of costs. Small numbers, deliberately unexaggerated — the point is a machine that is profitable from month two and compounds on references.

## 11. Founder

The founder built InStep alone — product, security, deployment, sales materials — and is in recovery. That's not a biography line; it's the product's design authority. Every feature that differentiates InStep (witness-signed check-ins, the grievance loop, "companion, not surveillance") exists because the founder knows which moments matter inside a house. Buyers in this market can tell the difference between software built *about* them and software built *from* them. Colorado-based, close to the first customers, and — per Beecon's own playbook — clear-eyed that the frontier is now conversations, not code.

## 12. Risks & mitigations

- **Single founder / bus factor.** Mitigation: everything is documented to run without memory (admin guide, sales kit, call sheet, founder checklist); the stack is deliberately boring (one file, no build step) so any competent developer could maintain it; uptime monitoring and CI smoke tests catch failures before customers do.
- **Churn among small operators** (houses close). Mitigation: multi-house owners and the complex diversify; no-contract pricing keeps trust high; the compliance file itself creates stickiness — the records live in InStep.
- **Data trust / regulatory adjacency** (42 CFR Part 2, HIPAA). Mitigation: honest positioning as operator tooling with operator responsibility, stated plainly in the policy; database-enforced isolation verified before customer #2; never overclaim ("timestamped and signed," not "tamper-proof").
- **Incumbent response** (Sobriety Hub cuts price). Mitigation: InStep's cost floor is near zero; the differentiation is fit and founder, not just price.
- **Sales stall.** Mitigation: the founding-$49 wedge, the show-don't-pitch demo requiring no meeting, and a named weekly quota of outreach conversations (see below).
- **Scale surprise at the complex.** Mitigation: the exact half-day fix is already written down; it's scheduled during the pilot, not under deadline.

## 13. The next 90 days

**Weeks 1–2 — get paid and unblock.** Stripe account, bank connected, $99 payment link + $49 founding link. Run the three pending SQL steps (app-errors log, hardened login block, feature-flags migration) and set the admin secret. Add the free uptime monitor. Decide entity: if the Colorado LLC is fast, form it first and open Stripe under it; otherwise start sole-prop and migrate at one customer.

**Weeks 2–4 — the first yes.** Close The Turning Point with the demo and the closing line, then stop talking. Set up their houses same-day. Ask for two introductions.

**Weeks 4–8 — the pilot.** Send the complex contact the recon questions; get the decision-maker intro; propose one building, 30 days, per-bed. Provision it (curfew off, "Building" label) in minutes. Do the scale-hardening pass while the pilot runs.

**Weeks 8–13 — the flywheel.** Five founding-price conversations per week from TTP referrals and local operator lists. First check-in with the state NARR affiliate once three houses are live. Measure everything: demos given, closes, time-to-live, first churn signal.

One metric for the quarter: **paying houses.** Everything on this list either produces one or removes a blocker to one.

---

*Open decisions reserved for the founder: entity timing (recommended before volume, not blocking the first dollar), founding-price sunset date, the personal-income threshold that defines "sustainable," and whether Beecon ever takes outside money — nothing in this plan requires it.*
