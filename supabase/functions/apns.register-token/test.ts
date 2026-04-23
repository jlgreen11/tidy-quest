/**
 * TidyQuest — apns.register-token tests
 * supabase/functions/apns.register-token/test.ts
 *
 * Run with: deno test --allow-env supabase/functions/apns.register-token/test.ts
 * SKIPPED acceptable when Deno/Docker is not available.
 */

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { RegisterTokenRequestSchema } from "./schema.ts";

// ---------------------------------------------------------------------------
// Test 1: Valid parent token registration
// ---------------------------------------------------------------------------
Deno.test("schema: valid parent apns token request", () => {
  const payload = {
    apns_token: "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2",
    app_bundle: "parent",
    platform:   "ios",
  };

  const result = RegisterTokenRequestSchema.safeParse(payload);
  assertEquals(result.success, true, "Valid parent token payload should parse");
  assertEquals(result.data?.app_bundle, "parent");
  assertEquals(result.data?.platform, "ios");
});

// ---------------------------------------------------------------------------
// Test 2: Valid kid token registration
// ---------------------------------------------------------------------------
Deno.test("schema: valid kid apns token request", () => {
  const payload = {
    apns_token: "f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5",
    app_bundle: "kid",
  };

  const result = RegisterTokenRequestSchema.safeParse(payload);
  assertEquals(result.success, true, "Valid kid token payload should parse");
  assertEquals(result.data?.app_bundle, "kid");
  assertEquals(result.data?.platform, "ios", "Platform should default to 'ios'");
});

// ---------------------------------------------------------------------------
// Test 3: Token too short — rejected
// ---------------------------------------------------------------------------
Deno.test("schema: rejects apns_token that is too short", () => {
  const payload = {
    apns_token: "abc123",  // less than 32 chars
    app_bundle: "parent",
  };

  const result = RegisterTokenRequestSchema.safeParse(payload);
  assertEquals(result.success, false, "Short token should fail validation");
});

// ---------------------------------------------------------------------------
// Test 4: Non-hex token rejected
// ---------------------------------------------------------------------------
Deno.test("schema: rejects non-hex apns_token", () => {
  const payload = {
    apns_token: "not-a-hex-value-but-long-enough-to-pass-length-check-!!!!!!!!!",
    app_bundle: "parent",
  };

  const result = RegisterTokenRequestSchema.safeParse(payload);
  assertEquals(result.success, false, "Non-hex token should fail validation");
});

// ---------------------------------------------------------------------------
// Test 5: Invalid app_bundle value
// ---------------------------------------------------------------------------
Deno.test("schema: rejects invalid app_bundle value", () => {
  const payload = {
    apns_token: "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2",
    app_bundle: "widget",  // not 'parent' or 'kid'
  };

  const result = RegisterTokenRequestSchema.safeParse(payload);
  assertEquals(result.success, false, "Invalid app_bundle should fail validation");
});

// ---------------------------------------------------------------------------
// Test 6: Missing app_bundle
// ---------------------------------------------------------------------------
Deno.test("schema: rejects missing app_bundle", () => {
  const payload = {
    apns_token: "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2",
  };

  const result = RegisterTokenRequestSchema.safeParse(payload);
  assertEquals(result.success, false, "Missing app_bundle should fail validation");
});

// ---------------------------------------------------------------------------
// Test 7: Platform defaults to 'ios' when not supplied
// ---------------------------------------------------------------------------
Deno.test("schema: platform defaults to ios when omitted", () => {
  const payload = {
    apns_token: "abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab",
    app_bundle: "kid",
  };

  const result = RegisterTokenRequestSchema.safeParse(payload);
  assertEquals(result.success, true);
  assertEquals(result.data?.platform, "ios");
});

// ---------------------------------------------------------------------------
// Test 8: Uppercase hex token is valid (normalised in DB layer)
// ---------------------------------------------------------------------------
Deno.test("schema: uppercase hex apns_token is accepted", () => {
  const payload = {
    apns_token: "ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890AB",
    app_bundle: "parent",
  };

  const result = RegisterTokenRequestSchema.safeParse(payload);
  assertEquals(result.success, true, "Uppercase hex should be accepted at schema level");
});

// ---------------------------------------------------------------------------
// Test 9: Token at exactly 32 chars (minimum) passes
// ---------------------------------------------------------------------------
Deno.test("schema: apns_token at minimum length (32 hex chars) passes", () => {
  const payload = {
    apns_token: "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4",  // exactly 32 chars
    app_bundle: "parent",
  };

  const result = RegisterTokenRequestSchema.safeParse(payload);
  assertEquals(result.success, true);
});

// ---------------------------------------------------------------------------
// Test 10: Token at 200 chars (max) passes; 201 fails
// ---------------------------------------------------------------------------
Deno.test("schema: apns_token at max length (200) passes; 201 fails", () => {
  const maxToken = "a".repeat(200);
  const overToken = "a".repeat(201);

  assertEquals(
    RegisterTokenRequestSchema.safeParse({ apns_token: maxToken, app_bundle: "kid" }).success,
    true,
    "200-char token should pass",
  );
  assertEquals(
    RegisterTokenRequestSchema.safeParse({ apns_token: overToken, app_bundle: "kid" }).success,
    false,
    "201-char token should fail",
  );
});
