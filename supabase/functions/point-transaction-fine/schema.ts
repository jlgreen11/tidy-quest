/**
 * point-transaction.fine — Zod request/response schemas
 */
import { z } from "https://deno.land/x/zod@v3.22.4/mod.ts";

export const PointTransactionFineRequest = z.object({
  user_id:           z.string().uuid(),          // the kid being fined
  amount:            z.number().int().min(1).max(1000), // positive; will be stored negative
  reason:            z.string().min(1).max(500).optional(),  // free-text reason
  canned_reason_key: z.string().min(1).max(100).optional(),  // key from canned list
}).refine(
  (data) => data.reason !== undefined || data.canned_reason_key !== undefined,
  { message: "At least one of 'reason' or 'canned_reason_key' is required" },
);

export type PointTransactionFineRequest = z.infer<typeof PointTransactionFineRequest>;

export interface PointTransactionFineResponse {
  transaction:   Record<string, unknown>;
  balance_after: number;
}
