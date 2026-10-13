# InStep™ Independent Sales Representative Agreement — DRAFT

> **DRAFT FOR ATTORNEY REVIEW — not legal advice.** Bracketed items are business decisions. Read the
> compliance section with your attorney before anyone sells: recovery housing has federal and state
> anti-kickback and patient-brokering laws that most software sales agreements never think about.
> Internal file; not served publicly.

This Agreement is between **Beecon Works LLC**, a [Colorado] limited liability company ("Company"),
and **[REP NAME]** ("Representative"), effective [DATE].

## 1. Appointment

Company appoints Representative, on a **non-exclusive** basis, to find and sign customers for InStep
(the "Product") in [territory, or "the United States"]. Company may appoint other representatives and
sell directly anywhere.

## 2. Independent contractor

Representative is an independent contractor, not an employee, partner, or agent. Representative
controls their own schedule and methods, pays their own taxes (Company issues a Form 1099), and
provides their own phone, computer, and transportation. Representative **cannot sign contracts,
change prices, or make promises on Company's behalf.**

## 3. What Representative may offer

- **Price:** the published price ($[99] per house per month) and only the discounts on Company's
  current written discount list ([e.g., founding coupon]). Anything else needs Company's written (email)
  approval before it's offered.
- **What the Product does:** only what it does today, as shown in the live demo and the Sales Kit.
  No promises of future features, custom work, integrations, uptime, or compliance outcomes
  ("this will pass your NARR audit," "this is HIPAA compliant," "records can't be changed").
- **Language:** follow Company's recovery-sensitive language standard (e.g., *resident*, *positive /
  negative / declined*; never "addict," "dirty," "failed a test").

## 4. Commission

- **Rate:** [20]% of **Collected Revenue** from each **Credited Account**.
- **Collected Revenue** = subscription fees Company actually receives through Stripe for that account,
  net of refunds, chargebacks, taxes, and payment-processing fees [— or: gross of processing fees].
- **Credited Account** = a customer organization recorded with Representative as its sales rep when
  it is set up, that Representative introduced and that signs up within [90] days of Representative
  registering the lead with Company by email. If two representatives claim the same account, the
  first written registration wins; Company decides disputes in good faith.
- **Duration:** commission is paid on each Credited Account's Collected Revenue for its first [12 / 24]
  months [— or: for as long as the account stays active and this Agreement is in effect].
- **Payment:** by the [15th] of each month for revenue collected in the previous month, with a
  statement listing each account, houses billed, amount collected, and commission.
- **Clawback:** if a Credited Account cancels, or its fees are refunded or charged back, within [90]
  days of its first payment, commission paid on that account is deducted from future commissions.
- **No other compensation:** no salary, draw, expense reimbursement, or bonus unless agreed in writing.

## 5. Compliance — required

Representative will not, directly or indirectly:

1. **Refer, recruit, steer, or arrange placement of any person into a recovery residence, treatment
   program, or laboratory, or accept anything of value for doing so.** Representative sells software
   to operators only. Federal law (the Eliminating Kickbacks in Recovery Act, 18 U.S.C. § 220) and many
   state "patient brokering" laws criminalize paying or receiving anything of value for referrals to
   recovery homes, clinical treatment facilities, and laboratories.
2. Offer an operator, staff member, or resident any payment, gift, or discount tied to resident
   referrals, census, screening volume, or use of a particular laboratory or provider.
3. Request, view, collect, or store any resident's personal or health information. Demonstrations use
   the demo only (`?demo=…`), never a customer's live account.
4. Make false or misleading statements about the Product, a competitor, or a customer.

A breach of this section is grounds for immediate termination and forfeits unpaid commission on the
affected accounts.

## 6. Company's obligations

Company provides demo access, the Sales Kit and price list, timely onboarding of signed customers,
customer support, and the monthly commission statement. Company may change the Product, prices, and
discount list with notice; changes don't reduce commission already earned.

## 7. Confidentiality and property

Customer lists, pricing exceptions, and non-public Company information are confidential during and
after this Agreement. InStep, Beecon Works, and all related materials and trademarks remain Company's
property; Representative may use them only to sell the Product under this Agreement.

## 8. Term and termination

Either party may end this Agreement with [30] days' written notice, or immediately for a material
breach (including section 5). After termination, Company pays commission on Collected Revenue from
Credited Accounts for [3] more months [— or: no further commission], subject to clawback.

## 9. General

Governed by the laws of [Colorado], venue in [Denver County]. Representative may not assign this
Agreement. Representative is responsible for their own conduct and will indemnify Company against
claims arising from statements or promises Representative makes outside section 3 or any breach of
section 5. This is the entire agreement; changes must be in writing and signed by both.

**Beecon Works LLC** — Name / Title / Date: ______________________

**Representative** — Name / Date: ______________________

---

### Notes for the reviewing attorney (delete before signing)

1. **EKRA (18 U.S.C. § 220)** reaches "recovery homes" and applies regardless of payer. Commission on
   SaaS fees from operators shouldn't be remuneration *for patient referrals*, but confirm section 5
   is enough and check the target states' patient-brokering statutes (e.g., Florida § 817.505).
2. Confirm 1099 classification holds in the Representative's state (some states apply an ABC test).
3. Decide commission duration (12 months vs. lifetime) — it drives long-term cost.
4. Commission attribution is recorded per account in the vendor Accounts page (`admin.html` →
   Accounts → Sales rep), and Collected Revenue comes from Stripe; the statement in section 4 can be
   built from the Accounts CSV export plus Stripe's payments report.
