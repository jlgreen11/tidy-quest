/**
 * user.claim-pair — POST (anonymous)
 * Auth: none (pairing code is the auth credential)
 * Rate: 3 requests per 60 seconds per source IP
 *
 * Kid device redeems a pairing code, receives a long-lived device token.
 * The pairing code hash is matched against app_user.device_pairing_code.
 * On success:
 *   1. Clears the pairing code from app_user (single-use).
 *   2. Returns a signed device token (mock: "device-token-<user_id>|<family_id>").
 *      TODO: Replace mock token with a signed JWT.
 */

import { createClient } from "npm:@supabase/supabase-js@2";
import {
  checkIdempotency,
  checkRateLimit,
  recordIdempotency,
} from "../_shared/auth.ts";
import {
  internalError,
  rateLimitError,
  validationError,
} from "../_shared/errors.ts";
import { AuditAction, EdgeErrorCode } from "../_shared/types.ts";
import { ClaimPairRequestSchema } from "./schema.ts";

async function hashPairingCode(code: string): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(code);
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");
}

/**
 * Generate a long-lived device token.
 * Mock format: "device-token-<user_id>|<family_id>"
 * TODO: Replace with signed JWT containing user_id, family_id, issued_at, device_id.
 */
function generateDeviceToken(userId: string, familyId: string): string {
  // TODO: generate a real signed JWT for device auth
  return `device-token-${userId}|${familyId}`;
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  // --- Supabase client ---
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    { auth: { persistSession: false } },
  );

  // --- Rate limit: 3/60s keyed by X-Forwarded-For or fallback "anon" ---
  const clientIp = req.headers.get("X-Forwarded-For") ?? "anon";
  const rl = await checkRateLimit(supabase, clientIp, "user.claim-pair", 3, 60);
  if (!rl.allowed) {
    return rateLimitError(rl.retryAfterSeconds);
  }

  // --- Idempotency ---
  const idempotencyKey = req.headers.get("Idempotency-Key") ?? "";
  if (idempotencyKey) {
    const idem = await checkIdempotency(supabase, idempotencyKey, "user.claim-pair");
    if (idem.hit && idem.cachedResponse) {
      return new Response(JSON.stringify(idem.cachedResponse), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }
  }

  // --- Parse + validate body ---
  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return validationError("Request body must be valid JSON");
  }

  const parsed = ClaimPairRequestSchema.safeParse(body);
  if (!parsed.success) {
    return validationError("Validation failed", { issues: parsed.error.issues });
  }
  const data = parsed.data;

  // --- Hash the submitted code ---
  const codeHash = await hashPairingCode(data.pairing_code);

  // --- Look up kid by pairing code hash ---
  const { data: kid, error: kidErr } = await supabase
    .from("app_user")
    .select("id, family_id, role, display_name, avatar, color, complexity_tier, cached_balance, device_pairing_expires_at")
    .eq("device_pairing_code", codeHash)
    .eq("role", "child")
    .is("deleted_at", null)
    .single();

  if (kidErr || !kid) {
    // Don't leak whether code exists or is expired
    return new Response(
      JSON.stringify({ error: { code: EdgeErrorCode.Unauthorized, message: "Invalid or expired pairing code" } }),
      { status: 401, headers: { "Content-Type": "application/json" } },
    );
  }

  // --- Check expiry ---
  const expiresAt = new Date(kid.device_pairing_expires_at).getTime();
  if (Date.now() > expiresAt) {
    return new Response(
      JSON.stringify({ error: { code: EdgeErrorCode.Unauthorized, message: "Pairing code has expired" } }),
      { status: 401, headers: { "Content-Type": "application/json" } },
    );
  }

  // --- Fetch family ---
  const { data: family, error: familyErr } = await supabase
    .from("family")
    .select("id, name, timezone, leaderboard_enabled, sibling_ledger_visible")
    .eq("id", kid.family_id)
    .is("deleted_at", null)
    .single();

  if (familyErr || !family) {
    console.error("[user.claim-pair] family fetch error:", familyErr);
    return internalError();
  }

  // --- Clear pairing code (single-use) ---
  const { error: clearErr } = await supabase
    .from("app_user")
    .update({
      device_pairing_code: null,
      device_pairing_expires_at: null,
    })
    .eq("id", kid.id);

  if (clearErr) {
    console.error("[user.claim-pair] clear pairing code error:", clearErr);
    return internalError();
  }

  // --- Generate device token ---
  const deviceToken = generateDeviceToken(kid.id, kid.family_id);

  // --- Audit log ---
  await supabase.from("audit_log").insert({
    family_id: kid.family_id,
    actor_user_id: kid.id,
    action: AuditAction.AuthDevicePair,
    target: `app_user:${kid.id}`,
    payload: {
      device_name: data.device_name ?? null,
      client_ip: clientIp,
    },
  });

  const responseBody = {
    device_token: deviceToken,
    kid: {
      id: kid.id,
      family_id: kid.family_id,
      role: kid.role as "child",
      display_name: kid.display_name,
      avatar: kid.avatar,
      color: kid.color,
      complexity_tier: kid.complexity_tier,
      cached_balance: kid.cached_balance,
    },
    family: {
      id: family.id,
      name: family.name,
      timezone: family.timezone,
      leaderboard_enabled: family.leaderboard_enabled,
      sibling_ledger_visible: family.sibling_ledger_visible,
    },
  };

  if (idempotencyKey) {
    await recordIdempotency(supabase, idempotencyKey, "user.claim-pair", responseBody);
  }

  return new Response(JSON.stringify(responseBody), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
