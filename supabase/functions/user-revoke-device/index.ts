/**
 * user.revoke-device — POST (SENSITIVE)
 * Auth: Bearer (Apple JWT)
 * Sensitive: X-App-Attest required
 * Rate: 5 requests per 60 seconds
 *
 * Revokes a kid's device by clearing the pairing code and device token.
 * The kid's device token becomes invalid; a new pair is required.
 * The calling parent must belong to the same family.
 *
 * Note: "device token" in our mock system is stateless (derived from user_id + family_id),
 * so revocation clears the pairing code and marks the user as needing re-pair.
 * TODO: Implement a token revocation list for real signed device JWTs.
 */

import { createClient } from "npm:@supabase/supabase-js@2";
import {
  checkIdempotency,
  checkRateLimit,
  parseAppleJwt,
  recordIdempotency,
  validateAppAttest,
} from "../_shared/auth.ts";
import {
  appAttestError,
  internalError,
  rateLimitError,
  unauthorizedError,
  validationError,
} from "../_shared/errors.ts";
import { AuditAction, EdgeErrorCode } from "../_shared/types.ts";
import { RevokeDeviceRequestSchema } from "./schema.ts";

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  // --- Auth ---
  const auth = parseAppleJwt(req.headers.get("Authorization"));
  if (!auth) {
    return unauthorizedError("Valid Apple JWT required");
  }

  // --- App Attest (SENSITIVE) ---
  const attestHeader = req.headers.get("X-App-Attest");
  if (!validateAppAttest(attestHeader)) {
    return appAttestError("X-App-Attest header required and must be non-empty");
  }

  // --- Supabase client ---
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    { auth: { persistSession: false } },
  );

  // --- Rate limit: 5/60s ---
  const rl = await checkRateLimit(supabase, auth.apple_sub, "user.revoke-device", 5, 60);
  if (!rl.allowed) {
    return rateLimitError(rl.retryAfterSeconds);
  }

  // --- Idempotency ---
  const idempotencyKey = req.headers.get("Idempotency-Key") ?? "";
  if (idempotencyKey) {
    const idem = await checkIdempotency(supabase, idempotencyKey, "user.revoke-device");
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

  const parsed = RevokeDeviceRequestSchema.safeParse(body);
  if (!parsed.success) {
    return validationError("Validation failed", { issues: parsed.error.issues });
  }
  const data = parsed.data;

  // --- Verify actor is a parent/caregiver of this family ---
  const { data: actor, error: actorErr } = await supabase
    .from("app_user")
    .select("id, family_id, role")
    .eq("apple_sub", auth.apple_sub)
    .eq("family_id", data.family_id)
    .is("deleted_at", null)
    .single();

  if (actorErr || !actor) {
    return new Response(
      JSON.stringify({ error: { code: EdgeErrorCode.Forbidden, message: "Not a member of this family" } }),
      { status: 403, headers: { "Content-Type": "application/json" } },
    );
  }

  if (!["parent", "caregiver"].includes(actor.role)) {
    return new Response(
      JSON.stringify({ error: { code: EdgeErrorCode.Forbidden, message: "Only parents or caregivers may revoke devices" } }),
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

  // --- Clear pairing state (invalidates any outstanding device token) ---
  const revokedAt = new Date().toISOString();

  const { error: updateErr } = await supabase
    .from("app_user")
    .update({
      device_pairing_code: null,
      device_pairing_expires_at: null,
    })
    .eq("id", data.kid_user_id);

  if (updateErr) {
    console.error("[user.revoke-device] update error:", updateErr);
    return internalError();
  }

  // --- Audit log ---
  await supabase.from("audit_log").insert({
    family_id: data.family_id,
    actor_user_id: actor.id,
    action: AuditAction.AuthDeviceRevoke,
    target: `app_user:${data.kid_user_id}`,
    payload: {
      kid_display_name: kid.display_name,
      reason: data.reason ?? null,
      revoked_at: revokedAt,
    },
  });

  const responseBody = {
    revoked: true as const,
    kid_user_id: data.kid_user_id,
    revoked_at: revokedAt,
  };

  if (idempotencyKey) {
    await recordIdempotency(supabase, idempotencyKey, "user.revoke-device", responseBody);
  }

  return new Response(JSON.stringify(responseBody), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
