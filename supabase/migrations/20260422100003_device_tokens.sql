-- =============================================================================
-- TidyQuest — Device Token Table
-- 20260422100003_device_tokens.sql
--
-- Stores APNs device tokens for push notification dispatch.
-- Each row represents a (user, token, app_bundle) triple.
-- Tokens are written by the apns.register-token edge function after
-- didRegisterForRemoteNotificationsWithDeviceToken fires on the iOS client.
-- =============================================================================

CREATE TABLE device_token (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid        NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
  apns_token   text        NOT NULL,
  platform     text        NOT NULL DEFAULT 'ios',
  app_bundle   text        NOT NULL,  -- 'parent' | 'kid'
  created_at   timestamptz NOT NULL DEFAULT now(),
  last_seen_at timestamptz NOT NULL DEFAULT now(),

  UNIQUE (user_id, apns_token, app_bundle)
);

CREATE INDEX device_token_user_idx ON device_token (user_id, app_bundle);

COMMENT ON TABLE device_token IS
  'APNs device tokens registered by iOS clients. Cleared when APNs reports an invalid token. Owned exclusively by the apns.register-token and notification.dispatch edge functions.';
COMMENT ON COLUMN device_token.app_bundle IS
  'Which iOS app registered this token. Accepted values: ''parent'', ''kid''.';
COMMENT ON COLUMN device_token.platform IS
  'Push platform. Currently only ''ios'' is supported. Reserved for future Android support.';
