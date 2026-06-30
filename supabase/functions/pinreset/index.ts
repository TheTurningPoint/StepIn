// pinreset — self-serve PIN reset for any user with an email on file, via an emailed code.
//
// POST { action: "request", name, org }            -> emails a 6-digit code (if a matching account
//                                                      with an email exists). Always replies OK
//                                                      (never reveals whether an account exists).
// POST { action: "reset", name, org, code, new_pin } -> verifies the code and sets the new PIN.
//
// Protections: codes are stored hashed (SHA-256), expire after 15 min, are single-use, and each
// code allows at most 5 verify attempts before it's burned (stops brute-forcing the 6 digits).
// Works for any role with an email on file; users without an email are told to ask their manager.
//
// Deployed with --no-verify-jwt (public). Required secrets: RESEND_API_KEY (to send; dry-run logs if
// unset). Auto-provided: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") ?? "";
const FROM = "InStep <reminders@instepapp.com>";
const CODE_TTL_MS = 15 * 60 * 1000;
const MAX_ATTEMPTS = 5;
const REQUEST_WINDOW_MS = 15 * 60 * 1000;
const MAX_REQUESTS = 3;

const admin = createClient(SUPABASE_URL, SERVICE_ROLE, { auth: { persistSession: false } });

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...cors, "Content-Type": "application/json" } });

async function sha256(s: string): Promise<string> {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return Array.from(new Uint8Array(buf)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

async function findUser(name: string, org: string) {
  // Anyone (resident/manager/owner) with a name + org match and an email on file.
  const { data: rows } = await admin
    .from("residents")
    .select("id,name,email,org")
    .not("email", "is", null);
  if (!org) return null; // require an explicit org — never match across tenants
  const matches = (rows ?? []).filter(
    (r) =>
      String(r.name).trim().toLowerCase() === name.toLowerCase() &&
      String(r.org ?? "") === org &&
      r.email && String(r.email).includes("@"),
  );
  if (matches.length !== 1) return null; // ambiguous (same name twice in an org) → refuse rather than guess
  return matches[0];
}

async function sendEmail(to: string, code: string, org: string): Promise<boolean> {
  if (!RESEND_API_KEY) {
    console.log(`[dry-run] reset code for ${to}: ${code}`);
    return true;
  }
  const html = `<div style="font-family:-apple-system,Segoe UI,Arial,sans-serif;color:#1a1a1a;line-height:1.6">
    <p>Your InStep PIN reset code is:</p>
    <p style="font-size:26px;font-weight:800;letter-spacing:3px">${code}</p>
    <p>It expires in 15 minutes and can be used once. If you didn't request this, you can ignore this email.</p>
    <p style="color:#666;font-size:13px">— ${org || "InStep"}</p>
  </div>`;
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { Authorization: `Bearer ${RESEND_API_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify({ from: FROM, to, subject: "Your InStep PIN reset code", html }),
  });
  return res.ok;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  let action = "", name = "", org = "", code = "", newPin = "";
  try {
    const b = await req.json();
    action = (b.action ?? "").trim();
    name = (b.name ?? "").trim();
    org = (b.org ?? "").trim();
    code = (b.code ?? "").trim();
    newPin = (b.new_pin ?? "").trim();
  } catch {
    return json({ error: "Bad request" }, 400);
  }
  if (!name) return json({ error: "Name required" }, 400);
  if (!org) return json({ error: "Missing organization" }, 400); // never allow a cross-tenant (empty-org) reset

  const generic = { ok: true, message: "If an account with an email on file exists, a code was sent." };

  if (action === "request") {
    const user = await findUser(name, org);
    if (!user) return json(generic); // don't reveal non-existence
    // Throttle requests per user.
    const since = new Date(Date.now() - REQUEST_WINDOW_MS).toISOString();
    const { count } = await admin
      .from("pin_resets").select("id", { count: "exact", head: true })
      .eq("resident_id", user.id).gte("created_at", since);
    if ((count ?? 0) >= MAX_REQUESTS) return json(generic);
    // Invalidate older unused codes, then issue a fresh one.
    await admin.from("pin_resets").update({ used: true }).eq("resident_id", user.id).eq("used", false);
    const c = String(Math.floor(100000 + Math.random() * 900000));
    await admin.from("pin_resets").insert({
      resident_id: user.id,
      code_hash: await sha256(c),
      expires_at: new Date(Date.now() + CODE_TTL_MS).toISOString(),
    });
    await sendEmail(user.email!, c, org);
    return json(generic);
  }

  if (action === "reset") {
    if (!code || !/^[0-9]{4,}$/.test(newPin)) return json({ message: "Enter the code and a 4-digit PIN." }, 400);
    const user = await findUser(name, org);
    if (!user) return json({ message: "Invalid or expired code." }, 400);
    const { data: row } = await admin
      .from("pin_resets")
      .select("id,code_hash,attempts")
      .eq("resident_id", user.id).eq("used", false)
      .gte("expires_at", new Date().toISOString())
      .order("created_at", { ascending: false }).limit(1).maybeSingle();
    if (!row) return json({ message: "Invalid or expired code." }, 400);
    if ((row.attempts ?? 0) >= MAX_ATTEMPTS) {
      await admin.from("pin_resets").update({ used: true }).eq("id", row.id);
      return json({ message: "Too many tries. Request a new code." }, 400);
    }
    if (row.code_hash !== (await sha256(code))) {
      await admin.from("pin_resets").update({ attempts: (row.attempts ?? 0) + 1 }).eq("id", row.id);
      return json({ message: "Invalid or expired code." }, 400);
    }
    const { error } = await admin.rpc("admin_set_pin_hash", { p_id: user.id, p_new_pin: newPin });
    if (error) return json({ message: "Could not reset. Try again." }, 500);
    await admin.from("pin_resets").update({ used: true }).eq("id", row.id);
    return json({ ok: true, message: "PIN reset. Sign in with your new PIN." });
  }

  return json({ error: "Unknown action" }, 400);
});
