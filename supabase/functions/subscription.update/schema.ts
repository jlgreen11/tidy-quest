/**
 * TidyQuest — subscription.update schemas
 * supabase/functions/subscription.update/schema.ts
 *
 * Accepts two payload shapes (union):
 *   1. StoreKit 2 JWS-signed receipt payload — unwrapped JWS data fields.
 *   2. App Store Server Notifications v2 payload.
 *
 * For tonight: mock-validate. Accept any payload carrying transactionId and
 * productId. Real Apple server-side JWS verification is marked TODO below.
 */

import { z } from "npm:zod@3";

// ---------------------------------------------------------------------------
// StoreKit 2 unwrapped JWS receipt fields
// Clients send the decoded JWS payload after signature verification on-device.
// TODO: server-side JWS verification via Apple's /verifyReceipt or JWK endpoint
// ---------------------------------------------------------------------------
export const StoreKit2ReceiptSchema = z.object({
  /** Identifies the payload type so we can discriminate the union. */
  payloadType: z.literal("storekit2-receipt"),
  transactionId: z.string().min(1),
  originalTransactionId: z.string().min(1).optional(),
  productId: z.string().min(1),
  /** ISO 8601 */
  purchaseDate: z.string().datetime({ offset: true }).optional(),
  /** ISO 8601 — null for consumables */
  expiresDate: z.string().datetime({ offset: true }).nullish(),
  /** 'autoRenewable' | 'nonRenewable' | 'consumable' | 'nonConsumable' */
  type: z.string().optional(),
  environment: z.enum(["Sandbox", "Production"]).optional(),
});

// ---------------------------------------------------------------------------
// App Store Server Notifications v2 (signedPayload decoded)
// ---------------------------------------------------------------------------
export const AppStoreServerNotificationSchema = z.object({
  payloadType: z.literal("appstore-notification"),
  notificationType: z.string().min(1),
  /** SUBSCRIBED | DID_RENEW | EXPIRED | DID_FAIL_TO_RENEW | GRACE_PERIOD_EXPIRED | etc. */
  subtype: z.string().optional(),
  /** ISO 8601 */
  signedDate: z.string().datetime({ offset: true }).optional(),
  data: z.object({
    transactionId: z.string().min(1),
    originalTransactionId: z.string().min(1).optional(),
    productId: z.string().min(1),
    expiresDate: z.string().datetime({ offset: true }).nullish(),
    purchaseDate: z.string().datetime({ offset: true }).optional(),
    environment: z.enum(["Sandbox", "Production"]).optional(),
  }),
});

/** Union of both receipt shapes */
export const ReceiptPayloadSchema = z.discriminatedUnion("payloadType", [
  StoreKit2ReceiptSchema,
  AppStoreServerNotificationSchema,
]);

export type ReceiptPayload = z.infer<typeof ReceiptPayloadSchema>;
export type StoreKit2Receipt = z.infer<typeof StoreKit2ReceiptSchema>;
export type AppStoreServerNotification = z.infer<typeof AppStoreServerNotificationSchema>;

// ---------------------------------------------------------------------------
// Helpers: normalise either shape into a flat structure
// ---------------------------------------------------------------------------

export interface NormalisedReceipt {
  transactionId: string;
  originalTransactionId: string | undefined;
  productId: string;
  purchaseDate: string | undefined;
  /** null for consumables; undefined if not supplied */
  expiresDate: string | null | undefined;
  environment: "Sandbox" | "Production" | undefined;
}

export function normaliseReceipt(payload: ReceiptPayload): NormalisedReceipt {
  if (payload.payloadType === "storekit2-receipt") {
    return {
      transactionId:         payload.transactionId,
      originalTransactionId: payload.originalTransactionId,
      productId:             payload.productId,
      purchaseDate:          payload.purchaseDate,
      expiresDate:           payload.expiresDate,
      environment:           payload.environment,
    };
  }
  return {
    transactionId:         payload.data.transactionId,
    originalTransactionId: payload.data.originalTransactionId,
    productId:             payload.data.productId,
    purchaseDate:          payload.data.purchaseDate,
    expiresDate:           payload.data.expiresDate,
    environment:           payload.data.environment,
  };
}

// ---------------------------------------------------------------------------
// Map productId → subscription tier
// ---------------------------------------------------------------------------

const PRODUCT_TIER_MAP: Record<string, "monthly" | "yearly"> = {
  "com.jlgreen11.tidyquest.monthly": "monthly",
  "com.jlgreen11.tidyquest.yearly":  "yearly",
};

export function productIdToTier(productId: string): "monthly" | "yearly" | null {
  return PRODUCT_TIER_MAP[productId] ?? null;
}

// ---------------------------------------------------------------------------
// Response type
// ---------------------------------------------------------------------------

export interface SubscriptionUpdateResponse {
  subscription: {
    id: string;
    family_id: string;
    store_transaction_id: string;
    product_id: string;
    tier: string;
    purchased_at: string | null;
    expires_at: string | null;
    status: string;
    updated_at: string;
  };
  tier: string;
  expires_at: string | null;
}
