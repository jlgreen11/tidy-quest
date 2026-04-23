/**
 * chore-instance.approve
 * POST /functions/v1/chore-instance.approve
 *
 * Auth:      Bearer (parent / caregiver)
 * Rate:      100/60s
 * Sensitive: No
 *
 * Atomically: update chore_instance status → 'approved' + insert point_transaction.
 * Idempotent: if already approved, returns the existing transaction.
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { authenticateBearer, checkRateLimit } from "../_shared/auth.ts";
import { errorResponse, internalError, validationError } from "../_shared/errors.ts";
import { EdgeErrorCode } from "../_shared/types.ts";
import { ChoreInstanceApproveRequest } from "./schema.ts";

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

  const rl = await checkRateLimit(user.id, "chore-instance.approve", 100);
  if (!rl.ok) return errorResponse(429, EdgeErrorCode.RateLimitExceeded, "Rate limit exceeded");

  if (!["parent", "caregiver"].includes(user.role)) {
    return errorResponse(403, EdgeErrorCode.Forbidden, "Only parents and caregivers can approve chores");
  }

  const idempotencyKey = req.headers.get("Idempotency-Key") ?? crypto.randomUUID();

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return validationError("Request body must be valid JSON");
  }

  const parsed = ChoreInstanceApproveRequest.safeParse(body);
  if (!parsed.success) return validationError("Invalid request body", { issues: parsed.error.issues });
  const data = parsed.data;

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // Fetch instance to verify family
  const { data: instance, error: fetchErr } = await supabase
    .from("chore_instance")
    .select("*, chore_template(family_id, name, base_points, requires_approval)")
    .eq("id", data.instance_id)
    .maybeSingle();

  if (fetchErr || !instance) {
    return errorResponse(404, EdgeErrorCode.InvalidInstance, "Chore instance not found");
  }

  const template = instance.chore_template as Record<string, unknown>;
  if (template.family_id !== user.family_id) {
    return errorResponse(403, EdgeErrorCode.Forbidden, "Chore instance belongs to a different family");
  }

  // Idempotency: already approved
  if (instance.status === "approved") {
    const { data: txn } = await supabase
      .from("point_transaction")
      .select("*")
      .eq("chore_instance_id", data.instance_id)
      .eq("kind", "chore_completion")
      .maybeSingle();

    const { data: u } = await supabase
      .from("app_user")
      .select("cached_balance")
      .eq("id", instance.user_id)
      .single();

    return new Response(
      JSON.stringify({ instance, transaction: txn, balance_after: u?.cached_balance }),
      { status: 200, headers: { "Content-Type": "application/json", ...CORS_HEADERS } },
    );
  }

  // Must be in 'completed' or 'pending' status to approve
  if (!["completed", "pending"].includes(instance.status)) {
    return errorResponse(409, EdgeErrorCode.ChoreAlreadyCompleted,
      `Cannot approve instance with status '${instance.status}'`);
  }

  // Call atomic RPC
  const { data: result, error: rpcErr } = await supabase.rpc("atomic_chore_instance_approve", {
    p_instance_id:      data.instance_id,
    p_approver_user_id: user.id,
    p_idempotency_key:  idempotencyKey,
  });

  if (rpcErr) {
    console.error("chore-instance.approve rpc error:", rpcErr);
    if (rpcErr.message?.includes("CHORE_ALREADY_COMPLETED") || rpcErr.code === "23505") {
      return errorResponse(409, EdgeErrorCode.ChoreAlreadyCompleted, "Chore already has a completion transaction");
    }
    return internalError();
  }

  const { data: finalInstance } = await supabase
    .from("chore_instance")
    .select("*")
    .eq("id", data.instance_id)
    .single();

  return new Response(
    JSON.stringify({
      instance:      finalInstance,
      transaction:   result,
      balance_after: (result as Record<string, unknown>)?.balance_after,
    }),
    { status: 200, headers: { "Content-Type": "application/json", ...CORS_HEADERS } },
  );
});
