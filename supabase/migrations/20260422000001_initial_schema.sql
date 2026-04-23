-- =============================================================================
-- TidyQuest — Initial Schema Migration
-- 20260422000001_initial_schema.sql
--
-- Creates all tables, enums, indexes, and the system sentinel user.
--
-- NOTE on uuid_generate_v7():
--   A canonical v7 UUID implementation requires reading the current timestamp
--   in milliseconds and encoding it per RFC 9562. We ship a simplified variant
--   below that uses gen_random_uuid() (v4) as the randomness source but overlays
--   the current ms timestamp in the upper 48 bits, giving time-sortable UUIDs
--   without a C extension dependency. The client (Swift TidyQuestCore) always
--   generates true v7 UUIDs and passes them in; this function is only the
--   Postgres-side fallback for server-generated rows (pg_cron jobs, etc.).
--   TODO: replace with pgcrypto + timeuuid extension when available on Supabase.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Extensions
-- ---------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "pgcrypto";   -- gen_random_bytes, gen_random_uuid
CREATE EXTENSION IF NOT EXISTS "pg_cron";    -- background jobs (migration 3)
CREATE EXTENSION IF NOT EXISTS "btree_gin";  -- GIN indexes on jsonb

-- ---------------------------------------------------------------------------
-- uuid_generate_v7() — time-sorted UUID fallback (server use only)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION uuid_generate_v7()
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
AS $$
DECLARE
  unix_ms   bigint;
  hex_ts    text;
  rand_part text;
BEGIN
  -- Current time in milliseconds since Unix epoch
  unix_ms   := floor(extract(epoch FROM clock_timestamp()) * 1000)::bigint;
  -- Encode timestamp as 12 hex chars (48 bits)
  hex_ts    := lpad(to_hex(unix_ms), 12, '0');
  -- Generate 80 bits of randomness (20 hex chars)
  rand_part := encode(gen_random_bytes(10), 'hex');

  -- Assemble: xxxxxxxx-xxxx-7xxx-yxxx-xxxxxxxxxxxx
  -- bytes:    [48-bit ts][4 bits = 7][12-bit rand][2 bits variant][62-bit rand]
  RETURN (
    substring(hex_ts, 1, 8) || '-' ||
    substring(hex_ts, 9, 4) || '-' ||
    '7' || substring(rand_part, 1, 3) || '-' ||
    -- Set variant bits: 10xx (values 8-b)
    to_hex((('x' || substring(rand_part, 4, 1))::bit(4)::int & 3 | 8)) ||
    substring(rand_part, 5, 3) || '-' ||
    substring(rand_part, 8, 12)
  )::uuid;
END;
$$;

COMMENT ON FUNCTION uuid_generate_v7() IS
  'Time-sortable UUID v7 fallback for server-generated IDs. Client (Swift) always supplies true v7 UUIDs; this function is only used when Postgres must generate an ID itself (pg_cron jobs, triggers). Implementation encodes Unix-ms timestamp in the upper 48 bits with random lower bits — not spec-perfect but sortable and collision-resistant.';

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------
CREATE TYPE chore_type_kind AS ENUM (
  'one_off',
  'daily',
  'weekly',
  'monthly',
  'seasonal',
  'routine_bound'
);

CREATE TYPE on_miss_policy AS ENUM (
  'skip',
  'decay',
  'deduct'
);

CREATE TYPE chore_instance_status AS ENUM (
  'pending',
  'completed',
  'missed',
  'approved',
  'rejected'
);

CREATE TYPE point_txn_kind AS ENUM (
  'chore_completion',
  'chore_bonus',
  'streak_bonus',
  'combo_bonus',
  'surprise_multiplier',
  'quest_completion',
  'redemption',
  'fine',
  'adjustment',
  'correction',
  'system_grant'
);

CREATE TYPE redemption_status AS ENUM (
  'pending',
  'fulfilled',
  'denied',
  'cancelled'
);

CREATE TYPE challenge_status AS ENUM (
  'draft',
  'active',
  'completed',
  'expired',
  'cancelled'
);

CREATE TYPE approval_request_kind AS ENUM (
  'chore_instance',
  'redemption_request',
  'transaction_contest'
);

CREATE TYPE approval_request_status AS ENUM (
  'pending',
  'approved',
  'denied',
  'cancelled'
);

CREATE TYPE notification_kind AS ENUM (
  'chore_approval_needed',
  'chore_approved',
  'chore_rejected',
  'redemption_approval_needed',
  'redemption_approved',
  'redemption_denied',
  'fine_issued',
  'streak_milestone',
  'quest_started',
  'quest_completed',
  'day2_reengage',
  'subscription_expiring',
  'system'
);

CREATE TYPE audit_action AS ENUM (
  'family.create',
  'family.delete',
  'family.recovery',
  'user.add',
  'user.remove',
  'user.role_change',
  'point_transaction.large',
  'point_transaction.reversal',
  'redemption.approve',
  'redemption.deny',
  'rls.deny',
  'auth.failed',
  'auth.device_pair',
  'auth.device_revoke',
  'subscription.state_change',
  'photo.upload',
  'photo.purge'
);

CREATE TYPE subscription_status AS ENUM (
  'trial',
  'active',
  'grace',
  'expired'
);

CREATE TYPE job_status AS ENUM (
  'success',
  'failure',
  'skipped'
);

-- ---------------------------------------------------------------------------
-- TABLE: family
-- ---------------------------------------------------------------------------
CREATE TABLE family (
  id                      uuid PRIMARY KEY DEFAULT uuid_generate_v7(),
  name                    text NOT NULL CHECK (length(name) BETWEEN 1 AND 100),
  timezone                text NOT NULL,  -- IANA, e.g., 'America/Los_Angeles'
  daily_reset_time        time NOT NULL DEFAULT '04:00',
  quiet_hours_start       time NOT NULL DEFAULT '21:00',
  quiet_hours_end         time NOT NULL DEFAULT '07:00',
  leaderboard_enabled     boolean NOT NULL DEFAULT false,
  sibling_ledger_visible  boolean NOT NULL DEFAULT false,
  subscription_tier       text NOT NULL DEFAULT 'trial'
    CHECK (subscription_tier IN ('trial','monthly','yearly','expired','grace')),
  subscription_expires_at timestamptz,
  weekly_band_target      int4range,      -- e.g., '[300, 500)'
  daily_deduction_cap     integer NOT NULL DEFAULT 50,
  weekly_deduction_cap    integer NOT NULL DEFAULT 150,
  settings                jsonb NOT NULL DEFAULT '{}',
  created_at              timestamptz NOT NULL DEFAULT now(),
  deleted_at              timestamptz
);

CREATE INDEX family_deleted_at_idx ON family (deleted_at) WHERE deleted_at IS NULL;

-- ---------------------------------------------------------------------------
-- TABLE: app_user
-- Named app_user to avoid collision with Postgres reserved word 'user'.
-- ---------------------------------------------------------------------------
CREATE TABLE app_user (
  id                           uuid PRIMARY KEY DEFAULT uuid_generate_v7(),
  -- family_id is nullable ONLY for the system sentinel (id = all-zeros).
  -- Every real user has a non-null family_id enforced via CHECK below.
  family_id                    uuid REFERENCES family(id) ON DELETE CASCADE,
  role                         text NOT NULL
    CHECK (role IN ('parent','child','caregiver','observer','system')),
  display_name                 text NOT NULL,
  avatar                       text NOT NULL,  -- asset identifier
  color                        text NOT NULL,  -- hex, palette-safe
  complexity_tier              text NOT NULL DEFAULT 'standard'
    CHECK (complexity_tier IN ('starter','standard','advanced')),
  birthdate                    date,
  apple_sub                    text UNIQUE,       -- parents only; nullable
  device_pairing_code          text,              -- kids; single-use; cleared after claim
  device_pairing_expires_at    timestamptz,
  cached_balance               integer NOT NULL DEFAULT 0,
  cached_balance_as_of_txn_id  uuid,
  created_at                   timestamptz NOT NULL DEFAULT now(),
  deleted_at                   timestamptz,

  -- Non-system users must have a family
  CONSTRAINT real_user_needs_family
    CHECK (
      (id = '00000000-0000-0000-0000-000000000000'::uuid AND family_id IS NULL)
      OR
      (id <> '00000000-0000-0000-0000-000000000000'::uuid AND family_id IS NOT NULL)
    )
);

CREATE INDEX app_user_family_id_idx ON app_user (family_id);
CREATE INDEX app_user_role_idx ON app_user (family_id, role);
CREATE INDEX app_user_deleted_idx ON app_user (deleted_at) WHERE deleted_at IS NULL;

-- ---------------------------------------------------------------------------
-- System sentinel user (inserted here, not in seed.sql, so it's always present)
-- seed.sql has: ON CONFLICT (id) DO NOTHING — safe to have it in both.
-- ---------------------------------------------------------------------------
INSERT INTO app_user (id, family_id, role, display_name, avatar, color, complexity_tier)
VALUES (
  '00000000-0000-0000-0000-000000000000',
  NULL,
  'system',
  'System',
  'gear',
  'slate',
  'advanced'
)
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- TABLE: chore_template
-- ---------------------------------------------------------------------------
CREATE TABLE chore_template (
  id                   uuid PRIMARY KEY DEFAULT uuid_generate_v7(),
  family_id            uuid NOT NULL REFERENCES family(id) ON DELETE CASCADE,
  name                 text NOT NULL,
  icon                 text NOT NULL,
  description          text,
  type                 chore_type_kind NOT NULL,
  schedule             jsonb NOT NULL DEFAULT '{}',
    -- { "daysOfWeek": [0..6], "dayOfMonth": n, "time": "HH:MM" }
  target_user_ids      uuid[] NOT NULL DEFAULT '{}',
  base_points          integer NOT NULL
    CHECK (base_points >= 0 AND base_points <= 500),
  cutoff_time          time,
  requires_photo       boolean NOT NULL DEFAULT false,
  requires_approval    boolean NOT NULL DEFAULT false,
  on_miss              on_miss_policy NOT NULL DEFAULT 'decay',
  on_miss_amount       integer NOT NULL DEFAULT 0,
  active               boolean NOT NULL DEFAULT true,
  created_at           timestamptz NOT NULL DEFAULT now(),
  archived_at          timestamptz
);

CREATE INDEX chore_template_family_idx ON chore_template (family_id);
CREATE INDEX chore_template_active_idx ON chore_template (family_id, active)
  WHERE active = true;

-- ---------------------------------------------------------------------------
-- TABLE: chore_instance
-- ---------------------------------------------------------------------------
CREATE TABLE chore_instance (
  id                   uuid PRIMARY KEY DEFAULT uuid_generate_v7(),
  template_id          uuid NOT NULL REFERENCES chore_template(id),
  user_id              uuid NOT NULL REFERENCES app_user(id),
  scheduled_for        date NOT NULL,       -- family-local calendar date
  window_start         time,
  window_end           time,
  status               chore_instance_status NOT NULL DEFAULT 'pending',
  completed_at         timestamptz,
  approved_at          timestamptz,
  proof_photo_id       uuid,                -- Storage object UUID
  awarded_points       integer,
  completed_by_device  text,               -- iPad multi-kid attribution
  completed_as_user    uuid,               -- who the device claimed to be
  created_at           timestamptz NOT NULL DEFAULT now(),

  -- Idempotency: one instance per (template, user, day)
  UNIQUE (template_id, user_id, scheduled_for)
);

CREATE INDEX chore_instance_user_date_idx
  ON chore_instance (user_id, scheduled_for);
CREATE INDEX chore_instance_template_idx
  ON chore_instance (template_id);
CREATE INDEX chore_instance_status_idx
  ON chore_instance (user_id, status)
  WHERE status IN ('pending', 'completed');
-- Same-family trigger applied in migration 20260422000002_triggers.sql

-- ---------------------------------------------------------------------------
-- TABLE: point_transaction  — the append-only ledger
-- ---------------------------------------------------------------------------
CREATE TABLE point_transaction (
  id                          uuid PRIMARY KEY DEFAULT uuid_generate_v7(),
  user_id                     uuid NOT NULL REFERENCES app_user(id),
  family_id                   uuid NOT NULL REFERENCES family(id),
  amount                      integer NOT NULL
    CHECK (amount BETWEEN -1000 AND 1000),
  kind                        point_txn_kind NOT NULL,
  reference_id                uuid,            -- polymorphic: chore_instance, reward, etc.
  reason                      text,
  created_by_user_id          uuid NOT NULL REFERENCES app_user(id),
  idempotency_key             uuid NOT NULL UNIQUE,
  chore_instance_id           uuid REFERENCES chore_instance(id),
  created_at                  timestamptz NOT NULL DEFAULT now(),
  reversed_by_transaction_id  uuid REFERENCES point_transaction(id),

  -- Negative transactions must carry a reason
  CHECK (amount >= 0 OR (reason IS NOT NULL AND length(reason) > 0))
);

-- Prevent double-credit for a single chore completion
CREATE UNIQUE INDEX pt_no_double_completion
  ON point_transaction (chore_instance_id)
  WHERE kind = 'chore_completion';

-- Fast balance computation and realtime queries
CREATE INDEX pt_user_id_idx ON point_transaction (user_id, created_at);
CREATE INDEX pt_family_id_idx ON point_transaction (family_id, created_at);

-- Triggers applied in migration 20260422000002_triggers.sql:
--   pt_append_only (BEFORE UPDATE OR DELETE)
--   pt_update_cached_balance (AFTER INSERT)

-- ---------------------------------------------------------------------------
-- TABLE: reward
-- ---------------------------------------------------------------------------
CREATE TABLE reward (
  id                uuid PRIMARY KEY DEFAULT uuid_generate_v7(),
  family_id         uuid NOT NULL REFERENCES family(id) ON DELETE CASCADE,
  name              text NOT NULL,
  icon              text NOT NULL,
  category          text NOT NULL,
    -- 'screen_time' | 'treat' | 'privilege' | 'cash_out' | 'saving_goal' | 'other'
  price             integer NOT NULL CHECK (price >= 0),
  cooldown          integer,    -- seconds; NULL = no cooldown
  auto_approve_under integer,   -- points threshold; NULL = never auto-approve
  active            boolean NOT NULL DEFAULT true,
  created_at        timestamptz NOT NULL DEFAULT now(),
  archived_at       timestamptz
);

CREATE INDEX reward_family_idx ON reward (family_id);
CREATE INDEX reward_active_idx ON reward (family_id, active) WHERE active = true;

-- ---------------------------------------------------------------------------
-- TABLE: redemption_request
-- ---------------------------------------------------------------------------
CREATE TABLE redemption_request (
  id                        uuid PRIMARY KEY DEFAULT uuid_generate_v7(),
  family_id                 uuid NOT NULL REFERENCES family(id) ON DELETE CASCADE,
  user_id                   uuid NOT NULL REFERENCES app_user(id),
  reward_id                 uuid NOT NULL REFERENCES reward(id),
  requested_at              timestamptz NOT NULL DEFAULT now(),
  status                    redemption_status NOT NULL DEFAULT 'pending',
  approved_by_user_id       uuid REFERENCES app_user(id),
  approved_at               timestamptz,
  resulting_transaction_id  uuid REFERENCES point_transaction(id),
  notes                     text,
  created_at                timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX redemption_request_family_status_idx
  ON redemption_request (family_id, status)
  WHERE status = 'pending';
CREATE INDEX redemption_request_user_idx
  ON redemption_request (user_id, requested_at);

-- ---------------------------------------------------------------------------
-- TABLE: routine
-- ---------------------------------------------------------------------------
CREATE TABLE routine (
  id                   uuid PRIMARY KEY DEFAULT uuid_generate_v7(),
  family_id            uuid NOT NULL REFERENCES family(id) ON DELETE CASCADE,
  name                 text NOT NULL,
  chore_template_ids   uuid[] NOT NULL DEFAULT '{}',   -- ordered list
  bonus_points         integer NOT NULL DEFAULT 0,
  active_for_user_ids  uuid[] NOT NULL DEFAULT '{}',
  time_window          jsonb,
    -- e.g., { "start": "07:00", "end": "09:00", "daysOfWeek": [1,2,3,4,5] }
  active               boolean NOT NULL DEFAULT true,
  created_at           timestamptz NOT NULL DEFAULT now(),
  archived_at          timestamptz
);

CREATE INDEX routine_family_idx ON routine (family_id);
CREATE INDEX routine_active_idx ON routine (family_id, active) WHERE active = true;

-- ---------------------------------------------------------------------------
-- TABLE: streak
-- Materialized per (user, chore_template) and (user, routine).
-- Exactly one of chore_template_id or routine_id must be non-null.
-- ---------------------------------------------------------------------------
CREATE TABLE streak (
  id                  uuid PRIMARY KEY DEFAULT uuid_generate_v7(),
  user_id             uuid NOT NULL REFERENCES app_user(id),
  chore_template_id   uuid REFERENCES chore_template(id),
  routine_id          uuid REFERENCES routine(id),
  current_length      integer NOT NULL DEFAULT 0,
  longest_length      integer NOT NULL DEFAULT 0,
  last_completed_date date,
  freezes_remaining   integer NOT NULL DEFAULT 0,  -- v1.0 feature; kept in schema
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),

  -- Exactly one of chore_template_id or routine_id must be set
  CONSTRAINT streak_xor_target
    CHECK (
      (chore_template_id IS NOT NULL AND routine_id IS NULL)
      OR
      (chore_template_id IS NULL AND routine_id IS NOT NULL)
    ),

  -- One streak row per (user, chore_template)
  UNIQUE (user_id, chore_template_id),
  -- One streak row per (user, routine)
  UNIQUE (user_id, routine_id)
);

CREATE INDEX streak_user_idx ON streak (user_id);

-- ---------------------------------------------------------------------------
-- TABLE: challenge  (a.k.a. quest)
-- ---------------------------------------------------------------------------
CREATE TABLE challenge (
  id                          uuid PRIMARY KEY DEFAULT uuid_generate_v7(),
  family_id                   uuid NOT NULL REFERENCES family(id) ON DELETE CASCADE,
  name                        text NOT NULL,
  description                 text,
  start_at                    timestamptz NOT NULL,
  end_at                      timestamptz NOT NULL,
  participant_user_ids         uuid[] NOT NULL DEFAULT '{}',
  constituent_chore_template_ids uuid[] NOT NULL DEFAULT '{}',
  bonus_points                integer NOT NULL DEFAULT 0,
  status                      challenge_status NOT NULL DEFAULT 'draft',
  created_at                  timestamptz NOT NULL DEFAULT now(),
  updated_at                  timestamptz NOT NULL DEFAULT now(),

  CHECK (end_at > start_at)
);

CREATE INDEX challenge_family_status_idx ON challenge (family_id, status);
CREATE INDEX challenge_active_idx
  ON challenge (family_id, start_at, end_at)
  WHERE status = 'active';

-- ---------------------------------------------------------------------------
-- TABLE: approval_request
-- Generalized: covers ChoreInstance approval, RedemptionRequest approval,
-- and contested point_transaction.
-- ---------------------------------------------------------------------------
CREATE TABLE approval_request (
  id                      uuid PRIMARY KEY DEFAULT uuid_generate_v7(),
  family_id               uuid NOT NULL REFERENCES family(id) ON DELETE CASCADE,
  requestor_user_id       uuid NOT NULL REFERENCES app_user(id),
  kind                    approval_request_kind NOT NULL,
  status                  approval_request_status NOT NULL DEFAULT 'pending',
  -- Polymorphic target — at most one non-null
  chore_instance_id       uuid REFERENCES chore_instance(id),
  redemption_request_id   uuid REFERENCES redemption_request(id),
  point_transaction_id    uuid REFERENCES point_transaction(id),
  reviewed_by_user_id     uuid REFERENCES app_user(id),
  reviewed_at             timestamptz,
  notes                   text,
  created_at              timestamptz NOT NULL DEFAULT now(),

  -- Exactly one target
  CONSTRAINT approval_request_one_target
    CHECK (
      (
        (chore_instance_id IS NOT NULL)::int +
        (redemption_request_id IS NOT NULL)::int +
        (point_transaction_id IS NOT NULL)::int
      ) = 1
    )
);

CREATE INDEX approval_request_family_status_idx
  ON approval_request (family_id, status)
  WHERE status = 'pending';
CREATE INDEX approval_request_requestor_idx
  ON approval_request (requestor_user_id);

-- ---------------------------------------------------------------------------
-- TABLE: notification
-- ---------------------------------------------------------------------------
CREATE TABLE notification (
  id          uuid PRIMARY KEY DEFAULT uuid_generate_v7(),
  family_id   uuid NOT NULL REFERENCES family(id) ON DELETE CASCADE,
  user_id     uuid NOT NULL REFERENCES app_user(id),
  kind        notification_kind NOT NULL,
  payload     jsonb NOT NULL DEFAULT '{}',
  sent_at     timestamptz,
  read_at     timestamptz,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX notification_user_unread_idx
  ON notification (user_id, created_at)
  WHERE read_at IS NULL;
CREATE INDEX notification_family_idx ON notification (family_id, created_at);

-- ---------------------------------------------------------------------------
-- TABLE: audit_log — append-only; trigger blocks UPDATE/DELETE
-- ---------------------------------------------------------------------------
CREATE TABLE audit_log (
  id              uuid PRIMARY KEY DEFAULT uuid_generate_v7(),
  family_id       uuid REFERENCES family(id),   -- nullable: some events are pre-family
  actor_user_id   uuid REFERENCES app_user(id),
  action          audit_action NOT NULL,
  target          text,       -- e.g., 'point_transaction:77777...'
  payload         jsonb NOT NULL DEFAULT '{}',
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX audit_log_family_idx ON audit_log (family_id, created_at);
CREATE INDEX audit_log_actor_idx  ON audit_log (actor_user_id, created_at);
CREATE INDEX audit_log_action_idx ON audit_log (action, created_at);

-- Append-only trigger applied in migration 20260422000002_triggers.sql

-- ---------------------------------------------------------------------------
-- TABLE: subscription — one row per family
-- ---------------------------------------------------------------------------
CREATE TABLE subscription (
  id                    uuid PRIMARY KEY DEFAULT uuid_generate_v7(),
  family_id             uuid NOT NULL UNIQUE REFERENCES family(id) ON DELETE CASCADE,
  store_transaction_id  text,
  product_id            text,
  tier                  text NOT NULL
    CHECK (tier IN ('trial','monthly','yearly')),
  purchased_at          timestamptz,
  expires_at            timestamptz,
  status                subscription_status NOT NULL DEFAULT 'trial',
  receipt_hash          text,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX subscription_expires_idx ON subscription (expires_at)
  WHERE status IN ('trial','active','grace');

-- ---------------------------------------------------------------------------
-- TABLE: job_log — pg_cron job observability; append-only; infinite retention
-- ---------------------------------------------------------------------------
CREATE TABLE job_log (
  id            uuid PRIMARY KEY DEFAULT uuid_generate_v7(),
  job_name      text NOT NULL,
  started_at    timestamptz NOT NULL DEFAULT now(),
  finished_at   timestamptz,
  status        job_status,
  rows_affected integer,
  error_message text,
  metadata      jsonb NOT NULL DEFAULT '{}'
);

CREATE INDEX job_log_name_idx     ON job_log (job_name, started_at);
CREATE INDEX job_log_status_idx   ON job_log (status, started_at);
CREATE INDEX job_log_started_idx  ON job_log (started_at);

-- ---------------------------------------------------------------------------
-- Comments on tables for pg documentation
-- ---------------------------------------------------------------------------
COMMENT ON TABLE family IS
  'Top-level tenant. All data is scoped by family_id. Soft-deleted via deleted_at.';
COMMENT ON TABLE app_user IS
  'Family members. Named app_user to avoid conflict with Postgres reserved word. System sentinel at id=00000000...';
COMMENT ON TABLE chore_template IS
  'Template defining a recurring or one-off chore. Instances are generated daily by pg_cron.';
COMMENT ON TABLE chore_instance IS
  'One specific occurrence of a chore on a specific date for a specific user. UNIQUE(template_id,user_id,scheduled_for) makes daily reset idempotent.';
COMMENT ON TABLE point_transaction IS
  'Append-only ledger. UPDATE/DELETE blocked by trigger. Balance derived from SUM; cached in app_user.cached_balance.';
COMMENT ON TABLE reward IS
  'Reward catalog entry. Price set by parent; auto_approve_under enables pre-approval rules.';
COMMENT ON TABLE redemption_request IS
  'Kid requests a reward. Approval atomically debits balance and marks fulfilled.';
COMMENT ON TABLE routine IS
  'Named collection of chore_templates. Completion bonus fires when all constituent chores are approved.';
COMMENT ON TABLE streak IS
  'Materialized streak per (user, chore_template) or (user, routine). Updated by trigger on chore_instance status change.';
COMMENT ON TABLE challenge IS
  'Time-boxed quest: bundle of chores with bonus payout. Lifecycle managed by pg_cron.';
COMMENT ON TABLE approval_request IS
  'Generalized approval: covers chore proof review, redemption queue, and contested transactions.';
COMMENT ON TABLE notification IS
  'Push and in-app notification record. sent_at = null means queued but not yet dispatched.';
COMMENT ON TABLE audit_log IS
  'Append-only audit trail. actor_user_id nullable for pre-auth events.';
COMMENT ON TABLE subscription IS
  'One row per family, updated by subscription.update edge function only. StoreKit 2 receipt validated server-side.';
COMMENT ON TABLE job_log IS
  'pg_cron job run log. Infinite retention for observability. No PII stored.';
