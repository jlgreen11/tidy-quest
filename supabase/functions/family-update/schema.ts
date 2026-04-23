/**
 * family.update — Zod schemas
 * Partial update of family settings. All fields optional except family_id.
 */
import { z } from "npm:zod@^3";

export const FamilyUpdateRequestSchema = z.object({
  family_id: z.string().uuid(),
  name: z.string().min(1).max(100).optional(),
  timezone: z.string().min(1).optional(),
  daily_reset_time: z.string().regex(/^\d{2}:\d{2}$/).optional(),
  quiet_hours_start: z.string().regex(/^\d{2}:\d{2}$/).optional(),
  quiet_hours_end: z.string().regex(/^\d{2}:\d{2}$/).optional(),
  leaderboard_enabled: z.boolean().optional(),
  sibling_ledger_visible: z.boolean().optional(),
  daily_deduction_cap: z.number().int().min(0).max(1000).optional(),
  weekly_deduction_cap: z.number().int().min(0).max(5000).optional(),
  settings: z.record(z.unknown()).optional(),
});

export type FamilyUpdateRequest = z.infer<typeof FamilyUpdateRequestSchema>;

export const FamilyUpdateResponseSchema = z.object({
  family: z.object({
    id: z.string().uuid(),
    name: z.string(),
    timezone: z.string(),
    daily_reset_time: z.string(),
    quiet_hours_start: z.string(),
    quiet_hours_end: z.string(),
    leaderboard_enabled: z.boolean(),
    sibling_ledger_visible: z.boolean(),
    subscription_tier: z.string(),
    subscription_expires_at: z.string().nullable(),
    daily_deduction_cap: z.number(),
    weekly_deduction_cap: z.number(),
    settings: z.record(z.unknown()),
    created_at: z.string(),
    deleted_at: z.string().nullable(),
  }),
});

export type FamilyUpdateResponse = z.infer<typeof FamilyUpdateResponseSchema>;
