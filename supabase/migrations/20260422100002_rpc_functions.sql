-- =============================================================================
-- TidyQuest — Atomic RPC functions for multi-step edge function operations
-- 20260422100002_rpc_functions.sql
--
-- These Postgres functions are called via supabase.rpc() from edge functions
-- to ensure atomicity at the DB level.  Each function runs inside its own
-- implicit transaction; if any statement raises an exception the entire
-- function call is rolled back automatically by Postgres.
--
-- Must run after 20260422000002_triggers.sql (tables + triggers exist).
-- =============================================================================


-- ---------------------------------------------------------------------------
-- 1. atomic_chore_instance_approve
--    Atomically: update instance status → 'approved',
--                insert point_transaction (chore_completion),
--                insert audit_log entry.
--    Returns the inserted point_transaction row as JSON.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION atomic_chore_instance_approve(
  p_instance_id          uuid,
  p_approver_user_id     uuid,
  p_idempotency_key      uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_instance        chore_instance%ROWTYPE;
  v_template        chore_template%ROWTYPE;
  v_user            app_user%ROWTYPE;
  v_txn_id          uuid;
  v_balance_after   integer;
  v_txn             jsonb;
BEGIN
  -- Lock the instance
  SELECT * INTO v_instance
    FROM chore_instance
   WHERE id = p_instance_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'INVALID_INSTANCE: chore_instance % not found', p_instance_id
      USING ERRCODE = 'no_data_found';
  END IF;

  -- Only 'completed' instances can be approved (requires_approval path)
  IF v_instance.status NOT IN ('completed', 'pending') THEN
    RAISE EXCEPTION 'CHORE_ALREADY_COMPLETED: instance status is %', v_instance.status
      USING ERRCODE = 'unique_violation';
  END IF;

  -- Fetch template for base_points
  SELECT * INTO v_template
    FROM chore_template
   WHERE id = v_instance.template_id;

  -- Fetch user for family_id
  SELECT * INTO v_user
    FROM app_user
   WHERE id = v_instance.user_id;

  -- Idempotency: if a completion transaction already exists, return it
  SELECT jsonb_build_object(
    'id', pt.id,
    'user_id', pt.user_id,
    'family_id', pt.family_id,
    'amount', pt.amount,
    'kind', pt.kind,
    'chore_instance_id', pt.chore_instance_id,
    'idempotency_key', pt.idempotency_key,
    'created_at', pt.created_at
  ) INTO v_txn
  FROM point_transaction pt
  WHERE pt.chore_instance_id = p_instance_id
    AND pt.kind = 'chore_completion';

  IF v_txn IS NOT NULL THEN
    RETURN v_txn;
  END IF;

  -- Update instance
  UPDATE chore_instance
     SET status      = 'approved',
         approved_at = now(),
         awarded_points = v_template.base_points
   WHERE id = p_instance_id;

  -- Generate transaction ID
  v_txn_id := uuid_generate_v7();

  -- Insert point transaction
  INSERT INTO point_transaction (
    id, user_id, family_id, amount, kind,
    reference_id, chore_instance_id,
    created_by_user_id, idempotency_key,
    reason
  ) VALUES (
    v_txn_id,
    v_instance.user_id,
    v_user.family_id,
    v_template.base_points,
    'chore_completion',
    p_instance_id,
    p_instance_id,
    p_approver_user_id,
    p_idempotency_key,
    'Chore completed: ' || v_template.name
  );

  -- Fetch updated balance (trigger already ran, cached_balance is up to date)
  SELECT cached_balance INTO v_balance_after
    FROM app_user WHERE id = v_instance.user_id;

  -- Audit log
  INSERT INTO audit_log (family_id, actor_user_id, action, target, payload)
  VALUES (
    v_user.family_id,
    p_approver_user_id,
    'redemption.approve',  -- closest available audit action; using structured payload
    'chore_instance:' || p_instance_id::text,
    jsonb_build_object(
      'event',            'chore_instance.approve',
      'instance_id',      p_instance_id,
      'template_id',      v_instance.template_id,
      'awarded_points',   v_template.base_points,
      'transaction_id',   v_txn_id,
      'balance_after',    v_balance_after
    )
  );

  RETURN jsonb_build_object(
    'id',                v_txn_id,
    'user_id',           v_instance.user_id,
    'family_id',         v_user.family_id,
    'amount',            v_template.base_points,
    'kind',              'chore_completion',
    'chore_instance_id', p_instance_id,
    'idempotency_key',   p_idempotency_key,
    'balance_after',     v_balance_after,
    'created_at',        now()
  );
END;
$$;

COMMENT ON FUNCTION atomic_chore_instance_approve IS
  'Atomically approves a chore instance and inserts a point_transaction. Called by chore-instance.approve edge function.';


-- ---------------------------------------------------------------------------
-- 2. atomic_redemption_approve
--    Atomically: verify balance >= price,
--                verify reward cooldown,
--                INSERT point_transaction (redemption, negative amount),
--                UPDATE redemption_request to fulfilled,
--                INSERT audit_log.
--    Returns jsonb with transaction and updated request.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION atomic_redemption_approve(
  p_request_id           uuid,
  p_approver_user_id     uuid,
  p_idempotency_key      uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_req             redemption_request%ROWTYPE;
  v_reward          reward%ROWTYPE;
  v_user            app_user%ROWTYPE;
  v_balance         integer;
  v_last_redemption timestamptz;
  v_txn_id          uuid;
  v_balance_after   integer;
BEGIN
  -- Lock the redemption request
  SELECT * INTO v_req
    FROM redemption_request
   WHERE id = p_request_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'NOT_FOUND: redemption_request % not found', p_request_id
      USING ERRCODE = 'no_data_found';
  END IF;

  IF v_req.status <> 'pending' THEN
    RAISE EXCEPTION 'CONFLICT: redemption_request status is %, expected pending', v_req.status
      USING ERRCODE = 'unique_violation';
  END IF;

  -- Fetch reward
  SELECT * INTO v_reward FROM reward WHERE id = v_req.reward_id;
  IF NOT FOUND OR v_reward.active = false THEN
    RAISE EXCEPTION 'REWARD_UNAVAILABLE: reward % not found or inactive', v_req.reward_id
      USING ERRCODE = 'no_data_found';
  END IF;

  -- Fetch user for current balance
  SELECT * INTO v_user FROM app_user WHERE id = v_req.user_id FOR UPDATE;
  v_balance := v_user.cached_balance;

  -- Balance check
  IF v_balance < v_reward.price THEN
    RAISE EXCEPTION 'INSUFFICIENT_BALANCE: balance=% price=%', v_balance, v_reward.price
      USING ERRCODE = 'check_violation';
  END IF;

  -- Cooldown check: look at last fulfilled redemption for this reward+user
  IF v_reward.cooldown IS NOT NULL THEN
    SELECT MAX(rr.approved_at) INTO v_last_redemption
      FROM redemption_request rr
     WHERE rr.user_id  = v_req.user_id
       AND rr.reward_id = v_req.reward_id
       AND rr.status   = 'fulfilled';

    IF v_last_redemption IS NOT NULL AND
       v_last_redemption + (v_reward.cooldown || ' seconds')::interval > now() THEN
      RAISE EXCEPTION 'COOLDOWN_ACTIVE: next eligible at %',
        (v_last_redemption + (v_reward.cooldown || ' seconds')::interval)
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;

  -- Idempotency: if transaction already exists for this request, return it
  IF v_req.resulting_transaction_id IS NOT NULL THEN
    RETURN jsonb_build_object(
      'already_fulfilled', true,
      'resulting_transaction_id', v_req.resulting_transaction_id
    );
  END IF;

  -- Insert point transaction (negative: debit)
  v_txn_id := uuid_generate_v7();

  INSERT INTO point_transaction (
    id, user_id, family_id, amount, kind,
    reference_id, created_by_user_id, idempotency_key,
    reason
  ) VALUES (
    v_txn_id,
    v_req.user_id,
    v_req.family_id,
    -v_reward.price,
    'redemption',
    p_request_id,
    p_approver_user_id,
    p_idempotency_key,
    'Redemption: ' || v_reward.name
  );

  -- Balance after (trigger has updated cached_balance)
  SELECT cached_balance INTO v_balance_after
    FROM app_user WHERE id = v_req.user_id;

  -- Update redemption_request
  UPDATE redemption_request
     SET status                   = 'fulfilled',
         approved_by_user_id      = p_approver_user_id,
         approved_at              = now(),
         resulting_transaction_id = v_txn_id
   WHERE id = p_request_id;

  -- Audit log
  INSERT INTO audit_log (family_id, actor_user_id, action, target, payload)
  VALUES (
    v_req.family_id,
    p_approver_user_id,
    'redemption.approve',
    'redemption_request:' || p_request_id::text,
    jsonb_build_object(
      'request_id',       p_request_id,
      'reward_id',        v_req.reward_id,
      'reward_name',      v_reward.name,
      'price',            v_reward.price,
      'user_id',          v_req.user_id,
      'transaction_id',   v_txn_id,
      'balance_before',   v_balance,
      'balance_after',    v_balance_after
    )
  );

  RETURN jsonb_build_object(
    'transaction_id',    v_txn_id,
    'amount',            -v_reward.price,
    'balance_after',     v_balance_after,
    'request_id',        p_request_id,
    'reward_id',         v_req.reward_id,
    'fulfilled_at',      now()
  );
END;
$$;

COMMENT ON FUNCTION atomic_redemption_approve IS
  'Atomically approves a redemption request: verifies balance, cooldown, debits points, marks fulfilled. Called by redemption.approve edge function.';


-- ---------------------------------------------------------------------------
-- 3. atomic_point_transaction_fine
--    Checks daily/weekly deduction caps for the family, then inserts fine.
--    Returns jsonb with transaction and balance_after.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION atomic_point_transaction_fine(
  p_user_id            uuid,
  p_amount             integer,     -- positive; will be negated
  p_reason             text,
  p_canned_reason_key  text,
  p_created_by_user_id uuid,
  p_idempotency_key    uuid,
  p_family_timezone    text         -- IANA timezone for day/week boundary calculation
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user                app_user%ROWTYPE;
  v_family              family%ROWTYPE;
  v_today_deductions    integer;
  v_week_deductions     integer;
  v_txn_id              uuid;
  v_balance_after       integer;
  v_effective_reason    text;
  v_today_local         date;
  v_week_start          date;
BEGIN
  -- Lock the user row
  SELECT * INTO v_user FROM app_user WHERE id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'NOT_FOUND: user % not found', p_user_id
      USING ERRCODE = 'no_data_found';
  END IF;

  SELECT * INTO v_family FROM family WHERE id = v_user.family_id;

  -- Calculate today and week boundaries in family timezone
  v_today_local := (now() AT TIME ZONE p_family_timezone)::date;
  -- Week starts on Monday
  v_week_start := date_trunc('week', now() AT TIME ZONE p_family_timezone)::date;

  -- Sum today's fines (negative transactions of kind='fine')
  SELECT COALESCE(SUM(ABS(amount)), 0) INTO v_today_deductions
    FROM point_transaction
   WHERE user_id = p_user_id
     AND kind    = 'fine'
     AND amount  < 0
     AND (created_at AT TIME ZONE p_family_timezone)::date = v_today_local;

  IF v_today_deductions + p_amount > v_family.daily_deduction_cap THEN
    RAISE EXCEPTION 'DAILY_DEDUCTION_CAP_EXCEEDED: today=% cap=% requested=%',
      v_today_deductions, v_family.daily_deduction_cap, p_amount
      USING ERRCODE = 'check_violation';
  END IF;

  -- Sum this week's fines
  SELECT COALESCE(SUM(ABS(amount)), 0) INTO v_week_deductions
    FROM point_transaction
   WHERE user_id = p_user_id
     AND kind    = 'fine'
     AND amount  < 0
     AND (created_at AT TIME ZONE p_family_timezone)::date >= v_week_start;

  IF v_week_deductions + p_amount > v_family.weekly_deduction_cap THEN
    RAISE EXCEPTION 'WEEKLY_DEDUCTION_CAP_EXCEEDED: week=% cap=% requested=%',
      v_week_deductions, v_family.weekly_deduction_cap, p_amount
      USING ERRCODE = 'check_violation';
  END IF;

  -- Build effective reason
  v_effective_reason := COALESCE(p_reason, p_canned_reason_key);

  v_txn_id := uuid_generate_v7();

  INSERT INTO point_transaction (
    id, user_id, family_id, amount, kind,
    created_by_user_id, idempotency_key, reason
  ) VALUES (
    v_txn_id,
    p_user_id,
    v_user.family_id,
    -p_amount,   -- negate: stored as negative
    'fine',
    p_created_by_user_id,
    p_idempotency_key,
    v_effective_reason
  );

  SELECT cached_balance INTO v_balance_after
    FROM app_user WHERE id = p_user_id;

  -- Audit log for fines
  INSERT INTO audit_log (family_id, actor_user_id, action, target, payload)
  VALUES (
    v_user.family_id,
    p_created_by_user_id,
    'point_transaction.large',
    'point_transaction:' || v_txn_id::text,
    jsonb_build_object(
      'event',              'fine',
      'user_id',            p_user_id,
      'amount',             -p_amount,
      'reason',             v_effective_reason,
      'canned_reason_key',  p_canned_reason_key,
      'balance_after',      v_balance_after,
      'today_deductions',   v_today_deductions + p_amount,
      'week_deductions',    v_week_deductions + p_amount
    )
  );

  RETURN jsonb_build_object(
    'id',            v_txn_id,
    'user_id',       p_user_id,
    'family_id',     v_user.family_id,
    'amount',        -p_amount,
    'kind',          'fine',
    'reason',        v_effective_reason,
    'balance_after', v_balance_after,
    'created_at',    now()
  );
END;
$$;

COMMENT ON FUNCTION atomic_point_transaction_fine IS
  'Checks daily/weekly deduction caps then inserts a fine transaction atomically. Called by point-transaction.fine edge function.';


-- ---------------------------------------------------------------------------
-- 4. atomic_point_transaction_reverse
--    Creates a correction transaction with opposite sign and sets
--    reversed_by_transaction_id on the original, using the privileged path.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION atomic_point_transaction_reverse(
  p_original_txn_id      uuid,
  p_reverser_user_id     uuid,
  p_idempotency_key      uuid,
  p_reason               text DEFAULT 'Transaction reversed'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_orig       point_transaction%ROWTYPE;
  v_corr_id    uuid;
  v_balance_after integer;
BEGIN
  -- Lock original
  SELECT * INTO v_orig
    FROM point_transaction
   WHERE id = p_original_txn_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'NOT_FOUND: point_transaction % not found', p_original_txn_id
      USING ERRCODE = 'no_data_found';
  END IF;

  -- Cannot reverse an already-reversed transaction
  IF v_orig.reversed_by_transaction_id IS NOT NULL THEN
    RAISE EXCEPTION 'CONFLICT: transaction % is already reversed by %',
      p_original_txn_id, v_orig.reversed_by_transaction_id
      USING ERRCODE = 'unique_violation';
  END IF;

  -- Cannot reverse a correction (prevents infinite loops)
  IF v_orig.kind = 'correction' THEN
    RAISE EXCEPTION 'CONFLICT: cannot reverse a correction transaction'
      USING ERRCODE = 'check_violation';
  END IF;

  v_corr_id := uuid_generate_v7();

  -- Insert correction transaction (opposite sign)
  INSERT INTO point_transaction (
    id, user_id, family_id, amount, kind,
    reference_id, created_by_user_id, idempotency_key, reason
  ) VALUES (
    v_corr_id,
    v_orig.user_id,
    v_orig.family_id,
    -v_orig.amount,   -- opposite sign
    'correction',
    p_original_txn_id,
    p_reverser_user_id,
    p_idempotency_key,
    p_reason
  );

  -- Enable privileged path for the UPDATE
  PERFORM set_config('app.privileged_reversal_path', 'true', true);

  -- Set reversed_by_transaction_id on original
  UPDATE point_transaction
     SET reversed_by_transaction_id = v_corr_id
   WHERE id = p_original_txn_id;

  -- Disable privileged path
  PERFORM set_config('app.privileged_reversal_path', 'false', true);

  SELECT cached_balance INTO v_balance_after
    FROM app_user WHERE id = v_orig.user_id;

  -- Audit log
  INSERT INTO audit_log (family_id, actor_user_id, action, target, payload)
  VALUES (
    v_orig.family_id,
    p_reverser_user_id,
    'point_transaction.reversal',
    'point_transaction:' || p_original_txn_id::text,
    jsonb_build_object(
      'original_txn_id',     p_original_txn_id,
      'correction_txn_id',   v_corr_id,
      'original_amount',     v_orig.amount,
      'correction_amount',   -v_orig.amount,
      'original_kind',       v_orig.kind,
      'user_id',             v_orig.user_id,
      'reason',              p_reason,
      'balance_after',       v_balance_after
    )
  );

  RETURN jsonb_build_object(
    'original_transaction_id',   p_original_txn_id,
    'correction_transaction_id', v_corr_id,
    'correction_amount',         -v_orig.amount,
    'balance_after',             v_balance_after,
    'created_at',                now()
  );
END;
$$;

COMMENT ON FUNCTION atomic_point_transaction_reverse IS
  'Atomically reverses a point_transaction by inserting a correction with opposite sign and linking back. Called by point-transaction.reverse edge function.';
