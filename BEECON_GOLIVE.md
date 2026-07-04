# Beecon Works — Go Live (Cloudflare Worker, auto-deploy from Git)

*You own **beeconworks.com** on Cloudflare. The Beecon site lives on your repo's **main** branch and is set
up to run as its own **static-assets Worker** — the same way InStep is deployed. Connect it once and every
future change goes live automatically. It does NOT touch instepapp.com — completely separate.*

**Heads-up:** your dashboard has no "Pages" option (Cloudflare moved to Workers-only) — that's expected;
we use the **Import a repository** flow below. Also **delete the stray `lucky-tree-48cd` Worker** you made
earlier, and attach **beeconworks.com** to the NEW `beeconworks` Worker (not to `instep` or that stray one),
so the domain isn't claimed twice.

---

## Part 1 — Import the repo as a new Worker (one-time, ~3 min)

1. Go to **dash.cloudflare.com** → **Workers & Pages**.
2. Click **Create application** → choose **Import a repository** (connect/authorize GitHub if it asks) →
   pick the **StepIn** repository.
3. In the build settings:
   - **Project / Worker name:** `beeconworks`
   - **Git branch:** `main`
   - **Root directory:** `beeconworks`   ← the important one (the site + its config live in that subfolder)
   - **Build command:** *(leave blank)*
   - **Deploy command:** `npx wrangler deploy` (this is usually the default — leave it)
4. Click **Create / Deploy.** First build takes ~1 minute. When it's done it's live at a
   **`beeconworks.<something>.workers.dev`** URL — open it and check the page looks right.

*From now on, whenever we change the site, it redeploys automatically — you don't touch the dashboard.*

---

## Part 2 — Put your domain on it (~2 min + a short wait)

1. Open the new **beeconworks** Worker → **Settings** → **Domains & Routes** (may be called **Custom domains**).
2. **Add** → **Custom domain** → type `beeconworks.com` → **Add domain**.
   - Because the domain is already on Cloudflare, it creates the DNS record for you automatically.
3. (Optional) Repeat for `www.beeconworks.com` so the www version works too.
4. Wait a few minutes — Cloudflare issues the SSL certificate on its own. Then **https://beeconworks.com**
   is live. 🎉

---

## Part 3 — Make the contact email work (optional, ~2 min)

The site's contact link is **hello@beeconworks.com**. Until you set up a mailbox, mail to it goes nowhere.
Easiest free fix — **Cloudflare Email Routing**:

1. Cloudflare dashboard → pick **beeconworks.com** → left sidebar **Email** → **Email Routing** → **Get started**.
2. Add a custom address: `hello@beeconworks.com` → forward to your real inbox (your personal email).
3. Verify your inbox (click the link Cloudflare emails you). Done — mail to hello@ lands in your inbox.

---

## If the import flow is confusing — fastest way to go live TODAY (fallback)

You already have the `lucky-tree-48cd` Worker (or make a fresh one). Open it → **upload assets** → drop the
**`beeconworks-site.zip`** I sent (index.html + images) → **Deploy**. Live in ~1 minute. Then do Part 2 to
attach the domain. Downside: updates need a re-upload (I'll send a fresh zip). You can switch to the Git
setup (Part 1) anytime.

---

## Updating the site later

Nothing to do. Once the repo is imported (Part 1), any change we make is committed to `main` and Cloudflare
rebuilds and redeploys within a minute. No uploads, no dashboard.

---

*Live checklist:*
- [ ] the `*.workers.dev` URL loads and looks right
- [ ] beeconworks.com shows the site (SSL green padlock)
- [ ] hello@beeconworks.com forwards to your inbox
