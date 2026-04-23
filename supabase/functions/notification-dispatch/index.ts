/**
 * TidyQuest — notification.dispatch edge function (internal)
 * supabase/functions/notification.dispatch/index.ts
 *
 * POST /functions/v1/notification.dispatch
 * Auth:      service_role only (X-Internal-Secret header)
 * Visibility: not exposed to clients; called by pg_cron / pg_net webhook
 *
 * For each pending notification row:
 *   1. Load the target user's APNs device tokens.
 *   2. Build the APNs payload (rich for approvals, simple for others).
 *   3. POST to APNs via HTTP/2 with JWT auth.
 *   4. On success: update notification.sent_at.
 *   5. On failure (bad device token): clear token, mark notification failed.
 *
 * MOCK MODE: if APNS_AUTH_KEY env var is absent, log payload + return success.
 * Real APNs goes live once Apple Developer account credentials are available.
 *
 * Notification failure tracking: a notification row gets a custom "failed" state
 * via the payload column (sent_at stays null, payload.dispatch_failed = true)
 * because the schema has no explicit failed status column.
 */

import { createClient } from "npm:@supabase/supabase-js@2";
import { internalError } from "../_shared/errors.ts";
import { NotificationKind } from "../_shared/types.ts";
import {
  ApnsPayload,
  DispatchRequest,
  DispatchRequestSchema,
  DispatchResponse,
  DispatchResult,
  NotificationRow,
} from "./schema.ts";

const ENDPOINT = "notification.dispatch";

// ---------------------------------------------------------------------------
// APNs JWT generation
// TODO: replace with real ES256 JWT signing using APNS_AUTH_KEY
// ---------------------------------------------------------------------------

/**
 * Generate an APNs provider authentication token.
 * Real implementation: ES256 JWT signed with the .p8 auth key.
 * Mock: returns a placeholder string.
 */
async function generateApnsJwt(
  keyId: string,
  teamId: string,
  authKey: string,
): Promise<string> {
  // TODO: implement real ES256 JWT signing
  //   1. header = base64url({ alg: "ES256", kid: keyId })
  //   2. claims = base64url({ iss: teamId, iat: Math.floor(Date.now()/1000) })
  //   3. sign header.claims with ECDSA P-256 private key (authKey = .p8 content)
  //   4. return `${header}.${claims}.${signature}`
  console.log("[TODO] Real APNs JWT signing — using mock token");
  // Suppress "unused" warnings in mock path
  void keyId; void teamId; void authKey;
  return `mock-apns-jwt-${teamId}-${Date.now()}`;
}

// ---------------------------------------------------------------------------
// APNs payload builder
// ---------------------------------------------------------------------------

function buildApnsPayload(notification: NotificationRow): ApnsPayload {
  const kind = notification.kind as NotificationKind;
  const p = notification.payload;

  // Rich notifications for approval flows
  if (
    kind === NotificationKind.ChoreApprovalNeeded ||
    kind === NotificationKind.RedemptionApprovalNeeded
  ) {
    const isChore = kind === NotificationKind.ChoreApprovalNeeded;
    return {
      aps: {
        alert: {
          title:    isChore ? "Chore Needs Approval" : "Reward Requested",
          subtitle: (p.kid_name as string) ?? undefined,
          body:     isChore
            ? `${p.kid_name ?? "Someone"} completed "${p.chore_name ?? "a chore"}" — tap to review.`
            : `${p.kid_name ?? "Someone"} wants "${p.reward_name ?? "a reward"}".`,
        },
        sound:                  "default",
        "mutable-content":      1,
        "interruption-level":   "active",
        "thread-id":            `family-${notification.family_id}`,
        category:               isChore ? "CHORE_APPROVAL" : "REDEMPTION_APPROVAL",
      },
      notification_id: notification.id,
      kind,
      ...p,
    };
  }

  // Approval outcome notifications (simple)
  if (
    kind === NotificationKind.ChoreApproved ||
    kind === NotificationKind.ChoreRejected
  ) {
    const approved = kind === NotificationKind.ChoreApproved;
    return {
      aps: {
        alert: {
          title: approved ? "Chore Approved!" : "Chore Not Approved",
          body:  approved
            ? `You earned ${p.points_awarded ?? ""} points for "${p.chore_name ?? "your chore"}".`
            : `"${p.chore_name ?? "Your chore"}" was not approved. ${p.reason ?? ""}`.trim(),
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

  if (kind === NotificationKind.RedemptionApproved) {
    return {
      aps: {
        alert: {
          title: "Reward Approved!",
          body:  `Enjoy your "${p.reward_name ?? "reward"}".`,
        },
        sound:                "default",
        "interruption-level": "active",
      },
      notification_id: notification.id,
      kind,
      ...p,
    };
  }

  if (kind === NotificationKind.RedemptionDenied) {
    return {
      aps: {
        alert: {
          title: "Reward Request Declined",
          body:  (p.reason as string) ?? "Your reward request was not approved.",
        },
        sound:                "default",
        "interruption-level": "passive",
      },
      notification_id: notification.id,
      kind,
      ...p,
    };
  }

  if (kind === NotificationKind.FineIssued) {
    return {
      aps: {
        alert: {
          title: "Points Deducted",
          body:  `${p.amount ?? ""} points were deducted. ${p.reason ?? ""}`.trim(),
        },
        sound:                "default",
        "interruption-level": "active",
      },
      notification_id: notification.id,
      kind,
      ...p,
    };
  }

  if (kind === NotificationKind.StreakMilestone) {
    return {
      aps: {
        alert: {
          title: "Streak Milestone!",
          body:  `${p.streak_length ?? ""} day streak on "${p.chore_name ?? "a chore"}". Keep it up!`,
        },
        sound:                "default",
        "interruption-level": "passive",
      },
      notification_id: notification.id,
      kind,
      ...p,
    };
  }

  if (kind === NotificationKind.SubscriptionExpiring) {
    return {
      aps: {
        alert: {
          title: "Subscription Expiring Soon",
          body:  `Your TidyQuest subscription expires ${p.expires_in ?? "soon"}. Renew to keep all features.`,
        },
        sound:                "default",
        "interruption-level": "time-sensitive",
      },
      notification_id: notification.id,
      kind,
      ...p,
    };
  }

  // Generic / system fallback
  return {
    aps: {
      alert: {
        title: (p.title as string) ?? "TidyQuest",
        body:  (p.body as string) ?? "You have a new notification.",
      },
      sound:                "default",
      "interruption-level": "passive",
    },
    notification_id: notification.id,
    kind,
    ...p,
  };
}

// ---------------------------------------------------------------------------
// APNs HTTP/2 dispatch (mock if APNS_AUTH_KEY is absent)
// ---------------------------------------------------------------------------

interface ApnsSendResult {
  success:    boolean;
  messageId?: string;
  reason?:    string;
  /** APNs status code (200 = ok, 410 = unregistered/bad token, etc.) */
  apnsStatus?: number;
}

async function sendToApns(
  deviceToken: string,
  payload: ApnsPayload,
  bundleId: string,
): Promise<ApnsSendResult> {
  const apnsKeyId   = Deno.env.get("APNS_KEY_ID");
  const apnsTeamId  = Deno.env.get("APNS_TEAM_ID");
  const apnsAuthKey = Deno.env.get("APNS_AUTH_KEY");

  // -------------------------------------------------------------------
  // MOCK PATH: APNS_AUTH_KEY absent → log and return success
  // -------------------------------------------------------------------
  if (!apnsAuthKey || !apnsKeyId || !apnsTeamId) {
    console.log("[notification.dispatch] MOCK APNs — credentials absent, logging payload:", {
      device_token: deviceToken.slice(0, 8) + "...",
      bundle_id:    bundleId,
      payload,
    });
    return { success: true, messageId: `mock-${crypto.randomUUID()}` };
  }

  // -------------------------------------------------------------------
  // REAL PATH: POST to APNs with JWT auth
  // TODO: This path goes live after Apple Developer account is active.
  // -------------------------------------------------------------------
  const jwt = await generateApnsJwt(apnsKeyId, apnsTeamId, apnsAuthKey);

  // APNs production host. Use 'api.sandbox.push.apple.com' for sandbox.
  const apnsHost = "api.push.apple.com";
  const apnsPath = `/3/device/${deviceToken}`;
  const apnsUrl  = `https://${apnsHost}${apnsPath}`;

  const apsPayloadJson = JSON.stringify(payload);

  try {
    const resp = await fetch(apnsUrl, {
      method: "POST",
      headers: {
        "Authorization":  `Bearer ${jwt}`,
        "Content-Type":   "application/json",
        "apns-topic":     bundleId,
        "apns-push-type": "alert",
        "apns-priority":  "10",
        "apns-expiration": String(Math.floor(Date.now() / 1000) + 86400), // expire in 24h
      },
      body: apsPayloadJson,
    });

    const messageId = resp.headers.get("apns-id") ?? undefined;

    if (resp.status === 200) {
      return { success: true, messageId, apnsStatus: 200 };
    }

    const body = await resp.json().catch(() => ({}));
    const reason: string = (body as Record<string, unknown>).reason as string ?? "Unknown";

    return {
      success:    false,
      reason,
      apnsStatus: resp.status,
      messageId,
    };
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("[notification.dispatch] APNs fetch error:", message);
    return { success: false, reason: message };
  }
}

// ---------------------------------------------------------------------------
// Main handler
// ---------------------------------------------------------------------------

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ error: { code: "METHOD_NOT_ALLOWED", message: "Use POST" } }),
      { status: 405, headers: { "Content-Type": "application/json" } },
    );
  }

  // Service-role-only: validate shared internal secret
  const internalSecret = Deno.env.get("INTERNAL_FUNCTION_SECRET");
  const providedSecret  = req.headers.get("X-Internal-Secret");
  if (internalSecret && providedSecret !== internalSecret) {
    return new Response(
      JSON.stringify({ error: { code: "UNAUTHORIZED", message: "service_role access required" } }),
      { status: 401, headers: { "Content-Type": "application/json" } },
    );
  }

  // Build service-role client
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceKey  = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const supabase = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false },
  });

  // Parse request body (optional — pg_cron may POST empty)
  let dispatchReq: DispatchRequest = { limit: 50 };
  try {
    const text = await req.text();
    if (text.trim()) {
      const parsed = DispatchRequestSchema.safeParse(JSON.parse(text));
      if (parsed.success) {
        dispatchReq = parsed.data;
      }
    }
  } catch {
    // Empty or malformed body — use defaults
  }

  // -------------------------------------------------------------------------
  // Query pending notifications
  // -------------------------------------------------------------------------
  let notifQuery = supabase
    .from("notification")
    .select("id, family_id, user_id, kind, payload, sent_at, created_at")
    .is("sent_at", null)
    .not("payload->dispatch_failed", "eq", true) // skip previously failed
    .order("created_at", { ascending: true })
    .limit(dispatchReq.limit);

  if (dispatchReq.notification_ids?.length) {
    notifQuery = notifQuery.in("id", dispatchReq.notification_ids);
  }

  const { data: notifications, error: notifErr } = await notifQuery;

  if (notifErr) {
    console.error(`[${ENDPOINT}] notification query failed:`, notifErr);
    return internalError();
  }

  const rows = (notifications ?? []) as NotificationRow[];
  const results: DispatchResult[] = [];
  let sent = 0, failed = 0, noToken = 0;

  // -------------------------------------------------------------------------
  // Process each notification
  // -------------------------------------------------------------------------
  for (const notification of rows) {
    // Load device tokens for this user
    const { data: tokenRows, error: tokenErr } = await supabase
      .from("device_token")
      .select("id, apns_token, app_bundle")
      .eq("user_id", notification.user_id);

    if (tokenErr) {
      console.error(`[${ENDPOINT}] token lookup error for user ${notification.user_id}:`, tokenErr);
      results.push({
        notification_id: notification.id,
        status: "failed",
        error: "Token lookup failed",
      });
      failed++;
      continue;
    }

    if (!tokenRows || tokenRows.length === 0) {
      results.push({ notification_id: notification.id, status: "no_token" });
      noToken++;
      continue;
    }

    // Build APNs payload once; send to all registered devices for this user
    const apnsPayload = buildApnsPayload(notification);

    // Determine bundle IDs to target based on the user's app_bundle value
    // For parents: com.jlgreen11.tidyquest.parent
    // For kids:    com.jlgreen11.tidyquest.kid
    let notificationSent = false;
    let lastError: string | undefined;

    for (const tokenRow of tokenRows) {
      const bundleId = tokenRow.app_bundle === "parent"
        ? "com.jlgreen11.tidyquest.parent"
        : "com.jlgreen11.tidyquest.kid";

      const sendResult = await sendToApns(
        tokenRow.apns_token,
        apnsPayload,
        bundleId,
      );

      if (sendResult.success) {
        notificationSent = true;

        results.push({
          notification_id: notification.id,
          status: Deno.env.get("APNS_AUTH_KEY") ? "sent" : "mock",
          apns_message_id: sendResult.messageId,
        });
        sent++;
      } else {
        lastError = `${sendResult.reason} (HTTP ${sendResult.apnsStatus ?? "??"})`;

        // APNs 410 = device token invalid/unregistered — clear it
        if (sendResult.apnsStatus === 410) {
          const { error: clearErr } = await supabase
            .from("device_token")
            .delete()
            .eq("id", tokenRow.id);
          if (clearErr) {
            console.error(`[${ENDPOINT}] failed to clear bad token:`, clearErr);
          } else {
            console.log(`[${ENDPOINT}] cleared invalid APNs token for user ${notification.user_id}`);
          }
        }
      }
    }

    if (!notificationSent) {
      // All tokens failed — mark notification as dispatch_failed
      const { error: markErr } = await supabase
        .from("notification")
        .update({
          payload: { ...notification.payload, dispatch_failed: true, dispatch_error: lastError },
        })
        .eq("id", notification.id);

      if (markErr) {
        console.error(`[${ENDPOINT}] failed to mark notification as failed:`, markErr);
      }

      results.push({
        notification_id: notification.id,
        status: "failed",
        error: lastError,
      });
      failed++;
      continue;
    }

    // Mark notification as sent (first successful send wins)
    const { error: updateErr } = await supabase
      .from("notification")
      .update({ sent_at: new Date().toISOString() })
      .eq("id", notification.id);

    if (updateErr) {
      console.error(`[${ENDPOINT}] failed to update sent_at:`, updateErr);
    }
  }

  const response: DispatchResponse = {
    processed: rows.length,
    sent,
    failed,
    no_token: noToken,
    results,
  };

  console.log(`[${ENDPOINT}] dispatch complete:`, {
    processed: rows.length,
    sent,
    failed,
    no_token: noToken,
  });

  return new Response(JSON.stringify(response), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
