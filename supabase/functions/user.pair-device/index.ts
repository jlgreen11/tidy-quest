/**
 * user.pair-device — POST
 * Auth: Bearer (Apple JWT)
 * Rate: 3 requests per 60 seconds
 *
 * Generates a 10-character alphanumeric pairing code for a kid device.
 * Excludes confusable characters: 0, O, 1, I, l.
 * Code is single-use with a 10-minute TTL.
 * Stores the SHA-256 hash in app_user.device_pairing_code.
 */

import { createClient } from "npm:@supabase/supabase-js@2";
import {
  checkIdempotency,
  checkRateLimit,
  parseAppleJwt,
  recordIdempotency,
} from "../_shared/auth.ts";
import {
  internalError,
  rateLimitError,
  unauthorizedError,
  validationError,
} from "../_shared/errors.ts";
import { AuditAction, EdgeErrorCode } from "../_shared/types.ts";
import { PairDeviceRequestSchema } from "./schema.ts";

// ---------------------------------------------------------------------------
// Pairing code generation
// Alphabet excludes confusable characters: 0, O, 1, I, l
// ---------------------------------------------------------------------------
const PAIRING_ALPHABET = "23456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz";
const PAIRING_CODE_LENGTH = 10;
const PAIRING_TTL_MS = 10 * 60 * 1000; // 10 minutes

function generatePairingCode(): string {
  const bytes = new Uint8Array(PAIRING_CODE_LENGTH);
  crypto.getRandomValues(bytes);
  return Array.from(bytes)
    .map((b) => PAIRING_ALPHABET[b % PAIRING_ALPHABET.length])
    .join("");
}

async function hashPairingCode(code: string): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(code);
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  // --- Auth ---
  const auth = parseAppleJwt(req.headers.get("Authorization"));
  if (!auth) {
    return unauthorizedError("Valid Apple JWT required");
  }

  // --- Supabase client ---
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    { auth: { persistSession: false } },
  );

  // --- Rate limit: 3/60s ---
  const rl = await checkRateLimit(supabase, auth.apple_sub, "user.pair-device", 3, 60);
  if (!rl.allowed) {
    return rateLimitError(rl.retryAfterSeconds);
  }

  // --- Idempotency ---
  const idempotencyKey = req.headers.get("Idempotency-Key") ?? "";
  if (idempotencyKey) {
    const idem = await checkIdempotency(supabase, idempotencyKey, "user.pair-device");
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

  const parsed = PairDeviceRequestSchema.safeParse(body);
  if (!parsed.success) {
    return validationError("Validation failed", { issues: parsed.error.issues });
  }
  const data = parsed.data;

  // --- Verify actor is a parent of this family ---
  const { data: actor, error: actorErr } = await supabase
    .from("app_user")
    .select("id, family_id, role")
    .eq("apple_sub", auth.apple_sub)
    .eq("family_id", data.family_id)
    .is("deleted_at", null)
    .single();

  if (actorErr || !actor) {
    return new Response(
      JSON.stringify({ error: { code: EdgeErrorCode.Forbidden, message: "Not a parent of this family" } }),
      { status: 403, headers: { "Content-Type": "application/json" } },
    );
  }

  if (!["parent", "caregiver"].includes(actor.role)) {
    return new Response(
      JSON.stringify({ error: { code: EdgeErrorCode.Forbidden, message: "Only parents or caregivers may pair kid devices" } }),
      { status: 403, headers: { "Content-Type": "application/json" } },
    );
  }

  // --- Verify target kid belongs to this family ---
  const { data: kid, error: kidErr } = await supabase
    .from("app_user")
    .select("id, family_id, role, display_name")
    .eq("id", data.kid_user_id)
    .eq("family_id", data.family_id)
    .eq("role", "child")
    .is("deleted_at", null)
    .single();

  if (kidErr || !kid) {
    return new Response(
      JSON.stringify({ error: { code: EdgeErrorCode.NotFound, message: "Kid not found in this family" } }),
      { status: 404, headers: { "Content-Type": "application/json" } },
    );
  }

  // --- Generate pairing code ---
  const pairingCode = generatePairingCode();
  const pairingCodeHash = await hashPairingCode(pairingCode);
  const expiresAt = new Date(Date.now() + PAIRING_TTL_MS).toISOString();

  // --- Store hash on app_user row ---
  const { error: updateErr } = await supabase
    .from("app_user")
    .update({
      device_pairing_code: pairingCodeHash,
      device_pairing_expires_at: expiresAt,
    })
    .eq("id", data.kid_user_id);

  if (updateErr) {
    console.error("[user.pair-device] update error:", updateErr);
    return internalError();
  }

  // --- Audit log ---
  await supabase.from("audit_log").insert({
    family_id: data.family_id,
    actor_user_id: actor.id,
    action: AuditAction.AuthDevicePair,
    target: `app_user:${data.kid_user_id}`,
    payload: {
      kid_display_name: kid.display_name,
      expires_at: expiresAt,
    },
  });

  const responseBody = {
    pairing_code: pairingCode,
    expires_at: expiresAt,
    kid_user_id: data.kid_user_id,
  };

  if (idempotencyKey) {
    await recordIdempotency(supabase, idempotencyKey, "user.pair-device", responseBody);
  }

  return new Response(JSON.stringify(responseBody), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
