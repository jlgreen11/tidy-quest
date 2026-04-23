/**
 * TidyQuest — Structured error builder for edge functions
 * supabase/functions/_shared/errors.ts
 *
 * Use appError() to build a typed JSON error response.
 * Never leak raw SQL errors to the client — log first, then call appError().
 */

import { EdgeErrorCode } from "./types.ts";

export interface AppErrorPayload {
  code: string;
  message: string;
  details?: Record<string, unknown>;
}

export interface AppErrorResponse {
  error: AppErrorPayload;
}

/**
 * Build a structured error response body.
 * Pass to new Response(JSON.stringify(appError(...)), { status, headers }).
 */
export function appError(
  code: EdgeErrorCode | string,
  message: string,
  details?: Record<string, unknown>,
): AppErrorResponse {
  const payload: AppErrorPayload = { code, message };
  if (details !== undefined) {
    payload.details = details;
  }
  return { error: payload };
}

/**
 * Helper: build a Response from an appError call.
 */
export function errorResponse(
  status: number,
  code: EdgeErrorCode | string,
  message: string,
  details?: Record<string, unknown>,
): Response {
  return new Response(
    JSON.stringify(appError(code, message, details)),
    {
      status,
      headers: { "Content-Type": "application/json" },
    },
  );
}

/** 400 Validation failed */
export function validationError(
  message: string,
  details?: Record<string, unknown>,
): Response {
  return errorResponse(400, EdgeErrorCode.InvalidInput, message, details);
}

/** 401 Unauthorized */
export function unauthorizedError(message = "Unauthorized"): Response {
  return errorResponse(401, EdgeErrorCode.Unauthorized, message);
}

/** 403 Forbidden / App Attest */
export function appAttestError(message = "App Attest validation failed"): Response {
  return errorResponse(403, EdgeErrorCode.AppAttestInvalid, message);
}

/** 429 Rate limit */
export function rateLimitError(retryAfterSeconds?: number): Response {
  const details = retryAfterSeconds !== undefined
    ? { retry_after_seconds: retryAfterSeconds }
    : undefined;
  return errorResponse(429, EdgeErrorCode.RateLimitExceeded, "Rate limit exceeded", details);
}

/** 500 Internal error — logs internally, generic to client */
export function internalError(): Response {
  return errorResponse(500, EdgeErrorCode.InternalError, "An internal error occurred");
}
