/**
 * chore-instance.complete
 * POST /functions/v1/chore-instance.complete
 *
 * Auth:      Bearer (parent/caregiver completing on behalf) OR Device (kid)
 * Rate:      20/60s
 * Sensitive: No
 *
 * Marks a chore_instance as completed.
 * - If template.requires_approval: status → 'completed' (no transaction yet)
 * - Else: status → 'approved', awarded_points set, point_transaction inserted
 *
 * Idempotency-Key header is honoured.
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { authenticateBearer, authenticateDevice, checkRateLimit } from "../_shared/auth.ts";
import { errorResponse, internalError, validationError } from "../_shared/errors.ts";
import { EdgeErrorCode } from "../_shared/types.ts";
import { ChoreInstanceCompleteRequest } from "./schema.ts";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, idempotency-key, x-device-token",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS_HEADERS });
  if (req.method !== "POST") return errorResponse(405, "METHOD_NOT_ALLOWED", "Only POST is accepted");

  // --- Auth: try Bearer first, fall back to Device ---
  let user: { id: string; family_id: string; role: string } | null = null;
  let authMode: "bearer" | "device" = "bearer";

  const bearerResult = await authenticateBearer(req);
  if (bearerResult.ok) {
    user = bearerResult.user;
  } else {
    const deviceResult = await authenticateDevice(req);
    if (!deviceResult.ok) return deviceResult.response;
    user = deviceResult.user;
    authMode = "device";
  }

  const rl = await checkRateLimit(user.id, "chore-instance.complete", 20);
  if (!rl.ok) return errorResponse(429, EdgeErrorCode.RateLimitExceeded, "Rate limit exceeded");

  const idempotencyKey = req.headers.get("Idempotency-Key");

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return validationError("Request body must be valid JSON");
  }

  const parsed = ChoreInstanceCompleteRequest.safeParse(body);
  if (!parsed.success) return validationError("Invalid request body", { issues: parsed.error.issues });
  const data = parsed.data;

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // --- Fetch instance with FOR UPDATE via RPC or select ---
  // Supabase JS doesn't expose FOR UPDATE directly; we call a targeted select then validate
  const { data: instance, error: fetchErr } = await supabase
    .from("chore_instance")
    .select(`
      *,
      chore_template (
        id, name, base_points, requires_photo, requires_approval, family_id
      )
    `)
    .eq("id", data.instance_id)
    .maybeSingle();

  if (fetchErr || !instance) {
    return errorResponse(404, EdgeErrorCode.InvalidInstance, "Chore instance not found");
  }

  const template = instance.chore_template as Record<string, unknown>;

  // --- Family guard ---
  if (template.family_id !== user.family_id) {
    return errorResponse(403, EdgeErrorCode.Forbidden, "Chore instance belongs to a different family");
  }

  // --- Device auth: verify device maps to the kid who owns this instance ---
  if (authMode === "device") {
    const claimedUserId = data.completed_as_user ?? user.id;
    if (instance.user_id !== claimedUserId) {
      return errorResponse(403, EdgeErrorCode.Forbidden, "Device is not paired to this chore's assigned user");
    }
  }

  // --- Idempotency check: already completed/approved ---
  if (instance.status === "approved" || instance.status === "completed") {
    // Return cached result; look up existing transaction if approved
    let transaction: Record<string, unknown> | null = null;
    let balanceAfter: number | null = null;

    if (instance.status === "approved") {
      const { data: txn } = await supabase
        .from("point_transaction")
        .select("*")
        .eq("chore_instance_id", data.instance_id)
        .eq("kind", "chore_completion")
        .maybeSingle();
      transaction = txn;
      if (txn) {
        const { data: u } = await supabase
          .from("app_user")
          .select("cached_balance")
          .eq("id", instance.user_id)
          .single();
        balanceAfter = u?.cached_balance ?? null;
      }
    }

    return new Response(
      JSON.stringify({ instance, transaction, balance_after: balanceAfter }),
      { status: 200, headers: { "Content-Type": "application/json", ...CORS_HEADERS } },
    );
  }

  if (instance.status !== "pending") {
    return errorResponse(409, EdgeErrorCode.ChoreAlreadyCompleted, `Cannot complete instance with status '${instance.status}'`);
  }

  // --- Photo requirement ---
  if (template.requires_photo && !data.proof_photo_id) {
    return errorResponse(400, "PHOTO_REQUIRED", "This chore requires a proof photo");
  }

  // --- Determine path ---
  const requiresApproval = template.requires_approval as boolean;
  const basePoints = template.base_points as number;

  if (requiresApproval) {
    // Status → 'completed' (awaiting parent approval); no transaction yet
    const { data: updatedInstance, error: updateErr } = await supabase
      .from("chore_instance")
      .update({
        status:             "completed",
        completed_at:       data.completed_at,
        proof_photo_id:     data.proof_photo_id ?? null,
        completed_by_device: data.completed_by_device ?? null,
        completed_as_user:  data.completed_as_user ?? null,
      })
      .eq("id", data.instance_id)
      .select()
      .single();

    if (updateErr) {
      console.error("chore-instance.complete update (awaiting approval):", updateErr);
      return internalError();
    }

    await supabase.from("audit_log").insert({
      family_id:     user.family_id,
      actor_user_id: user.id,
      action:        "user.add",
      target:        `chore_instance:${data.instance_id}`,
      payload: {
        event:       "chore_instance.complete",
        instance_id: data.instance_id,
        status:      "completed",
        awaiting_approval: true,
        auth_mode:   authMode,
      },
    });

    return new Response(
      JSON.stringify({ instance: updatedInstance, transaction: null, balance_after: null }),
      { status: 200, headers: { "Content-Type": "application/json", ...CORS_HEADERS } },
    );
  }

  // --- Auto-approve path: status → 'approved', insert transaction ---
  const txnId = idempotencyKey
    ? idempotencyKey
    : crypto.randomUUID();

  // Use RPC to ensure atomicity (instance update + transaction insert)
  const { data: txn, error: txnErr } = await supabase.rpc("atomic_chore_instance_approve", {
    p_instance_id:      data.instance_id,
    p_approver_user_id: user.id,
    p_idempotency_key:  txnId,
  });

  if (txnErr) {
    console.error("chore-instance.complete atomic approve error:", txnErr);
    if (txnErr.message?.includes("CHORE_ALREADY_COMPLETED")) {
      return errorResponse(409, EdgeErrorCode.ChoreAlreadyCompleted, "Chore is already completed");
    }
    return internalError();
  }

  // Also set completed_at / proof_photo_id that the RPC doesn't handle
  await supabase
    .from("chore_instance")
    .update({
      completed_at:       data.completed_at,
      proof_photo_id:     data.proof_photo_id ?? null,
      completed_by_device: data.completed_by_device ?? null,
      completed_as_user:  data.completed_as_user ?? null,
    })
    .eq("id", data.instance_id);

  const { data: finalInstance } = await supabase
    .from("chore_instance")
    .select("*")
    .eq("id", data.instance_id)
    .single();

  return new Response(
    JSON.stringify({
      instance:      finalInstance,
      transaction:   txn,
      balance_after: (txn as Record<string, unknown>)?.balance_after ?? null,
    }),
    { status: 200, headers: { "Content-Type": "application/json", ...CORS_HEADERS } },
  );
});
