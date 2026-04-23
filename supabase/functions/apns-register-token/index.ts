/**
 * TidyQuest — apns.register-token edge function
 * supabase/functions/apns.register-token/index.ts
 *
 * POST /functions/v1/apns.register-token
 * Auth:  Bearer (parent or kid JWT)
 * Rate:  5 requests / 60 seconds
 *
 * iOS client posts its APNs device token after didRegisterForRemoteNotifications.
 * Upserts into device_token table (unique on user_id, apns_token, app_bundle).
 * Updates last_seen_at on subsequent calls for the same token.
 *
 * Flow:
 *   1. Authenticate user via Bearer token (parent or kid).
 *   2. Rate-limit check.
 *   3. Validate request body.
 *   4. Upsert device_token row.
 *   5. Return the upserted row.
 */

import { createClient } from "npm:@supabase/supabase-js@2";
import {
  checkRateLimit,
  parseAppleJwt,
  parseDeviceToken,
} from "../_shared/auth.ts";
import {
  internalError,
  rateLimitError,
  unauthorizedError,
  validationError,
} from "../_shared/errors.ts";
import {
  RegisterTokenRequest,
  RegisterTokenRequestSchema,
  RegisterTokenResponse,
} from "./schema.ts";

const ENDPOINT        = "apns.register-token";
const RATE_MAX        = 5;
const RATE_WINDOW_SEC = 60;

Deno.serve(async (req: Request): Promise<Response> => {
  // -------------------------------------------------------------------------
  // 1. Method guard
  // -------------------------------------------------------------------------
  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ error: { code: "METHOD_NOT_ALLOWED", message: "Use POST" } }),
      { status: 405, headers: { "Content-Type": "application/json" } },
    );
  }

  // -------------------------------------------------------------------------
  // 2. Service-role client
  // -------------------------------------------------------------------------
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceKey  = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const supabase = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false },
  });

  // -------------------------------------------------------------------------
  // 3. Authenticate — support both parent Bearer and kid Device-Token
  // -------------------------------------------------------------------------
  const authHeader    = req.headers.get("Authorization");
  const deviceHeader  = req.headers.get("X-Device-Token");

  let userId: string | null   = null;
  let familyId: string | null = null;

  if (authHeader) {
    // Parent path: Bearer token
    const parsed = parseAppleJwt(authHeader);
    if (!parsed) {
      return unauthorizedError("Invalid Bearer token");
    }
    const { data: userRow, error: userErr } = await supabase
      .from("app_user")
      .select("id, family_id, role")
      .eq("apple_sub", parsed.apple_sub)
      .is("deleted_at", null)
      .single();

    if (userErr || !userRow) {
      return unauthorizedError("User not found");
    }
    userId   = userRow.id;
    familyId = userRow.family_id;
  } else if (deviceHeader) {
    // Kid path: device token
    const parsed = parseDeviceToken(deviceHeader);
    if (!parsed) {
      return unauthorizedError("Invalid X-Device-Token");
    }
    // Verify user exists
    const { data: userRow, error: userErr } = await supabase
      .from("app_user")
      .select("id, family_id")
      .eq("id", parsed.user_id)
      .eq("family_id", parsed.family_id)
      .is("deleted_at", null)
      .single();

    if (userErr || !userRow) {
      return unauthorizedError("User not found");
    }
    userId   = parsed.user_id;
    familyId = parsed.family_id;
  } else {
    return unauthorizedError("Authorization or X-Device-Token header required");
  }

  if (!userId || !familyId) {
    return unauthorizedError("Could not resolve user identity");
  }

  // -------------------------------------------------------------------------
  // 4. Rate limit
  // -------------------------------------------------------------------------
  const rl = await checkRateLimit(supabase, userId, ENDPOINT, RATE_MAX, RATE_WINDOW_SEC);
  if (!rl.allowed) {
    return rateLimitError(rl.retryAfterSeconds);
  }

  // -------------------------------------------------------------------------
  // 5. Parse body
  // -------------------------------------------------------------------------
  let rawBody: unknown;
  try {
    rawBody = await req.json();
  } catch {
    return validationError("Request body must be valid JSON");
  }

  const parseResult = RegisterTokenRequestSchema.safeParse(rawBody);
  if (!parseResult.success) {
    return validationError("Invalid request body", {
      issues: parseResult.error.issues,
    });
  }

  const body: RegisterTokenRequest = parseResult.data;

  // -------------------------------------------------------------------------
  // 6. Upsert device_token
  // UNIQUE (user_id, apns_token, app_bundle) — on conflict update last_seen_at
  // -------------------------------------------------------------------------
  const now = new Date().toISOString();

  const { data: tokenRow, error: upsertErr } = await supabase
    .from("device_token")
    .upsert(
      {
        user_id:      userId,
        apns_token:   body.apns_token.toLowerCase(), // normalise to lower hex
        platform:     body.platform,
        app_bundle:   body.app_bundle,
        created_at:   now,
        last_seen_at: now,
      },
      {
        onConflict: "user_id,apns_token,app_bundle",
        // Update last_seen_at and platform on conflict
        ignoreDuplicates: false,
      },
    )
    .select()
    .single();

  if (upsertErr || !tokenRow) {
    console.error(`[${ENDPOINT}] upsert failed:`, upsertErr);
    return internalError();
  }

  // -------------------------------------------------------------------------
  // 7. Return upserted row
  // -------------------------------------------------------------------------
  const responseBody: RegisterTokenResponse = {
    device_token: {
      id:           tokenRow.id,
      user_id:      tokenRow.user_id,
      apns_token:   tokenRow.apns_token,
      app_bundle:   tokenRow.app_bundle,
      platform:     tokenRow.platform,
      created_at:   tokenRow.created_at,
      last_seen_at: tokenRow.last_seen_at,
    },
  };

  return new Response(JSON.stringify(responseBody), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
