/**
 * user.revoke-device — Zod schemas
 * SENSITIVE: requires X-App-Attest header
 * Revokes a kid's device token by clearing pairing state.
 */
import { z } from "npm:zod@^3";

export const RevokeDeviceRequestSchema = z.object({
  kid_user_id: z.string().uuid(),
  family_id: z.string().uuid(),
  /** Optional reason for audit log */
  reason: z.string().max(500).optional(),
});

export type RevokeDeviceRequest = z.infer<typeof RevokeDeviceRequestSchema>;

export const RevokeDeviceResponseSchema = z.object({
  revoked: z.literal(true),
  kid_user_id: z.string().uuid(),
  revoked_at: z.string(),
});

export type RevokeDeviceResponse = z.infer<typeof RevokeDeviceResponseSchema>;
