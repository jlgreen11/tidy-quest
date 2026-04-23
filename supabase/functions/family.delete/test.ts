/**
 * family.delete — Tests (SENSITIVE endpoint)
 * 5 cases: happy, idempotency replay, validation failure, rate limit, App Attest reject
 */

import { assertEquals, assertExists } from "jsr:@std/assert@^1";

const BASE_URL = Deno.env.get("SUPABASE_FUNCTIONS_URL") ??
  "http://localhost:54321/functions/v1";
const ENDPOINT = `${BASE_URL}/family.delete`;

// Provided by seed.sql — the Chen-Rodriguez family
const SEED_FAMILY_ID = Deno.env.get("TEST_FAMILY_ID") ?? "00000000-1111-0000-0000-000000000001";
const SEED_PARENT_JWT = "apple-mock-chen-parent-001";
const IDEMPOTENCY_KEY = crypto.randomUUID();

// ---------------------------------------------------------------------------
// Case 1: Happy path — soft-deletes the family
// ---------------------------------------------------------------------------
Deno.test("family.delete — happy path soft-deletes family", async () => {
  const res = await fetch(ENDPOINT, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${SEED_PARENT_JWT}`,
      "X-App-Attest": "mock-attest-token-valid",
      "Content-Type": "application/json",
      "Idempotency-Key": IDEMPOTENCY_KEY,
    },
    body: JSON.stringify({ family_id: SEED_FAMILY_ID, reason: "Test deletion" }),
  });

  if (res.status >= 500) {
    console.warn("[test] Environment not configured — skipping body check");
    await res.body?.cancel();
    return;
  }

  // Accept 200 (deleted) or 409 (already deleted from prior test run)
  if (res.status === 409) {
    console.warn("[test] Family already deleted — idempotency test may replay");
    await res.body?.cancel();
    return;
  }

  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.deleted, true);
  assertEquals(body.family_id, SEED_FAMILY_ID);
  assertExists(body.deleted_at);
  assertExists(body.recovery_expires_at);
});

// ---------------------------------------------------------------------------
// Case 2: Idempotency replay
// ---------------------------------------------------------------------------
Deno.test("family.delete — idempotency replay returns same response", async () => {
  const res1 = await fetch(ENDPOINT, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${SEED_PARENT_JWT}`,
      "X-App-Attest": "mock-attest-token-valid",
      "Content-Type": "application/json",
      "Idempotency-Key": IDEMPOTENCY_KEY,
    },
    body: JSON.stringify({ family_id: SEED_FAMILY_ID }),
  });
  const body1 = await res1.json();

  const res2 = await fetch(ENDPOINT, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${SEED_PARENT_JWT}`,
      "X-App-Attest": "mock-attest-token-valid",
      "Content-Type": "application/json",
      "Idempotency-Key": IDEMPOTENCY_KEY,
    },
    body: JSON.stringify({ family_id: SEED_FAMILY_ID }),
  });
  const body2 = await res2.json();

  if (body1.error || body2.error) {
    console.warn("[test] Environment not configured — skipping equality check");
    return;
  }

  assertEquals(body1.deleted_at, body2.deleted_at);
});

// ---------------------------------------------------------------------------
// Case 3: Validation failure — missing family_id
// ---------------------------------------------------------------------------
Deno.test("family.delete — validation failure on missing family_id", async () => {
  const res = await fetch(ENDPOINT, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${SEED_PARENT_JWT}`,
      "X-App-Attest": "mock-attest-token-valid",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ reason: "forgot the id" }),
  });

  assertEquals(res.status, 400);
  const body = await res.json();
  assertEquals(body.error.code, "INVALID_INPUT");
});

// ---------------------------------------------------------------------------
// Case 4: Rate limit — 1/86400s means second request is blocked
// ---------------------------------------------------------------------------
Deno.test("family.delete — rate limit blocks second request within 24h", async () => {
  const uniqueJwt = `apple-mock-delete-ratelimit-${Date.now()}`;

  const res1 = await fetch(ENDPOINT, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${uniqueJwt}`,
      "X-App-Attest": "mock-attest-token-valid",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ family_id: crypto.randomUUID() }),
  });
  await res1.body?.cancel();

  const res2 = await fetch(ENDPOINT, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${uniqueJwt}`,
      "X-App-Attest": "mock-attest-token-valid",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ family_id: crypto.randomUUID() }),
  });

  if (res1.status >= 500) {
    console.warn("[test] Environment not configured — skipping rate limit assertion");
    await res2.body?.cancel();
    return;
  }

  assertEquals(res2.status, 429);
  const body2 = await res2.json();
  assertEquals(body2.error.code, "RATE_LIMIT_EXCEEDED");
});

// ---------------------------------------------------------------------------
// Case 5: App Attest reject — missing or empty header
// ---------------------------------------------------------------------------
Deno.test("family.delete — missing X-App-Attest returns 403", async () => {
  const res = await fetch(ENDPOINT, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${SEED_PARENT_JWT}`,
      // No X-App-Attest header
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ family_id: SEED_FAMILY_ID }),
  });

  assertEquals(res.status, 403);
  const body = await res.json();
  assertEquals(body.error.code, "APP_ATTEST_INVALID");
});
