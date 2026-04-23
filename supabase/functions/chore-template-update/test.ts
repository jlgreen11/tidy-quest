/**
 * chore-template.update — unit tests
 */
import { assertEquals } from "https://deno.land/std@0.208.0/assert/mod.ts";
import { ChoreTemplateUpdateRequest } from "./schema.ts";

const TEMPLATE_ID = "aaaaaaaa-aaaa-7aaa-8aaa-aaaaaaaaaaaa";

// Test 1: single field update is valid
Deno.test("schema: single field update accepted", () => {
  const result = ChoreTemplateUpdateRequest.safeParse({
    template_id: TEMPLATE_ID,
    name: "New Name",
  });
  assertEquals(result.success, true);
});

// Test 2: no update fields (only template_id) is rejected
Deno.test("schema: no update fields rejected", () => {
  const result = ChoreTemplateUpdateRequest.safeParse({
    template_id: TEMPLATE_ID,
  });
  assertEquals(result.success, false);
});

// Test 3: invalid UUID for template_id
Deno.test("schema: invalid template_id rejected", () => {
  const result = ChoreTemplateUpdateRequest.safeParse({
    template_id: "not-a-uuid",
    base_points: 10,
  });
  assertEquals(result.success, false);
});

// Test 4: base_points 0 is valid boundary
Deno.test("schema: base_points = 0 is valid", () => {
  const result = ChoreTemplateUpdateRequest.safeParse({
    template_id: TEMPLATE_ID,
    base_points: 0,
  });
  assertEquals(result.success, true);
});

// Test 5: multiple fields updated simultaneously
Deno.test("schema: multiple simultaneous field updates accepted", () => {
  const result = ChoreTemplateUpdateRequest.safeParse({
    template_id: TEMPLATE_ID,
    name: "Updated",
    base_points: 25,
    requires_photo: true,
    on_miss: "skip",
  });
  assertEquals(result.success, true);
  if (result.success) {
    assertEquals(result.data.base_points, 25);
    assertEquals(result.data.requires_photo, true);
  }
});
