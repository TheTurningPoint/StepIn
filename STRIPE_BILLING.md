# InStep — Per-house billing with Stripe

Internal. Not served publicly (`.assetsignore` excludes `*.md`).

Goal: each customer pays **one subscription whose quantity = number of houses**, so an 11th house
bills itself, failed cards get retried automatically, and commissions come straight from Stripe's
"collected" numbers. Replaces one-off Payment Links / manual invoices. One-time setup, ~20 minutes.

## 1. Create the product (once)

Stripe Dashboard → **Product catalog → Add product**

- Name: `InStep — per house`
- Pricing: **Recurring**, **$99.00 / month**, **Per unit** (this is what makes quantity = houses)
- Founding / discounted customers: don't make a second product — use a **coupon** (step 4).

## 2. Turn on the self-serve billing pieces (once)

- **Settings → Billing → Customer portal**: enable "Update payment method", "View invoice history",
  "Cancel subscription" (cancel at end of period). Leave **quantity changes off** — you set the house
  count from the Accounts page so customers can't under-report.
- **Settings → Billing → Subscriptions and emails**: turn on **Smart Retries**, "Send emails when card
  payments fail", and "Send a reminder email before a subscription renews" (optional).
- **Manage failed payments**: after all retries fail → **mark the subscription unpaid** (not cancel),
  so nothing is lost while you call them.

## 3. Sign up a new customer

1. Provision them in `admin.html` → **New customer** (fill in **Sales rep** and **Rate per house**).
2. Stripe → **Customers → Add customer** (owner's name + email).
3. On that customer → **Create subscription** → product `InStep — per house` → **Quantity = number of
   houses** they're starting with → "Email invoice to the customer" or "Automatically charge".
   - Free trial? Set **trial days** here (e.g. 14). Leave them as `trial` in the Accounts page until it
     converts.
4. Copy the subscription id (`sub_…`) into the account's **Stripe ref** on the Accounts page, and set
   status to **active** once the first payment clears.

## 4. Discounts (founding pricing, multi-house deals)

**Product catalog → Coupons → New**: e.g. `FOUNDING` = $50 off per month forever, or 20% off for 12
months. Apply it on the subscription. Also set the same effective **Rate per house** on the Accounts
page so your monthly totals and commissions match what Stripe collects.

## 5. Monthly routine (5 minutes, first business day of the month)

1. `admin.html` → **Accounts** → **Load accounts**.
2. For each **active** account, compare **house count** with the Stripe subscription **quantity**.
   If they added a house: Stripe → subscription → **Update** → quantity → "Prorate" on. If they
   closed one, lower it the same way.
3. Anything marked **Stalled setup** or **Gone quiet** → call them this week (that's churn before it
   happens).
4. **Export CSV** from the Accounts page + Stripe **Reports → Revenue / Payments** for last month →
   commissions are paid on what Stripe actually **collected** (net of refunds), per the rep agreement.

## 6. What to tell a customer

> "It's $99 a month per house, billed monthly — no contract. Add a house any time and it's added to the
> next bill; cancel any time and it stops at the end of the month. You can update your card and see
> every invoice from the link in your receipt."

## Not built (yet)

No automatic sync between the app and Stripe: the house count is read from the Accounts page and
set in Stripe by hand (step 5). If that becomes a chore past ~20 accounts, the next step is a small
`stripe-sync` Edge Function that updates each subscription's quantity from the house count nightly
(needs a Stripe **restricted key** stored as an Edge Function secret).
