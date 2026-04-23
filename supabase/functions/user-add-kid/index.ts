/**
 * user.add-kid — POST
 * Auth: Bearer (Apple JWT)
 * Rate: 5 requests per 60 seconds
 *
 * Creates a child app_user row in the specified family.
 * The calling user must be a parent or caregiver of that family.
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
import { AddKidRequestSchema } from "./schema.ts";

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

  // --- Rate limit: 5/60s ---
  const rl = await checkRateLimit(supabase, auth.apple_sub, "user.add-kid", 5, 60);
  if (!rl.allowed) {
    return rateLimitError(rl.retryAfterSeconds);
  }

  // --- Idempotency ---
  const idempotencyKey = req.headers.get("Idempotency-Key") ?? "";
  if (idempotencyKey) {
    const idem = await checkIdempotency(supabase, idempotencyKey, "user.add-kid");
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

  const parsed = AddKidRequestSchema.safeParse(body);
  if (!parsed.success) {
    return validationError("Validation failed", { issues: parsed.error.issues });
  }
  const data = parsed.data;

  // --- Verify actor belongs to family with allowed role ---
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
      JSON.stringify({ error: { code: EdgeErrorCode.Forbidden, message: "Only parents or caregivers may add kids" } }),
      { status: 403, headers: { "Content-Type": "application/json" } },
    );
  }

  // --- Insert child app_user ---
  const kidInsert: Record<string, unknown> = {
    family_id: data.family_id,
    role: "child",
    display_name: data.display_name,
    avatar: data.avatar,
    color: data.color,
    complexity_tier: data.complexity_tier ?? "standard",
  };
  if (data.id) kidInsert.id = data.id;
  if (data.birthdate) kidInsert.birthdate = data.birthdate;

  const { data: kid, error: kidErr } = await supabase
    .from("app_user")
    .insert(kidInsert)
    .select()
    .single();

  if (kidErr || !kid) {
    console.error("[user.add-kid] insert error:", kidErr);
    return internalError();
  }

  // --- Audit log ---
  await supabase.from("audit_log").insert({
    family_id: data.family_id,
    actor_user_id: actor.id,
    action: AuditAction.UserAdd,
    target: `app_user:${kid.id}`,
    payload: {
      display_name: kid.display_name,
      role: "child",
    },
  });

  const responseBody = {
    kid: {
      id: kid.id,
      family_id: kid.family_id,
      role: kid.role as "child",
      display_name: kid.display_name,
      avatar: kid.avatar,
      color: kid.color,
      complexity_tier: kid.complexity_tier,
      birthdate: kid.birthdate ?? null,
      cached_balance: kid.cached_balance,
      created_at: kid.created_at,
      deleted_at: kid.deleted_at ?? null,
    },
  };

  if (idempotencyKey) {
    await recordIdempotency(supabase, idempotencyKey, "user.add-kid", responseBody);
  }

  return new Response(JSON.stringify(responseBody), {
    status: 201,
    headers: { "Content-Type": "application/json" },
  });
});
