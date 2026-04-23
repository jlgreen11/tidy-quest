/**
 * chore-template.archive — Zod request/response schemas
 */
import { z } from "https://deno.land/x/zod@v3.22.4/mod.ts";

export const ChoreTemplateArchiveRequest = z.object({
  template_id: z.string().uuid(),
});

export type ChoreTemplateArchiveRequest = z.infer<typeof ChoreTemplateArchiveRequest>;

export interface ChoreTemplateArchiveResponse {
  template_id: string;
  archived_at: string;
}
