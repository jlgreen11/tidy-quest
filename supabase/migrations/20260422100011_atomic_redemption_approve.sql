-- atomic_redemption_approve (split from original 20260422100002_rpc_functions.sql)

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
