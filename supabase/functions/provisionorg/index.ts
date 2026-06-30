// provisionorg — vendor-only tool to stand up a new customer org from a form (no hand-run SQL).
//
// POST { secret, subdomain, org_name, owner_name, owner_pin, owner_email? }
//   -> creates the orgs row, the first owner in residents (with a hashed PIN), and the settings row.
//
// Secret-gated: the caller must send the ADMIN_SECRET. This can create owner accounts, so it is NOT
// for end users — only the vendor with the secret. Generic 401 on a bad/missing secret.
//
// Deployed with --no-verify-jwt (public). Required secret: ADMIN_SECRET (long random string).
// Auto-provided: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ADMIN_SECRET = Deno.env.get("ADMIN_SECRET") ?? "";

const admin = createClient(SUPABASE_URL, SERVICE_ROLE, { auth: { persistSession: false } });

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...cors, "Content-Type": "application/json" } });

// Constant-time-ish string compare.
function secretOk(got: string): boolean {
  if (!ADMIN_SECRET || !got || got.length !== ADMIN_SECRET.length) return false;
  let diff = 0;
  for (let i = 0; i < got.length; i++) diff |= got.charCodeAt(i) ^ ADMIN_SECRET.charCodeAt(i);
  return diff === 0;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  let b: Record<string, string> = {};
  try { b = await req.json(); } catch { return json({ error: "Bad request" }, 400); }

  if (!secretOk((b.secret ?? "").trim())) return json({ error: "Unauthorized" }, 401);

  const subdomain = (b.subdomain ?? "").trim().toLowerCase();
  const orgName = (b.org_name ?? "").trim();
  const ownerName = (b.owner_name ?? "").trim();
  const ownerPin = (b.owner_pin ?? "").trim();
  const ownerEmail = (b.owner_email ?? "").trim();

  if (!/^[a-z0-9-]{2,}$/.test(subdomain)) return json({ error: "Subdomain must be lowercase letters, numbers, or dashes." }, 400);
  if (!orgName) return json({ error: "Organization name is required." }, 400);
  if (!ownerName) return json({ error: "Owner name is required." }, 400);
  if (!/^[0-9]{4}$/.test(ownerPin)) return json({ error: "Owner PIN must be 4 digits." }, 400);

  // Never clobber an existing tenant.
  const { data: existing } = await admin.from("orgs").select("subdomain").eq("subdomain", subdomain).maybeSingle();
  if (existing) return json({ error: "That subdomain is already in use." }, 409);

  const { error: orgErr } = await admin.from("orgs").insert({ subdomain, name: orgName });
  if (orgErr) return json({ error: "Could not create org: " + orgErr.message }, 500);

  const ownerId = "owner-" + Date.now() + "-" + Math.floor(Math.random() * 1e6); // collision-resistant
  const { error: resErr } = await admin.from("residents").insert({
    id: ownerId, name: ownerName, role: "owner", org: subdomain, status: "active",
    email: ownerEmail && ownerEmail.includes("@") ? ownerEmail : null,
  });
  if (resErr) {
    await admin.from("orgs").delete().eq("subdomain", subdomain); // roll back the orphan org row so it can be retried
    return json({ error: "Could not create owner: " + resErr.message }, 500);
  }

  const { error: pinErr } = await admin.rpc("admin_set_pin_hash", { p_id: ownerId, p_new_pin: ownerPin });
  if (pinErr) {
    await admin.from("residents").delete().eq("id", ownerId); // roll back the owner that has no usable PIN
    await admin.from("orgs").delete().eq("subdomain", subdomain);
    return json({ error: "Could not set owner PIN: " + pinErr.message }, 500);
  }

  await admin.from("settings").upsert(
    { org: subdomain, house_name: orgName, required: 3, lab_policy: "all" },
    { onConflict: "org" },
  );

  return json({
    ok: true,
    subdomain,
    owner_id: ownerId,
    login_url: `https://${subdomain}.instepapp.com`,
    note: "Add this subdomain as a Cloudflare Worker custom domain before the owner can sign in.",
  });
});
