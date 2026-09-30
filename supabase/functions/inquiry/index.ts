// inquiry — public contact form backend for beeconworks.com (and CCG / InStep pages).
//
// POST { name, email, phone?, organization?, interest?, houses?, message?, source?, website? }
//   -> stores the inquiry in public.inquiries and emails hello@beeconworks.com (Reply goes to the sender).
//
// Protections: `website` is a honeypot (bots fill it; we pretend success and store nothing), field length
// caps, basic email check, and at most 5 inquiries per sender IP per hour (IP stored only as a SHA-256).
// The table has RLS on with no policies, so only this function (service role) can touch it.
//
// Deployed with --no-verify-jwt (public). Secrets: RESEND_API_KEY (to send; if unset the inquiry is still
// stored and the send is logged as a dry run). Auto-provided: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") ?? "";
const FROM = "Beecon Works inquiries <reminders@instepapp.com>";
const TO = "hello@beeconworks.com";
const MAX_PER_HOUR = 5;

const admin = createClient(SUPABASE_URL, SERVICE_ROLE, { auth: { persistSession: false } });
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...cors, "Content-Type": "application/json" } });

const clip = (v: unknown, n: number) => String(v ?? "").trim().slice(0, n);
const esc = (s: string) => s.replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]!));
async function sha256(s: string): Promise<string> {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return Array.from(new Uint8Array(buf)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
  let b: Record<string, unknown>;
  try { b = await req.json(); } catch { return json({ error: "Invalid request" }, 400); }

  // Honeypot: real people never see this field.
  if (clip(b.website, 200)) return json({ ok: true });

  const row = {
    name: clip(b.name, 120),
    email: clip(b.email, 200).toLowerCase(),
    phone: clip(b.phone, 40) || null,
    organization: clip(b.organization, 160) || null,
    interest: clip(b.interest, 80) || null,
    houses: clip(b.houses, 40) || null,
    message: clip(b.message, 4000) || null,
    source: clip(b.source, 200) || null,
  };
  if (!row.name) return json({ error: "Please include your name." }, 400);
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(row.email)) return json({ error: "Please include a valid email address." }, 400);

  const ip = req.headers.get("cf-connecting-ip") ?? req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "";
  const ip_hash = ip ? await sha256(ip) : null;
  if (ip_hash) {
    const since = new Date(Date.now() - 60 * 60 * 1000).toISOString();
    const { count } = await admin.from("inquiries").select("id", { count: "exact", head: true })
      .eq("ip_hash", ip_hash).gte("created_at", since);
    if ((count ?? 0) >= MAX_PER_HOUR) return json({ error: "Too many messages. Please email hello@beeconworks.com." }, 429);
  }

  const { data: saved, error } = await admin.from("inquiries").insert({ ...row, ip_hash }).select("id").single();
  if (error) return json({ error: "Could not send. Please email hello@beeconworks.com." }, 500);

  const lines: [string, string | null][] = [
    ["Name", row.name], ["Email", row.email], ["Phone", row.phone], ["Organization", row.organization],
    ["Interested in", row.interest], ["Houses", row.houses], ["Page", row.source],
  ];
  const html = `<div style="font-family:-apple-system,Segoe UI,Arial,sans-serif;color:#241C15;line-height:1.6">
    <h2 style="margin:0 0 12px">New inquiry</h2>
    <table style="border-collapse:collapse">${lines.filter(([, v]) => v).map(([k, v]) =>
      `<tr><td style="padding:4px 14px 4px 0;color:#6E6356">${k}</td><td style="padding:4px 0"><strong>${esc(v!)}</strong></td></tr>`).join("")}</table>
    ${row.message ? `<p style="margin-top:16px;white-space:pre-wrap">${esc(row.message)}</p>` : ""}
    <p style="color:#6E6356;font-size:13px;margin-top:18px">Reply to this email to answer ${esc(row.name)} directly.</p></div>`;
  let emailed = false;
  if (!RESEND_API_KEY) {
    console.log(`[dry-run] inquiry ${saved?.id} from ${row.email}`);
  } else {
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: `Bearer ${RESEND_API_KEY}`, "Content-Type": "application/json" },
      body: JSON.stringify({ from: FROM, to: TO, reply_to: row.email,
        subject: `Inquiry: ${row.interest || "General"} (${row.organization || row.name})`, html }),
    });
    emailed = res.ok;
    if (!res.ok) console.log("resend error", res.status, await res.text());
  }
  if (saved?.id) await admin.from("inquiries").update({ emailed }).eq("id", saved.id);
  return json({ ok: true });
});
