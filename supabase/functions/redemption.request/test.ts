/**
 * redemption.request — unit tests
 */
import { assertEquals } from "https://deno.land/std@0.208.0/assert/mod.ts";
import { RedemptionRequestBody } from "./schema.ts";

const REWARD_ID = "11112222-1111-7111-8111-111122221111";
const USER_ID   = "33334444-3333-7333-8333-333344443333";

// Test 1: valid minimal request
Deno.test("schema: valid minimal request", () => {
  const result = RedemptionRequestBody.safeParse({ reward_id: REWARD_ID });
  assertEquals(result.success, true);
});

// Test 2: valid request with all fields
Deno.test("schema: valid full request", () => {
  const result = RedemptionRequestBody.safeParse({
    id:                  "55556666-5555-7555-8555-555566665555",
    reward_id:           REWARD_ID,
    notes:               "Please!",
    requesting_as_user:  USER_ID,
  });
  assertEquals(result.success, true);
});

// Test 3: missing reward_id rejected
Deno.test("schema: missing reward_id rejected", () => {
  const result = RedemptionRequestBody.safeParse({ notes: "please" });
  assertEquals(result.success, false);
});

// Test 4: invalid UUID reward_id rejected
Deno.test("schema: invalid UUID reward_id rejected", () => {
  const result = RedemptionRequestBody.safeParse({ reward_id: "not-a-uuid" });
  assertEquals(result.success, false);
});

// Test 5: notes exceeding max length rejected
Deno.test("schema: notes > 500 chars rejected", () => {
  const result = RedemptionRequestBody.safeParse({
    reward_id: REWARD_ID,
    notes:     "x".repeat(501),
  });
  assertEquals(result.success, false);
});
