/**
 * chore-instance.reject — unit tests
 */
import { assertEquals } from "https://deno.land/std@0.208.0/assert/mod.ts";
import { ChoreInstanceRejectRequest } from "./schema.ts";

const INSTANCE_ID = "ffffffff-ffff-7fff-8fff-ffffffffffff";

// Test 1: valid request without reason
Deno.test("schema: valid request without reason", () => {
  const result = ChoreInstanceRejectRequest.safeParse({ instance_id: INSTANCE_ID });
  assertEquals(result.success, true);
  if (result.success) assertEquals(result.data.reason, undefined);
});

// Test 2: valid request with reason
Deno.test("schema: valid request with reason", () => {
  const result = ChoreInstanceRejectRequest.safeParse({
    instance_id: INSTANCE_ID,
    reason:      "Photo was blurry",
  });
  assertEquals(result.success, true);
  if (result.success) assertEquals(result.data.reason, "Photo was blurry");
});

// Test 3: empty reason string rejected (min 1)
Deno.test("schema: empty reason string rejected", () => {
  const result = ChoreInstanceRejectRequest.safeParse({
    instance_id: INSTANCE_ID,
    reason:      "",
  });
  assertEquals(result.success, false);
});

// Test 4: missing instance_id rejected
Deno.test("schema: missing instance_id rejected", () => {
  const result = ChoreInstanceRejectRequest.safeParse({ reason: "No photo" });
  assertEquals(result.success, false);
});

// Test 5: reason exceeding max length rejected
Deno.test("schema: reason > 500 chars rejected", () => {
  const result = ChoreInstanceRejectRequest.safeParse({
    instance_id: INSTANCE_ID,
    reason:      "a".repeat(501),
  });
  assertEquals(result.success, false);
});
