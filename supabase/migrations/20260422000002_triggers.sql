-- =============================================================================
-- TidyQuest — Triggers Migration
-- 20260422000002_triggers.sql
--
-- All trigger functions and trigger registrations.
-- Must run after 20260422000001_initial_schema.sql.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- HELPER: get family_id for a given app_user id
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION _get_user_family_id(p_user_id uuid)
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT family_id FROM app_user WHERE id = p_user_id;
$$;

-- ---------------------------------------------------------------------------
-- 1. check_chore_instance_same_family
--    Enforces template.family_id = user.family_id on chore_instance.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION check_chore_instance_same_family()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_template_family_id uuid;
  v_user_family_id     uuid;
BEGIN
  SELECT family_id INTO v_template_family_id
    FROM chore_template
   WHERE id = NEW.template_id;

  SELECT family_id INTO v_user_family_id
    FROM app_user
   WHERE id = NEW.user_id;

  IF v_template_family_id IS DISTINCT FROM v_user_family_id THEN
    RAISE EXCEPTION
      'chore_instance cross-family violation: template.family_id=% user.family_id=%',
      v_template_family_id, v_user_family_id
      USING ERRCODE = 'integrity_constraint_violation';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER chore_instance_same_family
BEFORE INSERT OR UPDATE ON chore_instance
FOR EACH ROW EXECUTE FUNCTION check_chore_instance_same_family();

-- ---------------------------------------------------------------------------
-- 2. check_redemption_request_same_family
--    Enforces user.family_id = reward.family_id = redemption_request.family_id
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION check_redemption_request_same_family()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_user_family_id   uuid;
  v_reward_family_id uuid;
BEGIN
  SELECT family_id INTO v_user_family_id
    FROM app_user WHERE id = NEW.user_id;

  SELECT family_id INTO v_reward_family_id
    FROM reward WHERE id = NEW.reward_id;

  IF v_user_family_id IS DISTINCT FROM NEW.family_id THEN
    RAISE EXCEPTION
      'redemption_request: user.family_id=% does not match family_id=%',
      v_user_family_id, NEW.family_id
      USING ERRCODE = 'integrity_constraint_violation';
  END IF;

  IF v_reward_family_id IS DISTINCT FROM NEW.family_id THEN
    RAISE EXCEPTION
      'redemption_request: reward.family_id=% does not match family_id=%',
      v_reward_family_id, NEW.family_id
      USING ERRCODE = 'integrity_constraint_violation';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER redemption_request_same_family
BEFORE INSERT OR UPDATE ON redemption_request
FOR EACH ROW EXECUTE FUNCTION check_redemption_request_same_family();

-- ---------------------------------------------------------------------------
-- 3. check_approval_request_same_family
--    Enforces requestor_user_id.family_id = approval_request.family_id
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION check_approval_request_same_family()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_requestor_family_id uuid;
BEGIN
  SELECT family_id INTO v_requestor_family_id
    FROM app_user WHERE id = NEW.requestor_user_id;

  IF v_requestor_family_id IS DISTINCT FROM NEW.family_id THEN
    RAISE EXCEPTION
      'approval_request: requestor.family_id=% does not match family_id=%',
      v_requestor_family_id, NEW.family_id
      USING ERRCODE = 'integrity_constraint_violation';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER approval_request_same_family
BEFORE INSERT OR UPDATE ON approval_request
FOR EACH ROW EXECUTE FUNCTION check_approval_request_same_family();

-- ---------------------------------------------------------------------------
-- 4. enforce_append_only
--    Blocks UPDATE and DELETE on point_transaction and audit_log.
--    Exception: the privileged reversal path sets session variable
--    'app.privileged_reversal_path' = 'true' (via SET LOCAL inside a txn).
--    This allows the point-transaction.reverse edge function to write
--    reversed_by_transaction_id on the original row.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION enforce_append_only()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  -- Allow update ONLY to set reversed_by_transaction_id via privileged path
  IF TG_OP = 'UPDATE' THEN
    IF current_setting('app.privileged_reversal_path', true) = 'true' THEN
      -- Only permit writing reversed_by_transaction_id; block all other column changes
      IF TG_TABLE_NAME = 'point_transaction' THEN
        IF (
          NEW.id                         = OLD.id          AND
          NEW.user_id                    = OLD.user_id     AND
          NEW.family_id                  = OLD.family_id   AND
          NEW.amount                     = OLD.amount      AND
          NEW.kind                       = OLD.kind        AND
          NEW.created_by_user_id         = OLD.created_by_user_id AND
          NEW.idempotency_key            = OLD.idempotency_key   AND
          NEW.created_at                 = OLD.created_at
        ) THEN
          RETURN NEW;  -- Only metadata changed (reversed_by_transaction_id); permit
        ELSE
          RAISE EXCEPTION
            'point_transaction: privileged reversal path may only set reversed_by_transaction_id'
            USING ERRCODE = 'integrity_constraint_violation';
        END IF;
      END IF;
    END IF;

    -- Default: block all updates
    RAISE EXCEPTION
      'UPDATE on % is not permitted; this table is append-only. Use point-transaction.reverse edge function for reversals.',
      TG_TABLE_NAME
      USING ERRCODE = 'integrity_constraint_violation';
  END IF;

  -- Always block DELETE
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION
      'DELETE on % is not permitted; this table is append-only.',
      TG_TABLE_NAME
      USING ERRCODE = 'integrity_constraint_violation';
  END IF;

  RETURN NULL;  -- Should never reach here
END;
$$;

CREATE TRIGGER pt_append_only
BEFORE UPDATE OR DELETE ON point_transaction
FOR EACH ROW EXECUTE FUNCTION enforce_append_only();

CREATE TRIGGER audit_log_append_only
BEFORE UPDATE OR DELETE ON audit_log
FOR EACH ROW EXECUTE FUNCTION enforce_append_only();

-- ---------------------------------------------------------------------------
-- 5. update_cached_balance
--    After INSERT on point_transaction, atomically update app_user.cached_balance
--    and cached_balance_as_of_txn_id.
--    Also logs to audit_log when |amount| > 100 (large transaction event).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_cached_balance()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_new_balance integer;
BEGIN
  -- Atomically increment cached balance
  UPDATE app_user
     SET cached_balance = cached_balance + NEW.amount,
         cached_balance_as_of_txn_id = NEW.id
   WHERE id = NEW.user_id
  RETURNING cached_balance INTO v_new_balance;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'update_cached_balance: app_user not found for id=%', NEW.user_id
      USING ERRCODE = 'no_data_found';
  END IF;

  -- Audit large transactions (absolute value > 100 points)
  IF abs(NEW.amount) > 100 THEN
    INSERT INTO audit_log (family_id, actor_user_id, action, target, payload)
    VALUES (
      NEW.family_id,
      NEW.created_by_user_id,
      'point_transaction.large',
      'point_transaction:' || NEW.id::text,
      jsonb_build_object(
        'amount',         NEW.amount,
        'kind',           NEW.kind,
        'balance_after',  v_new_balance,
        'user_id',        NEW.user_id
      )
    );
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER pt_update_cached_balance
AFTER INSERT ON point_transaction
FOR EACH ROW EXECUTE FUNCTION update_cached_balance();

-- ---------------------------------------------------------------------------
-- 6. update_streak_on_chore_status_change
--    When a chore_instance transitions to 'approved' (or 'completed' if
--    no approval required), update the streak for that (user, template).
--    Upserts a streak row; resets streak to 0 if last_completed_date gap > 1 day.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_streak_on_chore_status_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_last_date date;
  v_current   integer;
  v_longest   integer;
  v_new_current integer;
BEGIN
  -- Only fire when transitioning INTO approved
  IF NOT (NEW.status = 'approved' AND (OLD.status IS DISTINCT FROM 'approved')) THEN
    RETURN NEW;
  END IF;

  -- Fetch existing streak for this (user, template)
  SELECT last_completed_date, current_length, longest_length
    INTO v_last_date, v_current, v_longest
    FROM streak
   WHERE user_id = NEW.user_id
     AND chore_template_id = NEW.template_id;

  IF NOT FOUND THEN
    -- First time: create streak row
    INSERT INTO streak (user_id, chore_template_id, current_length, longest_length, last_completed_date)
    VALUES (NEW.user_id, NEW.template_id, 1, 1, NEW.scheduled_for);
    RETURN NEW;
  END IF;

  -- Compute new current streak length
  IF v_last_date IS NULL THEN
    v_new_current := 1;
  ELSIF NEW.scheduled_for = v_last_date + interval '1 day' THEN
    v_new_current := v_current + 1;
  ELSIF NEW.scheduled_for = v_last_date THEN
    -- Same day re-approval; no change
    RETURN NEW;
  ELSE
    -- Gap: reset streak
    v_new_current := 1;
  END IF;

  UPDATE streak
     SET current_length      = v_new_current,
         longest_length      = GREATEST(v_longest, v_new_current),
         last_completed_date = NEW.scheduled_for,
         updated_at          = now()
   WHERE user_id = NEW.user_id
     AND chore_template_id = NEW.template_id;

  RETURN NEW;
END;
$$;

CREATE TRIGGER chore_instance_update_streak
AFTER UPDATE ON chore_instance
FOR EACH ROW EXECUTE FUNCTION update_streak_on_chore_status_change();

-- ---------------------------------------------------------------------------
-- 7. update_subscription_updated_at
--    Auto-maintain updated_at on subscription rows.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION touch_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER subscription_touch_updated_at
BEFORE UPDATE ON subscription
FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

CREATE TRIGGER streak_touch_updated_at
BEFORE UPDATE ON streak
FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

CREATE TRIGGER challenge_touch_updated_at
BEFORE UPDATE ON challenge
FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
