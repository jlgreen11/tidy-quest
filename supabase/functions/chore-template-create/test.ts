/**
 * chore-template.create — unit tests
 *
 * Run: deno test --allow-env supabase/functions/chore-template.create/test.ts
 *
 * These tests exercise the Zod schema and request-validation logic in isolation.
 * Integration against a live Supabase instance is tested via the RLS test suite.
 */

import { assertEquals, assertObjectMatch } from "https://deno.land/std@0.208.0/assert/mod.ts";
import { ChoreTemplateCreateRequest } from "./schema.ts";

// Test 1: valid minimal payload parses successfully
Deno.test("schema: valid minimal payload", () => {
  const result = ChoreTemplateCreateRequest.safeParse({
    name: "Take out trash",
    icon: "trash",
    type: "weekly",
    schedule: { daysOfWeek: [1] },
    target_user_ids: ["11111111-1111-1111-1111-111111111111"],
    base_points: 10,
  });
  assertEquals(result.success, true);
  if (result.success) {
    assertEquals(result.data.requires_photo, false);
    assertEquals(result.data.requires_approval, false);
    assertEquals(result.data.on_miss, "decay");
    assertEquals(result.data.on_miss_amount, 0);
  }
});

// Test 2: base_points out of range is rejected
Deno.test("schema: base_points > 500 rejected", () => {
  const result = ChoreTemplateCreateRequest.safeParse({
    name: "Sweep floor",
    icon: "broom",
    type: "daily",
    schedule: {},
    target_user_ids: ["22222222-2222-2222-2222-222222222222"],
    base_points: 501,
  });
  assertEquals(result.success, false);
  if (!result.success) {
    const codes = result.error.issues.map((i) => i.path[0]);
    assertEquals(codes.includes("base_points"), true);
  }
});

// Test 3: missing required fields returns errors for each
Deno.test("schema: missing required fields", () => {
  const result = ChoreTemplateCreateRequest.safeParse({});
  assertEquals(result.success, false);
  if (!result.success) {
    const paths = result.error.issues.map((i) => String(i.path[0]));
    assertEquals(paths.includes("name"), true);
    assertEquals(paths.includes("type"), true);
    assertEquals(paths.includes("target_user_ids"), true);
  }
});

// Test 4: invalid UUID in target_user_ids is rejected
Deno.test("schema: invalid UUID in target_user_ids", () => {
  const result = ChoreTemplateCreateRequest.safeParse({
    name: "Dishes",
    icon: "fork",
    type: "daily",
    schedule: {},
    target_user_ids: ["not-a-uuid"],
    base_points: 5,
  });
  assertEquals(result.success, false);
  if (!result.success) {
    const paths = result.error.issues.map((i) => i.path[0]);
    assertEquals(paths.includes("target_user_ids"), true);
  }
});

// Test 5: optional fields default correctly and full payload accepted
Deno.test("schema: full payload with all fields", () => {
  const result = ChoreTemplateCreateRequest.safeParse({
    id: "33333333-3333-7333-8333-333333333333",
    name: "Morning routine",
    icon: "sun",
    description: "Complete morning checklist",
    type: "routine_bound",
    schedule: { daysOfWeek: [1, 2, 3, 4, 5] },
    target_user_ids: ["44444444-4444-4444-4444-444444444444"],
    base_points: 50,
    cutoff_time: "09:00",
    requires_photo: true,
    requires_approval: true,
    on_miss: "deduct",
    on_miss_amount: 5,
  });
  assertEquals(result.success, true);
  if (result.success) {
    assertEquals(result.data.requires_photo, true);
    assertEquals(result.data.on_miss, "deduct");
    assertEquals(result.data.cutoff_time, "09:00");
  }
});
