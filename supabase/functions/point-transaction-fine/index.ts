/**
 * point-transaction.fine
 * POST /functions/v1/point-transaction.fine
 *
 * Auth:      Bearer (parent / caregiver)
 * Rate:      30/60s
 * Sensitive: Yes when amount > 25 (App Attest required)
 *
 * Issues a fine (negative point transaction) against a kid.
 * Enforces family.daily_deduction_cap and family.weekly_deduction_cap.
 * Requires at least one of: reason (free-text) or canned_reason_key.
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { authenticateBearer, checkRateLimit, requireAppAttest } from "../_shared/auth.ts";
import { errorResponse, internalError, validationError } from "../_shared/errors.ts";
import { EdgeErrorCode } from "../_shared/types.ts";
import { PointTransactionFineRequest } from "./schema.ts";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, idempotency-key, x-app-attest",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS_HEADERS });
  if (req.method !== "POST") return errorResponse(405, "METHOD_NOT_ALLOWED", "Only POST is accepted");

  // Parse body early so we can check amount before requiring App Attest
  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return validationError("Request body must be valid JSON");
  }

  const parsed = PointTransactionFineRequest.safeParse(body);
  if (!parsed.success) return validationError("Invalid request body", { issues: parsed.error.issues });
  const data = parsed.data;

  // App Attest required when amount > 25
  if (data.amount > 25) {
    const attestResult = await requireAppAttest(req);
    if (!attestResult.ok) return attestResult.response;
  }

  const authResult = await authenticateBearer(req);
  if (!authResult.ok) return authResult.response;
  const { user } = authResult;

  if (!["parent", "caregiver"].includes(user.role)) {
    return errorResponse(403, EdgeErrorCode.Forbidden, "Only parents and caregivers can issue fines");
  }

  const rl = await checkRateLimit(user.id, "point-transaction.fine", 30);
  if (!rl.ok) return errorResponse(429, EdgeErrorCode.RateLimitExceeded, "Rate limit exceeded");

  const idempotencyKey = req.headers.get("Idempotency-Key") ?? crypto.randomUUID();

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // Verify the target user is in the same family
  const { data: targetUser, error: userErr } = await supabase
    .from("app_user")
    .select("id, family_id, role, display_name")
    .eq("id", data.user_id)
    .maybeSingle();

  if (userErr || !targetUser) {
    return errorResponse(404, EdgeErrorCode.NotFound, "User not found");
  }
  if (targetUser.family_id !== user.family_id) {
    return errorResponse(403, EdgeErrorCode.Forbidden, "User belongs to a different family");
  }
  if (targetUser.role !== "child") {
    return errorResponse(400, EdgeErrorCode.InvalidInput, "Fines can only be issued to children");
  }

  // Fetch family timezone for cap calculations
  const { data: family } = await supabase
    .from("family")
    .select("timezone")
    .eq("id", user.family_id)
    .single();

  const timezone = family?.timezone ?? "UTC";

  // Call atomic RPC (handles cap checks and insertion)
  const { data: result, error: rpcErr } = await supabase.rpc("atomic_point_transaction_fine", {
    p_user_id:            data.user_id,
    p_amount:             data.amount,
    p_reason:             data.reason ?? null,
    p_canned_reason_key:  data.canned_reason_key ?? null,
    p_created_by_user_id: user.id,
    p_idempotency_key:    idempotencyKey,
    p_family_timezone:    timezone,
  });

  if (rpcErr) {
    console.error("point-transaction.fine rpc error:", rpcErr);
    const msg = rpcErr.message ?? "";
    if (msg.includes("DAILY_DEDUCTION_CAP_EXCEEDED")) {
      return errorResponse(409, EdgeErrorCode.DailyDeductionCapExceeded,
        "Daily deduction cap would be exceeded by this fine");
    }
    if (msg.includes("WEEKLY_DEDUCTION_CAP_EXCEEDED")) {
      return errorResponse(409, EdgeErrorCode.WeeklyDeductionCapExceeded,
        "Weekly deduction cap would be exceeded by this fine");
    }
    if (rpcErr.code === "23505") {
      // Duplicate idempotency key — replay
      return errorResponse(409, EdgeErrorCode.Conflict, "Duplicate idempotency key");
    }
    return internalError();
  }

  return new Response(
    JSON.stringify({
      transaction:   result,
      balance_after: (result as Record<string, unknown>)?.balance_after,
    }),
    { status: 201, headers: { "Content-Type": "application/json", ...CORS_HEADERS } },
  );
});
