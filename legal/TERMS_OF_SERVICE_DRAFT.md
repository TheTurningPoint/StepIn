# InStep™ Customer Terms of Service — DRAFT

> **DRAFT FOR ATTORNEY REVIEW — not legal advice, not yet in effect.** Written to match what the
> software actually does today (October 2026). Bracketed items are business decisions. Internal file;
> not served publicly. Once reviewed, publish as `terms.html` and link it from the sign-up email,
> `demo.html`, and `privacy.html`.

**Beecon Works LLC** ("Beecon Works," "we") provides InStep (the "Service") to the organization that
signs up ("Customer," "you"). By creating an account or paying for the Service, you agree to these
Terms. Effective date: [DATE].

## 1. The Service

InStep is web software for operating recovery residences: resident meeting check-ins, curfew sign
in/out, chores, events, announcements, document signing, screening and incident records, grievances,
and printable reports. It runs in a web browser at your organization's subdomain of `instepapp.com`.

**InStep is a record-keeping tool. It is not:**
- an emergency, safety, or real-time monitoring service — a missed sign-in or a GPS location is a
  record, not an alert to emergency services;
- a medical record, clinical, or treatment system, or a substitute for professional judgment;
- a decision-maker — admission, discharge, house rules, and every decision about a resident are made
  by you, not the software.

## 2. Accounts and users

You create staff (owner, manager) and resident accounts and are responsible for who you give access
to, for keeping PINs private, and for removing access when someone leaves (archiving a manager or
discharging a resident ends their access immediately). You're responsible for activity under your
accounts and for getting any consents your residents must give under your house agreements and
applicable law.

## 3. Fees and billing

- **Price:** $[99] per House per month, unless your order or invoice says otherwise. A "House" is a
  location set up in InStep with at least one active resident or manager.
- **Billing:** monthly in advance through Stripe, starting [at sign-up / after a [14]-day trial].
  Adding a House is billed (prorated) from the day it's added; removing one takes effect on the next bill.
- **No long-term contract.** Cancel any time; the Service continues to the end of the paid month.
  [No refunds for partial months.]
- **Late payment:** if a payment fails and isn't fixed within [14] days of our notice, we may suspend
  access until it is. We won't delete your data for non-payment without the notice in section 7.
- **Price changes:** at least [30] days' written notice; they apply from your next billing period.
- Fees exclude taxes; you're responsible for applicable sales or use tax.

## 4. Your data

- **You own your data** — everything you and your residents enter ("Customer Data").
- **We use it only to provide and support the Service** for you. We don't sell it, rent it, use it for
  advertising, or share it with other customers.
- **Who can see it:** your users, according to their role (residents see only their own records;
  managers their House; owners the whole organization), and a limited number of Beecon Works staff
  only when needed to support you, fix a problem, or comply with law.
- **Service providers** that host or process it for us: Supabase (database and functions), Cloudflare
  (website hosting), Resend (email), Stripe (billing — payment details only). We'll give notice before
  adding a provider that stores Customer Data.
- **Security we actually use:** encrypted connections (HTTPS), database access rules that separate
  organizations, houses, and roles, PINs stored only as one-way hashes, and an activity log of changes
  to compliance records. No system is perfectly secure, and we don't claim records are tamper-proof.
- **If there's a breach** affecting your Customer Data, we'll tell you without undue delay and within
  [72] hours of confirming it, with what we know and what we're doing about it.

## 5. Sensitive information — please read

Recovery residences handle sensitive information. **You** decide what you enter and whether laws such
as 42 CFR Part 2 (substance use disorder records), HIPAA, or state confidentiality rules apply to your
program. Many recovery residences are not covered by them; programs that provide clinical services
often are. InStep does not currently sign HIPAA Business Associate Agreements or Part 2 Qualified
Service Organization Agreements [— contact us if you need one]. If your program is covered, talk to us
before entering protected health information (for example, using the optional medication feature).

## 6. Acceptable use

Don't use the Service to break the law, to discriminate against residents in violation of fair housing
or disability law, to collect information about people who haven't agreed to use it, or to try to access
another organization's data or get around access rules. Don't resell the Service without our agreement.

## 7. Export, cancellation, and deletion

- You can export your records (reports, CSV files, signed documents) at any time while your account
  is active.
- After cancellation, we keep your Customer Data for [60] days so you can export it or come back,
  then delete it from the live system (backups roll off within [30] more days), unless law requires us
  to keep it. Tell us if you need it deleted sooner.
- Your own record-retention obligations (for example NARR, licensing, or funding requirements) are
  yours; export what you need to keep before your data is deleted.

## 8. Availability and support

We work to keep the Service available and back it up [daily], but it's provided without a guaranteed
uptime. Planned maintenance happens outside [8 a.m.–9 p.m. Mountain time] where possible. Support:
**hello@beeconworks.com**, answered within [one business day].

## 9. Changes to the Service and these Terms

We improve the Service over time and may change features; we won't remove a core feature you rely on
(meeting check-ins, curfew, screening and incident records, documents, reports) without [60] days'
notice. If we change these Terms in a way that matters, we'll email the account owner at least [30]
days before the change takes effect.

## 10. Warranties and liability

- The Service is provided **"as is."** To the extent the law allows, we disclaim implied warranties
  (merchantability, fitness for a particular purpose, non-infringement).
- **Liability cap:** each party's total liability under these Terms is limited to the fees you paid in
  the [12] months before the claim. Neither party is liable for indirect, incidental, special, or
  consequential damages or lost profits. [These limits don't apply to a party's indemnity obligations,
  breach of confidentiality, or amounts you owe.]
- **Indemnity:** you'll defend us against third-party claims arising from your operation of your
  residences or your users' conduct; we'll defend you against claims that the Service, as we provide
  it, infringes someone's intellectual property.

## 11. Termination by us

We may suspend or end the Service for non-payment (section 3), a serious breach you don't fix within
[30] days of notice, or misuse that threatens other customers' security. On termination, section 7
applies.

## 12. General

Governed by the laws of [Colorado], with venue in [Denver County]. These Terms, plus any order or
invoice, are the whole agreement. Notices to us: hello@beeconworks.com; to you: the account owner's
email. Neither party may assign these Terms except with a sale of its business. If a provision is
unenforceable, the rest stays in effect.

---

### Notes for the reviewing attorney (delete before publishing)

1. **Part 2 / HIPAA posture (section 5).** Some customers will run clinical programs. Decide whether to
   offer a BAA/QSOA (Supabase offers a BAA only on certain paid plans, with its HIPAA add-on) or to keep the "talk to us first" position.
2. **Fair housing.** People in recovery are protected under the Fair Housing Act; the "not a
   decision-maker" language (section 1) and acceptable use (section 6) are meant to keep discharge
   decisions with the operator.
3. **Emergency disclaimer (section 1).** Curfew GPS and check-ins could be read as "monitoring";
   confirm the disclaimer is strong enough for a wrongful-death/negligence theory.
4. **Data retention (section 7)** must match what operations actually does; set the day counts to a
   process you'll follow every time.
5. Click-wrap vs. signature: decide whether owners accept on first sign-in (needs a small in-app
   checkbox, not built yet) or sign an order form.
