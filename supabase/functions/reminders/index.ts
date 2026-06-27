// reminders — daily email nudges to residents who opted in.
//
// Sends ONE email per opted-in resident summarizing what's waiting on them:
//   • documents pending their signature (resident_documents.status = 'pending')
//   • active announcements they haven't acknowledged (announcements.archived = false,
//     scoped to their house or is_global, minus rows in announcement_acks)
// De-duped via `reminders_log` so the same item isn't re-nagged too often
// (documents every 3 days; announcements every 7, since they tend to linger).
//
// Security: this is deployed with `--no-verify-jwt`, so it guards itself with a
// shared secret. The caller (a scheduled cron job) MUST send header:
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
const DOC_DEDUPE_DAYS = 3;
const ANN_DEDUPE_DAYS = 7;
const ANN_MAX_AGE_DAYS = 30;

const admin = createClient(SUPABASE_URL, SERVICE_ROLE, {
  auth: { persistSession: false },
});

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

const esc = (s: unknown) =>
  String(s ?? "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

function emailHtml(
  name: string,
  org: string,
  docs: any[],
  anns: any[],
) {
  let body = "";
  if (docs.length) {
    body += `<p>You have ${docs.length === 1 ? "a document" : docs.length + " documents"} waiting for your signature:</p>
      <ul style="padding-left:18px">${docs.map((d) => `<li style="margin:4px 0">${esc(d.template_name ?? d.name ?? d.title ?? "A document")}</li>`).join("")}</ul>`;
  }
  if (anns.length) {
    body += `<p>${anns.length === 1 ? "There's a house announcement" : "There are house announcements"} to review:</p>
      <ul style="padding-left:18px">${anns.map((a) => `<li style="margin:4px 0">${esc((a.message || "").slice(0, 140))}</li>`).join("")}</ul>`;
  }
  return `<div style="font-family:-apple-system,Segoe UI,Arial,sans-serif;color:#1a1a1a;line-height:1.6">
    <p>Hi ${esc(name)},</p>
    ${body}
    <p>Please sign in to InStep when you have a moment.</p>
    <p style="color:#666;font-size:13px">— ${esc(org)}</p>
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

  // Org name for the email greeting/footer.
  let org = "your recovery residence";
  const { data: settings } = await admin
    .from("settings").select("house_name").eq("id", 1).maybeSingle();
  if (settings?.house_name) org = settings.house_name;

  // Opted-in, active residents with an email on file.
  const { data: residents, error: rErr } = await admin
    .from("residents")
    .select("id,name,email,house,notify_opt_in,status,role")
    .eq("role", "resident")
    .eq("status", "active")
    .eq("notify_opt_in", true);
  if (rErr) return json({ error: rErr.message }, 500);

  const withEmail = (residents ?? []).filter((r) => r.email && r.email.includes("@"));
  if (!withEmail.length) {
    return json({ ok: true, dryRun, residents_emailed: 0, docs_reminded: 0, announcements_reminded: 0, note: "no opted-in residents with an email" });
  }
  const ids = withEmail.map((r) => r.id);

  // Pending documents.
  const { data: docs, error: dErr } = await admin
    .from("resident_documents")
    .select("*")
    .in("resident_id", ids)
    .eq("status", "pending");
  if (dErr) return json({ error: dErr.message }, 500);

  // Active (recent) announcements + this set of residents' acknowledgements.
  const annSince = new Date(Date.now() - ANN_MAX_AGE_DAYS * 86400000).toISOString();
  const { data: anns, error: aErr } = await admin
    .from("announcements")
    .select("id,message,house,is_global,created_at,archived")
    .eq("archived", false)
    .gte("created_at", annSince);
  if (aErr) return json({ error: aErr.message }, 500);
  const { data: acks } = await admin
    .from("announcement_acks")
    .select("announcement_id,resident_id")
    .in("resident_id", ids);
  const acked = new Set((acks ?? []).map((x) => `${x.resident_id}|${x.announcement_id}`));

  // De-dupe against recent reminders (per-kind window).
  const docSince = new Date(Date.now() - DOC_DEDUPE_DAYS * 86400000).toISOString();
  const annDedupeSince = new Date(Date.now() - ANN_DEDUPE_DAYS * 86400000).toISOString();
  const earliest = docSince < annDedupeSince ? docSince : annDedupeSince;
  const { data: recent } = await admin
    .from("reminders_log")
    .select("resident_id,kind,ref,sent_at")
    .gte("sent_at", earliest);
  const remindedDoc = new Set<string>();
  const remindedAnn = new Set<string>();
  for (const x of recent ?? []) {
    const key = `${x.resident_id}|${x.ref}`;
    if (x.kind === "doc" && x.sent_at >= docSince) remindedDoc.add(key);
    if (x.kind === "ann" && x.sent_at >= annDedupeSince) remindedAnn.add(key);
  }

  let emailed = 0;
  let docCount = 0;
  let annCount = 0;
  const failures: string[] = [];
  for (const r of withEmail) {
    const myDocs = (docs ?? []).filter(
      (d) => d.resident_id === r.id && !remindedDoc.has(`${r.id}|${d.id}`),
    );
    const myAnns = (anns ?? []).filter(
      (a) => (a.is_global || a.house === r.house) && !acked.has(`${r.id}|${a.id}`) && !remindedAnn.has(`${r.id}|${a.id}`),
    );
    if (!myDocs.length && !myAnns.length) continue;

    const parts: string[] = [];
    if (myDocs.length) parts.push(`${myDocs.length} document${myDocs.length === 1 ? "" : "s"} to sign`);
    if (myAnns.length) parts.push(`${myAnns.length} announcement${myAnns.length === 1 ? "" : "s"}`);
    const subject = `Reminder: ${parts.join(" + ")}`;
    const html = emailHtml(r.name, org, myDocs, myAnns);

    if (!dryRun) {
      const ok = await sendEmail(r.email!, subject, html);
      if (!ok) { failures.push(r.id); continue; }
      const rows = [
        ...myDocs.map((d) => ({ resident_id: r.id, kind: "doc", ref: d.id })),
        ...myAnns.map((a) => ({ resident_id: r.id, kind: "ann", ref: a.id })),
      ];
      if (rows.length) await admin.from("reminders_log").insert(rows);
    }
    emailed++;
    docCount += myDocs.length;
    annCount += myAnns.length;
  }

  return json({
    ok: true,
    dryRun,
    residents_emailed: emailed,
    docs_reminded: docCount,
    announcements_reminded: annCount,
    failures,
  });
});
