/**
 * chore-instance.reject — Zod request/response schemas
 */
import { z } from "https://deno.land/x/zod@v3.22.4/mod.ts";

export const ChoreInstanceRejectRequest = z.object({
  instance_id: z.string().uuid(),
  reason:      z.string().min(1).max(500).optional(), // optional rejection note
});

export type ChoreInstanceRejectRequest = z.infer<typeof ChoreInstanceRejectRequest>;

export interface ChoreInstanceRejectResponse {
  instance: Record<string, unknown>;
}
