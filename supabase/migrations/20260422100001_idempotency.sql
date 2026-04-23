-- =============================================================================
-- TidyQuest — Idempotency & Rate Limit Tables
-- 20260422100001_idempotency.sql
--
-- idempotency: caches edge function responses keyed on (idempotency_key, endpoint)
--              for 24 hours, enabling safe client retries.
-- rate_limit:  tracks per-user request counts within sliding windows.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- TABLE: idempotency
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS idempotency (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  idempotency_key  text NOT NULL,
  endpoint         text NOT NULL,
  response_body    jsonb NOT NULL,
  created_at       timestamptz NOT NULL DEFAULT now(),

  UNIQUE (idempotency_key, endpoint)
);

-- Index for expiry cleanup (pg_cron or explicit cleanup)
CREATE INDEX idempotency_created_at_idx ON idempotency (created_at);

COMMENT ON TABLE idempotency IS
  'Caches edge function responses keyed on (idempotency_key, endpoint). '
  'Records expire after 24 hours (enforced in application logic). '
  'Clients supply Idempotency-Key header; safe retries return the same cached JSON.';

-- ---------------------------------------------------------------------------
-- TABLE: rate_limit
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rate_limit (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_key     text NOT NULL,   -- apple_sub, user_id, or client IP
  endpoint     text NOT NULL,
  count        integer NOT NULL DEFAULT 1 CHECK (count >= 0),
  window_start timestamptz NOT NULL DEFAULT now(),

  UNIQUE (user_key, endpoint)
);

CREATE INDEX rate_limit_window_idx ON rate_limit (user_key, endpoint, window_start);

COMMENT ON TABLE rate_limit IS
  'Tracks request counts per (user_key, endpoint) in a sliding window. '
  'Edge functions reset the window when now() - window_start > window_seconds. '
  'Fail-open on infra errors (rate limit table unavailable does not block requests).';

-- ---------------------------------------------------------------------------
-- Cleanup function: purge expired idempotency rows (called by pg_cron)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION purge_expired_idempotency()
RETURNS void
LANGUAGE sql
AS $$
  DELETE FROM idempotency WHERE created_at < now() - INTERVAL '24 hours';
$$;

COMMENT ON FUNCTION purge_expired_idempotency() IS
  'Remove idempotency records older than 24 hours. Scheduled via pg_cron daily.';
