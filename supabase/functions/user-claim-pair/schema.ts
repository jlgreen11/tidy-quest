/**
 * user.claim-pair — Zod schemas
 * Anonymous endpoint: kid device redeems a pairing code for a long-lived device token.
 */
import { z } from "npm:zod@^3";

export const ClaimPairRequestSchema = z.object({
  /** The plaintext 10-character pairing code (as shown on parent screen) */
  pairing_code: z.string().length(10),
  /** Optional device identifier for attribution */
  device_name: z.string().max(100).optional(),
});

export type ClaimPairRequest = z.infer<typeof ClaimPairRequestSchema>;

export const ClaimPairResponseSchema = z.object({
  /** Long-lived device token for the kid device (store securely in Keychain) */
  device_token: z.string(),
  kid: z.object({
    id: z.string().uuid(),
    family_id: z.string().uuid(),
    role: z.literal("child"),
    display_name: z.string(),
    avatar: z.string(),
    color: z.string(),
    complexity_tier: z.string(),
    cached_balance: z.number(),
  }),
  family: z.object({
    id: z.string().uuid(),
    name: z.string(),
    timezone: z.string(),
    leaderboard_enabled: z.boolean(),
    sibling_ledger_visible: z.boolean(),
  }),
});

export type ClaimPairResponse = z.infer<typeof ClaimPairResponseSchema>;
