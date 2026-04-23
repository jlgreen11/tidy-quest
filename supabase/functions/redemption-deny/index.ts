/**
 * redemption.deny
 * POST /functions/v1/redemption.deny
 *
 * Auth:      Bearer (parent / caregiver)
 * Rate:      60/60s
 * Sensitive: No
 *
 * Sets redemption_request.status = 'denied'. No point_transaction is created.
 * Idempotent: denying an already-denied request returns 200.
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { authenticateBearer, checkRateLimit, createServiceClient } from "../_shared/auth.ts";
import { errorResponse, internalError, validationError } from "../_shared/errors.ts";
import { EdgeErrorCode } from "../_shared/types.ts";
import { RedemptionDenyRequest } from "./schema.ts";

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

  if (!["parent", "caregiver"].includes(user.role)) {
    return errorResponse(403, EdgeErrorCode.Forbidden, "Only parents and caregivers can deny redemptions");
  }

  const rl = await checkRateLimit(createServiceClient(), user.id, "redemption.deny", 60, 60);
  if (!rl.allowed) return errorResponse(429, EdgeErrorCode.RateLimitExceeded, "Rate limit exceeded");

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return validationError("Request body must be valid JSON");
  }

  const parsed = RedemptionDenyRequest.safeParse(body);
  if (!parsed.success) return validationError("Invalid request body", { issues: parsed.error.issues });
  const { request_id, reason } = parsed.data;

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: reqRow, error: fetchErr } = await supabase
    .from("redemption_request")
    .select("id, family_id, status, user_id, reward_id")
    .eq("id", request_id)
    .maybeSingle();

  if (fetchErr || !reqRow) {
    return errorResponse(404, EdgeErrorCode.NotFound, "Redemption request not found");
  }
  if (reqRow.family_id !== user.family_id) {
    return errorResponse(403, EdgeErrorCode.Forbidden, "Redemption request belongs to a different family");
  }

  // Idempotent
  if (reqRow.status === "denied") {
    const { data: existing } = await supabase
      .from("redemption_request")
      .select("*")
      .eq("id", request_id)
      .single();
    return new Response(
      JSON.stringify({ request: existing }),
      { status: 200, headers: { "Content-Type": "application/json", ...CORS_HEADERS } },
    );
  }

  if (reqRow.status !== "pending") {
    return errorResponse(409, EdgeErrorCode.Conflict,
      `Cannot deny redemption request with status '${reqRow.status}'`);
  }

  const { data: updated, error: updateErr } = await supabase
    .from("redemption_request")
    .update({
      status:              "denied",
      approved_by_user_id: user.id,
      approved_at:         new Date().toISOString(),
      notes:               reason ?? null,
    })
    .eq("id", request_id)
    .select()
    .single();

  if (updateErr) {
    console.error("redemption.deny update error:", updateErr);
    return internalError();
  }

  await supabase.from("audit_log").insert({
    family_id:     user.family_id,
    actor_user_id: user.id,
    action:        "redemption.deny",
    target:        `redemption_request:${request_id}`,
    payload: {
      event:      "redemption.deny",
      request_id,
      reward_id:  reqRow.reward_id,
      user_id:    reqRow.user_id,
      reason:     reason ?? null,
      denied_by:  user.id,
    },
  });

  return new Response(
    JSON.stringify({ request: updated }),
    { status: 200, headers: { "Content-Type": "application/json", ...CORS_HEADERS } },
  );
});
