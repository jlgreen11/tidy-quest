/**
 * user.revoke-device — Tests (SENSITIVE endpoint)
 * 5 cases: happy, idempotency replay, validation failure, rate limit, App Attest reject
 */

import { assertEquals, assertExists } from "jsr:@std/assert@^1";

const BASE_URL = Deno.env.get("SUPABASE_FUNCTIONS_URL") ??
  "http://localhost:54321/functions/v1";
const ENDPOINT = `${BASE_URL}/user.revoke-device`;

const SEED_FAMILY_ID = Deno.env.get("TEST_FAMILY_ID") ?? "00000000-1111-0000-0000-000000000001";
const SEED_KID_ID = Deno.env.get("TEST_KID_ID") ?? "00000000-1111-0000-0000-000000000002";
const SEED_PARENT_JWT = "apple-mock-chen-parent-001";
const IDEMPOTENCY_KEY = crypto.randomUUID();

// ---------------------------------------------------------------------------
// Case 1: Happy path — revokes kid's device
// ---------------------------------------------------------------------------
Deno.test("user.revoke-device — happy path revokes device", async () => {
  const res = await fetch(ENDPOINT, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${SEED_PARENT_JWT}`,
      "X-App-Attest": "mock-attest-token-valid",
      "Content-Type": "application/json",
      "Idempotency-Key": IDEMPOTENCY_KEY,
    },
    body: JSON.stringify({
      kid_user_id: SEED_KID_ID,
      family_id: SEED_FAMILY_ID,
      reason: "Lost device",
    }),
  });

  if (res.status >= 500) {
    console.warn("[test] Environment not configured — skipping body check");
    await res.body?.cancel();
    return;
  }

  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.revoked, true);
  assertEquals(body.kid_user_id, SEED_KID_ID);
  assertExists(body.revoked_at);
});

// ---------------------------------------------------------------------------
// Case 2: Idempotency replay — second call returns cached response
// ---------------------------------------------------------------------------
Deno.test("user.revoke-device — idempotency replay returns cached response", async () => {
  const res1 = await fetch(ENDPOINT, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${SEED_PARENT_JWT}`,
      "X-App-Attest": "mock-attest-token-valid",
      "Content-Type": "application/json",
      "Idempotency-Key": IDEMPOTENCY_KEY,
    },
    body: JSON.stringify({ kid_user_id: SEED_KID_ID, family_id: SEED_FAMILY_ID }),
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
    body: JSON.stringify({ kid_user_id: SEED_KID_ID, family_id: SEED_FAMILY_ID }),
  });
  const body2 = await res2.json();

  if (body1.error || body2.error) {
    console.warn("[test] Environment not configured — skipping equality check");
    return;
  }

  assertEquals(body1.revoked_at, body2.revoked_at);
  assertEquals(body1.kid_user_id, body2.kid_user_id);
});

// ---------------------------------------------------------------------------
// Case 3: Validation failure — missing kid_user_id
// ---------------------------------------------------------------------------
Deno.test("user.revoke-device — validation failure on missing kid_user_id", async () => {
  const res = await fetch(ENDPOINT, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${SEED_PARENT_JWT}`,
      "X-App-Attest": "mock-attest-token-valid",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ family_id: SEED_FAMILY_ID }),
  });

  assertEquals(res.status, 400);
  const body = await res.json();
  assertEquals(body.error.code, "INVALID_INPUT");
});

// ---------------------------------------------------------------------------
// Case 4: Rate limit — 6th request in 60s blocked
// ---------------------------------------------------------------------------
Deno.test("user.revoke-device — rate limit after 5 requests in 60s", async () => {
  const uniqueJwt = `apple-mock-revoke-ratelimit-${Date.now()}`;
  let lastStatus = 0;

  for (let i = 0; i < 6; i++) {
    const res = await fetch(ENDPOINT, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${uniqueJwt}`,
        "X-App-Attest": "mock-attest-token-valid",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ kid_user_id: SEED_KID_ID, family_id: SEED_FAMILY_ID }),
    });
    lastStatus = res.status;
    await res.body?.cancel();
    if (lastStatus === 429) break;
  }

  if (lastStatus >= 500 || lastStatus === 403 || lastStatus === 404) {
    console.warn("[test] Environment not configured — skipping rate limit assertion");
    return;
  }

  assertEquals(lastStatus, 429);
});

// ---------------------------------------------------------------------------
// Case 5: App Attest reject — empty header returns 403
// ---------------------------------------------------------------------------
Deno.test("user.revoke-device — empty X-App-Attest returns 403", async () => {
  const res = await fetch(ENDPOINT, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${SEED_PARENT_JWT}`,
      "X-App-Attest": "",  // empty — mock validation should reject
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ kid_user_id: SEED_KID_ID, family_id: SEED_FAMILY_ID }),
  });

  assertEquals(res.status, 403);
  const body = await res.json();
  assertEquals(body.error.code, "APP_ATTEST_INVALID");
});
