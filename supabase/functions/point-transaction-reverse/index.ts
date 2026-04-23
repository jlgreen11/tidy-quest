/**
 * point-transaction.reverse
 * POST /functions/v1/point-transaction.reverse
 *
 * Auth:      Bearer (parent / caregiver)
 * Rate:      30/60s
 * Sensitive: Yes (App Attest always required)
 *
 * Creates a 'correction' point_transaction with the opposite sign of the original,
 * and sets reversed_by_transaction_id on the original via the privileged path.
 *
 * The actual update uses app.privileged_reversal_path session variable (see triggers
 * migration) to bypass the append-only trigger for setting that one column.
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { authenticateBearer, checkRateLimit, requireAppAttest, createServiceClient } from "../_shared/auth.ts";
import { errorResponse, internalError, validationError } from "../_shared/errors.ts";
import { EdgeErrorCode } from "../_shared/types.ts";
import { PointTransactionReverseRequest } from "./schema.ts";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, idempotency-key, x-app-attest",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS_HEADERS });
  if (req.method !== "POST") return errorResponse(405, "METHOD_NOT_ALLOWED", "Only POST is accepted");

  // App Attest always required for reversals
  const attestResult = await requireAppAttest(req);
  if (!attestResult.ok) return attestResult.response;

  const authResult = await authenticateBearer(req);
  if (!authResult.ok) return authResult.response;
  const { user } = authResult;

  if (!["parent", "caregiver"].includes(user.role)) {
    return errorResponse(403, EdgeErrorCode.Forbidden, "Only parents and caregivers can reverse transactions");
  }

  const rl = await checkRateLimit(createServiceClient(), user.id, "point-transaction.reverse", 30, 60);
  if (!rl.allowed) return errorResponse(429, EdgeErrorCode.RateLimitExceeded, "Rate limit exceeded");

  const idempotencyKey = req.headers.get("Idempotency-Key") ?? crypto.randomUUID();

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return validationError("Request body must be valid JSON");
  }

  const parsed = PointTransactionReverseRequest.safeParse(body);
  if (!parsed.success) return validationError("Invalid request body", { issues: parsed.error.issues });
  const { transaction_id, reason } = parsed.data;

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // Verify the original transaction belongs to this family
  const { data: origTxn, error: fetchErr } = await supabase
    .from("point_transaction")
    .select("id, family_id, user_id, amount, kind, reversed_by_transaction_id")
    .eq("id", transaction_id)
    .maybeSingle();

  if (fetchErr || !origTxn) {
    return errorResponse(404, EdgeErrorCode.NotFound, "Transaction not found");
  }
  if (origTxn.family_id !== user.family_id) {
    return errorResponse(403, EdgeErrorCode.Forbidden, "Transaction belongs to a different family");
  }

  // Idempotency: already reversed
  if (origTxn.reversed_by_transaction_id !== null) {
    const { data: corrTxn } = await supabase
      .from("point_transaction")
      .select("*")
      .eq("id", origTxn.reversed_by_transaction_id)
      .single();

    const { data: u } = await supabase
      .from("app_user")
      .select("cached_balance")
      .eq("id", origTxn.user_id)
      .single();

    return new Response(
      JSON.stringify({
        original_transaction_id:   transaction_id,
        correction_transaction_id: origTxn.reversed_by_transaction_id,
        correction_amount:         corrTxn?.amount,
        balance_after:             u?.cached_balance,
      }),
      { status: 200, headers: { "Content-Type": "application/json", ...CORS_HEADERS } },
    );
  }

  // Cannot reverse a correction
  if (origTxn.kind === "correction") {
    return errorResponse(409, EdgeErrorCode.Conflict, "Cannot reverse a correction transaction");
  }

  // Call atomic RPC
  const { data: result, error: rpcErr } = await supabase.rpc("atomic_point_transaction_reverse", {
    p_original_txn_id:    transaction_id,
    p_reverser_user_id:   user.id,
    p_idempotency_key:    idempotencyKey,
    p_reason:             reason ?? "Transaction reversed",
  });

  if (rpcErr) {
    console.error("point-transaction.reverse rpc error:", rpcErr);
    const msg = rpcErr.message ?? "";
    if (msg.includes("CONFLICT") || rpcErr.code === "23505") {
      return errorResponse(409, EdgeErrorCode.Conflict, "Transaction is already reversed");
    }
    if (msg.includes("NOT_FOUND")) {
      return errorResponse(404, EdgeErrorCode.NotFound, "Transaction not found");
    }
    return internalError();
  }

  return new Response(
    JSON.stringify(result),
    { status: 200, headers: { "Content-Type": "application/json", ...CORS_HEADERS } },
  );
});
