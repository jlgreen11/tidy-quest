/**
 * chore-instance.complete — unit tests
 */
import { assertEquals } from "https://deno.land/std@0.208.0/assert/mod.ts";
import { ChoreInstanceCompleteRequest } from "./schema.ts";

const INSTANCE_ID = "cccccccc-cccc-7ccc-8ccc-cccccccccccc";
const PHOTO_ID    = "dddddddd-dddd-7ddd-8ddd-dddddddddddd";

// Test 1: valid minimal request
Deno.test("schema: valid minimal request (no photo)", () => {
  const result = ChoreInstanceCompleteRequest.safeParse({
    instance_id:  INSTANCE_ID,
    completed_at: "2026-04-22T08:00:00+00:00",
  });
  assertEquals(result.success, true);
});

// Test 2: valid request with photo
Deno.test("schema: valid request with proof_photo_id", () => {
  const result = ChoreInstanceCompleteRequest.safeParse({
    instance_id:    INSTANCE_ID,
    completed_at:   "2026-04-22T08:00:00Z",
    proof_photo_id: PHOTO_ID,
  });
  assertEquals(result.success, true);
  if (result.success) assertEquals(result.data.proof_photo_id, PHOTO_ID);
});

// Test 3: invalid instance_id
Deno.test("schema: invalid instance_id rejected", () => {
  const result = ChoreInstanceCompleteRequest.safeParse({
    instance_id:  "bad-id",
    completed_at: "2026-04-22T08:00:00Z",
  });
  assertEquals(result.success, false);
});

// Test 4: missing completed_at
Deno.test("schema: missing completed_at rejected", () => {
  const result = ChoreInstanceCompleteRequest.safeParse({
    instance_id: INSTANCE_ID,
  });
  assertEquals(result.success, false);
});

// Test 5: non-ISO8601 completed_at rejected
Deno.test("schema: non-ISO8601 completed_at rejected", () => {
  const result = ChoreInstanceCompleteRequest.safeParse({
    instance_id:  INSTANCE_ID,
    completed_at: "April 22 2026",
  });
  assertEquals(result.success, false);
});
