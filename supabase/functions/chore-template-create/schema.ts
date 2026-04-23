/**
 * chore-template.create — Zod request/response schemas
 */
import { z } from "https://deno.land/x/zod@v3.22.4/mod.ts";

export const ChoreTemplateCreateRequest = z.object({
  id: z.string().uuid().optional(),           // client-supplied UUIDv7; generated server-side if absent
  name: z.string().min(1).max(100),
  icon: z.string().min(1).max(50),
  description: z.string().max(500).optional(),
  type: z.enum(["one_off", "daily", "weekly", "monthly", "seasonal", "routine_bound"]),
  schedule: z.record(z.unknown()).default({}), // validated by pg; minimal shape here
  target_user_ids: z.array(z.string().uuid()).min(1),
  base_points: z.number().int().min(0).max(500),
  cutoff_time: z.string().regex(/^\d{2}:\d{2}(:\d{2})?$/).optional(), // HH:MM or HH:MM:SS
  requires_photo: z.boolean().default(false),
  requires_approval: z.boolean().default(false),
  on_miss: z.enum(["skip", "decay", "deduct"]).default("decay"),
  on_miss_amount: z.number().int().min(0).max(500).default(0),
});

export type ChoreTemplateCreateRequest = z.infer<typeof ChoreTemplateCreateRequest>;

export interface ChoreTemplateCreateResponse {
  template: {
    id: string;
    family_id: string;
    name: string;
    icon: string;
    description: string | null;
    type: string;
    schedule: Record<string, unknown>;
    target_user_ids: string[];
    base_points: number;
    cutoff_time: string | null;
    requires_photo: boolean;
    requires_approval: boolean;
    on_miss: string;
    on_miss_amount: number;
    active: boolean;
    created_at: string;
    archived_at: string | null;
  };
}
