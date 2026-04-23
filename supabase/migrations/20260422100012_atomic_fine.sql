-- atomic_point_transaction_fine (split from original 20260422100002_rpc_functions.sql)

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
