/**
 * user.update-kid — POST
 * Auth: Bearer (Apple JWT)
 * Rate: 30 requests per 60 seconds
 *
 * Partial update of a child app_user row (display_name, avatar, color, complexity_tier).
 * Actor must be a parent or caregiver of the same family as the kid.
 * Do NOT use this endpoint for role changes — use user-add-kid / user-revoke-device instead.
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
import { UpdateKidRequestSchema } from "./schema.ts";

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

  // --- Rate limit: 30/60s ---
  const rl = await checkRateLimit(supabase, auth.apple_sub, "user.update-kid", 30, 60);
  if (!rl.allowed) {
    return rateLimitError(rl.retryAfterSeconds);
  }

  // --- Idempotency ---
  const idempotencyKey = req.headers.get("Idempotency-Key") ?? "";
  if (idempotencyKey) {
    const idem = await checkIdempotency(supabase, idempotencyKey, "user.update-kid");
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

  const parsed = UpdateKidRequestSchema.safeParse(body);
  if (!parsed.success) {
    return validationError("Validation failed", { issues: parsed.error.issues });
  }
  const data = parsed.data;

  // --- Resolve the actor user ---
  const { data: actor, error: actorErr } = await supabase
    .from("app_user")
    .select("id, family_id, role")
    .eq("apple_sub", auth.apple_sub)
    .is("deleted_at", null)
    .single();

  if (actorErr || !actor) {
    return new Response(
      JSON.stringify({ error: { code: EdgeErrorCode.Forbidden, message: "Actor not found" } }),
      { status: 403, headers: { "Content-Type": "application/json" } },
    );
  }

  if (!["parent", "caregiver"].includes(actor.role)) {
    return new Response(
      JSON.stringify({ error: { code: EdgeErrorCode.Forbidden, message: "Only parents or caregivers may update kid profiles" } }),
      { status: 403, headers: { "Content-Type": "application/json" } },
    );
  }

  // --- Verify target is a child in the same family ---
  const { data: kid, error: kidFetchErr } = await supabase
    .from("app_user")
    .select("id, family_id, role")
    .eq("id", data.kid_user_id)
    .is("deleted_at", null)
    .single();

  if (kidFetchErr || !kid) {
    return new Response(
      JSON.stringify({ error: { code: EdgeErrorCode.NotFound, message: "Kid not found" } }),
      { status: 404, headers: { "Content-Type": "application/json" } },
    );
  }

  if (kid.family_id !== actor.family_id) {
    return new Response(
      JSON.stringify({ error: { code: EdgeErrorCode.Forbidden, message: "Kid is not in the same family" } }),
      { status: 403, headers: { "Content-Type": "application/json" } },
    );
  }

  if (kid.role !== "child") {
    return new Response(
      JSON.stringify({ error: { code: EdgeErrorCode.Forbidden, message: "Target user is not a child — role changes require user-add-kid or user-revoke-device" } }),
      { status: 403, headers: { "Content-Type": "application/json" } },
    );
  }

  // --- Build update payload (only supplied fields) ---
  const updatePayload: Record<string, unknown> = {};
  if (data.display_name !== undefined) updatePayload.display_name = data.display_name;
  if (data.avatar !== undefined) updatePayload.avatar = data.avatar;
  if (data.color !== undefined) updatePayload.color = data.color;
  if (data.complexity_tier !== undefined) updatePayload.complexity_tier = data.complexity_tier;

  if (Object.keys(updatePayload).length === 0) {
    return validationError("At least one field must be provided for update");
  }

  // --- Perform update ---
  const { data: updatedKid, error: updateErr } = await supabase
    .from("app_user")
    .update(updatePayload)
    .eq("id", data.kid_user_id)
    .is("deleted_at", null)
    .select()
    .single();

  if (updateErr || !updatedKid) {
    console.error("[user.update-kid] update error:", updateErr);
    return internalError();
  }

  // --- Audit log ---
  await supabase.from("audit_log").insert({
    family_id: actor.family_id,
    actor_user_id: actor.id,
    action: AuditAction.UserAdd,
    target: `app_user:${updatedKid.id}`,
    payload: {
      fields_updated: Object.keys(updatePayload),
    },
  });

  const responseBody = {
    user: {
      id: updatedKid.id,
      family_id: updatedKid.family_id,
      role: updatedKid.role,
      display_name: updatedKid.display_name,
      avatar: updatedKid.avatar,
      color: updatedKid.color,
      complexity_tier: updatedKid.complexity_tier,
      birthdate: updatedKid.birthdate ?? null,
      cached_balance: updatedKid.cached_balance,
      created_at: updatedKid.created_at,
      deleted_at: updatedKid.deleted_at ?? null,
    },
  };

  if (idempotencyKey) {
    await recordIdempotency(supabase, idempotencyKey, "user.update-kid", responseBody);
  }

  return new Response(JSON.stringify(responseBody), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
