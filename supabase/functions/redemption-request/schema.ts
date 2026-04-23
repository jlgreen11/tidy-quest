/**
 * redemption.request — Zod request/response schemas
 */
import { z } from "https://deno.land/x/zod@v3.22.4/mod.ts";

export const RedemptionRequestBody = z.object({
  id:        z.string().uuid().optional(), // client-supplied UUIDv7
  reward_id: z.string().uuid(),
  notes:     z.string().max(500).optional(),
  // When completing via device, must identify the kid
  requesting_as_user: z.string().uuid().optional(),
});

export type RedemptionRequestBody = z.infer<typeof RedemptionRequestBody>;

export interface RedemptionRequestResponse {
  request: Record<string, unknown>;
}
