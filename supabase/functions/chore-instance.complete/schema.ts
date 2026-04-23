/**
 * chore-instance.complete — Zod request/response schemas
 */
import { z } from "https://deno.land/x/zod@v3.22.4/mod.ts";

export const ChoreInstanceCompleteRequest = z.object({
  instance_id:          z.string().uuid(),
  completed_at:         z.string().datetime({ offset: true }),  // ISO8601 with offset
  proof_photo_id:       z.string().uuid().optional(),
  completed_by_device:  z.string().max(200).optional(),         // iPad device identifier
  // When completing via device token, completed_as_user must identify the kid
  completed_as_user:    z.string().uuid().optional(),
});

export type ChoreInstanceCompleteRequest = z.infer<typeof ChoreInstanceCompleteRequest>;

export interface ChoreInstanceCompleteResponse {
  instance:      Record<string, unknown>;
  transaction?:  Record<string, unknown> | null;
  balance_after?: number | null;
}
