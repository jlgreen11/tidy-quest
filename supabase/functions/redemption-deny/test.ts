/**
 * redemption.deny — unit tests
 */
import { assertEquals } from "https://deno.land/std@0.208.0/assert/mod.ts";
import { RedemptionDenyRequest } from "./schema.ts";

const REQUEST_ID = "99990000-9999-7999-8999-999900009999";

// Test 1: valid request without reason
Deno.test("schema: valid without reason", () => {
  const result = RedemptionDenyRequest.safeParse({ request_id: REQUEST_ID });
  assertEquals(result.success, true);
});

// Test 2: valid request with reason
Deno.test("schema: valid with reason", () => {
  const result = RedemptionDenyRequest.safeParse({
    request_id: REQUEST_ID,
    reason:     "Chores not finished yet",
  });
  assertEquals(result.success, true);
  if (result.success) assertEquals(result.data.reason, "Chores not finished yet");
});

// Test 3: missing request_id rejected
Deno.test("schema: missing request_id rejected", () => {
  const result = RedemptionDenyRequest.safeParse({});
  assertEquals(result.success, false);
});

// Test 4: empty reason rejected (min 1)
Deno.test("schema: empty reason rejected", () => {
  const result = RedemptionDenyRequest.safeParse({
    request_id: REQUEST_ID,
    reason:     "",
  });
  assertEquals(result.success, false);
});

// Test 5: reason at max length (500) accepted
Deno.test("schema: reason at exactly 500 chars accepted", () => {
  const result = RedemptionDenyRequest.safeParse({
    request_id: REQUEST_ID,
    reason:     "y".repeat(500),
  });
  assertEquals(result.success, true);
});
