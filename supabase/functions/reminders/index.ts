// reminders — daily email nudges to residents who opted in.
//
// v1 sends ONE email per resident listing the documents still waiting on their
// signature (resident_documents.status = 'pending'). It de-dupes against the
// `reminders_log` table so the same document isn't re-nagged more than once every
// few days. (Announcements are an easy next addition — see the TODO below.)
//
// Security: this is deployed with `--no-verify-jwt`, so it guards itself with a
// shared secret. The caller (a scheduled cron job) MUST send header
//   x-cron-secret: <CRON_SECRET>
//
// Required Edge Function secrets (set once via the dashboard or `supabase secrets set`):
//   CRON_SECRET     any long random string; the scheduler must echo it back.
//   RESEND_API_KEY  Resend API key. If unset, the function runs in DRY-RUN mode
//                   (computes + logs nothing, just reports what it WOULD send).
// Auto-provided by Supabase: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const CRON_SECRET = Deno.env.get("CRON_SECRET") ?? "";
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") ?? "";
const FROM = "InStep <reminders@instepapp.com>";
const DEDUPE_DAYS = 3;

const admin = createClient(SUPABASE_URL, SERVICE_ROLE, {
  auth: { persistSession: false },
});

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

function emailHtml(name: string, docs: { template_name: string }[], org: string) {
  const items = docs
    .map((d) => `<li style="margin:4px 0">${d.template_name}</li>`)
    .join("");
  return `<div style="font-family:-apple-system,Segoe UI,Arial,sans-serif;color:#1a1a1a;line-height:1.6">
    <p>Hi ${name},</p>
    <p>You have ${docs.length === 1 ? "a document" : "documents"} waiting for your signature at ${org}:</p>
    <ul style="padding-left:18px">${items}</ul>
    <p>Please sign in to InStep and complete ${docs.length === 1 ? "it" : "them"} when you have a moment.</p>
    <p style="color:#666;font-size:13px">— ${org}</p>
  </div>`;
}

async function sendEmail(to: string, subject: string, html: string): Promise<boolean> {
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ from: FROM, to, subject, html }),
  });
  return res.ok;
}

Deno.serve(async (req) => {
  // Auth: cron must present the shared secret.
  const provided = req.headers.get("x-cron-secret") ?? "";
  if (!CRON_SECRET || provided !== CRON_SECRET) {
    return json({ error: "unauthorized" }, 401);
  }

  const dryRun = !RESEND_API_KEY;
  const orgName = (() => {
    return "your recovery residence";
  })();

  // Opted-in, active residents with an email on file.
  const { data: residents, error: rErr } = await admin
    .from("residents")
    .select("id,name,email,house,notify_opt_in,status,role")
    .eq("role", "resident")
    .eq("status", "active")
    .eq("notify_opt_in", true);
  if (rErr) return json({ error: rErr.message }, 500);

  const withEmail = (residents ?? []).filter((r) => r.email && r.email.includes("@"));
  if (!withEmail.length) return json({ ok: true, dryRun, residents_emailed: 0, docs_reminded: 0, note: "no opted-in residents with an email" });

  // Pending documents for those residents.
  const ids = withEmail.map((r) => r.id);
  const { data: docs, error: dErr } = await admin
    .from("resident_documents")
    .select("id,resident_id,template_name,status")
    .in("resident_id", ids)
    .eq("status", "pending");
  if (dErr) return json({ error: dErr.message }, 500);

  // De-dupe against recent reminders.
  const since = new Date(Date.now() - DEDUPE_DAYS * 86400000).toISOString();
  const { data: recent } = await admin
    .from("reminders_log")
    .select("resident_id,kind,ref,sent_at")
    .gte("sent_at", since);
  const already = new Set((recent ?? []).map((x) => `${x.resident_id}|${x.kind}|${x.ref}`));

  const byResident = new Map<string, { id: string; template_name: string }[]>();
  for (const d of docs ?? []) {
    if (already.has(`${d.resident_id}|doc|${d.id}`)) continue;
    const arr = byResident.get(d.resident_id) ?? [];
    arr.push({ id: d.id, template_name: d.template_name });
    byResident.set(d.resident_id, arr);
  }

  let emailed = 0;
  let reminded = 0;
  const failures: string[] = [];
  for (const r of withEmail) {
    const pend = byResident.get(r.id);
    if (!pend || !pend.length) continue;
    const subject = `Reminder: ${pend.length} document${pend.length === 1 ? "" : "s"} to sign`;
    const html = emailHtml(r.name, pend, orgName);

    if (!dryRun) {
      const ok = await sendEmail(r.email!, subject, html);
      if (!ok) { failures.push(r.id); continue; }
      const rows = pend.map((d) => ({ resident_id: r.id, kind: "doc", ref: d.id }));
      await admin.from("reminders_log").insert(rows);
    }
    emailed++;
    reminded += pend.length;
  }

  // TODO(next): also remind on unacknowledged active announcements
  // (announcements.archived=false scoped to house/is_global, minus announcement_acks).

  return json({
    ok: true,
    dryRun,
    residents_emailed: emailed,
    docs_reminded: reminded,
    failures,
  });
});
