/**
 * chore-template.archive
 * POST /functions/v1/chore-template.archive
 *
 * Auth:      Bearer (parent / caregiver)
 * Rate:      30/60s
 * Sensitive: No
 *
 * Soft-deletes a chore template by setting archived_at = now().
 * Idempotent: archiving an already-archived template returns 200 with existing archived_at.
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { authenticateBearer, checkRateLimit } from "../_shared/auth.ts";
import { errorResponse, internalError, validationError } from "../_shared/errors.ts";
import { EdgeErrorCode } from "../_shared/types.ts";
import { ChoreTemplateArchiveRequest } from "./schema.ts";

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

  const rl = await checkRateLimit(user.id, "chore-template.archive", 30);
  if (!rl.ok) return errorResponse(429, EdgeErrorCode.RateLimitExceeded, "Rate limit exceeded");

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return validationError("Request body must be valid JSON");
  }

  const parsed = ChoreTemplateArchiveRequest.safeParse(body);
  if (!parsed.success) return validationError("Invalid request body", { issues: parsed.error.issues });
  const { template_id } = parsed.data;

  if (!["parent", "caregiver"].includes(user.role)) {
    return errorResponse(403, EdgeErrorCode.Forbidden, "Only parents and caregivers can archive chore templates");
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // Fetch existing
  const { data: existing, error: fetchErr } = await supabase
    .from("chore_template")
    .select("id, family_id, archived_at")
    .eq("id", template_id)
    .maybeSingle();

  if (fetchErr || !existing) {
    return errorResponse(404, EdgeErrorCode.NotFound, "Chore template not found");
  }
  if (existing.family_id !== user.family_id) {
    return errorResponse(403, EdgeErrorCode.Forbidden, "Template belongs to a different family");
  }

  // Idempotent: already archived
  if (existing.archived_at !== null) {
    return new Response(
      JSON.stringify({ template_id, archived_at: existing.archived_at }),
      { status: 200, headers: { "Content-Type": "application/json", ...CORS_HEADERS } },
    );
  }

  const archivedAt = new Date().toISOString();
  const { error: updateErr } = await supabase
    .from("chore_template")
    .update({ archived_at: archivedAt, active: false })
    .eq("id", template_id);

  if (updateErr) {
    console.error("chore-template.archive update error:", updateErr);
    return internalError();
  }

  await supabase.from("audit_log").insert({
    family_id:     user.family_id,
    actor_user_id: user.id,
    action:        "user.remove",
    target:        `chore_template:${template_id}`,
    payload: {
      event:       "chore_template.archive",
      template_id,
      archived_at: archivedAt,
    },
  });

  return new Response(
    JSON.stringify({ template_id, archived_at: archivedAt }),
    { status: 200, headers: { "Content-Type": "application/json", ...CORS_HEADERS } },
  );
});
