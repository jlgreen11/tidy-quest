-- =============================================================================
-- RLS Tests: point_transaction table
-- supabase/tests/rls/test_point_transaction.sql
--
-- This is the most security-critical table: append-only ledger.
-- UPDATE and DELETE must be denied by BOTH RLS and the trigger.
--
-- Seed IDs:
--   Family A:  11111111-1111-1111-1111-111111111111
--   Parent Mei: 22222222-2222-2222-2222-222222222221
--   Child Zara: 33333333-3333-3333-3333-333333333333
--   Child Ava:  33333333-3333-3333-3333-333333333331
--   Child Kai:  33333333-3333-3333-3333-333333333332
--   Zara's fine txn: 77777777-7777-7777-7777-777777777701
-- =============================================================================

\i supabase/tests/rls/helpers.sql

BEGIN;

-- Setup: family B for cross-family isolation
SET ROLE postgres;
INSERT INTO family (id, name, timezone, daily_reset_time, quiet_hours_start, quiet_hours_end,
                    leaderboard_enabled, sibling_ledger_visible, subscription_tier,
                    daily_deduction_cap, weekly_deduction_cap, settings)
VALUES ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Family B', 'America/New_York',
        '04:00', '21:00', '07:00', false, false, 'trial', 50, 150, '{}')
ON CONFLICT (id) DO NOTHING;

INSERT INTO app_user (id, family_id, role, display_name, avatar, color, complexity_tier)
VALUES
  ('b2b2b2b2-b2b2-b2b2-b2b2-b2b2b2b2b221',
   'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
   'parent', 'Parent B', 'parent-1', 'coral', 'standard'),
  ('b3b3b3b3-b3b3-b3b3-b3b3-b3b3b3b3b331',
   'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
   'child', 'Kid B', 'kid-rocket', 'sky', 'standard')
ON CONFLICT (id) DO NOTHING;

INSERT INTO point_transaction (id, user_id, family_id, amount, kind,
                               created_by_user_id, idempotency_key, created_at)
VALUES ('b7b7b7b7-b7b7-b7b7-b7b7-b7b7b7b7b701',
        'b3b3b3b3-b3b3-b3b3-b3b3-b3b3b3b3b331',
        'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
        10, 'chore_completion',
        'b2b2b2b2-b2b2-b2b2-b2b2-b2b2b2b2b221',
        gen_random_uuid(), now())
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- Test 1: Parent can SELECT all transactions in own family
-- ============================================================================
SELECT tests.begin_test('point_transaction: parent can SELECT own family transactions');
SELECT tests.set_as_parent(
  '22222222-2222-2222-2222-222222222221'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
-- At least Zara's fine txn must be visible
SELECT tests.expect_rows(
  'SELECT * FROM point_transaction WHERE id = ''77777777-7777-7777-7777-777777777701''',
  1
);
SELECT tests.end_test('point_transaction: parent can SELECT own family transactions');

-- ============================================================================
-- Test 2: Parent A CANNOT SELECT family B transactions
-- ============================================================================
SELECT tests.begin_test('point_transaction: parent A cannot SELECT family B transactions');
SELECT tests.set_as_parent(
  '22222222-2222-2222-2222-222222222221'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
SELECT tests.expect_rows(
  'SELECT * FROM point_transaction WHERE family_id = ''bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb''',
  0
);
SELECT tests.end_test('point_transaction: parent A cannot SELECT family B transactions');

-- ============================================================================
-- Test 3: Child can SELECT own transactions (sibling_ledger_visible=false in seed)
-- ============================================================================
SELECT tests.begin_test('point_transaction: child can SELECT own transactions');
SELECT tests.set_as_child(
  '33333333-3333-3333-3333-333333333333'::uuid,  -- Zara
  '11111111-1111-1111-1111-111111111111'::uuid
);
-- Zara's fine should be visible to her
SELECT tests.expect_rows(
  'SELECT * FROM point_transaction WHERE id = ''77777777-7777-7777-7777-777777777701''',
  1
);
SELECT tests.end_test('point_transaction: child can SELECT own transactions');

-- ============================================================================
-- Test 4: Child CANNOT SELECT sibling transactions (sibling_ledger_visible=false)
-- ============================================================================
SELECT tests.begin_test('point_transaction: child cannot SELECT sibling transactions when ledger hidden');
SELECT tests.set_as_child(
  '33333333-3333-3333-3333-333333333331'::uuid,  -- Ava
  '11111111-1111-1111-1111-111111111111'::uuid
);
-- Zara's fine belongs to Zara, not Ava
SELECT tests.expect_rows(
  'SELECT * FROM point_transaction WHERE id = ''77777777-7777-7777-7777-777777777701''',
  0
);
SELECT tests.end_test('point_transaction: child cannot SELECT sibling transactions when ledger hidden');

-- ============================================================================
-- Test 5: Child CANNOT SELECT family B transactions
-- ============================================================================
SELECT tests.begin_test('point_transaction: child A cannot SELECT family B transactions');
SELECT tests.set_as_child(
  '33333333-3333-3333-3333-333333333331'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
SELECT tests.expect_rows(
  'SELECT * FROM point_transaction WHERE family_id = ''bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb''',
  0
);
SELECT tests.end_test('point_transaction: child A cannot SELECT family B transactions');

-- ============================================================================
-- Test 6: anon CANNOT SELECT any point_transaction
-- ============================================================================
SELECT tests.begin_test('point_transaction: anon cannot SELECT any row');
SELECT tests.set_as_anon();
SELECT tests.expect_rows('SELECT * FROM point_transaction', 0);
SELECT tests.end_test('point_transaction: anon cannot SELECT any row');

-- ============================================================================
-- Test 7: Child CANNOT INSERT a point_transaction directly
-- ============================================================================
SELECT tests.begin_test('point_transaction: child cannot INSERT directly');
SELECT tests.set_as_child(
  '33333333-3333-3333-3333-333333333331'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
SELECT tests.expect_denied($$
  INSERT INTO point_transaction (id, user_id, family_id, amount, kind,
                                 created_by_user_id, idempotency_key)
  VALUES (gen_random_uuid(),
          '33333333-3333-3333-3333-333333333331',
          '11111111-1111-1111-1111-111111111111',
          500, 'chore_completion',
          '33333333-3333-3333-3333-333333333331',
          gen_random_uuid())
$$);
SELECT tests.end_test('point_transaction: child cannot INSERT directly');

-- ============================================================================
-- Test 8: Parent CANNOT UPDATE a point_transaction (RLS layer denial)
-- ============================================================================
SELECT tests.begin_test('point_transaction: parent cannot UPDATE (RLS denies)');
SELECT tests.set_as_parent(
  '22222222-2222-2222-2222-222222222221'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
-- No UPDATE policy exists for authenticated → RLS silently denies (0 rows) or
-- the enforce_append_only trigger fires as secondary defense.
-- We verify no exception is raised (RLS is silent) but amount is unchanged:
UPDATE point_transaction SET amount = 999
WHERE id = '77777777-7777-7777-7777-777777777701';
-- Reset to postgres to verify unchanged
SET ROLE postgres;
SELECT tests.expect_rows(
  'SELECT * FROM point_transaction WHERE id = ''77777777-7777-7777-7777-777777777701'' AND amount = 999',
  0
);
SELECT tests.end_test('point_transaction: parent cannot UPDATE (RLS denies)');

-- ============================================================================
-- Test 9: Even service_role UPDATE is blocked by enforce_append_only trigger
-- ============================================================================
SELECT tests.begin_test('point_transaction: service_role UPDATE blocked by trigger');
SET ROLE postgres;  -- service_role bypasses RLS but NOT triggers
SELECT tests.expect_denied($$
  UPDATE point_transaction SET amount = 999
  WHERE id = '77777777-7777-7777-7777-777777777701'
$$);
SELECT tests.end_test('point_transaction: service_role UPDATE blocked by trigger');

-- ============================================================================
-- Test 10: Even service_role DELETE is blocked by enforce_append_only trigger
-- ============================================================================
SELECT tests.begin_test('point_transaction: service_role DELETE blocked by trigger');
SET ROLE postgres;
SELECT tests.expect_denied($$
  DELETE FROM point_transaction
  WHERE id = '77777777-7777-7777-7777-777777777701'
$$);
SELECT tests.end_test('point_transaction: service_role DELETE blocked by trigger');

-- ============================================================================
-- Test 11: Child can SELECT own transactions but NOT sibling's even if same family
-- (redundancy check on sibling_ledger_visible=false path — using Kai as viewer)
-- ============================================================================
SELECT tests.begin_test('point_transaction: Kai cannot see Ava transactions');
SELECT tests.set_as_child(
  '33333333-3333-3333-3333-333333333332'::uuid,  -- Kai
  '11111111-1111-1111-1111-111111111111'::uuid
);
-- Zara's fine belongs to Zara, not Kai
SELECT tests.expect_rows(
  'SELECT * FROM point_transaction WHERE user_id = ''33333333-3333-3333-3333-333333333331''',
  0  -- Kai cannot see Ava's transactions
);
SELECT tests.end_test('point_transaction: Kai cannot see Ava transactions');

-- ============================================================================
-- Test 12: Parent cannot DELETE a point_transaction (RLS denies)
-- ============================================================================
SELECT tests.begin_test('point_transaction: parent cannot DELETE (RLS denies)');
SELECT tests.set_as_parent(
  '22222222-2222-2222-2222-222222222221'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
DELETE FROM point_transaction
WHERE id = '77777777-7777-7777-7777-777777777701';
-- Verify row still exists (RLS silently blocked or trigger raised)
SET ROLE postgres;
SELECT tests.expect_rows(
  'SELECT * FROM point_transaction WHERE id = ''77777777-7777-7777-7777-777777777701''',
  1
);
SELECT tests.end_test('point_transaction: parent cannot DELETE (RLS denies)');

-- Cleanup — outer ROLLBACK discards everything inserted in this file,
-- so no explicit DELETE is needed (and DELETE FROM family would fail on
-- FK constraints from point_transaction anyway).
ROLLBACK;
