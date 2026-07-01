# InStep — Sales Kit

Internal. Not served publicly (`.assetsignore` excludes `*.md`). This is everything you need to
sell InStep without being a salesperson. The core idea: **you don't pitch, you show.** The demo does
the selling. Your job is to open it, click through, and say the price.

---

## 1. The one-paragraph summary (copy-paste into a text or email)

> InStep is a simple app for running a sober-living / recovery residence. Residents check in to
> meetings (GPS + witness signature), sign in and out for curfew, and sign their house documents
> from their phone. You log drug screens and incidents, post house announcements, and print
> NARR-ready compliance reports in one tap. Your own branded web address, works on any phone, nothing
> to install. $99/house per month — no contract, cancel anytime. Want me to send you a link to click
> around in a live demo?

Keep it to that. Don't oversell. The demo is the pitch.

---

## 2. The 3-minute demo (what to click, what to say)

Open the **Manager** demo: `https://instepapp.com/?demo=manager` (or tap "Launch demo" on
instepapp.com). Everything is sample data; nothing saves. Go slow, let them watch.

1. **Home / "Needs attention"** — *"This is what a house manager sees first — anything that needs you
   today: open grievances, screenings to send to the lab, documents to countersign, and any curfew
   sign-ins that happened away from the house."*
2. **In / Out list** — *"Live curfew status for every resident — who's home, who's out and where,
   who's late. They sign in and out from their own phone, GPS-stamped."*
3. **Actions → Log a screening** — open a drug test. *"Urine, breathalyzer, or both, with a result
   for each, observed or not, signed by the staff and the resident. If a urine specimen goes to a lab,
   you track the lab result here too — and if the two tests disagree it's flagged as a split result."*
4. **Report tab → Screening / Attendance / Incidents / Grievances** — *"Every record prints to a
   clean, dated, signed PDF for your NARR file, or exports to a spreadsheet — one tap."* Tap **Print /
   PDF** and **Export CSV** so they see it.
5. **Grievances** — *"Residents can file a concern, anonymously if they want, and you track it to
   resolution — that's a NARR requirement most houses do on paper."*
6. **Switch to the Owner demo** (`?demo=owner`) — *"If you own more than one house, the owner view
   rolls them all up — every house's status, residents, and on-track numbers in one place."*
7. **Resident demo** (`?demo=resident`) — *"And this is the resident's whole experience — recovery-day
   counter, curfew, meeting check-in, document signing. It's friendly on purpose; it's their daily
   companion, not a surveillance tool."*

Close the demo by going back to "Needs attention": *"That's it — the whole house runs from these few
screens."*

---

## 3. Objections you'll hear (and honest answers)

- **"It's $99 a house?"** — *"Yes, per house per month, no contract. One avoided compliance gap or one
  cleaner audit pays for it. Founding houses are $49/month locked in."*
- **"We already do this on paper."** — *"Paper works until an audit, a dispute, or a 2am incident.
  This is the same records, but timestamped, signed, searchable, and printable in one tap — and the
  residents do half the data entry themselves by checking in."*
- **"Is the residents' information safe?"** — *"Yes. Every house's data is walled off — a manager only
  sees their own house. It's locked to logged-in users; you can't read anything without signing in.
  Drug-test and medical notes are protected the same way."* (True today for a single org.)
- **"Is it hard to switch / set up?"** — *"No install — it's a web link that works on any phone. I set
  up your house and your first login; you add residents in a couple minutes. You can be live the same
  day."*
- **"What if a resident doesn't have a smartphone?"** — *"Staff can do everything on their behalf from
  the manager side — check-ins, screenings, signatures. The resident phone is a convenience, not a
  requirement."*
- **"Built for recovery residences specifically?"** — *"Yes — it's built around the NARR standard:
  attendance, screening, incidents, grievances, signed documents. Not a generic property app."*
- **"How do documents and signatures work — is that legal?"** — *"Residents e-sign house rules,
  releases, and agreements right on their phone. You get back a single audit-ready PDF: your exact
  original, plus a signature page showing both parties, their roles, and timestamps — the same
  'keep the original, append the signatures' approach e-sign tools like DocuSign use. That's a valid
  electronic signature for this kind of paperwork — intent to sign, consent, and a retained record are
  all captured — and it's searchable and printable for your NARR file instead of sitting in a binder.
  For anything unusually high-stakes you'd still use a dedicated e-sign service, but for house documents
  this is exactly right."* (Honest framing — don't claim courtroom-grade tamper-proofing.)

If you don't know an answer, say *"good question, let me confirm and get right back to you."* Never
guess on data/privacy questions.

---

## 4. The ask (closing line)

Pick one, say it plainly, then stop talking:

> *"If it looks useful, I can have your house set up today for $99 a month — want me to get you
> started?"*

or, softer:

> *"Want me to set up a free week with your real house so you can try it for real?"*

Pricing: **$99 / house / month**, no contract. **Founding houses: $49/month, locked in.** Collect
payment with a Stripe Payment Link (see the Stripe walkthrough in the project notes) — you just send
the link.

---

## 5. Follow-up message (if they went quiet)

> Hey [name] — no pressure at all. Here's the demo link again if you want to click around:
> https://instepapp.com/?demo=manager . Happy to set your house up whenever the timing's right.

---

## Reminders for you
- You built this. You know the problem better than any salesperson would. That's your edge — lean on
  it.
- Show, don't sell. Silence after the price is fine; let them think.
- One "yes" (The Turning Point) is the whole goal right now. Everything else can follow.
