/**
 * family.delete — POST (SENSITIVE)
 * Auth: Bearer (Apple JWT)
 * Sensitive: X-App-Attest required
 * Rate: 1 request per 86400 seconds (24h)
 *
 * Soft-deletes a family by setting deleted_at. Data is retained for 30 days
 * to allow recovery. The calling parent must belong to the family.
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
import { FamilyDeleteRequestSchema } from "./schema.ts";

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

  // --- Rate limit: 1/86400s per apple_sub ---
  const rl = await checkRateLimit(supabase, auth.apple_sub, "family.delete", 1, 86400);
  if (!rl.allowed) {
    return rateLimitError(rl.retryAfterSeconds);
  }

  // --- Idempotency ---
  const idempotencyKey = req.headers.get("Idempotency-Key") ?? "";
  if (idempotencyKey) {
    const idem = await checkIdempotency(supabase, idempotencyKey, "family.delete");
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

  const parsed = FamilyDeleteRequestSchema.safeParse(body);
  if (!parsed.success) {
    return validationError("Validation failed", { issues: parsed.error.issues });
  }
  const data = parsed.data;

  // --- Verify actor belongs to the family as a parent ---
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

  if (actor.role !== "parent") {
    return new Response(
      JSON.stringify({ error: { code: EdgeErrorCode.Forbidden, message: "Only parents may delete a family" } }),
      { status: 403, headers: { "Content-Type": "application/json" } },
    );
  }

  // --- Check family not already deleted ---
  const { data: family, error: familyErr } = await supabase
    .from("family")
    .select("id, name, deleted_at")
    .eq("id", data.family_id)
    .single();

  if (familyErr || !family) {
    console.error("[family.delete] family select error:", familyErr);
    return internalError();
  }

  if (family.deleted_at !== null) {
    return new Response(
      JSON.stringify({ error: { code: EdgeErrorCode.Conflict, message: "Family is already deleted" } }),
      { status: 409, headers: { "Content-Type": "application/json" } },
    );
  }

  // --- Soft delete ---
  const deletedAt = new Date().toISOString();
  const recoveryExpiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();

  const { error: updateErr } = await supabase
    .from("family")
    .update({ deleted_at: deletedAt })
    .eq("id", data.family_id);

  if (updateErr) {
    console.error("[family.delete] soft delete error:", updateErr);
    return internalError();
  }

  // --- Audit log ---
  await supabase.from("audit_log").insert({
    family_id: data.family_id,
    actor_user_id: actor.id,
    action: AuditAction.FamilyDelete,
    target: `family:${data.family_id}`,
    payload: {
      reason: data.reason ?? null,
      recovery_expires_at: recoveryExpiresAt,
    },
  });

  const responseBody = {
    deleted: true as const,
    family_id: data.family_id,
    deleted_at: deletedAt,
    recovery_expires_at: recoveryExpiresAt,
    message: "Family soft-deleted. Data retained for 30 days for recovery.",
  };

  if (idempotencyKey) {
    await recordIdempotency(supabase, idempotencyKey, "family.delete", responseBody);
  }

  return new Response(JSON.stringify(responseBody), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
