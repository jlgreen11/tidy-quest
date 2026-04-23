/**
 * chore-template.archive — unit tests
 */
import { assertEquals } from "https://deno.land/std@0.208.0/assert/mod.ts";
import { ChoreTemplateArchiveRequest } from "./schema.ts";

const VALID_UUID = "bbbbbbbb-bbbb-7bbb-8bbb-bbbbbbbbbbbb";

// Test 1: valid UUID accepted
Deno.test("schema: valid template_id accepted", () => {
  const result = ChoreTemplateArchiveRequest.safeParse({ template_id: VALID_UUID });
  assertEquals(result.success, true);
});

// Test 2: missing template_id rejected
Deno.test("schema: missing template_id rejected", () => {
  const result = ChoreTemplateArchiveRequest.safeParse({});
  assertEquals(result.success, false);
});

// Test 3: non-UUID template_id rejected
Deno.test("schema: non-UUID template_id rejected", () => {
  const result = ChoreTemplateArchiveRequest.safeParse({ template_id: "abc-123" });
  assertEquals(result.success, false);
});

// Test 4: extra fields are stripped (Zod strips by default)
Deno.test("schema: extra fields stripped silently", () => {
  const result = ChoreTemplateArchiveRequest.safeParse({
    template_id: VALID_UUID,
    extra_field: "should be stripped",
  });
  assertEquals(result.success, true);
  if (result.success) {
    assertEquals("extra_field" in result.data, false);
  }
});

// Test 5: null template_id rejected
Deno.test("schema: null template_id rejected", () => {
  const result = ChoreTemplateArchiveRequest.safeParse({ template_id: null });
  assertEquals(result.success, false);
});
