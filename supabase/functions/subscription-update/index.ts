/**
 * TidyQuest — subscription.update edge function
 * supabase/functions/subscription.update/index.ts
 *
 * POST /functions/v1/subscription.update
 * Auth:      Bearer (parent JWT)
 * Rate:      10 requests / 60 seconds
 * Idempotent via Idempotency-Key header
 *
 * Accepts StoreKit 2 JWS-signed receipt payloads OR App Store Server
 * Notifications v2 payloads (discriminated union via Zod).
 *
 * For tonight: MOCK validation — any payload with transactionId + productId is
 * accepted. Real Apple server-side JWS verification is marked TODO below.
 *
 * Flow:
 *   1. Authenticate parent via Bearer token.
 *   2. Rate-limit check.
 *   3. Idempotency-Key check.
 *   4. Parse + mock-validate receipt.
 *   5. Upsert subscription row for this family.
 *   6. Update family.subscription_tier and subscription_expires_at.
 *   7. Write audit_log entry (subscription.state_change).
 *   8. Return { subscription, tier, expires_at }.
 */

import { createClient } from "npm:@supabase/supabase-js@2";
import {
  checkIdempotency,
  checkRateLimit,
  parseAppleJwt,
  recordIdempotency,
} from "../_shared/auth.ts";
import {
  internalError,
  rateLimitError,
  unauthorizedError,
  validationError,
} from "../_shared/errors.ts";
import { AuditAction, SubscriptionStatus, SubscriptionTier } from "../_shared/types.ts";
import {
  normaliseReceipt,
  productIdToTier,
  ReceiptPayloadSchema,
  SubscriptionUpdateResponse,
} from "./schema.ts";

const ENDPOINT = "subscription.update";
const RATE_MAX = 10;
const RATE_WINDOW_SECONDS = 60;

Deno.serve(async (req: Request): Promise<Response> => {
  // -------------------------------------------------------------------------
  // 1. Method guard
  // -------------------------------------------------------------------------
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: { code: "METHOD_NOT_ALLOWED", message: "Use POST" } }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  // -------------------------------------------------------------------------
  // 2. Service-role client (bypasses RLS for atomic multi-table writes)
  // -------------------------------------------------------------------------
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceKey  = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const supabase = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false },
  });

  // -------------------------------------------------------------------------
  // 3. Authenticate parent via Bearer token
  // -------------------------------------------------------------------------
  const authHeader = req.headers.get("Authorization");
  const parsed = parseAppleJwt(authHeader);
  if (!parsed) {
    return unauthorizedError("Valid Bearer token required");
  }

  // Resolve parent user from apple_sub
  const { data: userRow, error: userErr } = await supabase
    .from("app_user")
    .select("id, family_id, role")
    .eq("apple_sub", parsed.apple_sub)
    .is("deleted_at", null)
    .single();

  if (userErr || !userRow) {
    console.error("[subscription.update] user lookup failed:", userErr);
    return unauthorizedError("User not found");
  }

  if (!["parent", "caregiver"].includes(userRow.role)) {
    return unauthorizedError("Only parents may update subscriptions");
  }

  const familyId = userRow.family_id as string;
  const userId   = userRow.id as string;

  // -------------------------------------------------------------------------
  // 4. Rate limit
  // -------------------------------------------------------------------------
  const rl = await checkRateLimit(supabase, userId, ENDPOINT, RATE_MAX, RATE_WINDOW_SECONDS);
  if (!rl.allowed) {
    return rateLimitError(rl.retryAfterSeconds);
  }

  // -------------------------------------------------------------------------
  // 5. Idempotency
  // -------------------------------------------------------------------------
  const idempotencyKey = req.headers.get("Idempotency-Key") ?? "";
  if (idempotencyKey) {
    const idem = await checkIdempotency(supabase, idempotencyKey, ENDPOINT);
    if (idem.hit && idem.cachedResponse) {
      return new Response(JSON.stringify(idem.cachedResponse), {
        status: 200,
        headers: { "Content-Type": "application/json", "X-Idempotency-Replay": "true" },
      });
    }
  }

  // -------------------------------------------------------------------------
  // 6. Parse body
  // -------------------------------------------------------------------------
  let rawBody: unknown;
  try {
    rawBody = await req.json();
  } catch {
    return validationError("Request body must be valid JSON");
  }

  const parseResult = ReceiptPayloadSchema.safeParse(rawBody);
  if (!parseResult.success) {
    return validationError("Invalid receipt payload", {
      issues: parseResult.error.issues,
    });
  }

  const receipt = normaliseReceipt(parseResult.data);

  // -------------------------------------------------------------------------
  // 7. MOCK receipt validation
  // TODO: replace with real Apple server-side JWS verification
  //   - For StoreKit 2 receipts: verify JWS signature using Apple's public keys
  //     (fetch from https://appleid.apple.com/auth/keys).
  //   - For App Store Server Notifications: verify signedPayload JWS.
  //   - Call Apple's /verifyReceipt or App Store Server API to confirm validity.
  //   - Check bundle ID matches com.jlgreen11.tidyquest.parent.
  //   - Check environment (Sandbox ↔ staging, Production ↔ prod).
  // -------------------------------------------------------------------------
  console.log("[TODO] Apple receipt verification — mock accepted:", {
    transactionId: receipt.transactionId,
    productId:     receipt.productId,
    environment:   receipt.environment ?? "unknown",
  });

  const tier = productIdToTier(receipt.productId);
  if (!tier) {
    return validationError(`Unknown productId: ${receipt.productId}`, {
      known_products: ["com.jlgreen11.tidyquest.monthly", "com.jlgreen11.tidyquest.yearly"],
    });
  }

  const purchasedAt = receipt.purchaseDate ?? new Date().toISOString();
  const expiresAt   = receipt.expiresDate ?? null;

  // Compute subscription status
  let status: SubscriptionStatus;
  if (expiresAt && new Date(expiresAt) < new Date()) {
    status = SubscriptionStatus.Expired;
  } else {
    status = SubscriptionStatus.Active;
  }

  // -------------------------------------------------------------------------
  // 8. Upsert subscription row (keyed on family_id)
  // -------------------------------------------------------------------------
  const receiptHash = `mock-${receipt.transactionId}`; // TODO: real hash of JWS payload

  const { data: sub, error: subErr } = await supabase
    .from("subscription")
    .upsert(
      {
        family_id:            familyId,
        store_transaction_id: receipt.transactionId,
        product_id:           receipt.productId,
        tier,
        purchased_at:         purchasedAt,
        expires_at:           expiresAt,
        status,
        receipt_hash:         receiptHash,
        updated_at:           new Date().toISOString(),
      },
      { onConflict: "family_id" },
    )
    .select()
    .single();

  if (subErr || !sub) {
    console.error("[subscription.update] subscription upsert failed:", subErr);
    return internalError();
  }

  // -------------------------------------------------------------------------
  // 9. Update family.subscription_tier and subscription_expires_at
  // -------------------------------------------------------------------------
  const familyTier: SubscriptionTier =
    status === SubscriptionStatus.Expired
      ? SubscriptionTier.Expired
      : (tier as SubscriptionTier);

  const { error: familyErr } = await supabase
    .from("family")
    .update({
      subscription_tier:       familyTier,
      subscription_expires_at: expiresAt,
    })
    .eq("id", familyId);

  if (familyErr) {
    console.error("[subscription.update] family update failed:", familyErr);
    return internalError();
  }

  // -------------------------------------------------------------------------
  // 10. Write audit_log
  // -------------------------------------------------------------------------
  const { error: auditErr } = await supabase.from("audit_log").insert({
    family_id:     familyId,
    actor_user_id: userId,
    action:        AuditAction.SubscriptionStateChange,
    target:        `subscription:${sub.id}`,
    payload: {
      transaction_id: receipt.transactionId,
      product_id:     receipt.productId,
      tier,
      status,
      expires_at:     expiresAt,
      environment:    receipt.environment ?? "unknown",
      mock_validated: true,
    },
  });

  if (auditErr) {
    // Non-fatal: log but don't fail the request
    console.error("[subscription.update] audit_log insert failed:", auditErr);
  }

  // -------------------------------------------------------------------------
  // 11. Build and return response
  // -------------------------------------------------------------------------
  const responseBody: SubscriptionUpdateResponse = {
    subscription: {
      id:                   sub.id,
      family_id:            sub.family_id,
      store_transaction_id: sub.store_transaction_id,
      product_id:           sub.product_id,
      tier:                 sub.tier,
      purchased_at:         sub.purchased_at ?? null,
      expires_at:           sub.expires_at ?? null,
      status:               sub.status,
      updated_at:           sub.updated_at,
    },
    tier:       sub.tier,
    expires_at: sub.expires_at ?? null,
  };

  if (idempotencyKey) {
    await recordIdempotency(supabase, idempotencyKey, ENDPOINT, responseBody as unknown as Record<string, unknown>);
  }

  return new Response(JSON.stringify(responseBody), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
