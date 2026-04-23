/**
 * TidyQuest — photo.purge-expired tests
 * supabase/functions/photo.purge-expired/test.ts
 *
 * Run with: deno test --allow-env supabase/functions/photo.purge-expired/test.ts
 * SKIPPED acceptable when Deno/Docker is not available.
 */

import { assertEquals, assertExists } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  PurgeRequestSchema,
  PurgeResponse,
  PurgeItemResult,
} from "./schema.ts";

// ---------------------------------------------------------------------------
// Test 1: PurgeRequestSchema — empty body (pg_cron pattern) uses defaults
// ---------------------------------------------------------------------------
Deno.test("schema: PurgeRequestSchema applies defaults for empty object", () => {
  const result = PurgeRequestSchema.safeParse({});
  assertEquals(result.success, true);
  assertEquals(result.data?.dry_run, false, "dry_run should default to false");
  assertEquals(result.data?.limit, 200, "limit should default to 200");
});

// ---------------------------------------------------------------------------
// Test 2: PurgeRequestSchema — dry_run flag accepted
// ---------------------------------------------------------------------------
Deno.test("schema: PurgeRequestSchema accepts dry_run=true", () => {
  const result = PurgeRequestSchema.safeParse({ dry_run: true });
  assertEquals(result.success, true);
  assertEquals(result.data?.dry_run, true);
});

// ---------------------------------------------------------------------------
// Test 3: PurgeRequestSchema — custom limit
// ---------------------------------------------------------------------------
Deno.test("schema: PurgeRequestSchema accepts custom limit within range", () => {
  const result = PurgeRequestSchema.safeParse({ limit: 500 });
  assertEquals(result.success, true);
  assertEquals(result.data?.limit, 500);
});

// ---------------------------------------------------------------------------
// Test 4: PurgeRequestSchema — limit over cap rejected
// ---------------------------------------------------------------------------
Deno.test("schema: PurgeRequestSchema rejects limit > 1000", () => {
  const result = PurgeRequestSchema.safeParse({ limit: 1001 });
  assertEquals(result.success, false);
});

// ---------------------------------------------------------------------------
// Test 5: PurgeRequestSchema — null body (pg_cron POST) treated as default
// ---------------------------------------------------------------------------
Deno.test("schema: PurgeRequestSchema handles undefined input (pg_cron empty body)", () => {
  // PurgeRequestSchema is optional+default — undefined input should give defaults
  const result = PurgeRequestSchema.safeParse(undefined);
  assertEquals(result.success, true);
  assertEquals(result.data?.dry_run, false);
  assertEquals(result.data?.limit, 200);
});

// ---------------------------------------------------------------------------
// Test 6: PurgeResponse structure contract
// ---------------------------------------------------------------------------
Deno.test("PurgeResponse: matches expected structure", () => {
  const results: PurgeItemResult[] = [
    {
      audit_log_id:      "audit-1",
      chore_instance_id: "ci-1",
      proof_photo_id:    "photo-uuid-1",
      status:            "deleted",
    },
    {
      audit_log_id:      "audit-2",
      chore_instance_id: "ci-2",
      proof_photo_id:    "photo-uuid-2",
      status:            "not_found",
    },
    {
      audit_log_id:      "audit-3",
      chore_instance_id: "ci-3",
      proof_photo_id:    "photo-uuid-3",
      status:            "failed",
      error:             "Storage error: connection timeout",
    },
  ];

  const response: PurgeResponse = {
    processed: 3,
    deleted:   1,
    not_found: 1,
    failed:    1,
    dry_run:   false,
    results,
  };

  assertEquals(response.processed, 3);
  assertEquals(response.deleted, 1);
  assertEquals(response.not_found, 1);
  assertEquals(response.failed, 1);
  assertEquals(response.dry_run, false);
  assertEquals(response.results.length, 3);

  const failedResult = response.results.find((r) => r.status === "failed");
  assertExists(failedResult);
  assertExists(failedResult.error);
});

// ---------------------------------------------------------------------------
// Test 7: dry_run PurgeItemResult has correct status
// ---------------------------------------------------------------------------
Deno.test("PurgeItemResult: dry_run status is valid", () => {
  const item: PurgeItemResult = {
    audit_log_id:      "audit-dry",
    chore_instance_id: "ci-dry",
    proof_photo_id:    "photo-dry",
    status:            "dry_run",
  };

  assertEquals(item.status, "dry_run");
  assertEquals(item.error, undefined);
});

// ---------------------------------------------------------------------------
// Test 8: PurgeRequestSchema — limit=0 rejected (min=1)
// ---------------------------------------------------------------------------
Deno.test("schema: PurgeRequestSchema rejects limit=0", () => {
  const result = PurgeRequestSchema.safeParse({ limit: 0 });
  assertEquals(result.success, false, "Limit 0 must be rejected (min is 1)");
});
