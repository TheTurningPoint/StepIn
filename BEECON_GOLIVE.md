# Beecon Works — Go Live (Cloudflare Pages)

*You own **beeconworks.com** on Cloudflare. This puts the site live on it in ~5 minutes. It does NOT
touch instepapp.com — completely separate.*

You have the file **`beeconworks-site.zip`** (index.html + 3 images). That's the whole site.

---

## Part 1 — Put the site online (~2 min)

1. Go to **dash.cloudflare.com** and log in.
2. Left sidebar → **Workers & Pages** → blue **Create** button → **Pages** tab → **Upload assets**.
3. **Project name:** type `beeconworks` → **Create project**.
4. **Drag `beeconworks-site.zip` onto the upload box** (or unzip it and drag the 4 files). Cloudflare
   unpacks it. Make sure it shows **index.html** in the file list (it's at the top level — good).
5. Click **Deploy site**.
6. In ~30–60 seconds it's live at **https://beeconworks.pages.dev** — open that link and check it.

*If it looks right, keep going. If an image is missing, tell me.*

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

- **Quick way:** same Pages project → **Create deployment** → drop a new zip. (I'll send you a fresh zip
  whenever we change something.)
- **Hands-off way:** I can connect the GitHub repo so every change auto-deploys — no more manual uploads.
  Just say "wire up auto-deploy" and I'll set it up.

---

*Live checklist:*
- [ ] beeconworks.pages.dev loads and looks right
- [ ] beeconworks.com shows the site (SSL green padlock)
- [ ] hello@beeconworks.com forwards to your inbox
