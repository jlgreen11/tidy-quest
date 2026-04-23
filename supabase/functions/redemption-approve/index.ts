/**
 * redemption.approve
 * POST /functions/v1/redemption.approve
 *
 * Auth:      Bearer (parent / caregiver)
 * Rate:      60/60s
 * Sensitive: Yes (App Attest required)
 *
 * ATOMIC TRANSACTION via atomic_redemption_approve() Postgres RPC:
 *   1. SELECT redemption_request FOR UPDATE
 *   2. Verify status = 'pending'
 *   3. Verify balance >= reward.price
 *   4. Verify reward cooldown respected
 *   5. INSERT point_transaction (amount = -price, kind = 'redemption')
 *   6. UPDATE redemption_request SET status = 'fulfilled', resulting_transaction_id
 *   7. INSERT audit_log
 *   Any failure → auto-ROLLBACK (Postgres function transaction boundary)
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { authenticateBearer, checkRateLimit, requireAppAttest, createServiceClient } from "../_shared/auth.ts";
import { errorResponse, internalError, validationError } from "../_shared/errors.ts";
import { EdgeErrorCode } from "../_shared/types.ts";
import { RedemptionApproveRequest } from "./schema.ts";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, idempotency-key, x-app-attest",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS_HEADERS });
  if (req.method !== "POST") return errorResponse(405, "METHOD_NOT_ALLOWED", "Only POST is accepted");

  // --- App Attest (SENSITIVE) ---
  const attestResult = await requireAppAttest(req);
  if (!attestResult.ok) return attestResult.response;

  // --- Auth ---
  const authResult = await authenticateBearer(req);
  if (!authResult.ok) return authResult.response;
  const { user } = authResult;

  if (!["parent", "caregiver"].includes(user.role)) {
    return errorResponse(403, EdgeErrorCode.Forbidden, "Only parents and caregivers can approve redemptions");
  }

  const rl = await checkRateLimit(createServiceClient(), user.id, "redemption.approve", 60, 60);
  if (!rl.allowed) return errorResponse(429, EdgeErrorCode.RateLimitExceeded, "Rate limit exceeded");

  const idempotencyKey = req.headers.get("Idempotency-Key") ?? crypto.randomUUID();

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return validationError("Request body must be valid JSON");
  }

  const parsed = RedemptionApproveRequest.safeParse(body);
  if (!parsed.success) return validationError("Invalid request body", { issues: parsed.error.issues });
  const { request_id } = parsed.data;

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // Verify the redemption request belongs to this family before calling RPC
  const { data: reqRow, error: fetchErr } = await supabase
    .from("redemption_request")
    .select("id, family_id, status, resulting_transaction_id")
    .eq("id", request_id)
    .maybeSingle();

  if (fetchErr || !reqRow) {
    return errorResponse(404, EdgeErrorCode.NotFound, "Redemption request not found");
  }
  if (reqRow.family_id !== user.family_id) {
    return errorResponse(403, EdgeErrorCode.Forbidden, "Redemption request belongs to a different family");
  }

  // Idempotency: already fulfilled
  if (reqRow.status === "fulfilled") {
    const { data: txn } = await supabase
      .from("point_transaction")
      .select("*")
      .eq("id", reqRow.resulting_transaction_id)
      .maybeSingle();

    const { data: updatedReq } = await supabase
      .from("redemption_request")
      .select("*")
      .eq("id", request_id)
      .single();

    const { data: u } = await supabase
      .from("app_user")
      .select("cached_balance")
      .eq("id", updatedReq?.user_id)
      .single();

    return new Response(
      JSON.stringify({ request: updatedReq, transaction: txn, balance_after: u?.cached_balance }),
      { status: 200, headers: { "Content-Type": "application/json", ...CORS_HEADERS } },
    );
  }

  if (reqRow.status !== "pending") {
    return errorResponse(409, EdgeErrorCode.Conflict,
      `Cannot approve redemption request with status '${reqRow.status}'`);
  }

  // --- ATOMIC RPC call ---
  const { data: result, error: rpcErr } = await supabase.rpc("atomic_redemption_approve", {
    p_request_id:       request_id,
    p_approver_user_id: user.id,
    p_idempotency_key:  idempotencyKey,
  });

  if (rpcErr) {
    console.error("redemption.approve rpc error:", rpcErr);
    const msg = rpcErr.message ?? "";
    if (msg.includes("INSUFFICIENT_BALANCE")) {
      return errorResponse(409, EdgeErrorCode.InsufficientBalance, "Kid's balance is insufficient for this reward");
    }
    if (msg.includes("REWARD_UNAVAILABLE")) {
      return errorResponse(409, EdgeErrorCode.RewardUnavailable, "Reward is not available");
    }
    if (msg.includes("COOLDOWN_ACTIVE")) {
      return errorResponse(409, EdgeErrorCode.CooldownActive, "Reward cooldown is still active");
    }
    if (msg.includes("CONFLICT")) {
      return errorResponse(409, EdgeErrorCode.Conflict, "Redemption request is no longer pending");
    }
    return internalError();
  }

  // Fetch final state of request and transaction
  const { data: finalReq } = await supabase
    .from("redemption_request")
    .select("*")
    .eq("id", request_id)
    .single();

  const { data: txn } = await supabase
    .from("point_transaction")
    .select("*")
    .eq("id", (result as Record<string, unknown>)?.transaction_id)
    .maybeSingle();

  return new Response(
    JSON.stringify({
      request:      finalReq,
      transaction:  txn,
      balance_after: (result as Record<string, unknown>)?.balance_after,
    }),
    { status: 200, headers: { "Content-Type": "application/json", ...CORS_HEADERS } },
  );
});
