/**
 * chore-instance.reject
 * POST /functions/v1/chore-instance.reject
 *
 * Auth:      Bearer (parent / caregiver)
 * Rate:      100/60s
 * Sensitive: No
 *
 * Sets chore_instance.status = 'rejected'. No point_transaction is created.
 * Idempotent: rejecting an already-rejected instance returns 200.
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { authenticateBearer, checkRateLimit } from "../_shared/auth.ts";
import { errorResponse, internalError, validationError } from "../_shared/errors.ts";
import { EdgeErrorCode } from "../_shared/types.ts";
import { ChoreInstanceRejectRequest } from "./schema.ts";

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

  const rl = await checkRateLimit(user.id, "chore-instance.reject", 100);
  if (!rl.ok) return errorResponse(429, EdgeErrorCode.RateLimitExceeded, "Rate limit exceeded");

  if (!["parent", "caregiver"].includes(user.role)) {
    return errorResponse(403, EdgeErrorCode.Forbidden, "Only parents and caregivers can reject chores");
  }

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return validationError("Request body must be valid JSON");
  }

  const parsed = ChoreInstanceRejectRequest.safeParse(body);
  if (!parsed.success) return validationError("Invalid request body", { issues: parsed.error.issues });
  const data = parsed.data;

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: instance, error: fetchErr } = await supabase
    .from("chore_instance")
    .select("*, chore_template(family_id)")
    .eq("id", data.instance_id)
    .maybeSingle();

  if (fetchErr || !instance) {
    return errorResponse(404, EdgeErrorCode.InvalidInstance, "Chore instance not found");
  }

  const template = instance.chore_template as Record<string, unknown>;
  if (template.family_id !== user.family_id) {
    return errorResponse(403, EdgeErrorCode.Forbidden, "Chore instance belongs to a different family");
  }

  // Idempotent
  if (instance.status === "rejected") {
    return new Response(
      JSON.stringify({ instance }),
      { status: 200, headers: { "Content-Type": "application/json", ...CORS_HEADERS } },
    );
  }

  // Can only reject 'completed' or 'pending' instances
  if (!["completed", "pending"].includes(instance.status)) {
    return errorResponse(409, EdgeErrorCode.Conflict,
      `Cannot reject instance with status '${instance.status}'`);
  }

  const { data: updated, error: updateErr } = await supabase
    .from("chore_instance")
    .update({ status: "rejected" })
    .eq("id", data.instance_id)
    .select()
    .single();

  if (updateErr) {
    console.error("chore-instance.reject update error:", updateErr);
    return internalError();
  }

  await supabase.from("audit_log").insert({
    family_id:     user.family_id,
    actor_user_id: user.id,
    action:        "user.role_change",
    target:        `chore_instance:${data.instance_id}`,
    payload: {
      event:       "chore_instance.reject",
      instance_id: data.instance_id,
      reason:      data.reason ?? null,
      rejected_by: user.id,
    },
  });

  return new Response(
    JSON.stringify({ instance: updated }),
    { status: 200, headers: { "Content-Type": "application/json", ...CORS_HEADERS } },
  );
});
