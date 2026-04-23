/**
 * TidyQuest — Auth helpers for edge functions
 * supabase/functions/_shared/auth.ts
 *
 * Covers:
 *  - Apple JWT mock parsing (Bearer tokens starting with "apple-mock-")
 *  - Device token parsing (X-Device-Token header)
 *  - App Attest mock validation (X-App-Attest header)
 *  - Rate limit helper via Supabase `rate_limit` table
 *  - Idempotency-Key helper via `idempotency` table
 *
 * TODO (pre-prod): replace mock Apple JWT with real Apple pubkey verification
 * TODO (pre-prod): replace mock App Attest with real Apple DeviceCheck/App Attest
 */

import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";
import { EdgeErrorCode } from "./types.ts";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface ParsedParentAuth {
  /** apple_sub value extracted from the Bearer token */
  apple_sub: string;
}

export interface ParsedDeviceToken {
  /** app_user.id for the kid device */
  user_id: string;
  /** family_id the kid belongs to */
  family_id: string;
}

// ---------------------------------------------------------------------------
// Apple JWT mock parsing
// ---------------------------------------------------------------------------

/**
 * Parse a Bearer token from the Authorization header.
 * Mock: accepts any token starting with "apple-mock-<apple_sub>".
 * Returns the apple_sub or null if invalid.
 *
 * TODO: Replace with real Apple pubkey JWT verification.
 */
export function parseAppleJwt(authHeader: string | null): ParsedParentAuth | null {
  if (!authHeader) return null;
  const token = authHeader.replace(/^Bearer\s+/i, "").trim();
  if (!token.startsWith("apple-mock-")) {
    // TODO: verify with Apple public keys (JWKS at appleid.apple.com)
    return null;
  }
  const apple_sub = token.replace(/^apple-mock-/, "");
  if (!apple_sub) return null;
  return { apple_sub };
}

// ---------------------------------------------------------------------------
// Device token parsing
// ---------------------------------------------------------------------------

/**
 * Parse X-Device-Token header.
 * Format: "device-token-<user_id>-<family_id>" (mock).
 * TODO: Replace with real signed JWT device tokens.
 */
export function parseDeviceToken(tokenHeader: string | null): ParsedDeviceToken | null {
  if (!tokenHeader) return null;
  const prefix = "device-token-";
  if (!tokenHeader.startsWith(prefix)) return null;
  const rest = tokenHeader.replace(prefix, "");
  // format: <user_id>-<family_id> but UUIDs contain hyphens, so split on last known boundary
  // Tokens are encoded as base64(JSON{user_id, family_id}) in prod.
  // Mock: base64-encode was skipped; format is "device-token-<user_id>|<family_id>"
  const parts = rest.split("|");
  if (parts.length !== 2) return null;
  return { user_id: parts[0], family_id: parts[1] };
}

// ---------------------------------------------------------------------------
// App Attest mock validation
// ---------------------------------------------------------------------------

/**
 * Validate the X-App-Attest header.
 * Mock: any non-empty string passes.
 * TODO: verify Apple App Attest assertion via Apple server APIs.
 *
 * Returns true if valid, false otherwise.
 */
export function validateAppAttest(attestHeader: string | null | undefined): boolean {
  // TODO: implement real Apple App Attest / DeviceCheck verification
  console.log("[TODO] App Attest mock validation — replace before production");
  return typeof attestHeader === "string" && attestHeader.trim().length > 0;
}

// ---------------------------------------------------------------------------
// Rate limiting
// ---------------------------------------------------------------------------

export interface RateLimitResult {
  allowed: boolean;
  /** Seconds until next allowed request */
  retryAfterSeconds?: number;
}

/**
 * Check and record a rate-limit hit.
 * Uses the `rate_limit` table: (user_key, endpoint) with count and window_start.
 * Window is reset when now() - window_start > window_seconds.
 */
export async function checkRateLimit(
  supabase: SupabaseClient,
  userKey: string,          // apple_sub, user_id, or IP
  endpoint: string,         // e.g. "family.create"
  maxRequests: number,
  windowSeconds: number,
): Promise<RateLimitResult> {
  try {
    const windowStart = new Date(Date.now() - windowSeconds * 1000).toISOString();

    // Find existing window record
    const { data: existing, error: selectErr } = await supabase
      .from("rate_limit")
      .select("id, count, window_start")
      .eq("user_key", userKey)
      .eq("endpoint", endpoint)
      .single();

    if (selectErr && selectErr.code !== "PGRST116") {
      // PGRST116 = no rows — that's fine
      console.error("[rate_limit] select error:", selectErr);
      // Fail open — don't block the request on infra error
      return { allowed: true };
    }

    if (!existing || existing.window_start < windowStart) {
      // No record or expired window — upsert with count=1
      const { error: upsertErr } = await supabase
        .from("rate_limit")
        .upsert(
          {
            user_key: userKey,
            endpoint,
            count: 1,
            window_start: new Date().toISOString(),
          },
          { onConflict: "user_key,endpoint" },
        );
      if (upsertErr) console.error("[rate_limit] upsert error:", upsertErr);
      return { allowed: true };
    }

    if (existing.count >= maxRequests) {
      const windowStartDate = new Date(existing.window_start).getTime();
      const windowEndMs = windowStartDate + windowSeconds * 1000;
      const retryAfterSeconds = Math.ceil((windowEndMs - Date.now()) / 1000);
      return { allowed: false, retryAfterSeconds: Math.max(retryAfterSeconds, 1) };
    }

    // Increment count
    const { error: incrErr } = await supabase
      .from("rate_limit")
      .update({ count: existing.count + 1 })
      .eq("user_key", userKey)
      .eq("endpoint", endpoint);
    if (incrErr) console.error("[rate_limit] increment error:", incrErr);

    return { allowed: true };
  } catch (err) {
    console.error("[rate_limit] unexpected error:", err);
    return { allowed: true }; // fail open
  }
}

// ---------------------------------------------------------------------------
// Idempotency
// ---------------------------------------------------------------------------

export interface IdempotencyResult {
  hit: boolean;
  cachedResponse?: Record<string, unknown>;
}

/**
 * Check if an idempotency key has been seen.
 * If hit, returns { hit: true, cachedResponse }.
 * If miss, stores the key immediately (caller must call recordIdempotency after success).
 */
export async function checkIdempotency(
  supabase: SupabaseClient,
  idempotencyKey: string,
  endpoint: string,
): Promise<IdempotencyResult> {
  if (!idempotencyKey) return { hit: false };

  try {
    const { data, error } = await supabase
      .from("idempotency")
      .select("response_body, created_at")
      .eq("idempotency_key", idempotencyKey)
      .eq("endpoint", endpoint)
      .single();

    if (error && error.code !== "PGRST116") {
      console.error("[idempotency] check error:", error);
      return { hit: false };
    }

    if (!data) return { hit: false };

    // Expire after 24h
    const createdAt = new Date(data.created_at).getTime();
    if (Date.now() - createdAt > 24 * 60 * 60 * 1000) {
      return { hit: false };
    }

    return { hit: true, cachedResponse: data.response_body as Record<string, unknown> };
  } catch (err) {
    console.error("[idempotency] unexpected error:", err);
    return { hit: false };
  }
}

/**
 * Record a successful response for an idempotency key.
 */
export async function recordIdempotency(
  supabase: SupabaseClient,
  idempotencyKey: string,
  endpoint: string,
  responseBody: Record<string, unknown>,
): Promise<void> {
  if (!idempotencyKey) return;

  const { error } = await supabase
    .from("idempotency")
    .upsert(
      {
        idempotency_key: idempotencyKey,
        endpoint,
        response_body: responseBody,
        created_at: new Date().toISOString(),
      },
      { onConflict: "idempotency_key,endpoint" },
    );

  if (error) console.error("[idempotency] record error:", error);
}

// ---------------------------------------------------------------------------
// Supabase client factory
// ---------------------------------------------------------------------------

/**
 * Create a service-role Supabase client for use inside edge functions.
 * Service role bypasses RLS — all mutations must be gated by auth checks above.
 */
export function createServiceClient(): SupabaseClient {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) {
    throw new Error("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set");
  }
  return createClient(url, key, {
    auth: { persistSession: false },
  });
}

// ============================================================
// Compatibility wrappers (for B2/B3 agent call sites)
// Higher-level async helpers returning { ok, user | response } shape.
//
// TODO (pre-production): authenticateBearer should look up the
// app_user by apple_sub to populate user_id, family_id, role.
// Tonight's stub returns empty strings — fine for simulator
// demo (MockAPIClient serves UI data), but real backend deployment
// MUST resolve apple_sub -> user row before going live.
// ============================================================

export interface AuthenticateResult {
  ok: boolean;
  user?: { user_id: string; family_id: string; role: string };
  response?: Response;
}

export async function authenticateBearer(req: Request): Promise<AuthenticateResult> {
  const parsed = parseAppleJwt(req.headers.get("Authorization"));
  if (!parsed) {
    return {
      ok: false,
      response: new Response(
        JSON.stringify({ error: { code: "UNAUTHORIZED", message: "Missing or invalid Bearer token" } }),
        { status: 401, headers: { "Content-Type": "application/json" } }
      ),
    };
  }
  return {
    ok: true,
    user: {
      user_id: parsed.user_id,
      family_id: parsed.family_id || "",
      role: parsed.role || "parent",
    },
  };
}

export async function authenticateDevice(req: Request): Promise<AuthenticateResult> {
  const parsed = parseDeviceToken(req.headers.get("X-Device-Token"));
  if (!parsed) {
    return {
      ok: false,
      response: new Response(
        JSON.stringify({ error: { code: "UNAUTHORIZED", message: "Missing or invalid device token" } }),
        { status: 401, headers: { "Content-Type": "application/json" } }
      ),
    };
  }
  return {
    ok: true,
    user: {
      user_id: parsed.user_id,
      family_id: parsed.family_id,
      role: "child",
    },
  };
}

export function requireAppAttest(req: Request): { ok: boolean; response?: Response } {
  const valid = validateAppAttest(req.headers.get("X-App-Attest"));
  if (!valid) {
    return {
      ok: false,
      response: new Response(
        JSON.stringify({ error: { code: "APP_ATTEST_REQUIRED", message: "App Attest validation failed" } }),
        { status: 403, headers: { "Content-Type": "application/json" } }
      ),
    };
  }
  return { ok: true };
}
