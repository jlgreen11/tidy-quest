-- =============================================================================
-- RLS Tests: app_user table
-- supabase/tests/rls/test_app_user.sql
--
-- Seed IDs:
--   Family A:  11111111-1111-1111-1111-111111111111
--   Parent Mei: 22222222-2222-2222-2222-222222222221
--   Parent Luis: 22222222-2222-2222-2222-222222222222
--   Child Ava:  33333333-3333-3333-3333-333333333331
--   Child Kai:  33333333-3333-3333-3333-333333333332
--   Child Zara: 33333333-3333-3333-3333-333333333333
--   System sentinel: 00000000-0000-0000-0000-000000000000
-- =============================================================================

\i supabase/tests/rls/helpers.sql

BEGIN;

-- Setup: second family for cross-family tests
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

-- ============================================================================
-- Test 1: Parent can SELECT all family members in own family
-- ============================================================================
SELECT tests.begin_test('app_user: parent can SELECT all family members');
SELECT tests.set_as_parent(
  '22222222-2222-2222-2222-222222222221'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
-- 2 parents + 4 kids = 6 users in family A
SELECT tests.expect_rows(
  'SELECT * FROM app_user WHERE family_id = ''11111111-1111-1111-1111-111111111111''',
  6
);
SELECT tests.end_test('app_user: parent can SELECT all family members');

-- ============================================================================
-- Test 2: Parent A CANNOT SELECT family B members
-- ============================================================================
SELECT tests.begin_test('app_user: parent A cannot SELECT family B members');
SELECT tests.set_as_parent(
  '22222222-2222-2222-2222-222222222221'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
SELECT tests.expect_rows(
  'SELECT * FROM app_user WHERE family_id = ''bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb''',
  0
);
SELECT tests.end_test('app_user: parent A cannot SELECT family B members');

-- ============================================================================
-- Test 3: System sentinel is globally readable by authenticated
-- ============================================================================
SELECT tests.begin_test('app_user: system sentinel is readable by any authenticated user');
SELECT tests.set_as_child(
  '33333333-3333-3333-3333-333333333331'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
SELECT tests.expect_rows(
  'SELECT * FROM app_user WHERE id = ''00000000-0000-0000-0000-000000000000''',
  1
);
SELECT tests.end_test('app_user: system sentinel is readable by any authenticated user');

-- ============================================================================
-- Test 4: Child can SELECT only own row (not siblings)
-- ============================================================================
SELECT tests.begin_test('app_user: child can SELECT own row only');
SELECT tests.set_as_child(
  '33333333-3333-3333-3333-333333333331'::uuid,  -- Ava
  '11111111-1111-1111-1111-111111111111'::uuid
);
SELECT tests.expect_rows(
  'SELECT * FROM app_user WHERE family_id = ''11111111-1111-1111-1111-111111111111''',
  1  -- only Ava's own row + sentinel covered by a separate policy
);
SELECT tests.end_test('app_user: child can SELECT own row only');

-- ============================================================================
-- Test 5: Child CANNOT SELECT sibling row
-- ============================================================================
SELECT tests.begin_test('app_user: child cannot SELECT sibling row');
SELECT tests.set_as_child(
  '33333333-3333-3333-3333-333333333331'::uuid,  -- Ava
  '11111111-1111-1111-1111-111111111111'::uuid
);
SELECT tests.expect_rows(
  'SELECT * FROM app_user WHERE id = ''33333333-3333-3333-3333-333333333332''',  -- Kai
  0
);
SELECT tests.end_test('app_user: child cannot SELECT sibling row');

-- ============================================================================
-- Test 6: Child CANNOT SELECT family B users
-- ============================================================================
SELECT tests.begin_test('app_user: child A cannot SELECT family B users');
SELECT tests.set_as_child(
  '33333333-3333-3333-3333-333333333331'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
SELECT tests.expect_rows(
  'SELECT * FROM app_user WHERE family_id = ''bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb''',
  0
);
SELECT tests.end_test('app_user: child A cannot SELECT family B users');

-- ============================================================================
-- Test 7: anon CANNOT SELECT any app_user row
-- ============================================================================
SELECT tests.begin_test('app_user: anon cannot SELECT any row');
SELECT tests.set_as_anon();
SELECT tests.expect_rows('SELECT * FROM app_user', 0);
SELECT tests.end_test('app_user: anon cannot SELECT any row');

-- ============================================================================
-- Test 8: Child CANNOT INSERT a new user
-- ============================================================================
SELECT tests.begin_test('app_user: child cannot INSERT user');
SELECT tests.set_as_child(
  '33333333-3333-3333-3333-333333333331'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
SELECT tests.expect_denied($$
  INSERT INTO app_user (id, family_id, role, display_name, avatar, color, complexity_tier)
  VALUES ('deadbeef-dead-beef-dead-beefdeadbeef',
          '11111111-1111-1111-1111-111111111111',
          'child', 'Ghost Kid', 'kid-star', 'coral', 'standard')
$$);
SELECT tests.end_test('app_user: child cannot INSERT user');

-- ============================================================================
-- Test 9: Child CANNOT UPDATE own row (e.g., change their role)
-- ============================================================================
SELECT tests.begin_test('app_user: child cannot UPDATE own row');
SELECT tests.set_as_child(
  '33333333-3333-3333-3333-333333333331'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
SELECT tests.expect_denied($$
  UPDATE app_user SET role = 'parent'
  WHERE id = '33333333-3333-3333-3333-333333333331'
$$);
SELECT tests.end_test('app_user: child cannot UPDATE own row');

-- ============================================================================
-- Test 10: Parent can INSERT new family member
-- ============================================================================
SELECT tests.begin_test('app_user: parent can INSERT new family member');
SELECT tests.set_as_parent(
  '22222222-2222-2222-2222-222222222221'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
INSERT INTO app_user (id, family_id, role, display_name, avatar, color, complexity_tier)
VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        '11111111-1111-1111-1111-111111111111',
        'child', 'New Kid', 'kid-star', 'sage', 'starter');
SELECT tests.expect_rows(
  'SELECT * FROM app_user WHERE id = ''aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa''',
  1
);
SELECT tests.end_test('app_user: parent can INSERT new family member');

-- ============================================================================
-- Test 11: Parent CANNOT INSERT user into family B
-- ============================================================================
SELECT tests.begin_test('app_user: parent A cannot INSERT user into family B');
SELECT tests.set_as_parent(
  '22222222-2222-2222-2222-222222222221'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
SELECT tests.expect_denied($$
  INSERT INTO app_user (id, family_id, role, display_name, avatar, color, complexity_tier)
  VALUES ('cccccccc-cccc-cccc-cccc-cccccccccccc',
          'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
          'child', 'Planted Kid', 'kid-star', 'sky', 'starter')
$$);
SELECT tests.end_test('app_user: parent A cannot INSERT user into family B');

-- ============================================================================
-- Test 12: System sentinel is NOT modifiable by any authenticated user
-- ============================================================================
SELECT tests.begin_test('app_user: system sentinel cannot be modified by parent');
SELECT tests.set_as_parent(
  '22222222-2222-2222-2222-222222222221'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
-- sentinel has family_id=NULL, so parent policy (family_id = tq_family_id()) will NOT match
SELECT tests.expect_denied($$
  UPDATE app_user SET display_name = 'Hacked System'
  WHERE id = '00000000-0000-0000-0000-000000000000'
$$);
SELECT tests.end_test('app_user: system sentinel cannot be modified by parent');

-- Cleanup
SET ROLE postgres;
DELETE FROM family WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

ROLLBACK;
