/**
 * family.update — POST
 * Auth: Bearer (Apple JWT)
 * Rate: 10 requests per 60 seconds
 *
 * Partial update of family settings. Only supplied fields are written.
 * Actor must be a parent of the specified family.
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
import { EdgeErrorCode } from "../_shared/types.ts";
import { FamilyUpdateRequestSchema } from "./schema.ts";

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

  // --- Rate limit: 10/60s ---
  const rl = await checkRateLimit(supabase, auth.apple_sub, "family.update", 10, 60);
  if (!rl.allowed) {
    return rateLimitError(rl.retryAfterSeconds);
  }

  // --- Idempotency ---
  const idempotencyKey = req.headers.get("Idempotency-Key") ?? "";
  if (idempotencyKey) {
    const idem = await checkIdempotency(supabase, idempotencyKey, "family.update");
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

  const parsed = FamilyUpdateRequestSchema.safeParse(body);
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

  if (actor.role !== "parent" && actor.role !== "caregiver") {
    return new Response(
      JSON.stringify({ error: { code: EdgeErrorCode.Forbidden, message: "Only parents or caregivers may update family settings" } }),
      { status: 403, headers: { "Content-Type": "application/json" } },
    );
  }

  // --- Build update payload (only supplied fields) ---
  const updatePayload: Record<string, unknown> = {};
  if (data.name !== undefined) updatePayload.name = data.name;
  if (data.timezone !== undefined) updatePayload.timezone = data.timezone;
  if (data.daily_reset_time !== undefined) updatePayload.daily_reset_time = data.daily_reset_time;
  if (data.quiet_hours_start !== undefined) updatePayload.quiet_hours_start = data.quiet_hours_start;
  if (data.quiet_hours_end !== undefined) updatePayload.quiet_hours_end = data.quiet_hours_end;
  if (data.leaderboard_enabled !== undefined) updatePayload.leaderboard_enabled = data.leaderboard_enabled;
  if (data.sibling_ledger_visible !== undefined) updatePayload.sibling_ledger_visible = data.sibling_ledger_visible;
  if (data.weekly_band_target !== undefined) updatePayload.weekly_band_target = data.weekly_band_target;
  if (data.daily_deduction_cap !== undefined) updatePayload.daily_deduction_cap = data.daily_deduction_cap;
  if (data.weekly_deduction_cap !== undefined) updatePayload.weekly_deduction_cap = data.weekly_deduction_cap;

  // settings: merge-patch into existing jsonb (not replace).
  // Fetch current settings, merge, then write back.
  if (data.settings !== undefined) {
    const { data: currentFamily } = await supabase
      .from("family")
      .select("settings")
      .eq("id", data.family_id)
      .single();
    const existingSettings = (currentFamily?.settings ?? {}) as Record<string, unknown>;
    updatePayload.settings = { ...existingSettings, ...data.settings };
  }

  if (Object.keys(updatePayload).length === 0) {
    return validationError("At least one field must be provided for update");
  }

  // --- Perform update ---
  const { data: updatedFamily, error: updateErr } = await supabase
    .from("family")
    .update(updatePayload)
    .eq("id", data.family_id)
    .is("deleted_at", null)
    .select()
    .single();

  if (updateErr || !updatedFamily) {
    console.error("[family.update] update error:", updateErr);
    return internalError();
  }

  const responseBody = {
    family: {
      id: updatedFamily.id,
      name: updatedFamily.name,
      timezone: updatedFamily.timezone,
      daily_reset_time: updatedFamily.daily_reset_time,
      quiet_hours_start: updatedFamily.quiet_hours_start,
      quiet_hours_end: updatedFamily.quiet_hours_end,
      leaderboard_enabled: updatedFamily.leaderboard_enabled,
      sibling_ledger_visible: updatedFamily.sibling_ledger_visible,
      subscription_tier: updatedFamily.subscription_tier,
      subscription_expires_at: updatedFamily.subscription_expires_at,
      weekly_band_target: updatedFamily.weekly_band_target ?? null,
      daily_deduction_cap: updatedFamily.daily_deduction_cap,
      weekly_deduction_cap: updatedFamily.weekly_deduction_cap,
      settings: updatedFamily.settings,
      created_at: updatedFamily.created_at,
      deleted_at: updatedFamily.deleted_at,
    },
  };

  if (idempotencyKey) {
    await recordIdempotency(supabase, idempotencyKey, "family.update", responseBody);
  }

  return new Response(JSON.stringify(responseBody), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
