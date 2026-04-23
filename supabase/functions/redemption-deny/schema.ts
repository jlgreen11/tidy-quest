/**
 * redemption.deny — Zod request/response schemas
 */
import { z } from "https://deno.land/x/zod@v3.22.4/mod.ts";

export const RedemptionDenyRequest = z.object({
  request_id: z.string().uuid(),
  reason:     z.string().min(1).max(500).optional(),
});

export type RedemptionDenyRequest = z.infer<typeof RedemptionDenyRequest>;

export interface RedemptionDenyResponse {
  request: Record<string, unknown>;
}
