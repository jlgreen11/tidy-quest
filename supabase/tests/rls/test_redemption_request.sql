-- =============================================================================
-- RLS Tests: redemption_request table
-- supabase/tests/rls/test_redemption_request.sql
--
-- Seed IDs:
--   Family A:  11111111-1111-1111-1111-111111111111
--   Parent Mei: 22222222-2222-2222-2222-222222222221
--   Child Ava:  33333333-3333-3333-3333-333333333331
--   Child Zara: 33333333-3333-3333-3333-333333333333
--   Reward 501 (tablet time): 55555555-5555-5555-5555-555555555501
--
-- Note: redemption_request table DDL is owned by A1. Tests assume columns:
--   id, family_id, user_id, reward_id, status, requested_at, resulting_transaction_id
-- Adjust if A1 uses different column names.
-- =============================================================================

\i supabase/tests/rls/helpers.sql

BEGIN;

-- Setup: seed some redemption_requests as postgres (service_role equivalent)
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

INSERT INTO reward (id, family_id, name, icon, category, price, active)
VALUES ('b5b5b5b5-b5b5-b5b5-b5b5-b5b5b5b5b501',
        'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
        'Family B Reward', 'star', 'treat', 50, true)
ON CONFLICT (id) DO NOTHING;

-- Ava's pending redemption request
INSERT INTO redemption_request (id, family_id, user_id, reward_id, status, requested_at)
VALUES
  ('d1d1d1d1-d1d1-d1d1-d1d1-d1d1d1d1d101',
   '11111111-1111-1111-1111-111111111111',
   '33333333-3333-3333-3333-333333333331',  -- Ava
   '55555555-5555-5555-5555-555555555501',
   'pending', now() - interval '1 hour'),

  -- Zara's pending redemption request
  ('d1d1d1d1-d1d1-d1d1-d1d1-d1d1d1d1d102',
   '11111111-1111-1111-1111-111111111111',
   '33333333-3333-3333-3333-333333333333',  -- Zara
   '55555555-5555-5555-5555-555555555505',
   'pending', now() - interval '30 minutes'),

  -- Family B kid's request
  ('d1d1d1d1-d1d1-d1d1-d1d1-d1d1d1d1d103',
   'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
   'b3b3b3b3-b3b3-b3b3-b3b3-b3b3b3b3b331',
   'b5b5b5b5-b5b5-b5b5-b5b5-b5b5b5b5b501',
   'pending', now())
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- Test 1: Parent can SELECT all redemption_requests in own family
-- ============================================================================
SELECT tests.begin_test('redemption_request: parent can SELECT own family requests');
SELECT tests.set_as_parent(
  '22222222-2222-2222-2222-222222222221'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
SELECT tests.expect_rows(
  'SELECT * FROM redemption_request WHERE family_id = ''11111111-1111-1111-1111-111111111111''',
  2  -- Ava + Zara
);
SELECT tests.end_test('redemption_request: parent can SELECT own family requests');

-- ============================================================================
-- Test 2: Parent A CANNOT SELECT family B requests
-- ============================================================================
SELECT tests.begin_test('redemption_request: parent A cannot SELECT family B requests');
SELECT tests.set_as_parent(
  '22222222-2222-2222-2222-222222222221'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
SELECT tests.expect_rows(
  'SELECT * FROM redemption_request WHERE family_id = ''bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb''',
  0
);
SELECT tests.end_test('redemption_request: parent A cannot SELECT family B requests');

-- ============================================================================
-- Test 3: Child can SELECT own redemption_requests only
-- ============================================================================
SELECT tests.begin_test('redemption_request: child can SELECT own requests');
SELECT tests.set_as_child(
  '33333333-3333-3333-3333-333333333331'::uuid,  -- Ava
  '11111111-1111-1111-1111-111111111111'::uuid
);
SELECT tests.expect_rows(
  'SELECT * FROM redemption_request WHERE user_id = ''33333333-3333-3333-3333-333333333331''',
  1  -- only Ava's
);
SELECT tests.end_test('redemption_request: child can SELECT own requests');

-- ============================================================================
-- Test 4: Child CANNOT SELECT sibling's redemption_requests
-- ============================================================================
SELECT tests.begin_test('redemption_request: child cannot SELECT sibling requests');
SELECT tests.set_as_child(
  '33333333-3333-3333-3333-333333333331'::uuid,  -- Ava
  '11111111-1111-1111-1111-111111111111'::uuid
);
SELECT tests.expect_rows(
  'SELECT * FROM redemption_request WHERE id = ''d1d1d1d1-d1d1-d1d1-d1d1-d1d1d1d1d102''',  -- Zara's
  0
);
SELECT tests.end_test('redemption_request: child cannot SELECT sibling requests');

-- ============================================================================
-- Test 5: Child CANNOT SELECT family B requests
-- ============================================================================
SELECT tests.begin_test('redemption_request: child A cannot SELECT family B requests');
SELECT tests.set_as_child(
  '33333333-3333-3333-3333-333333333331'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
SELECT tests.expect_rows(
  'SELECT * FROM redemption_request WHERE family_id = ''bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb''',
  0
);
SELECT tests.end_test('redemption_request: child A cannot SELECT family B requests');

-- ============================================================================
-- Test 6: anon CANNOT SELECT any redemption_request
-- ============================================================================
SELECT tests.begin_test('redemption_request: anon cannot SELECT any row');
SELECT tests.set_as_anon();
SELECT tests.expect_rows('SELECT * FROM redemption_request', 0);
SELECT tests.end_test('redemption_request: anon cannot SELECT any row');

-- ============================================================================
-- Test 7: Child can INSERT own redemption_request (scoped to self + family)
-- ============================================================================
SELECT tests.begin_test('redemption_request: child can INSERT own request');
SELECT tests.set_as_child(
  '33333333-3333-3333-3333-333333333331'::uuid,  -- Ava
  '11111111-1111-1111-1111-111111111111'::uuid
);
INSERT INTO redemption_request (id, family_id, user_id, reward_id, status, requested_at)
VALUES ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeee01',
        '11111111-1111-1111-1111-111111111111',
        '33333333-3333-3333-3333-333333333331',
        '55555555-5555-5555-5555-555555555504',  -- stay up late
        'pending', now());
SELECT tests.expect_rows(
  'SELECT * FROM redemption_request WHERE id = ''eeeeeeee-eeee-eeee-eeee-eeeeeeeeee01''',
  1
);
SELECT tests.end_test('redemption_request: child can INSERT own request');

-- ============================================================================
-- Test 8: Child CANNOT INSERT redemption_request for sibling
-- ============================================================================
SELECT tests.begin_test('redemption_request: child cannot INSERT request for sibling');
SELECT tests.set_as_child(
  '33333333-3333-3333-3333-333333333331'::uuid,  -- Ava
  '11111111-1111-1111-1111-111111111111'::uuid
);
SELECT tests.expect_denied($$
  INSERT INTO redemption_request (id, family_id, user_id, reward_id, status, requested_at)
  VALUES (gen_random_uuid(),
          '11111111-1111-1111-1111-111111111111',
          '33333333-3333-3333-3333-333333333333',  -- Zara, not Ava
          '55555555-5555-5555-5555-555555555501',
          'pending', now())
$$);
SELECT tests.end_test('redemption_request: child cannot INSERT request for sibling');

-- ============================================================================
-- Test 9: Child CANNOT UPDATE a redemption_request (approve/deny is parent-only)
-- ============================================================================
SELECT tests.begin_test('redemption_request: child cannot UPDATE request status');
SELECT tests.set_as_child(
  '33333333-3333-3333-3333-333333333331'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
SELECT tests.expect_denied($$
  UPDATE redemption_request SET status = 'fulfilled'
  WHERE id = 'd1d1d1d1-d1d1-d1d1-d1d1-d1d1d1d1d101'
$$);
SELECT tests.end_test('redemption_request: child cannot UPDATE request status');

-- ============================================================================
-- Test 10: Parent can UPDATE redemption_request (approve flow)
-- ============================================================================
SELECT tests.begin_test('redemption_request: parent can UPDATE request to approved');
SELECT tests.set_as_parent(
  '22222222-2222-2222-2222-222222222221'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
UPDATE redemption_request SET status = 'fulfilled'
WHERE id = 'd1d1d1d1-d1d1-d1d1-d1d1-d1d1d1d1d101';
SELECT tests.expect_rows(
  'SELECT * FROM redemption_request WHERE id = ''d1d1d1d1-d1d1-d1d1-d1d1-d1d1d1d1d101'' AND status = ''fulfilled''',
  1
);
SELECT tests.end_test('redemption_request: parent can UPDATE request to approved');

-- Cleanup
SET ROLE postgres;
DELETE FROM family WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

ROLLBACK;
