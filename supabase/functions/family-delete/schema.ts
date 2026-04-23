/**
 * family.delete — Zod schemas
 * SENSITIVE: requires X-App-Attest header
 */
import { z } from "npm:zod@^3";

export const FamilyDeleteRequestSchema = z.object({
  family_id: z.string().uuid(),
  /** Optional reason for audit log */
  reason: z.string().max(500).optional(),
});

export type FamilyDeleteRequest = z.infer<typeof FamilyDeleteRequestSchema>;

export const FamilyDeleteResponseSchema = z.object({
  deleted: z.literal(true),
  family_id: z.string().uuid(),
  /** ISO timestamp of soft deletion */
  deleted_at: z.string(),
  /** ISO timestamp after which the family is permanently purged (deleted_at + 30 days) */
  recovery_expires_at: z.string(),
  message: z.string(),
});

export type FamilyDeleteResponse = z.infer<typeof FamilyDeleteResponseSchema>;
