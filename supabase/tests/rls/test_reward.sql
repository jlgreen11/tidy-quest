-- =============================================================================
-- RLS Tests: reward table
-- supabase/tests/rls/test_reward.sql
--
-- Seed IDs:
--   Family A:  11111111-1111-1111-1111-111111111111
--   Parent Mei: 22222222-2222-2222-2222-222222222221
--   Child Ava:  33333333-3333-3333-3333-333333333331
--   Reward 501 (tablet time): 55555555-5555-5555-5555-555555555501
--   Reward 506 (Lego kit):    55555555-5555-5555-5555-555555555506
-- =============================================================================

\i supabase/tests/rls/helpers.sql

BEGIN;

-- Setup: family B + one reward
SET ROLE postgres;
INSERT INTO family (id, name, timezone, daily_reset_time, quiet_hours_start, quiet_hours_end,
                    leaderboard_enabled, sibling_ledger_visible, subscription_tier,
                    daily_deduction_cap, weekly_deduction_cap, settings)
VALUES ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Family B', 'America/New_York',
        '04:00', '21:00', '07:00', false, false, 'trial', 50, 150, '{}')
ON CONFLICT (id) DO NOTHING;

INSERT INTO app_user (id, family_id, role, display_name, avatar, color, complexity_tier)
VALUES ('b2b2b2b2-b2b2-b2b2-b2b2-b2b2b2b2b221',
        'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
        'parent', 'Parent B', 'parent-1', 'coral', 'standard')
ON CONFLICT (id) DO NOTHING;

INSERT INTO reward (id, family_id, name, icon, category, price, active)
VALUES ('b5b5b5b5-b5b5-b5b5-b5b5-b5b5b5b5b501',
        'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
        'Family B Reward', 'star', 'treat', 50, true)
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- Test 1: Parent can SELECT all rewards in own family
-- ============================================================================
SELECT tests.begin_test('reward: parent can SELECT own family rewards');
SELECT tests.set_as_parent(
  '22222222-2222-2222-2222-222222222221'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
-- Seed has 7 rewards in family A
SELECT tests.expect_rows(
  'SELECT * FROM reward WHERE family_id = ''11111111-1111-1111-1111-111111111111''',
  7
);
SELECT tests.end_test('reward: parent can SELECT own family rewards');

-- ============================================================================
-- Test 2: Parent A CANNOT SELECT family B rewards
-- ============================================================================
SELECT tests.begin_test('reward: parent A cannot SELECT family B rewards');
SELECT tests.set_as_parent(
  '22222222-2222-2222-2222-222222222221'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
SELECT tests.expect_rows(
  'SELECT * FROM reward WHERE family_id = ''bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb''',
  0
);
SELECT tests.end_test('reward: parent A cannot SELECT family B rewards');

-- ============================================================================
-- Test 3: Child can SELECT the full reward catalog for own family
-- ============================================================================
SELECT tests.begin_test('reward: child can SELECT own family reward catalog');
SELECT tests.set_as_child(
  '33333333-3333-3333-3333-333333333331'::uuid,  -- Ava
  '11111111-1111-1111-1111-111111111111'::uuid
);
SELECT tests.expect_rows(
  'SELECT * FROM reward WHERE family_id = ''11111111-1111-1111-1111-111111111111''',
  7
);
SELECT tests.end_test('reward: child can SELECT own family reward catalog');

-- ============================================================================
-- Test 4: Child CANNOT SELECT family B rewards
-- ============================================================================
SELECT tests.begin_test('reward: child A cannot SELECT family B rewards');
SELECT tests.set_as_child(
  '33333333-3333-3333-3333-333333333331'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
SELECT tests.expect_rows(
  'SELECT * FROM reward WHERE family_id = ''bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb''',
  0
);
SELECT tests.end_test('reward: child A cannot SELECT family B rewards');

-- ============================================================================
-- Test 5: anon CANNOT SELECT any reward
-- ============================================================================
SELECT tests.begin_test('reward: anon cannot SELECT any reward');
SELECT tests.set_as_anon();
SELECT tests.expect_rows('SELECT * FROM reward', 0);
SELECT tests.end_test('reward: anon cannot SELECT any reward');

-- ============================================================================
-- Test 6: Child CANNOT INSERT a reward
-- ============================================================================
SELECT tests.begin_test('reward: child cannot INSERT reward');
SELECT tests.set_as_child(
  '33333333-3333-3333-3333-333333333331'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
SELECT tests.expect_denied($$
  INSERT INTO reward (id, family_id, name, icon, category, price, active)
  VALUES (gen_random_uuid(),
          '11111111-1111-1111-1111-111111111111',
          'Free Money', 'dollarsign.circle.fill', 'cash_out', 0, true)
$$);
SELECT tests.end_test('reward: child cannot INSERT reward');

-- ============================================================================
-- Test 7: Child CANNOT UPDATE a reward
-- ============================================================================
SELECT tests.begin_test('reward: child cannot UPDATE reward price');
SELECT tests.set_as_child(
  '33333333-3333-3333-3333-333333333331'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
SELECT tests.expect_denied($$
  UPDATE reward SET price = 1
  WHERE id = '55555555-5555-5555-5555-555555555506'
$$);
SELECT tests.end_test('reward: child cannot UPDATE reward price');

-- ============================================================================
-- Test 8: Parent can INSERT a new reward
-- ============================================================================
SELECT tests.begin_test('reward: parent can INSERT reward');
SELECT tests.set_as_parent(
  '22222222-2222-2222-2222-222222222221'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
INSERT INTO reward (id, family_id, name, icon, category, price, active)
VALUES ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeee01',
        '11111111-1111-1111-1111-111111111111',
        'Movie Night', 'film.fill', 'privilege', 120, true);
SELECT tests.expect_rows(
  'SELECT * FROM reward WHERE id = ''eeeeeeee-eeee-eeee-eeee-eeeeeeeeee01''',
  1
);
SELECT tests.end_test('reward: parent can INSERT reward');

-- ============================================================================
-- Test 9: Parent can UPDATE reward in own family
-- ============================================================================
SELECT tests.begin_test('reward: parent can UPDATE reward');
SELECT tests.set_as_parent(
  '22222222-2222-2222-2222-222222222221'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
UPDATE reward SET price = 80
WHERE id = '55555555-5555-5555-5555-555555555501';
SELECT tests.expect_rows(
  'SELECT * FROM reward WHERE id = ''55555555-5555-5555-5555-555555555501'' AND price = 80',
  1
);
SELECT tests.end_test('reward: parent can UPDATE reward');

-- ============================================================================
-- Test 10: Parent A CANNOT UPDATE family B reward
-- ============================================================================
SELECT tests.begin_test('reward: parent A cannot UPDATE family B reward');
SELECT tests.set_as_parent(
  '22222222-2222-2222-2222-222222222221'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
UPDATE reward SET price = 1
WHERE id = 'b5b5b5b5-b5b5-b5b5-b5b5-b5b5b5b5b501';
SET ROLE postgres;
SELECT tests.expect_rows(
  'SELECT * FROM reward WHERE id = ''b5b5b5b5-b5b5-b5b5-b5b5-b5b5b5b5b501'' AND price = 1',
  0
);
SELECT tests.end_test('reward: parent A cannot UPDATE family B reward');

-- Cleanup
SET ROLE postgres;
DELETE FROM family WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

ROLLBACK;
