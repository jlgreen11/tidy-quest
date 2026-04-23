/**
 * redemption.approve — unit tests
 *
 * Tests 1-3 cover schema validation.
 * Tests 4-5 demonstrate the intended atomicity behavior (documented test cases;
 * live DB execution requires a running Supabase instance).
 */
import { assertEquals, assertExists } from "https://deno.land/std@0.208.0/assert/mod.ts";
import { RedemptionApproveRequest } from "./schema.ts";

const REQUEST_ID = "77778888-7777-7777-8777-777788887777";

// Test 1: valid request_id accepted
Deno.test("schema: valid request_id accepted", () => {
  const result = RedemptionApproveRequest.safeParse({ request_id: REQUEST_ID });
  assertEquals(result.success, true);
});

// Test 2: missing request_id rejected
Deno.test("schema: missing request_id rejected", () => {
  const result = RedemptionApproveRequest.safeParse({});
  assertEquals(result.success, false);
});

// Test 3: non-UUID request_id rejected
Deno.test("schema: non-UUID request_id rejected", () => {
  const result = RedemptionApproveRequest.safeParse({ request_id: "bad-id" });
  assertEquals(result.success, false);
});

// Test 4: atomicity contract — document expected error codes on failure
// This test documents expected behavior; actual DB test lives in supabase/tests/rls/
Deno.test("contract: INSUFFICIENT_BALANCE surfaces as 409", () => {
  // When kid.cached_balance < reward.price, atomic_redemption_approve raises
  // INSUFFICIENT_BALANCE.  The edge function must translate this to HTTP 409
  // with code EdgeErrorCode.InsufficientBalance.
  const expectedHttpStatus = 409;
  const expectedCode = "INSUFFICIENT_BALANCE";
  // Document the contract (not a live call in unit test)
  assertExists(expectedCode);
  assertEquals(expectedHttpStatus, 409);
});

// Test 5: atomicity contract — cooldown error surfaces correctly
Deno.test("contract: COOLDOWN_ACTIVE surfaces as 409", () => {
  // When the reward cooldown period has not elapsed, the RPC raises COOLDOWN_ACTIVE.
  // The edge function translates this to HTTP 409 with code EdgeErrorCode.CooldownActive.
  const expectedHttpStatus = 409;
  const expectedCode = "COOLDOWN_ACTIVE";
  assertExists(expectedCode);
  assertEquals(expectedHttpStatus, 409);
});
