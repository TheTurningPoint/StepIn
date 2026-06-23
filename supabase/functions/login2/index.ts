// login2 — name+PIN login that ALSO issues a real auth token.
//
// Why this exists: the app currently talks to the database as the public "anon"
// key for everyone, so the database can't tell a logged-in user from a stranger.
// This function verifies name+PIN server-side (using the service role, so it keeps
// working even after we lock the tables down), rate-limits guesses, and returns a
// signed JWT with role:"authenticated" plus the user's house/role as claims. The
// app then attaches that token to every request, so RLS can require a real login.
//
// Runs ALONGSIDE the existing `login` function — nothing is replaced until cutover.
//
// Required Edge Function secret (set once in the dashboard):
//   JWT_SECRET = your project's JWT secret (Settings -> API -> JWT Settings).
// Auto-provided by Supabase: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY.

// deploy trigger: v1
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { create, getNumericDate } from "https://deno.land/x/djwt@v3.0.2/mod.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const JWT_SECRET = Deno.env.get("JWT_SECRET")!;

const admin = createClient(SUPABASE_URL, SERVICE_ROLE, {
  auth: { persistSession: false },
});

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });

// Simple per-name rate limit: max 5 attempts per rolling 30s window.
// Uses a tiny table `login_attempts` (created via SQL before deploy).
async function rateLimited(name: string): Promise<boolean> {
  const now = Date.now();
  const { data } = await admin
    .from("login_attempts")
    .select("attempts, window_start")
    .eq("name", name)
    .maybeSingle();

  if (data) {
    const started = new Date(data.window_start).getTime();
    if (now - started < 30_000) {
      if (data.attempts >= 5) return true;
      await admin
        .from("login_attempts")
        .update({ attempts: data.attempts + 1 })
        .eq("name", name);
      return false;
    }
  }
  await admin
    .from("login_attempts")
    .upsert({ name, attempts: 1, window_start: new Date(now).toISOString() });
  return false;
}

async function signToken(user: Record<string, unknown>): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(JWT_SECRET),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign", "verify"],
  );
  return await create(
    { alg: "HS256", typ: "JWT" },
    {
      role: "authenticated",
      aud: "authenticated",
      sub: String(user.id),
      house: user.house ?? null,
      urole: user.role ?? "resident",
      exp: getNumericDate(60 * 60 * 12), // 12 hours
    },
    key,
  );
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  let name = "", pin = "";
  try {
    const body = await req.json();
    name = (body.name ?? "").trim();
    pin = (body.pin ?? "").trim();
  } catch {
    return json({ error: "Bad request" }, 400);
  }
  if (!name || !pin) return json({ error: "Name and PIN required" }, 400);

  if (await rateLimited(name.toLowerCase())) {
    return json({ message: "Too many attempts. Please wait 30 seconds." }, 429);
  }

  // Verify name + PIN. PINs are currently stored in plain text.
  const { data: rows, error } = await admin
    .from("residents")
    .select("*")
    .eq("pin", pin);
  if (error) return json({ error: "Server error" }, 500);

  const user = (rows ?? []).find(
    (r) => String(r.name).trim().toLowerCase() === name.toLowerCase(),
  );
  if (!user) {
    return json(
      { message: "Name or PIN not found. Check spelling and try again." },
      401,
    );
  }

  // Success: clear the attempt counter and hand back the user + token.
  await admin.from("login_attempts").delete().eq("name", name.toLowerCase());
  const token = await signToken(user);
  const { pin: _omit, ...safeUser } = user;
  return json({ user: safeUser, token });
});
