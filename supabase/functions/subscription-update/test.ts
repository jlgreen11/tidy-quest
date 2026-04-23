/**
 * TidyQuest — subscription.update tests
 * supabase/functions/subscription.update/test.ts
 *
 * Run with: deno test --allow-env supabase/functions/subscription.update/test.ts
 * SKIPPED acceptable when Deno/Docker is not available.
 */

import { assertEquals, assertExists } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  normaliseReceipt,
  productIdToTier,
  ReceiptPayloadSchema,
  StoreKit2Receipt,
} from "./schema.ts";

// ---------------------------------------------------------------------------
// Test 1: StoreKit2 receipt schema — valid monthly payload
// ---------------------------------------------------------------------------
Deno.test("schema: accepts valid StoreKit2 monthly receipt", () => {
  const payload = {
    payloadType:   "storekit2-receipt",
    transactionId: "txn-abc-123",
    productId:     "com.jlgreen11.tidyquest.monthly",
    purchaseDate:  "2026-04-22T00:00:00Z",
    expiresDate:   "2026-05-22T00:00:00Z",
    environment:   "Sandbox",
  };

  const result = ReceiptPayloadSchema.safeParse(payload);
  assertEquals(result.success, true, "Valid StoreKit2 receipt must parse successfully");
});

// ---------------------------------------------------------------------------
// Test 2: AppStore Server Notification schema — valid yearly payload
// ---------------------------------------------------------------------------
Deno.test("schema: accepts valid App Store Server Notification (yearly)", () => {
  const payload = {
    payloadType:       "appstore-notification",
    notificationType:  "SUBSCRIBED",
    subtype:           "INITIAL_BUY",
    signedDate:        "2026-04-22T00:00:00Z",
    data: {
      transactionId:  "txn-def-456",
      productId:      "com.jlgreen11.tidyquest.yearly",
      purchaseDate:   "2026-04-22T00:00:00Z",
      expiresDate:    "2027-04-22T00:00:00Z",
      environment:    "Production",
    },
  };

  const result = ReceiptPayloadSchema.safeParse(payload);
  assertEquals(result.success, true, "Valid AppStore notification must parse successfully");
});

// ---------------------------------------------------------------------------
// Test 3: Missing transactionId fails validation
// ---------------------------------------------------------------------------
Deno.test("schema: rejects payload missing transactionId", () => {
  const payload = {
    payloadType: "storekit2-receipt",
    // transactionId intentionally missing
    productId:   "com.jlgreen11.tidyquest.monthly",
  };

  const result = ReceiptPayloadSchema.safeParse(payload);
  assertEquals(result.success, false, "Missing transactionId must fail validation");
});

// ---------------------------------------------------------------------------
// Test 4: normaliseReceipt extracts fields consistently from StoreKit2
// ---------------------------------------------------------------------------
Deno.test("normaliseReceipt: extracts fields from StoreKit2 receipt", () => {
  const sk2Payload: StoreKit2Receipt = {
    payloadType:           "storekit2-receipt",
    transactionId:         "txn-normalize-test",
    originalTransactionId: "orig-111",
    productId:             "com.jlgreen11.tidyquest.yearly",
    purchaseDate:          "2026-04-01T00:00:00Z",
    expiresDate:           "2027-04-01T00:00:00Z",
    environment:           "Sandbox",
  };

  const result = ReceiptPayloadSchema.safeParse(sk2Payload);
  assertEquals(result.success, true);

  const normalised = normaliseReceipt(result.data!);
  assertEquals(normalised.transactionId, "txn-normalize-test");
  assertEquals(normalised.productId, "com.jlgreen11.tidyquest.yearly");
  assertEquals(normalised.expiresDate, "2027-04-01T00:00:00Z");
  assertEquals(normalised.environment, "Sandbox");
});

// ---------------------------------------------------------------------------
// Test 5: productIdToTier maps correctly, returns null for unknown products
// ---------------------------------------------------------------------------
Deno.test("productIdToTier: maps known products and rejects unknown", () => {
  assertEquals(productIdToTier("com.jlgreen11.tidyquest.monthly"), "monthly");
  assertEquals(productIdToTier("com.jlgreen11.tidyquest.yearly"), "yearly");
  assertEquals(productIdToTier("com.example.other.product"), null);
  assertEquals(productIdToTier(""), null);
});

// ---------------------------------------------------------------------------
// Test 6: AppStore notification normalisation via data sub-object
// ---------------------------------------------------------------------------
Deno.test("normaliseReceipt: extracts fields from AppStore Server Notification", () => {
  const notifPayload = {
    payloadType:      "appstore-notification",
    notificationType: "DID_RENEW",
    data: {
      transactionId:         "txn-renew-789",
      originalTransactionId: "orig-789",
      productId:             "com.jlgreen11.tidyquest.monthly",
      purchaseDate:          "2026-04-22T00:00:00Z",
      expiresDate:           "2026-05-22T00:00:00Z",
      environment:           "Production" as const,
    },
  };

  const result = ReceiptPayloadSchema.safeParse(notifPayload);
  assertEquals(result.success, true);

  const normalised = normaliseReceipt(result.data!);
  assertEquals(normalised.transactionId, "txn-renew-789");
  assertEquals(normalised.productId, "com.jlgreen11.tidyquest.monthly");
  assertEquals(normalised.environment, "Production");
  assertExists(normalised.purchaseDate);
});

// ---------------------------------------------------------------------------
// Test 7: Schema rejects invalid payloadType discriminant
// ---------------------------------------------------------------------------
Deno.test("schema: rejects unknown payloadType", () => {
  const payload = {
    payloadType:   "unknown-type",
    transactionId: "txn-000",
    productId:     "com.jlgreen11.tidyquest.monthly",
  };

  const result = ReceiptPayloadSchema.safeParse(payload);
  assertEquals(result.success, false);
});

// ---------------------------------------------------------------------------
// Test 8: AppStore notification rejects missing data.transactionId
// ---------------------------------------------------------------------------
Deno.test("schema: AppStore notification rejects missing data.transactionId", () => {
  const payload = {
    payloadType:      "appstore-notification",
    notificationType: "SUBSCRIBED",
    data: {
      // transactionId missing
      productId:    "com.jlgreen11.tidyquest.yearly",
      environment:  "Sandbox",
    },
  };

  const result = ReceiptPayloadSchema.safeParse(payload);
  assertEquals(result.success, false);
});

// ---------------------------------------------------------------------------
// Test 9: nullish expiresDate is accepted (consumable scenario)
// ---------------------------------------------------------------------------
Deno.test("schema: accepts null expiresDate (consumable)", () => {
  const payload = {
    payloadType:   "storekit2-receipt",
    transactionId: "txn-consumable-001",
    productId:     "com.jlgreen11.tidyquest.monthly",
    expiresDate:   null,
  };

  const result = ReceiptPayloadSchema.safeParse(payload);
  assertEquals(result.success, true);
  const normalised = normaliseReceipt(result.data!);
  assertEquals(normalised.expiresDate, null);
});

// ---------------------------------------------------------------------------
// Test 10: productIdToTier is case-sensitive (no accidental matches)
// ---------------------------------------------------------------------------
Deno.test("productIdToTier: case-sensitive matching", () => {
  assertEquals(productIdToTier("COM.JLGREEN11.TIDYQUEST.MONTHLY"), null);
  assertEquals(productIdToTier("com.jlgreen11.tidyquest.Monthly"), null);
});
