/**
 * redemption.request
 * POST /functions/v1/redemption.request
 *
 * Auth:      Bearer (kid via parent JWT) OR Device (kid device token)
 * Rate:      10/60s
 * Sensitive: No
 *
 * Creates a redemption_request for a reward. Validates the reward is active
 * and belongs to the same family.
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { authenticateBearer, authenticateDevice, checkRateLimit, createServiceClient } from "../_shared/auth.ts";
import { errorResponse, internalError, validationError } from "../_shared/errors.ts";
import { EdgeErrorCode } from "../_shared/types.ts";
import { RedemptionRequestBody } from "./schema.ts";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, idempotency-key, x-device-token",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS_HEADERS });
  if (req.method !== "POST") return errorResponse(405, "METHOD_NOT_ALLOWED", "Only POST is accepted");

  // Auth: Bearer or Device
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

  const rl = await checkRateLimit(createServiceClient(), user.id, "redemption.request", 10, 60);
  if (!rl.allowed) return errorResponse(429, EdgeErrorCode.RateLimitExceeded, "Rate limit exceeded");

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return validationError("Request body must be valid JSON");
  }

  const parsed = RedemptionRequestBody.safeParse(body);
  if (!parsed.success) return validationError("Invalid request body", { issues: parsed.error.issues });
  const data = parsed.data;

  // Determine the requesting user
  const requestingUserId = authMode === "device"
    ? (data.requesting_as_user ?? user.id)
    : user.id;

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // Verify reward is active and in same family
  const { data: reward, error: rewardErr } = await supabase
    .from("reward")
    .select("id, family_id, name, price, active, cooldown, archived_at")
    .eq("id", data.reward_id)
    .maybeSingle();

  if (rewardErr || !reward) {
    return errorResponse(404, EdgeErrorCode.NotFound, "Reward not found");
  }
  if (reward.family_id !== user.family_id) {
    return errorResponse(403, EdgeErrorCode.Forbidden, "Reward belongs to a different family");
  }
  if (!reward.active || reward.archived_at !== null) {
    return errorResponse(409, EdgeErrorCode.RewardUnavailable, "Reward is not currently available");
  }

  // Build insert payload
  const insertPayload: Record<string, unknown> = {
    family_id:  user.family_id,
    user_id:    requestingUserId,
    reward_id:  data.reward_id,
    notes:      data.notes ?? null,
    status:     "pending",
  };
  if (data.id) insertPayload.id = data.id;

  const { data: redemptionReq, error: insertErr } = await supabase
    .from("redemption_request")
    .insert(insertPayload)
    .select()
    .single();

  if (insertErr) {
    console.error("redemption.request insert error:", insertErr);
    if (insertErr.code === "23505") {
      // Duplicate ID — return existing
      const { data: existing } = await supabase
        .from("redemption_request")
        .select("*")
        .eq("id", data.id!)
        .single();
      return new Response(JSON.stringify({ request: existing }), {
        status: 200,
        headers: { "Content-Type": "application/json", ...CORS_HEADERS },
      });
    }
    return internalError();
  }

  await supabase.from("audit_log").insert({
    family_id:     user.family_id,
    actor_user_id: user.id,
    action:        "user.add",
    target:        `redemption_request:${redemptionReq.id}`,
    payload: {
      event:        "redemption.request",
      request_id:   redemptionReq.id,
      reward_id:    data.reward_id,
      reward_name:  reward.name,
      price:        reward.price,
      user_id:      requestingUserId,
      auth_mode:    authMode,
    },
  });

  return new Response(
    JSON.stringify({ request: redemptionReq }),
    { status: 201, headers: { "Content-Type": "application/json", ...CORS_HEADERS } },
  );
});
