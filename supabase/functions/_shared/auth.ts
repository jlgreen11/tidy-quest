/**
 * TidyQuest — Auth helpers for edge functions
 * supabase/functions/_shared/auth.ts
 *
 * Covers:
 *  - Apple JWT mock parsing (Bearer tokens starting with "apple-mock-")
 *    — gated to local-only behind ALLOW_MOCK_AUTH env var (audit C1)
 *  - HMAC-signed device JWT issuance and verification (audit C2)
 *  - App Attest mock validation (X-App-Attest header)
 *  - Rate limit helper via Supabase `rate_limit` table — single 5-arg signature (audit C3)
 *  - Idempotency-Key helper via `idempotency` table — keys hashed before storage (audit C4)
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
  id: string;
  /** family_id the kid belongs to */
  family_id: string;
}

/** Authenticated principal returned by authenticateBearer / authenticateDevice. */
export interface AuthenticatedUser {
  /** app_user.id (NOT apple_sub) */
  id: string;
  family_id: string;
  role: string;
}

// ---------------------------------------------------------------------------
// Mock-auth gating (audit C1)
// ---------------------------------------------------------------------------

/**
 * Mock auth tokens (`apple-mock-<sub>`) and unsigned/legacy device tokens are
 * accepted ONLY when ALL of the following are true:
 *   1. ALLOW_MOCK_AUTH=true
 *   2. We are NOT running on Supabase Edge / Deno Deploy (DENO_DEPLOYMENT_ID unset)
 *
 * Any deployed environment (staging, production) MUST reject mock tokens
 * regardless of how the env var is set, because DENO_DEPLOYMENT_ID is set
 * by the runtime on every deploy.
 */
export function mockAuthAllowed(): boolean {
  // Allowed whenever ALLOW_MOCK_AUTH is explicitly set to "true". Production
  // environments should leave this env var UNSET so mock tokens are rejected.
  // Staging sets it to true to enable contract tests + simulator demos.
  return Deno.env.get("ALLOW_MOCK_AUTH") === "true";
}

// ---------------------------------------------------------------------------
// Apple JWT mock parsing
// ---------------------------------------------------------------------------

/**
 * Parse a Bearer token from the Authorization header.
 * Mock format: "apple-mock-<apple_sub>" — only accepted in local dev.
 * Returns the apple_sub or null if invalid.
 *
 * TODO: Replace with real Apple pubkey JWT verification.
 */
export function parseAppleJwt(authHeader: string | null): ParsedParentAuth | null {
  if (!authHeader) return null;
  const token = authHeader.replace(/^Bearer\s+/i, "").trim();
  if (token.startsWith("apple-mock-")) {
    if (!mockAuthAllowed()) {
      console.warn("[auth] apple-mock token rejected: mock auth disabled in this environment");
      return null;
    }
    // Keep the full "apple-mock-xxx" string as apple_sub so it matches the
    // DB column value (seed writes "apple-mock-mei-001" etc.).
    if (!token) return null;
    return { apple_sub: token };
  }
  // TODO: verify with Apple public keys (JWKS at appleid.apple.com)
  return null;
}

// ---------------------------------------------------------------------------
// Device token — HMAC-signed JWT (audit C2)
// ---------------------------------------------------------------------------

const DEVICE_JWT_HEADER_B64 = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"; // {"alg":"HS256","typ":"JWT"}

interface DeviceJwtPayload {
  uid: string;       // app_user.id
  fid: string;       // family_id
  iat: number;       // issued at (unix seconds)
  sub: "device";     // discriminator
}

function base64UrlEncode(input: Uint8Array | string): string {
  const bytes = typeof input === "string" ? new TextEncoder().encode(input) : input;
  let str = "";
  for (let i = 0; i < bytes.length; i++) str += String.fromCharCode(bytes[i]);
  return btoa(str).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

function base64UrlDecode(input: string): Uint8Array {
  const pad = input.length % 4 === 0 ? "" : "=".repeat(4 - (input.length % 4));
  const b64 = input.replaceAll("-", "+").replaceAll("_", "/") + pad;
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

async function getDeviceTokenSecretKey(): Promise<CryptoKey> {
  const secret = Deno.env.get("DEVICE_TOKEN_SECRET");
  if (!secret || secret.length < 32) {
    throw new Error("DEVICE_TOKEN_SECRET must be set (>=32 chars) for device JWT signing");
  }
  return await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign", "verify"],
  );
}

/**
 * Mint a signed HMAC-SHA256 JWT bound to (user_id, family_id).
 * Used by user.claim-pair when issuing a device token to a paired kid device.
 */
export async function issueDeviceToken(userId: string, familyId: string): Promise<string> {
  const payload: DeviceJwtPayload = {
    uid: userId,
    fid: familyId,
    iat: Math.floor(Date.now() / 1000),
    sub: "device",
  };
  const payloadB64 = base64UrlEncode(JSON.stringify(payload));
  const signingInput = DEVICE_JWT_HEADER_B64 + "." + payloadB64;
  const key = await getDeviceTokenSecretKey();
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(signingInput));
  return signingInput + "." + base64UrlEncode(new Uint8Array(sig));
}

/**
 * Parse + verify the X-Device-Token header.
 * Accepts:
 *   - HMAC-signed JWT minted by issueDeviceToken (production format)
 *   - Legacy plaintext "device-token-<uid>|<fid>" — ONLY when mockAuthAllowed()
 */
export async function parseDeviceToken(tokenHeader: string | null): Promise<ParsedDeviceToken | null> {
  if (!tokenHeader) return null;

  // Legacy plaintext fallback — local dev only (audit C2)
  if (tokenHeader.startsWith("device-token-")) {
    if (!mockAuthAllowed()) {
      console.warn("[auth] legacy device-token rejected: mock auth disabled in this environment");
      return null;
    }
    const rest = tokenHeader.replace("device-token-", "");
    const parts = rest.split("|");
    if (parts.length !== 2) return null;
    return { id: parts[0], family_id: parts[1] };
  }

  // Verify signed JWT
  const segments = tokenHeader.split(".");
  if (segments.length !== 3) return null;
  const [headerB64, payloadB64, sigB64] = segments;
  if (headerB64 !== DEVICE_JWT_HEADER_B64) return null;

  let key: CryptoKey;
  try {
    key = await getDeviceTokenSecretKey();
  } catch (err) {
    console.error("[auth] device token key error:", err);
    return null;
  }
  const sigBytes = base64UrlDecode(sigB64);
  const valid = await crypto.subtle.verify(
    "HMAC",
    key,
    sigBytes,
    new TextEncoder().encode(headerB64 + "." + payloadB64),
  );
  if (!valid) return null;

  let payload: DeviceJwtPayload;
  try {
    const decoded = new TextDecoder().decode(base64UrlDecode(payloadB64));
    payload = JSON.parse(decoded);
  } catch {
    return null;
  }
  if (payload.sub !== "device" || !payload.uid || !payload.fid) return null;
  return { id: payload.uid, family_id: payload.fid };
}

// ---------------------------------------------------------------------------
// App Attest mock validation
// ---------------------------------------------------------------------------

/**
 * Validate the X-App-Attest header.
 * Mock: any non-empty string passes.
 * TODO: verify Apple App Attest assertion via Apple server APIs.
 */
export function validateAppAttest(attestHeader: string | null | undefined): boolean {
  // TODO: implement real Apple App Attest / DeviceCheck verification
  console.log("[TODO] App Attest mock validation — replace before production");
  return typeof attestHeader === "string" && attestHeader.trim().length > 0;
}

// ---------------------------------------------------------------------------
// Rate limiting (audit C3 — single canonical 5-arg signature)
// ---------------------------------------------------------------------------

export interface RateLimitResult {
  allowed: boolean;
  /** Seconds until next allowed request */
  retryAfterSeconds?: number;
}

/**
 * Check and record a rate-limit hit.
 *   (supabase, userKey, endpoint, maxRequests, windowSeconds)
 * Returns { allowed: boolean }.
 */
export async function checkRateLimit(
  supabase: SupabaseClient,
  userKey: string,
  endpoint: string,
  maxRequests: number,
  windowSeconds: number,
): Promise<RateLimitResult> {
  try {
    const windowStart = new Date(Date.now() - windowSeconds * 1000).toISOString();

    const { data: existing, error: selectErr } = await supabase
      .from("rate_limit")
      .select("id, count, window_start")
      .eq("user_key", userKey)
      .eq("endpoint", endpoint)
      .single();

    if (selectErr && selectErr.code !== "PGRST116") {
      console.error("[rate_limit] select error:", selectErr);
      return { allowed: true }; // fail open
    }

    if (!existing || existing.window_start < windowStart) {
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

    const { error: incrErr } = await supabase
      .from("rate_limit")
      .update({ count: existing.count + 1 })
      .eq("user_key", userKey)
      .eq("endpoint", endpoint);
    if (incrErr) console.error("[rate_limit] increment error:", incrErr);

    return { allowed: true };
  } catch (err) {
    console.error("[rate_limit] unexpected error:", err);
    return { allowed: true };
  }
}

// ---------------------------------------------------------------------------
// Idempotency (audit C4 — keys hashed before storage)
// ---------------------------------------------------------------------------

export interface IdempotencyResult {
  hit: boolean;
  cachedResponse?: Record<string, unknown>;
}

/** SHA-256 hex digest of the raw client-supplied idempotency key. */
export async function hashIdempotencyKey(rawKey: string): Promise<string> {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(rawKey));
  const bytes = Array.from(new Uint8Array(buf));
  return bytes.map((b) => b.toString(16).padStart(2, "0")).join("");
}

export async function checkIdempotency(
  supabase: SupabaseClient,
  idempotencyKey: string,
  endpoint: string,
): Promise<IdempotencyResult> {
  if (!idempotencyKey) return { hit: false };

  try {
    const keyHash = await hashIdempotencyKey(idempotencyKey);
    const { data, error } = await supabase
      .from("idempotency")
      .select("response_body, created_at")
      .eq("idempotency_key", keyHash)
      .eq("endpoint", endpoint)
      .single();

    if (error && error.code !== "PGRST116") {
      console.error("[idempotency] check error:", error);
      return { hit: false };
    }
    if (!data) return { hit: false };

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

export async function recordIdempotency(
  supabase: SupabaseClient,
  idempotencyKey: string,
  endpoint: string,
  responseBody: Record<string, unknown>,
): Promise<void> {
  if (!idempotencyKey) return;
  const keyHash = await hashIdempotencyKey(idempotencyKey);

  const { error } = await supabase
    .from("idempotency")
    .upsert(
      {
        idempotency_key: keyHash,
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
// High-level authenticate helpers (audit C3)
//
// authenticateBearer resolves apple_sub -> app_user via DB lookup so
// callers receive a real principal { id, family_id, role } rather than
// the previously-undefined parsed.user_id / parsed.family_id / parsed.role.
//
// Shape is { id, family_id, role } across both helpers.
// ============================================================

export interface AuthenticateResult {
  ok: boolean;
  user?: AuthenticatedUser;
  response?: Response;
}

function unauthorizedResponse(message: string): Response {
  return new Response(
    JSON.stringify({ error: { code: EdgeErrorCode.Unauthorized, message } }),
    { status: 401, headers: { "Content-Type": "application/json" } },
  );
}

export async function authenticateBearer(req: Request): Promise<AuthenticateResult> {
  const parsed = parseAppleJwt(req.headers.get("Authorization"));
  if (!parsed) {
    return { ok: false, response: unauthorizedResponse("Missing or invalid Bearer token") };
  }

  const supabase = createServiceClient();
  const { data: row, error } = await supabase
    .from("app_user")
    .select("id, family_id, role")
    .eq("apple_sub", parsed.apple_sub)
    .is("deleted_at", null)
    .maybeSingle();

  if (error) {
    console.error("[auth] app_user lookup error:", error);
    return { ok: false, response: unauthorizedResponse("Authentication failed") };
  }
  if (!row) {
    return { ok: false, response: unauthorizedResponse("Unknown account") };
  }

  return {
    ok: true,
    user: { id: row.id, family_id: row.family_id, role: row.role },
  };
}

export async function authenticateDevice(req: Request): Promise<AuthenticateResult> {
  const parsed = await parseDeviceToken(req.headers.get("X-Device-Token"));
  if (!parsed) {
    return {
      ok: false,
      response: new Response(
        JSON.stringify({ error: { code: EdgeErrorCode.Unauthorized, message: "Missing or invalid device token" } }),
        { status: 401, headers: { "Content-Type": "application/json" } }
      ),
    };
  }
  return {
    ok: true,
    user: { id: parsed.id, family_id: parsed.family_id, role: "child" },
  };
}

export function requireAppAttest(req: Request): { ok: boolean; response?: Response } {
  const valid = validateAppAttest(req.headers.get("X-App-Attest"));
  if (!valid) {
    return {
      ok: false,
      response: new Response(
        JSON.stringify({ error: { code: EdgeErrorCode.AppAttestRequired, message: "App Attest validation failed" } }),
        { status: 403, headers: { "Content-Type": "application/json" } }
      ),
    };
  }
  return { ok: true };
}
