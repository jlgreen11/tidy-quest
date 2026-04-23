/**
 * TidyQuest — photo.purge-expired schemas
 * supabase/functions/photo.purge-expired/schema.ts
 *
 * Service-role only. Called daily at 03:00 UTC by pg_cron.
 * Deletes Storage objects for chore_instance proof photos older than 7 days.
 */

import { z } from "npm:zod@3";

// ---------------------------------------------------------------------------
// Request schema — pg_cron posts an empty body; accept optional dry_run flag.
// ---------------------------------------------------------------------------

export const PurgeRequestSchema = z.object({
  /**
   * If true, log what would be deleted but skip the actual Storage delete.
   * Useful for testing without destroying data.
   */
  dry_run: z.boolean().optional().default(false),
  /** Max rows to process per invocation (default 200; safety cap). */
  limit: z.number().int().min(1).max(1000).optional().default(200),
}).optional().default({});

export type PurgeRequest = z.infer<typeof PurgeRequestSchema>;

// ---------------------------------------------------------------------------
// Audit row shape (queried from audit_log written by fn_photo_purge)
// ---------------------------------------------------------------------------

export interface PhotoPurgeAuditRow {
  id:        string;
  family_id: string | null;
  payload:   {
    proof_photo_id:    string;
    chore_instance_id: string;
    user_id:           string;
  };
  created_at: string;
}

// ---------------------------------------------------------------------------
// Per-item purge result
// ---------------------------------------------------------------------------

export interface PurgeItemResult {
  audit_log_id:      string;
  chore_instance_id: string;
  proof_photo_id:    string;
  status:            "deleted" | "not_found" | "failed" | "dry_run";
  error?:            string;
}

// ---------------------------------------------------------------------------
// Response type
// ---------------------------------------------------------------------------

export interface PurgeResponse {
  processed: number;
  deleted:   number;
  not_found: number;
  failed:    number;
  dry_run:   boolean;
  results:   PurgeItemResult[];
}
