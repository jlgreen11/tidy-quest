/**
 * redemption.approve — Zod request/response schemas
 */
import { z } from "https://deno.land/x/zod@v3.22.4/mod.ts";

export const RedemptionApproveRequest = z.object({
  request_id: z.string().uuid(),
});

export type RedemptionApproveRequest = z.infer<typeof RedemptionApproveRequest>;

export interface RedemptionApproveResponse {
  request:      Record<string, unknown>;
  transaction:  Record<string, unknown>;
  balance_after: number;
}
