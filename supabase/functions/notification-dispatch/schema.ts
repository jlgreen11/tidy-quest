/**
 * TidyQuest — notification.dispatch schemas
 * supabase/functions/notification.dispatch/schema.ts
 *
 * Internal function: called by pg_cron webhook / pg_net trigger.
 * Reads pending rows from the notification table and dispatches APNs push.
 */

import { z } from "npm:zod@3";
import { NotificationKind } from "../_shared/types.ts";

// ---------------------------------------------------------------------------
// Request schema — pg_cron can POST an empty body; we also accept a list of
// notification IDs to process (for targeted re-dispatch or testing).
// ---------------------------------------------------------------------------

export const DispatchRequestSchema = z.object({
  /** Limit how many notifications to process per invocation (default 50). */
  limit: z.number().int().min(1).max(500).optional().default(50),
  /** If supplied, process only these specific notification IDs. */
  notification_ids: z.array(z.string().uuid()).max(100).optional(),
});

export type DispatchRequest = z.infer<typeof DispatchRequestSchema>;

// ---------------------------------------------------------------------------
// APNs payload builder types
// ---------------------------------------------------------------------------

/** APNs aps dictionary */
export interface ApnsAps {
  alert:            ApnsAlert | string;
  badge?:           number;
  sound?:           string;
  "content-available"?: 1;
  "mutable-content"?:   1;
  "interruption-level"?: "passive" | "active" | "time-sensitive" | "critical";
  "thread-id"?:     string;
  "category"?:      string;
}

/** Rich APNs alert object */
export interface ApnsAlert {
  title:         string;
  subtitle?:     string;
  body:          string;
  "launch-image"?: string;
}

/** Full APNs payload */
export interface ApnsPayload {
  aps:            ApnsAps;
  /** Custom data fields passed to the app's notification handler */
  [key: string]: unknown;
}

// ---------------------------------------------------------------------------
// Notification row (from DB)
// ---------------------------------------------------------------------------

export interface NotificationRow {
  id:         string;
  family_id:  string;
  user_id:    string;
  kind:       NotificationKind;
  payload:    Record<string, unknown>;
  sent_at:    string | null;
  created_at: string;
}

// ---------------------------------------------------------------------------
// Dispatch result per notification
// ---------------------------------------------------------------------------

export interface DispatchResult {
  notification_id: string;
  status:          "sent" | "failed" | "no_token" | "mock";
  apns_message_id?: string;
  error?:           string;
}

// ---------------------------------------------------------------------------
// Response type
// ---------------------------------------------------------------------------

export interface DispatchResponse {
  processed:  number;
  sent:       number;
  failed:     number;
  no_token:   number;
  results:    DispatchResult[];
}
