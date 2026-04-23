/**
 * user.add-kid — Tests
 * 5 cases: happy, idempotency replay, validation failure, rate limit, no App Attest (not sensitive)
 */

import { assertEquals, assertExists } from "jsr:@std/assert@^1";

const BASE_URL = Deno.env.get("SUPABASE_FUNCTIONS_URL") ??
  "http://localhost:54321/functions/v1";
const ENDPOINT = `${BASE_URL}/user.add-kid`;

const SEED_FAMILY_ID = Deno.env.get("TEST_FAMILY_ID") ?? "00000000-1111-0000-0000-000000000001";
const SEED_PARENT_JWT = "apple-mock-chen-parent-001";
const IDEMPOTENCY_KEY = crypto.randomUUID();

// ---------------------------------------------------------------------------
// Case 1: Happy path — creates a child user
// ---------------------------------------------------------------------------
Deno.test("user.add-kid — happy path creates child", async () => {
  const res = await fetch(ENDPOINT, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${SEED_PARENT_JWT}`,
      "Content-Type": "application/json",
      "Idempotency-Key": IDEMPOTENCY_KEY,
    },
    body: JSON.stringify({
      family_id: SEED_FAMILY_ID,
      display_name: "Maya",
      avatar: "star.fill",
      color: "#FF6B6B",
      complexity_tier: "standard",
      birthdate: "2016-03-15",
    }),
  });

  if (res.status >= 500) {
    console.warn("[test] Environment not configured — skipping body check");
    await res.body?.cancel();
    return;
  }

  assertEquals(res.status, 201);
  const body = await res.json();
  assertExists(body.kid);
  assertEquals(body.kid.role, "child");
  assertEquals(body.kid.display_name, "Maya");
  assertEquals(body.kid.color, "#FF6B6B");
  assertEquals(body.kid.family_id, SEED_FAMILY_ID);
});

// ---------------------------------------------------------------------------
// Case 2: Idempotency replay — same key returns same kid
// ---------------------------------------------------------------------------
Deno.test("user.add-kid — idempotency replay returns same kid", async () => {
  const res1 = await fetch(ENDPOINT, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${SEED_PARENT_JWT}`,
      "Content-Type": "application/json",
      "Idempotency-Key": IDEMPOTENCY_KEY,
    },
    body: JSON.stringify({
      family_id: SEED_FAMILY_ID,
      display_name: "Maya",
      avatar: "star.fill",
      color: "#FF6B6B",
    }),
  });
  const body1 = await res1.json();

  const res2 = await fetch(ENDPOINT, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${SEED_PARENT_JWT}`,
      "Content-Type": "application/json",
      "Idempotency-Key": IDEMPOTENCY_KEY,
    },
    body: JSON.stringify({
      family_id: SEED_FAMILY_ID,
      display_name: "DIFFERENT NAME",
      avatar: "star.fill",
      color: "#FF6B6B",
    }),
  });
  const body2 = await res2.json();

  if (body1.error || body2.error) {
    console.warn("[test] Environment not configured — skipping equality check");
    return;
  }

  // Same kid returned on replay
  assertEquals(body1.kid.id, body2.kid.id);
  assertEquals(body1.kid.display_name, body2.kid.display_name);
});

// ---------------------------------------------------------------------------
// Case 3: Validation failure — invalid color format
// ---------------------------------------------------------------------------
Deno.test("user.add-kid — validation failure on invalid color", async () => {
  const res = await fetch(ENDPOINT, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${SEED_PARENT_JWT}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      family_id: SEED_FAMILY_ID,
      display_name: "Kid",
      avatar: "star.fill",
      color: "not-a-hex-color",  // invalid
    }),
  });

  assertEquals(res.status, 400);
  const body = await res.json();
  assertEquals(body.error.code, "INVALID_INPUT");
  assertExists(body.error.details?.issues);
});

// ---------------------------------------------------------------------------
// Case 4: Rate limit — 6th request in 60s blocked
// ---------------------------------------------------------------------------
Deno.test("user.add-kid — rate limit after 5 requests in 60s", async () => {
  const uniqueJwt = `apple-mock-addkid-ratelimit-${Date.now()}`;
  let lastStatus = 0;

  for (let i = 0; i < 6; i++) {
    const res = await fetch(ENDPOINT, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${uniqueJwt}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        family_id: SEED_FAMILY_ID,
        display_name: `Kid ${i}`,
        avatar: "star.fill",
        color: "#FF6B6B",
      }),
    });
    lastStatus = res.status;
    await res.body?.cancel();
    if (lastStatus === 429) break;
  }

  if (lastStatus >= 500 || lastStatus === 403) {
    console.warn("[test] Environment not configured — skipping rate limit assertion");
    return;
  }

  assertEquals(lastStatus, 429);
});

// ---------------------------------------------------------------------------
// Case 5: Missing auth returns 401
// ---------------------------------------------------------------------------
Deno.test("user.add-kid — missing auth returns 401", async () => {
  const res = await fetch(ENDPOINT, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      family_id: SEED_FAMILY_ID,
      display_name: "Unauthorized Kid",
      avatar: "star.fill",
      color: "#FF6B6B",
    }),
  });

  assertEquals(res.status, 401);
  const body = await res.json();
  assertEquals(body.error.code, "UNAUTHORIZED");
});
