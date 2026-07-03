# InStep — Meeting Brief: The Turning Point

*First paying house · July 2026. Internal prep — not for the room. (`.assetsignore` keeps `*.md` unserved.)*

---

## Remember 5 things

1. **Never say "tamper-proof," "GPS-verified," or "verified attendance."**
   Say **"timestamped and signed"** and **"GPS location-stamped, witness-signed."**
   The witness signature is the verification — the GPS is a location stamp.
2. **Rent is not in-app yet.** Today: payment link. In-app billing is on the
   roadmap. Say it before they ask.
3. **Show, don't pitch.** The demo click-path is the meeting. Open
   `?demo=manager` and let the product talk.
4. **Set sobriety dates during setup** — the recovery-day counter falls back to
   move-in date if a sobriety date isn't set. Get this right on day one.
5. **The close:** "If it looks useful, I can have your house set up today for
   $99 a month — want me to get you started?" Then stop talking.

---

## Positioning

**One-liner:** InStep is a phone-first management app for sober-living and
recovery residences, built around the NARR standard — attendance, screenings,
incidents, grievances, and signed documents, all recorded, timestamped, and
signed, from any phone.

**The pitch in one breath:** Everything NARR asks a house to document, most
houses still do on paper. InStep replaces the binder — and residents do half
the data entry themselves, from their own phones.

- **$99/house/month.** Unlimited residents and staff. No contract, no setup fee.
- Live in production, security-reviewed. Multi-tenant by subdomain
  (theirhouse.instepapp.com). No install — works on any phone with a browser.
- Traction: The Turning Point (multi-house) closing; a ~200-bed transitional
  complex in recon for a per-bed pilot ($3–5/bed/month).

---

## Features by role

### Resident — a daily companion, not surveillance
- **Recovery-day counter** front and center every time they open the app.
- **Meeting check-in:** GPS location-stamp plus an in-person witness signature,
  counting toward the weekly meeting requirement.
- **Curfew sign in/out** with destination; late sign-ins are flagged.
- **E-sign documents** with a finger — house agreements, policies.
- **File a grievance or concern**, with an anonymous option.
- **Self-service PIN reset** by emailed code — no midnight calls to staff.

### Manager — runs one house
- **"Needs attention" home screen:** open grievances, screenings awaiting lab
  results, documents to countersign, curfew sign-ins that happened away from
  the house.
- **Live In/Out board** — who's in the house right now.
- **Log a screening:** urine and/or breathalyzer, a result per test, observed
  or not, dual-signed by staff and resident. One negative + one positive flags
  as a **"split result"**; lab follow-up per house policy. Results are
  Negative / Positive / Declined.
- **Incident log:** typed, described, signed, timestamped.
- **Manage residents, chores, events, announcements.**
- **Reports:** Attendance, Screening, Incident, Grievance — one tap to a
  NARR-ready PDF or CSV.

### Owner — one or many houses
- **Multi-house roll-up** on one screen.
- **Org settings and branding**, manager administration.
- **Activity log** — a record of who changed or removed what.
- **Owner-only app-error view.**

---

## NARR framing

NARR — the National Association of Recovery Residences — sets the standard for
recovery housing. Certification, and increasingly state funding and referral
eligibility, requires documentation most houses keep on paper. Paper fails
exactly when it matters: at audit time, in a word-versus-word dispute with no
signed record, and in the hours of manager time it eats every week.

| NARR requires | InStep provides |
| --- | --- |
| Documented meeting attendance | Witness-signed check-ins with GPS location stamp, counted against the weekly requirement |
| Drug/alcohol screening logs | Dual-signed screenings with per-test results and lab follow-up tracking |
| Incident reports | Typed, described, signed, timestamped incident log |
| Resident grievance process | In-app grievance filing with an anonymous option, tracked to resolution |
| Signed resident agreements | Finger-signed documents with the original preserved, countersigned by staff |

Every requirement outputs a one-tap PDF or CSV. When the auditor asks, the
answer is a print button.

---

## Pricing and competition

**InStep: $99/house/month flat.** Unlimited residents and staff, no contract,
no setup fee.

**Sobriety Hub** — closest competitor. ~$75 per full user + $25 per manager +
$250 onboarding; cost grows with headcount. It **does have in-app rent
collection — our honest gap.** Today InStep handles rent via a payment link;
in-app billing is roadmapped. If rent collection is their #1 need, say so
plainly and note the total price difference still usually favors InStep.

**One Step** — built for licensed treatment centers: EMR, e-prescribing,
insurance billing. Heavy, quote-only pricing, and overkill for sober living.
Different animal; don't compete, categorize.

**Why InStep wins:**
- Flat, transparent pricing — the price doesn't grow with the house.
- Genuinely mobile-first for residents, not a desktop app with a mobile view.
- Same-day setup. A human answers the email — the founder.
- Built by someone with lived recovery experience.
- **"Designed for the worst day, not the demo."**

---

## Objection answers

**"$99 a house?"**
Per house, per month, unlimited people, no contract. One cleaner audit pays
for it.

**"We already do this on paper."**
Paper works right up until an audit, a dispute, or a 2 a.m. incident. This is
the same records — timestamped, signed, searchable, printable — and residents
do half the data entry themselves.

**"Is the information safe?"**
Every house's data is walled off — a manager sees only their house. Access is
locked to logged-in users, PINs are one-way hashed, and everything is
encrypted in transit and at rest.
*(All true today. Do not extend into regulatory-compliance promises.)*

**"Is it hard to switch or set up?"**
There's nothing to install — it's a web link. I set up the house and your
first login myself. You can be live today.

**"What about a resident with no smartphone?"**
Staff can do everything on a resident's behalf. The phone is a convenience,
not a requirement.

**"Is this built for recovery residences specifically?"**
Yes — built around the NARR standard from day one, not a generic property app
with the labels changed.

**"Are the e-signatures legal?"**
We keep the exact original document plus a signature page recording intent,
consent, and timestamp — the same approach the standard e-sign tools use — and
output an audit-ready PDF.
*(Don't claim courtroom-grade tamper-proofing. For unusually high-stakes
documents, recommend a dedicated e-sign service.)*

**Anything you don't know:**
"Good question — let me confirm and get right back to you."
Never guess on anything touching data or privacy.

---

## Demo click-path

You don't pitch. You show. Have these tabs open before the call.

1. **Manager demo** — `instepapp.com/?demo=manager`
2. **"Needs attention"** — the morning-coffee screen. Let it land.
3. **In/Out board** — who's in the house right now.
4. **Actions → Log a screening** — walk the dual-sign flow.
5. **Report tab** — Print/PDF and Export CSV. Say: "This is your audit."
6. **Grievances** — the NARR requirement everyone forgets they have.
7. **Owner demo** — `?demo=owner` — the multi-house roll-up (they're multi-house).
8. **Resident demo** — `?demo=resident` — "a daily companion, not surveillance."
9. **Back to "Needs attention."** End where they'll start every morning.

**Close:** "If it looks useful, I can have your house set up today for $99 a
month — want me to get you started?" **Then stop talking.**

---

## Landmines and honest gaps

- **Never "tamper-proof."** Say *timestamped and signed*.
- **Never "GPS-verified" or "verified attendance."** Say *GPS location-stamped
  and witness-signed* — the witness signature is the verification; the GPS is
  a location stamp.
- **Rent isn't in-app yet.** Payment link today; in-app billing roadmapped.
  Volunteer it before they find it.
- **Scale:** an org past ~100 residents needs a half-day client-side
  optimization first. The backend already scales. (Not their situation today —
  relevant only if the 200-bed pilot comes up.)
- **Setup detail that bites:** set each resident's **sobriety date**, or the
  recovery-day counter falls back to move-in date.
- **Privacy claims stop at operator tooling.** "Walled off per house and org"
  is true today; do not promise regulatory compliance beyond that.
