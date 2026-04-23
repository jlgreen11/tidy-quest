/**
 * chore-template.update — Zod request/response schemas
 */
import { z } from "https://deno.land/x/zod@v3.22.4/mod.ts";

export const ChoreTemplateUpdateRequest = z.object({
  template_id: z.string().uuid(),
  // All fields are optional; only supplied fields are updated (PATCH semantics)
  name:              z.string().min(1).max(100).optional(),
  icon:              z.string().min(1).max(50).optional(),
  description:       z.string().max(500).nullable().optional(),
  type:              z.enum(["one_off", "daily", "weekly", "monthly", "seasonal", "routine_bound"]).optional(),
  schedule:          z.record(z.unknown()).optional(),
  target_user_ids:   z.array(z.string().uuid()).min(1).optional(),
  base_points:       z.number().int().min(0).max(500).optional(),
  cutoff_time:       z.string().regex(/^\d{2}:\d{2}(:\d{2})?$/).nullable().optional(),
  requires_photo:    z.boolean().optional(),
  requires_approval: z.boolean().optional(),
  on_miss:           z.enum(["skip", "decay", "deduct"]).optional(),
  on_miss_amount:    z.number().int().min(0).max(500).optional(),
  active:            z.boolean().optional(),
}).refine(
  (data) => Object.keys(data).filter((k) => k !== "template_id").length > 0,
  { message: "At least one field to update must be provided" },
);

export type ChoreTemplateUpdateRequest = z.infer<typeof ChoreTemplateUpdateRequest>;

export interface ChoreTemplateUpdateResponse {
  template: Record<string, unknown>;
}
