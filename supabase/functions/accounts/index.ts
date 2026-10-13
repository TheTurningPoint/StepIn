// accounts — vendor-only view of every customer org: size, activity, setup progress, billing.
//
// POST { secret }                         -> { ok, accounts: [...], totals }
// POST { secret, action: "update", org, sales_rep?, rate_per_house?, status?, billing_ref?, signed_on?, notes? }
//                                         -> { ok }  (edits that org's vendor_accounts row)
//
// Secret-gated with the same ADMIN_SECRET as provisionorg (used from admin.html, which is not served
// publicly). Reads with the service role across all orgs; returns counts and dates only — no resident
// names, screenings, or other records.
//
// Deployed with --no-verify-jwt (public). Required secret: ADMIN_SECRET.
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

function secretOk(got: string): boolean {
  if (!ADMIN_SECRET || !got || got.length !== ADMIN_SECRET.length) return false;
  let diff = 0;
  for (let i = 0; i < got.length; i++) diff |= got.charCodeAt(i) ^ ADMIN_SECRET.charCodeAt(i);
  return diff === 0;
}

// Read every row, 1,000 at a time (the API caps each request at 1,000).
// deno-lint-ignore no-explicit-any
async function allRows(make: () => any): Promise<any[]> {
  // deno-lint-ignore no-explicit-any
  const out: any[] = [];
  for (let from = 0; ; from += 1000) {
    const { data, error } = await make().range(from, from + 999);
    if (error) throw new Error(error.message);
    out.push(...(data ?? []));
    if (!data || data.length < 1000) break;
  }
  return out;
}

const DAY = 86400000;
const STATUSES = ["trial", "active", "paused", "cancelled"];

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  // deno-lint-ignore no-explicit-any
  let b: Record<string, any> = {};
  try { b = await req.json(); } catch { return json({ error: "Bad request" }, 400); }
  if (!secretOk(String(b.secret ?? "").trim())) return json({ error: "Unauthorized" }, 401);

  if (b.action === "update") {
    const org = String(b.org ?? "").trim();
    if (!org) return json({ error: "Missing org" }, 400);
    const row: Record<string, unknown> = { org, updated_at: new Date().toISOString() };
    if ("sales_rep" in b) row.sales_rep = String(b.sales_rep ?? "").trim() || null;
    if ("billing_ref" in b) row.billing_ref = String(b.billing_ref ?? "").trim() || null;
    if ("notes" in b) row.notes = String(b.notes ?? "").trim() || null;
    if ("signed_on" in b) row.signed_on = /^\d{4}-\d{2}-\d{2}$/.test(String(b.signed_on)) ? b.signed_on : null;
    if ("rate_per_house" in b) {
      const r = Number(b.rate_per_house);
      if (!(r >= 0 && r < 10000)) return json({ error: "Rate must be a number" }, 400);
      row.rate_per_house = r;
    }
    if ("status" in b) {
      if (!STATUSES.includes(String(b.status))) return json({ error: "Unknown status" }, 400);
      row.status = b.status;
    }
    const { error } = await admin.from("vendor_accounts").upsert(row, { onConflict: "org" });
    if (error) return json({ error: error.message }, 500);
    return json({ ok: true });
  }

  try {
    const now = Date.now();
    const since7 = new Date(now - 7 * DAY).toISOString();
    const since30 = new Date(now - 30 * DAY).toISOString();
    const since30d = since30.slice(0, 10);

    const [orgs, vendor, settings, people, checkins, curfew, screenings, templates, audit] = await Promise.all([
      allRows(() => admin.from("orgs").select("subdomain,name,created_at").order("subdomain")),
      allRows(() => admin.from("vendor_accounts").select("*").order("org")),
      allRows(() => admin.from("settings").select("org,timezone,house_coords,feature_curfew").order("org")),
      allRows(() => admin.from("residents").select("id,org,role,house,status,email").order("id")),
      allRows(() => admin.from("checkins").select("id,org,ts").gte("ts", since30).order("id")),
      allRows(() => admin.from("curfew_log").select("id,org,ts").gte("ts", since30).order("id")),
      allRows(() => admin.from("drug_tests").select("id,org").gte("test_date", since30d).order("id")),
      allRows(() => admin.from("document_templates").select("id,org").order("id")),
      allRows(() => admin.from("audit_log").select("id,org,changed_at").gte("changed_at", since30).order("id")),
    ]);

    const by = <T extends { org?: string }>(rows: T[]) => {
      const m: Record<string, T[]> = {};
      for (const r of rows) (m[r.org ?? ""] ??= []).push(r);
      return m;
    };
    const vByOrg = Object.fromEntries(vendor.map((v) => [v.org, v]));
    const sByOrg = Object.fromEntries(settings.map((s) => [s.org, s]));
    const pBy = by(people), cBy = by(checkins), fBy = by(curfew), dBy = by(screenings), tBy = by(templates), aBy = by(audit);
    const latest = (...lists: string[][]) => lists.flat().filter(Boolean).sort().pop() ?? null;

    const accounts = orgs.map((o) => {
      const org = o.subdomain as string;
      const ppl = (pBy[org] ?? []).filter((p) => p.status !== "discharged");
      const residents = ppl.filter((p) => p.role === "resident");
      const managers = ppl.filter((p) => p.role === "manager");
      const owners = ppl.filter((p) => p.role === "owner");
      // A billable house = a house name with at least one active resident or manager.
      const houses = [...new Set(ppl.filter((p) => p.role !== "owner" && p.house).map((p) => p.house as string))].sort();
      const ci = cBy[org] ?? [], cf = fBy[org] ?? [];
      const lastActivity = latest(ci.map((x) => x.ts), cf.map((x) => x.ts), (aBy[org] ?? []).map((x) => x.changed_at));
      const s = sByOrg[org] ?? {};
      const v = vByOrg[org] ?? { status: "trial", rate_per_house: 99 };
      const setup = {
        owner_email: owners.some((p) => p.email && String(p.email).includes("@")),
        manager_added: managers.length > 0,
        residents_added: residents.length > 0,
        time_zone_set: !!s.timezone,
        house_location_set: !!s.house_coords && Object.keys(s.house_coords).length > 0,
        documents_added: (tBy[org] ?? []).length > 0,
        first_check_in: ci.length > 0,
      };
      const setupDone = Object.values(setup).filter(Boolean).length;
      const ageDays = Math.floor((now - new Date(o.created_at).getTime()) / DAY);
      const idleDays = lastActivity ? Math.floor((now - new Date(lastActivity).getTime()) / DAY) : null;
      let health = "healthy";
      if (v.status === "cancelled" || v.status === "paused") health = v.status;
      else if (setupDone < 5) health = ageDays > 14 ? "stalled setup" : "setting up";
      else if (idleDays === null || idleDays >= 7) health = "gone quiet";
      return {
        org, name: o.name, created_at: o.created_at, age_days: ageDays,
        houses, house_count: houses.length,
        residents: residents.length, managers: managers.length, owners: owners.length,
        check_ins_7d: ci.filter((x) => x.ts >= since7).length, check_ins_30d: ci.length,
        curfew_7d: cf.filter((x) => x.ts >= since7).length, screenings_30d: (dBy[org] ?? []).length,
        last_activity: lastActivity, idle_days: idleDays,
        setup, setup_done: setupDone, setup_total: Object.keys(setup).length, health,
        sales_rep: v.sales_rep ?? null, rate_per_house: Number(v.rate_per_house ?? 99), status: v.status,
        billing_ref: v.billing_ref ?? null, signed_on: v.signed_on ?? null, notes: v.notes ?? null,
        monthly: v.status === "active" ? houses.length * Number(v.rate_per_house ?? 99) : 0,
      };
    });

    const reps: Record<string, { accounts: number; houses: number; monthly: number }> = {};
    for (const a of accounts) {
      if (a.status !== "active") continue;
      const r = (reps[a.sales_rep ?? "(none)"] ??= { accounts: 0, houses: 0, monthly: 0 });
      r.accounts++; r.houses += a.house_count; r.monthly += a.monthly;
    }
    const totals = {
      accounts: accounts.length,
      active: accounts.filter((a) => a.status === "active").length,
      houses_billed: accounts.filter((a) => a.status === "active").reduce((n, a) => n + a.house_count, 0),
      monthly: accounts.reduce((n, a) => n + a.monthly, 0),
      needs_attention: accounts.filter((a) => ["stalled setup", "gone quiet"].includes(a.health)).length,
      by_rep: reps,
    };
    return json({ ok: true, generated_at: new Date(now).toISOString(), accounts, totals });
  } catch (e) {
    return json({ error: String((e as Error).message ?? e) }, 500);
  }
});
