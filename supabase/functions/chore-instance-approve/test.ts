/**
 * chore-instance.approve — unit tests
 */
import { assertEquals } from "https://deno.land/std@0.208.0/assert/mod.ts";
import { ChoreInstanceApproveRequest } from "./schema.ts";

const INSTANCE_ID = "eeeeeeee-eeee-7eee-8eee-eeeeeeeeeeee";

// Test 1: valid minimal request
Deno.test("schema: valid minimal request", () => {
  const result = ChoreInstanceApproveRequest.safeParse({ instance_id: INSTANCE_ID });
  assertEquals(result.success, true);
});

// Test 2: valid request with bonus_points
Deno.test("schema: valid request with bonus_points", () => {
  const result = ChoreInstanceApproveRequest.safeParse({
    instance_id:  INSTANCE_ID,
    bonus_points: 5,
  });
  assertEquals(result.success, true);
  if (result.success) assertEquals(result.data.bonus_points, 5);
});

// Test 3: bonus_points exceeds max (500)
Deno.test("schema: bonus_points > 500 rejected", () => {
  const result = ChoreInstanceApproveRequest.safeParse({
    instance_id:  INSTANCE_ID,
    bonus_points: 501,
  });
  assertEquals(result.success, false);
});

// Test 4: negative bonus_points rejected
Deno.test("schema: negative bonus_points rejected", () => {
  const result = ChoreInstanceApproveRequest.safeParse({
    instance_id:  INSTANCE_ID,
    bonus_points: -1,
  });
  assertEquals(result.success, false);
});

// Test 5: missing instance_id rejected
Deno.test("schema: missing instance_id rejected", () => {
  const result = ChoreInstanceApproveRequest.safeParse({});
  assertEquals(result.success, false);
});
