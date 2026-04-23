/**
 * chore-template.update
 * POST /functions/v1/chore-template.update
 *
 * Auth:      Bearer (parent / caregiver)
 * Rate:      60/60s
 * Sensitive: No
 *
 * PATCH-semantics: only supplied fields are updated.
 * Archived templates cannot be updated.
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { authenticateBearer, checkRateLimit, createServiceClient } from "../_shared/auth.ts";
import { errorResponse, internalError, validationError } from "../_shared/errors.ts";
import { EdgeErrorCode } from "../_shared/types.ts";
import { ChoreTemplateUpdateRequest } from "./schema.ts";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, idempotency-key",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS_HEADERS });
  if (req.method !== "POST") return errorResponse(405, "METHOD_NOT_ALLOWED", "Only POST is accepted");

  const authResult = await authenticateBearer(req);
  if (!authResult.ok) return authResult.response;
  const { user } = authResult;

  const rl = await checkRateLimit(createServiceClient(), user.id, "chore-template.update", 60, 60);
  if (!rl.allowed) return errorResponse(429, EdgeErrorCode.RateLimitExceeded, "Rate limit exceeded");

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return validationError("Request body must be valid JSON");
  }

  const parsed = ChoreTemplateUpdateRequest.safeParse(body);
  if (!parsed.success) return validationError("Invalid request body", { issues: parsed.error.issues });
  const data = parsed.data;

  if (!["parent", "caregiver"].includes(user.role)) {
    return errorResponse(403, EdgeErrorCode.Forbidden, "Only parents and caregivers can update chore templates");
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // Fetch existing to verify ownership and not archived
  const { data: existing, error: fetchErr } = await supabase
    .from("chore_template")
    .select("id, family_id, archived_at")
    .eq("id", data.template_id)
    .maybeSingle();

  if (fetchErr || !existing) {
    return errorResponse(404, EdgeErrorCode.NotFound, "Chore template not found");
  }
  if (existing.family_id !== user.family_id) {
    return errorResponse(403, EdgeErrorCode.Forbidden, "Template belongs to a different family");
  }
  if (existing.archived_at !== null) {
    return errorResponse(409, EdgeErrorCode.Conflict, "Archived templates cannot be updated");
  }

  // Build update payload (exclude template_id)
  const { template_id, ...rest } = data;
  const updatePayload: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(rest)) {
    if (v !== undefined) updatePayload[k] = v;
  }

  const { data: updated, error: updateErr } = await supabase
    .from("chore_template")
    .update(updatePayload)
    .eq("id", data.template_id)
    .select()
    .single();

  if (updateErr) {
    console.error("chore-template.update error:", updateErr);
    return internalError();
  }

  await supabase.from("audit_log").insert({
    family_id:     user.family_id,
    actor_user_id: user.id,
    action:        "user.add",
    target:        `chore_template:${data.template_id}`,
    payload: {
      event:       "chore_template.update",
      template_id: data.template_id,
      changes:     updatePayload,
    },
  });

  return new Response(JSON.stringify({ template: updated }), {
    status: 200,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
  });
});
