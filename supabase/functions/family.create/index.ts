/**
 * family.create — POST
 * Auth: Bearer (Apple JWT)
 * Rate: 1 request per 60 seconds per user
 *
 * Creates a new family and the calling parent's app_user row atomically.
 * The apple_sub claim from the JWT is stored on the app_user row.
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
import { AuditAction } from "../_shared/types.ts";
import { FamilyCreateRequestSchema } from "./schema.ts";

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  // --- Auth ---
  const auth = parseAppleJwt(req.headers.get("Authorization"));
  if (!auth) {
    return unauthorizedError("Valid Apple JWT required");
  }

  // --- Supabase client (service role) ---
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    { auth: { persistSession: false } },
  );

  // --- Rate limit: 1/60s per apple_sub ---
  const rl = await checkRateLimit(supabase, auth.apple_sub, "family.create", 1, 60);
  if (!rl.allowed) {
    return rateLimitError(rl.retryAfterSeconds);
  }

  // --- Idempotency ---
  const idempotencyKey = req.headers.get("Idempotency-Key") ?? "";
  if (idempotencyKey) {
    const idem = await checkIdempotency(supabase, idempotencyKey, "family.create");
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

  const parsed = FamilyCreateRequestSchema.safeParse(body);
  if (!parsed.success) {
    return validationError("Validation failed", {
      issues: parsed.error.issues,
    });
  }
  const data = parsed.data;

  // --- Check apple_sub not already in use ---
  const { data: existingUser } = await supabase
    .from("app_user")
    .select("id, family_id")
    .eq("apple_sub", auth.apple_sub)
    .is("deleted_at", null)
    .single();

  if (existingUser) {
    return new Response(
      JSON.stringify({
        error: {
          code: "CONFLICT",
          message: "A family already exists for this Apple account",
          details: { existing_family_id: existingUser.family_id },
        },
      }),
      { status: 409, headers: { "Content-Type": "application/json" } },
    );
  }

  // --- Create family ---
  const familyInsert: Record<string, unknown> = {
    name: data.name,
    timezone: data.timezone,
  };
  if (data.id) familyInsert.id = data.id;
  if (data.daily_reset_time) familyInsert.daily_reset_time = data.daily_reset_time;
  if (data.quiet_hours_start) familyInsert.quiet_hours_start = data.quiet_hours_start;
  if (data.quiet_hours_end) familyInsert.quiet_hours_end = data.quiet_hours_end;
  if (data.leaderboard_enabled !== undefined) {
    familyInsert.leaderboard_enabled = data.leaderboard_enabled;
  }
  if (data.sibling_ledger_visible !== undefined) {
    familyInsert.sibling_ledger_visible = data.sibling_ledger_visible;
  }
  if (data.settings) familyInsert.settings = data.settings;

  const { data: family, error: familyErr } = await supabase
    .from("family")
    .insert(familyInsert)
    .select()
    .single();

  if (familyErr || !family) {
    console.error("[family.create] family insert error:", familyErr);
    return internalError();
  }

  // --- Create parent app_user ---
  const { data: parentUser, error: userErr } = await supabase
    .from("app_user")
    .insert({
      family_id: family.id,
      role: "parent",
      display_name: data.name + " Parent",  // client can update via family.update
      avatar: "person.fill",
      color: "#4D96FF",
      complexity_tier: "standard",
      apple_sub: auth.apple_sub,
    })
    .select()
    .single();

  if (userErr || !parentUser) {
    console.error("[family.create] parent user insert error:", userErr);
    // Attempt rollback
    await supabase.from("family").delete().eq("id", family.id);
    return internalError();
  }

  // --- Audit log ---
  await supabase.from("audit_log").insert({
    family_id: family.id,
    actor_user_id: parentUser.id,
    action: AuditAction.FamilyCreate,
    target: `family:${family.id}`,
    payload: { family_name: family.name },
  });

  // --- Build response ---
  const responseBody = {
    family: {
      id: family.id,
      name: family.name,
      timezone: family.timezone,
      daily_reset_time: family.daily_reset_time,
      quiet_hours_start: family.quiet_hours_start,
      quiet_hours_end: family.quiet_hours_end,
      leaderboard_enabled: family.leaderboard_enabled,
      sibling_ledger_visible: family.sibling_ledger_visible,
      subscription_tier: family.subscription_tier,
      subscription_expires_at: family.subscription_expires_at,
      daily_deduction_cap: family.daily_deduction_cap,
      weekly_deduction_cap: family.weekly_deduction_cap,
      settings: family.settings,
      created_at: family.created_at,
      deleted_at: family.deleted_at,
    },
    parent_user: {
      id: parentUser.id,
      family_id: parentUser.family_id,
      role: parentUser.role,
      display_name: parentUser.display_name,
      avatar: parentUser.avatar,
      color: parentUser.color,
      complexity_tier: parentUser.complexity_tier,
      created_at: parentUser.created_at,
    },
  };

  if (idempotencyKey) {
    await recordIdempotency(supabase, idempotencyKey, "family.create", responseBody);
  }

  return new Response(JSON.stringify(responseBody), {
    status: 201,
    headers: { "Content-Type": "application/json" },
  });
});
