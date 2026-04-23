-- atomic_point_transaction_reverse (split from original 20260422100002_rpc_functions.sql)

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
