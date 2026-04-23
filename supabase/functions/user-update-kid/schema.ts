/**
 * user.update-kid — Zod schemas
 * Partial update of a child app_user row.
 */
import { z } from "npm:zod@^3";

export const UpdateKidRequestSchema = z.object({
  kid_user_id: z.string().uuid(),
  display_name: z.string().min(1).max(100).optional(),
  avatar: z.string().min(1).optional(),
  /** Hex color from the KidColor palette */
  color: z.string().regex(/^#[0-9A-Fa-f]{6}$/).optional(),
  complexity_tier: z.enum(["starter", "standard", "advanced"]).optional(),
});

export type UpdateKidRequest = z.infer<typeof UpdateKidRequestSchema>;

export const UpdateKidResponseSchema = z.object({
  user: z.object({
    id: z.string().uuid(),
    family_id: z.string().uuid().nullable(),
    role: z.string(),
    display_name: z.string(),
    avatar: z.string(),
    color: z.string(),
    complexity_tier: z.string(),
    birthdate: z.string().nullable(),
    cached_balance: z.number(),
    created_at: z.string(),
    deleted_at: z.string().nullable(),
  }),
});

export type UpdateKidResponse = z.infer<typeof UpdateKidResponseSchema>;
