# Beecon Works — Go Live (Cloudflare Pages, auto-deploy from Git)

*You own **beeconworks.com** on Cloudflare. The Beecon site now lives on your repo's **main** branch, so
we connect the repo once and every future change goes live automatically — no more uploads. It does NOT
touch instepapp.com — completely separate.*

**One-time note:** you earlier created a Worker named `lucky-tree-48cd` from the "upload" flow. Ignore or
delete it, and make sure you attach **beeconworks.com** to the NEW Pages project below (not to that Worker),
so the domain doesn't get claimed twice.

---

## Part 1 — Connect the repo (one-time, ~2 min)

1. Go to **dash.cloudflare.com** and log in.
2. Left sidebar → **Workers & Pages** → blue **Create** → **Pages** tab → **Connect to Git**.
3. **Connect GitHub** → authorize Cloudflare → pick the **StepIn** repository → **Begin setup**.
4. Fill in the build settings:
   - **Project name:** `beeconworks`
   - **Production branch:** `main`
   - **Framework preset:** `None`
   - **Build command:** *(leave blank)*
   - **Build output directory:** `beeconworks`  ← important (the site lives in that subfolder)
5. Click **Save and Deploy.** First build takes ~1 minute → live at **https://beeconworks.pages.dev**.
   Open that link and check it.

*From now on, whenever we change the site, it redeploys automatically — you don't touch the dashboard.*

---

## Part 2 — Put your domain on it (~2 min + a short wait)

1. In that same new project, open the **Custom domains** tab.
2. **Set up a custom domain** → type `beeconworks.com` → **Continue** → **Activate domain**.
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

## Updating the site later

Nothing to do. Once the repo is connected (Part 1), any change we make is committed to `main` and
Cloudflare rebuilds and redeploys the site on its own within a minute. No uploads, no dashboard.

---

*Live checklist:*
- [ ] beeconworks.pages.dev loads and looks right
- [ ] beeconworks.com shows the site (SSL green padlock)
- [ ] hello@beeconworks.com forwards to your inbox
