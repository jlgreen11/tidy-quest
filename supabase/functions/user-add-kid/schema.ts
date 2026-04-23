/**
 * user.add-kid — Zod schemas
 */
import { z } from "npm:zod@^3";

export const AddKidRequestSchema = z.object({
  family_id: z.string().uuid(),
  /** Optional client-generated UUIDv7 */
  id: z.string().uuid().optional(),
  display_name: z.string().min(1).max(100),
  /** Asset identifier from the app's icon library */
  avatar: z.string().min(1),
  /** Hex color from the KidColor palette */
  color: z.string().regex(/^#[0-9A-Fa-f]{6}$/),
  complexity_tier: z.enum(["starter", "standard", "advanced"]).optional(),
  birthdate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
});

export type AddKidRequest = z.infer<typeof AddKidRequestSchema>;

export const AddKidResponseSchema = z.object({
  kid: z.object({
    id: z.string().uuid(),
    family_id: z.string().uuid(),
    role: z.literal("child"),
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

export type AddKidResponse = z.infer<typeof AddKidResponseSchema>;
