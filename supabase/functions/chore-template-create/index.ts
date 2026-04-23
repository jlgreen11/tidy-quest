/**
 * chore-template.create
 * POST /functions/v1/chore-template.create
 *
 * Auth:      Bearer (parent / caregiver)
 * Rate:      30/60s
 * Sensitive: No
 *
 * Creates a new chore_template for the authenticated user's family.
 * Accepts an optional client-supplied UUIDv7; generates one server-side otherwise.
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { authenticateBearer, checkRateLimit, createServiceClient } from "../_shared/auth.ts";
import { errorResponse, internalError, validationError } from "../_shared/errors.ts";
import { EdgeErrorCode } from "../_shared/types.ts";
import { ChoreTemplateCreateRequest } from "./schema.ts";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, idempotency-key",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return errorResponse(405, "METHOD_NOT_ALLOWED", "Only POST is accepted");
  }

  // --- Auth ---
  const authResult = await authenticateBearer(req);
  if (!authResult.ok) return authResult.response;
  const { user } = authResult;

  // --- Rate limit ---
  const rl = await checkRateLimit(createServiceClient(), user.id, "chore-template.create", 30, 60);
  if (!rl.allowed) return errorResponse(429, EdgeErrorCode.RateLimitExceeded, "Rate limit exceeded", { retry_after_seconds: rl.retryAfter });

  // --- Idempotency key ---
  const idempotencyKey = req.headers.get("Idempotency-Key");

  // --- Parse & validate body ---
  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return validationError("Request body must be valid JSON");
  }

  const parsed = ChoreTemplateCreateRequest.safeParse(body);
  if (!parsed.success) {
    return validationError("Invalid request body", { issues: parsed.error.issues });
  }
  const data = parsed.data;

  // --- Supabase client (service role to bypass RLS for write) ---
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // --- Verify caller role permits template creation ---
  if (!["parent", "caregiver"].includes(user.role)) {
    return errorResponse(403, EdgeErrorCode.Forbidden, "Only parents and caregivers can create chore templates");
  }

  // --- Idempotency replay: check if a template with this key was already created ---
  if (idempotencyKey) {
    const { data: existing } = await supabase
      .from("chore_template")
      .select("*")
      .eq("family_id", user.family_id)
      .eq("name", data.name)         // best-effort; idempotency_key column not on this table
      .maybeSingle();
    // Note: chore_template has no idempotency_key column; caller-supplied id is the idempotency mechanism
  }

  // --- Insert ---
  const insertPayload: Record<string, unknown> = {
    family_id:         user.family_id,
    name:              data.name,
    icon:              data.icon,
    description:       data.description ?? null,
    type:              data.type,
    schedule:          data.schedule,
    target_user_ids:   data.target_user_ids,
    base_points:       data.base_points,
    cutoff_time:       data.cutoff_time ?? null,
    requires_photo:    data.requires_photo,
    requires_approval: data.requires_approval,
    on_miss:           data.on_miss,
    on_miss_amount:    data.on_miss_amount,
  };
  if (data.id) insertPayload.id = data.id;

  const { data: template, error: insertError } = await supabase
    .from("chore_template")
    .insert(insertPayload)
    .select()
    .single();

  if (insertError) {
    console.error("chore-template.create insert error:", insertError);
    if (insertError.code === "23505") {
      // Duplicate ID — replay
      const { data: existing } = await supabase
        .from("chore_template")
        .select("*")
        .eq("id", data.id!)
        .single();
      return new Response(JSON.stringify({ template: existing }), {
        status: 200,
        headers: { "Content-Type": "application/json", ...CORS_HEADERS },
      });
    }
    return internalError();
  }

  // --- Audit log ---
  await supabase.from("audit_log").insert({
    family_id:     user.family_id,
    actor_user_id: user.id,
    action:        "user.add",        // closest available; no 'chore_template.create' audit action
    target:        `chore_template:${template.id}`,
    payload: {
      event:       "chore_template.create",
      template_id: template.id,
      name:        template.name,
      type:        template.type,
      base_points: template.base_points,
    },
  });

  return new Response(JSON.stringify({ template }), {
    status: 201,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
  });
});
