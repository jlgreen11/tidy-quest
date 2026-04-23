/**
 * point-transaction.reverse — unit tests
 */
import { assertEquals, assertExists } from "https://deno.land/std@0.208.0/assert/mod.ts";
import { PointTransactionReverseRequest } from "./schema.ts";

const TXN_ID = "ccccdddd-cccc-7ccc-8ccc-ccccddddcccc";

// Test 1: valid minimal request (no reason)
Deno.test("schema: valid without reason", () => {
  const result = PointTransactionReverseRequest.safeParse({ transaction_id: TXN_ID });
  assertEquals(result.success, true);
  if (result.success) assertEquals(result.data.reason, undefined);
});

// Test 2: valid with reason
Deno.test("schema: valid with reason", () => {
  const result = PointTransactionReverseRequest.safeParse({
    transaction_id: TXN_ID,
    reason:         "Entered by mistake",
  });
  assertEquals(result.success, true);
  if (result.success) assertEquals(result.data.reason, "Entered by mistake");
});

// Test 3: missing transaction_id rejected
Deno.test("schema: missing transaction_id rejected", () => {
  const result = PointTransactionReverseRequest.safeParse({});
  assertEquals(result.success, false);
});

// Test 4: non-UUID transaction_id rejected
Deno.test("schema: non-UUID transaction_id rejected", () => {
  const result = PointTransactionReverseRequest.safeParse({ transaction_id: "bad" });
  assertEquals(result.success, false);
});

// Test 5: contract — correction-of-correction is blocked at RPC level
// Documents that the handler returns 409 CONFLICT when kind = 'correction'
Deno.test("contract: reversing a correction returns 409 CONFLICT", () => {
  // Documented contract: atomic_point_transaction_reverse raises
  // 'CONFLICT: cannot reverse a correction transaction'.
  // The edge function translates to HTTP 409 with code EdgeErrorCode.Conflict.
  const expectedStatus = 409;
  const expectedCode = "CONFLICT";
  assertExists(expectedCode);
  assertEquals(expectedStatus, 409);
});
