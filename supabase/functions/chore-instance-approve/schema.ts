/**
 * chore-instance.approve — Zod request/response schemas
 */
import { z } from "https://deno.land/x/zod@v3.22.4/mod.ts";

export const ChoreInstanceApproveRequest = z.object({
  instance_id:     z.string().uuid(),
  bonus_points:    z.number().int().min(0).max(500).optional(), // optional one-time bonus
});

export type ChoreInstanceApproveRequest = z.infer<typeof ChoreInstanceApproveRequest>;

export interface ChoreInstanceApproveResponse {
  instance:      Record<string, unknown>;
  transaction:   Record<string, unknown>;
  balance_after: number;
}
