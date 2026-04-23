/**
 * point-transaction.fine — unit tests
 */
import { assertEquals } from "https://deno.land/std@0.208.0/assert/mod.ts";
import { PointTransactionFineRequest } from "./schema.ts";

const USER_ID = "aaaabbbb-aaaa-7aaa-8aaa-aaaabbbbaaaa";

// Test 1: valid with free-text reason
Deno.test("schema: valid with free-text reason", () => {
  const result = PointTransactionFineRequest.safeParse({
    user_id: USER_ID,
    amount:  10,
    reason:  "Left room messy",
  });
  assertEquals(result.success, true);
});

// Test 2: valid with canned_reason_key only
Deno.test("schema: valid with canned_reason_key only", () => {
  const result = PointTransactionFineRequest.safeParse({
    user_id:           USER_ID,
    amount:            5,
    canned_reason_key: "left_room_messy",
  });
  assertEquals(result.success, true);
});

// Test 3: missing both reason and canned_reason_key rejected
Deno.test("schema: missing reason and canned_reason_key rejected", () => {
  const result = PointTransactionFineRequest.safeParse({
    user_id: USER_ID,
    amount:  5,
  });
  assertEquals(result.success, false);
});

// Test 4: amount = 0 rejected (min 1)
Deno.test("schema: amount = 0 rejected", () => {
  const result = PointTransactionFineRequest.safeParse({
    user_id: USER_ID,
    amount:  0,
    reason:  "Test",
  });
  assertEquals(result.success, false);
});

// Test 5: amount > 25 still passes schema (App Attest check happens at HTTP layer)
Deno.test("schema: amount > 25 passes schema validation", () => {
  const result = PointTransactionFineRequest.safeParse({
    user_id: USER_ID,
    amount:  26,
    reason:  "Screen time exceeded",
  });
  // Schema accepts it; App Attest enforcement happens in the handler
  assertEquals(result.success, true);
  if (result.success) assertEquals(result.data.amount, 26);
});
