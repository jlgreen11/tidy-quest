/**
 * user.pair-device — Zod schemas
 * Generates a 10-char alphanumeric single-use pairing code for a kid.
 */
import { z } from "npm:zod@^3";

export const PairDeviceRequestSchema = z.object({
  /** The kid's app_user ID to generate a pairing code for */
  kid_user_id: z.string().uuid(),
  family_id: z.string().uuid(),
});

export type PairDeviceRequest = z.infer<typeof PairDeviceRequestSchema>;

export const PairDeviceResponseSchema = z.object({
  pairing_code: z.string().length(10),
  /** ISO timestamp when this code expires (10 minutes from now) */
  expires_at: z.string(),
  kid_user_id: z.string().uuid(),
});

export type PairDeviceResponse = z.infer<typeof PairDeviceResponseSchema>;
