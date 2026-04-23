/**
 * family.create — Zod schemas
 */
import { z } from "npm:zod@^3";

export const FamilyCreateRequestSchema = z.object({
  /** Client-generated UUIDv7 for the family */
  id: z.string().uuid().optional(),
  name: z.string().min(1).max(100),
  timezone: z.string().min(1),
  /** IANA timezone string e.g. "America/Los_Angeles" */
  daily_reset_time: z.string().regex(/^\d{2}:\d{2}$/).optional(),
  quiet_hours_start: z.string().regex(/^\d{2}:\d{2}$/).optional(),
  quiet_hours_end: z.string().regex(/^\d{2}:\d{2}$/).optional(),
  leaderboard_enabled: z.boolean().optional(),
  sibling_ledger_visible: z.boolean().optional(),
  settings: z.record(z.unknown()).optional(),
});

export type FamilyCreateRequest = z.infer<typeof FamilyCreateRequestSchema>;

export const FamilyCreateResponseSchema = z.object({
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
  /** The parent app_user row created alongside the family */
  parent_user: z.object({
    id: z.string().uuid(),
    family_id: z.string().uuid(),
    role: z.literal("parent"),
    display_name: z.string(),
    avatar: z.string(),
    color: z.string(),
    complexity_tier: z.string(),
    created_at: z.string(),
  }),
});

export type FamilyCreateResponse = z.infer<typeof FamilyCreateResponseSchema>;
