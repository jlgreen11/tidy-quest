/**
 * TidyQuest — apns.register-token schemas
 * supabase/functions/apns.register-token/schema.ts
 *
 * iOS clients POST their APNs device token after didRegisterForRemoteNotifications.
 */

import { z } from "npm:zod@3";

// ---------------------------------------------------------------------------
// Request schema
// ---------------------------------------------------------------------------

export const RegisterTokenRequestSchema = z.object({
  /** Raw hex APNs device token as returned by the iOS SDK (64 hex chars). */
  apns_token: z
    .string()
    .min(32, "apns_token too short")
    .max(200, "apns_token too long")
    .regex(/^[0-9a-fA-F]+$/, "apns_token must be hex-encoded"),
  /**
   * Which app bundle registered the token.
   * 'parent' → com.jlgreen11.tidyquest.parent
   * 'kid'    → com.jlgreen11.tidyquest.kid
   */
  app_bundle: z.enum(["parent", "kid"]),
  /** Platform hint — reserved for future Android support. */
  platform: z.string().default("ios"),
});

export type RegisterTokenRequest = z.infer<typeof RegisterTokenRequestSchema>;

// ---------------------------------------------------------------------------
// Response type
// ---------------------------------------------------------------------------

export interface RegisterTokenResponse {
  device_token: {
    id:           string;
    user_id:      string;
    apns_token:   string;
    app_bundle:   string;
    platform:     string;
    created_at:   string;
    last_seen_at: string;
  };
}
