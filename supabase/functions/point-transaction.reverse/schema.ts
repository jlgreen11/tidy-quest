/**
 * point-transaction.reverse — Zod request/response schemas
 */
import { z } from "https://deno.land/x/zod@v3.22.4/mod.ts";

export const PointTransactionReverseRequest = z.object({
  transaction_id: z.string().uuid(),              // the original transaction to reverse
  reason:         z.string().min(1).max(500).optional(), // why it's being reversed
});

export type PointTransactionReverseRequest = z.infer<typeof PointTransactionReverseRequest>;

export interface PointTransactionReverseResponse {
  original_transaction_id:   string;
  correction_transaction_id: string;
  correction_amount:         number;
  balance_after:             number;
}
