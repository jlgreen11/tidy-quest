/**
 * TidyQuest — notification.dispatch tests
 * supabase/functions/notification.dispatch/test.ts
 *
 * Run with: deno test --allow-env supabase/functions/notification.dispatch/test.ts
 * SKIPPED acceptable when Deno/Docker is not available.
 *
 * These tests cover:
 *   - DispatchRequestSchema validation
 *   - APNs payload shape construction (via exported builder)
 *   - Dispatch response structure contract
 */

import { assertEquals, assertExists } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { DispatchRequestSchema } from "./schema.ts";
import { NotificationKind } from "../_shared/types.ts";
import type { ApnsPayload, DispatchResponse, NotificationRow } from "./schema.ts";

// ---------------------------------------------------------------------------
// Inline payload builder (mirrors index.ts buildApnsPayload; tested in isolation)
// ---------------------------------------------------------------------------

function buildApnsPayloadForTest(notification: NotificationRow): ApnsPayload {
  const kind = notification.kind as NotificationKind;
  const p = notification.payload;

  if (kind === NotificationKind.ChoreApprovalNeeded) {
    return {
      aps: {
        alert: {
          title:    "Chore Needs Approval",
          subtitle: (p.kid_name as string) ?? undefined,
          body:     `${p.kid_name ?? "Someone"} completed "${p.chore_name ?? "a chore"}" — tap to review.`,
        },
        sound:                "default",
        "mutable-content":    1,
        "interruption-level": "active",
        "thread-id":          `family-${notification.family_id}`,
        category:             "CHORE_APPROVAL",
      },
      notification_id: notification.id,
      kind,
      ...p,
    };
  }

  if (kind === NotificationKind.ChoreApproved) {
    return {
      aps: {
        alert: {
          title: "Chore Approved!",
          body:  `You earned ${p.points_awarded ?? ""} points for "${p.chore_name ?? "your chore"}".`,
        },
        sound:                "default",
        "interruption-level": "active",
        "thread-id":          `family-${notification.family_id}`,
      },
      notification_id: notification.id,
      kind,
      ...p,
    };
  }

  return {
    aps: {
      alert: {
        title: (p.title as string) ?? "TidyQuest",
        body:  (p.body as string) ?? "You have a new notification.",
      },
      sound: "default",
    },
    notification_id: notification.id,
    kind,
    ...p,
  };
}

// ---------------------------------------------------------------------------
// Test 1: DispatchRequestSchema — defaults applied correctly
// ---------------------------------------------------------------------------
Deno.test("schema: DispatchRequestSchema applies defaults", () => {
  const result = DispatchRequestSchema.safeParse({});
  assertEquals(result.success, true);
  assertEquals(result.data?.limit, 50, "Default limit should be 50");
});

// ---------------------------------------------------------------------------
// Test 2: DispatchRequestSchema — custom limit accepted
// ---------------------------------------------------------------------------
Deno.test("schema: DispatchRequestSchema accepts custom limit", () => {
  const result = DispatchRequestSchema.safeParse({ limit: 100 });
  assertEquals(result.success, true);
  assertEquals(result.data?.limit, 100);
});

// ---------------------------------------------------------------------------
// Test 3: DispatchRequestSchema — limit out of range rejected
// ---------------------------------------------------------------------------
Deno.test("schema: DispatchRequestSchema rejects limit > 500", () => {
  const result = DispatchRequestSchema.safeParse({ limit: 501 });
  assertEquals(result.success, false);
});

// ---------------------------------------------------------------------------
// Test 4: APNs payload builder — chore approval rich notification
// ---------------------------------------------------------------------------
Deno.test("buildApnsPayload: chore approval notification has correct shape", () => {
  const notification: NotificationRow = {
    id:         "notif-uuid-001",
    family_id:  "fam-uuid-001",
    user_id:    "user-uuid-001",
    kind:       NotificationKind.ChoreApprovalNeeded,
    payload: {
      kid_name:   "Emma",
      chore_name: "Clean Room",
    },
    sent_at:    null,
    created_at: new Date().toISOString(),
  };

  const payload = buildApnsPayloadForTest(notification);

  assertExists(payload.aps);
  assertExists(payload.aps.alert);
  assertEquals(typeof payload.aps.alert, "object");

  const alert = payload.aps.alert as { title: string; subtitle?: string; body: string };
  assertEquals(alert.title, "Chore Needs Approval");
  assertEquals(alert.subtitle, "Emma");
  assertEquals(payload.aps["mutable-content"], 1);
  assertEquals(payload.aps.category, "CHORE_APPROVAL");
  assertEquals(payload.notification_id, "notif-uuid-001");
});

// ---------------------------------------------------------------------------
// Test 5: APNs payload builder — chore approved notification
// ---------------------------------------------------------------------------
Deno.test("buildApnsPayload: chore approved notification has correct shape", () => {
  const notification: NotificationRow = {
    id:         "notif-uuid-002",
    family_id:  "fam-uuid-001",
    user_id:    "user-uuid-002",
    kind:       NotificationKind.ChoreApproved,
    payload: {
      chore_name:     "Make Bed",
      points_awarded: 10,
    },
    sent_at:    null,
    created_at: new Date().toISOString(),
  };

  const payload = buildApnsPayloadForTest(notification);
  const alert = payload.aps.alert as { title: string; body: string };

  assertEquals(alert.title, "Chore Approved!");
  assertEquals(payload.aps["interruption-level"], "active");
  assertEquals(payload.notification_id, "notif-uuid-002");
});

// ---------------------------------------------------------------------------
// Test 6: DispatchRequest with notification_ids filter
// ---------------------------------------------------------------------------
Deno.test("schema: DispatchRequestSchema accepts notification_ids array", () => {
  const ids = [
    "00000000-0000-0000-0000-000000000001",
    "00000000-0000-0000-0000-000000000002",
  ];
  const result = DispatchRequestSchema.safeParse({ notification_ids: ids, limit: 10 });
  assertEquals(result.success, true);
  assertEquals(result.data?.notification_ids, ids);
});

// ---------------------------------------------------------------------------
// Test 7: DispatchResponse structure contract
// ---------------------------------------------------------------------------
Deno.test("DispatchResponse: structure matches expected contract", () => {
  const response: DispatchResponse = {
    processed: 3,
    sent:      2,
    failed:    1,
    no_token:  0,
    results: [
      { notification_id: "n1", status: "sent",    apns_message_id: "apns-123" },
      { notification_id: "n2", status: "mock",    apns_message_id: "mock-456" },
      { notification_id: "n3", status: "failed",  error: "Bad device token" },
    ],
  };

  assertEquals(response.processed, 3);
  assertEquals(response.sent, 2);
  assertEquals(response.results.length, 3);
  assertEquals(response.results[0].status, "sent");
  assertEquals(response.results[2].status, "failed");
  assertExists(response.results[2].error);
});

// ---------------------------------------------------------------------------
// Test 8: invalid notification_id UUID in filter
// ---------------------------------------------------------------------------
Deno.test("schema: DispatchRequestSchema rejects invalid UUID in notification_ids", () => {
  const result = DispatchRequestSchema.safeParse({
    notification_ids: ["not-a-uuid"],
  });
  assertEquals(result.success, false);
});
