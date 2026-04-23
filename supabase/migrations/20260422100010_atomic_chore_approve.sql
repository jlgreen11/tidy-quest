-- atomic_chore_instance_approve (split from original 20260422100002_rpc_functions.sql)

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
