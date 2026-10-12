// weeklyreport — weekly summary email to owners/managers.
//
// One email per staff member (role owner/manager, active, with an email on file): the past 7 days of
// activity for their scope — owners see their whole org (all houses), managers see their own house.
// Covers residents, meeting check-ins (+ how many are on track), screenings (+ positives/refused),
// incidents, grievances (new + open), and late curfew sign-ins. De-duped via `reminders_log`
// (kind = 'weekly') so a given run is sent once.
//
// Security: deployed --no-verify-jwt; the scheduled cron MUST send header  x-cron-secret: <CRON_SECRET>.
// Secrets: CRON_SECRET (required), RESEND_API_KEY (unset => dry-run, computes but doesn't send).
// Auto-provided: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const CRON_SECRET = Deno.env.get("CRON_SECRET") ?? "";
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") ?? "";
const FROM = "InStep <reminders@instepapp.com>";
const WINDOW_DAYS = 7;

const admin = createClient(SUPABASE_URL, SERVICE_ROLE, { auth: { persistSession: false } });

// Effective screening result, mirroring effResult() in index.html: a lab verdict overrides the instant
// test — prescribed/negative clears an instant positive (not a violation), positive confirms.
function effResult(t: { result?: string; lab_result?: string; lab_sent_date?: string | null }): string | undefined {
  let r = t.lab_result;
  if (r === "confirmed") r = "positive";
  if (t.lab_sent_date && r) {
    if (r === "prescribed" || r === "negative") return "pass";
    if (r === "positive") return "fail";
  }
  return t.result;
}
const json = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { "Content-Type": "application/json" } });

// Read every row, 1,000 at a time (the API returns at most 1,000 rows per request), and keep long
// id lists in batches so the request URL stays short. Needed once many orgs share these tables.
// deno-lint-ignore no-explicit-any
async function allRows(make: () => any): Promise<{ data: any[]; error: any }> {
  // deno-lint-ignore no-explicit-any
  const out: any[] = [];
  for (let from = 0; ; from += 1000) {
    const { data, error } = await make().range(from, from + 999);
    if (error) return { data: out, error };
    out.push(...(data ?? []));
    if (!data || data.length < 1000) break;
  }
  return { data: out, error: null };
}
// deno-lint-ignore no-explicit-any
async function allRowsIn(ids: string[], make: (chunk: string[]) => any): Promise<{ data: any[]; error: any }> {
  // deno-lint-ignore no-explicit-any
  const out: any[] = [];
  for (let i = 0; i < ids.length; i += 150) {
    const r = await allRows(() => make(ids.slice(i, i + 150)));
    if (r.error) return { data: out, error: r.error };
    out.push(...r.data);
  }
  return { data: out, error: null };
}

const esc = (s: unknown) => String(s ?? "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

function row(label: string, value: string) {
  return `<tr><td style="padding:7px 0;color:#555;font-size:14px">${esc(label)}</td>
    <td style="padding:7px 0;font-size:15px;font-weight:700;text-align:right">${esc(value)}</td></tr>`;
}

function emailHtml(name: string, scopeLabel: string, rangeLabel: string, s: Record<string, number>) {
  return `<div style="font-family:-apple-system,Segoe UI,Arial,sans-serif;color:#1a1a1a;line-height:1.6;max-width:520px">
    <p>Hi ${esc(name)},</p>
    <p>Here's the past week at <strong>${esc(scopeLabel)}</strong> (${esc(rangeLabel)}):</p>
    <table style="width:100%;border-collapse:collapse;margin:8px 0 14px">
      ${row("Active residents", String(s.residents))}
      ${row("Meeting check-ins", String(s.meetings))}
      ${row("Residents on track this week", `${s.onTrack} of ${s.residents}`)}
      ${row("Screenings", String(s.screenings))}
      ${row("— Positive", String(s.positives))}
      ${row("— Declined", String(s.refused))}
      ${row("Late curfew sign-ins", String(s.late))}
      ${row("Incidents", String(s.incidents))}
      ${row("New grievances", String(s.grievancesNew))}
      ${row("Open grievances", String(s.grievancesOpen))}
    </table>
    <p style="font-size:13px;color:#666">Open InStep for the full records and printable reports.</p>
    <p style="color:#666;font-size:13px">— ${esc(scopeLabel)}</p>
  </div>`;
}

async function sendEmail(to: string, subject: string, html: string): Promise<boolean> {
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { Authorization: `Bearer ${RESEND_API_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify({ from: FROM, to, subject, html }),
  });
  return res.ok;
}

Deno.serve(async (req) => {
  const provided = req.headers.get("x-cron-secret") ?? "";
  if (!CRON_SECRET || provided !== CRON_SECRET) return json({ error: "unauthorized" }, 401);
  const dryRun = !RESEND_API_KEY;

  const now = Date.now();
  const since = new Date(now - WINDOW_DAYS * 86400000).toISOString();
  const sinceDate = since.slice(0, 10);
  const runRef = new Date(now).toISOString().slice(0, 10);
  // Dedupe by ISO week (the week's Monday), NOT a rolling 7-day window — so a daily cron sends once per
  // week and a late/early weekly run can't double-send or skip a week from clock jitter.
  const weekRef = new Date(now - (((new Date(now).getUTCDay() + 6) % 7)) * 86400000).toISOString().slice(0, 10);
  const rangeLabel = `${sinceDate} – ${runRef}`;

  // Recipients: active owners/managers with an email.
  const { data: staff, error: sErr } = await allRows(() => admin
    .from("residents").select("id,name,email,role,house,org")
    .in("role", ["owner", "manager"]).eq("status", "active").order("id"));
  if (sErr) return json({ error: sErr.message }, 500);
  const recipients = (staff ?? []).filter((r) => r.email && String(r.email).includes("@"));
  if (!recipients.length) return json({ ok: true, dryRun, sent: 0, note: "no owner/manager with an email" });

  // Reference data + the week's activity (all orgs; grouped in memory).
  const orgs = [...new Set(recipients.map((r) => r.org))];
  const { data: settings } = await allRows(() => admin.from("settings").select("org,house_name,required").order("org"));
  const orgInfo: Record<string, { name: string; required: number }> = {};
  for (const s of settings ?? []) orgInfo[s.org as string] = { name: (s.house_name as string) || "your residence", required: (s.required as number) || 3 };

  const { data: residents } = await allRows(() => admin.from("residents").select("id,house,org,status,role").eq("status", "active").eq("role", "resident").order("id"));
  const { data: checkins } = await allRows(() => admin.from("checkins").select("id,resident_id,house,org,ts").gte("ts", since).order("id"));
  const { data: drugs } = await allRows(() => admin.from("drug_tests").select("id,result,lab_result,lab_sent_date,house,org,test_date").gte("test_date", sinceDate).order("id"));
  const { data: incidents } = await allRows(() => admin.from("incidents").select("id,house,org,incident_date").gte("incident_date", sinceDate).order("id"));
  const { data: curfew } = await allRows(() => admin.from("curfew_log").select("id,late,action,house,org,ts").gte("ts", since).order("id"));
  const { data: grievances } = await allRows(() => admin.from("grievances").select("id,status,house,org,grievance_date").order("id"));

  // Already sent this ISO week? Match ref >= this week's Monday (ISO dates sort chronologically) so it
  // also catches rows written earlier this week under the old run-date key — no double-send at the
  // deploy boundary — while next week's later Monday still triggers a fresh send.
  const { data: sentLog, error: sentErr } = await allRows(() => admin.from("reminders_log").select("resident_id").eq("kind", "weekly").gte("ref", weekRef).order("resident_id").order("ref"));
  if (sentErr) return json({ error: sentErr.message }, 500); // can't de-dupe safely
  const alreadySent = new Set((sentLog ?? []).map((x) => x.resident_id));

  const inScope = (r: { org: string; house?: string | null }, rec: { org: string; role: string; house?: string | null }) =>
    r.org === rec.org && (rec.role === "owner" || r.house === rec.house);

  let sent = 0, failures = 0;
  for (const rec of recipients) {
    if (alreadySent.has(rec.id)) continue;
    const info = orgInfo[rec.org as string] || { name: "your residence", required: 3 };
    const scopeLabel = rec.role === "owner" ? info.name : (rec.house || info.name);

    const resInScope = (residents ?? []).filter((r) => inScope(r, rec));
    const resIds = new Set(resInScope.map((r) => r.id));
    const ciInScope = (checkins ?? []).filter((c) => resIds.has(c.resident_id));
    const perRes: Record<string, number> = {};
    for (const c of ciInScope) perRes[c.resident_id] = (perRes[c.resident_id] || 0) + 1;
    const onTrack = resInScope.filter((r) => (perRes[r.id] || 0) >= info.required).length;
    const dr = (drugs ?? []).filter((d) => inScope(d, rec));
    const cf = (curfew ?? []).filter((c) => inScope(c, rec) && c.action === "in" && c.late);
    const inc = (incidents ?? []).filter((i) => inScope(i, rec));
    const grAll = (grievances ?? []).filter((g) => inScope(g, rec));

    const s = {
      residents: resInScope.length,
      meetings: ciInScope.length,
      onTrack,
      screenings: dr.length,
      positives: dr.filter((d) => effResult(d) === "fail").length,
      refused: dr.filter((d) => effResult(d) === "refused").length,
      late: cf.length,
      incidents: inc.length,
      grievancesNew: grAll.filter((g) => (g.grievance_date as string) >= sinceDate).length,
      grievancesOpen: grAll.filter((g) => g.status !== "resolved").length,
    };

    const subject = `InStep weekly report — ${scopeLabel}`;
    const html = emailHtml(rec.name as string, scopeLabel, rangeLabel, s);
    if (!dryRun) {
      const ok = await sendEmail(rec.email as string, subject, html);
      if (!ok) { failures++; continue; } // leave no log row → retried next run
      const { error: logErr } = await admin.from("reminders_log").insert({ resident_id: rec.id, kind: "weekly", ref: weekRef, org: rec.org });
      if (logErr) console.error("weekly reminders_log insert failed for", rec.id, logErr.message);
    }
    sent++;
  }

  return json({ ok: true, dryRun, sent, failures, recipients: recipients.length });
});
