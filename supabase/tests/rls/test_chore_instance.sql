-- =============================================================================
-- RLS Tests: chore_instance table
-- supabase/tests/rls/test_chore_instance.sql
--
-- Seed IDs:
--   Family A:  11111111-1111-1111-1111-111111111111
--   Parent Mei: 22222222-2222-2222-2222-222222222221
--   Child Ava:  33333333-3333-3333-3333-333333333331
--   Child Kai:  33333333-3333-3333-3333-333333333332
--   Child Zara: 33333333-3333-3333-3333-333333333333
--   Ava's instance today (make-bed approved): 66666666-6666-6666-6666-666666666601
--   Ava's instance today (brush-teeth pending): 66666666-6666-6666-6666-666666666602
--   Kai's instance today (make-bed approved): 66666666-6666-6666-6666-666666666603
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

INSERT INTO chore_template (id, family_id, name, icon, type, schedule,
                            target_user_ids, base_points, requires_photo,
                            requires_approval, on_miss, on_miss_amount, active)
VALUES ('b4b4b4b4-b4b4-b4b4-b4b4-b4b4b4b4b401',
        'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
        'Family B Chore', 'star', 'daily', '{"daysOfWeek":[0,1,2,3,4,5,6]}',
        ARRAY['b3b3b3b3-b3b3-b3b3-b3b3-b3b3b3b3b331']::uuid[],
        10, false, false, 'decay', 0, true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO chore_instance (id, template_id, user_id, scheduled_for, status, created_at)
VALUES ('b6b6b6b6-b6b6-b6b6-b6b6-b6b6b6b6b601',
        'b4b4b4b4-b4b4-b4b4-b4b4-b4b4b4b4b401',
        'b3b3b3b3-b3b3-b3b3-b3b3-b3b3b3b3b331',
        current_date, 'pending', now())
ON CONFLICT (template_id, user_id, scheduled_for) DO NOTHING;

-- ============================================================================
-- Test 1: Parent can SELECT all chore_instances in own family
-- ============================================================================
SELECT tests.begin_test('chore_instance: parent can SELECT own family instances');
SELECT tests.set_as_parent(
  '22222222-2222-2222-2222-222222222221'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
-- Seed has 8 today-instances (66..601 through 66..608) plus many historical
-- Just verify today's 8 are visible
SELECT tests.expect_rows(
  'SELECT * FROM chore_instance WHERE id IN (
     ''66666666-6666-6666-6666-666666666601'',
     ''66666666-6666-6666-6666-666666666602'',
     ''66666666-6666-6666-6666-666666666603'',
     ''66666666-6666-6666-6666-666666666604'',
     ''66666666-6666-6666-6666-666666666605'',
     ''66666666-6666-6666-6666-666666666606'',
     ''66666666-6666-6666-6666-666666666607'',
     ''66666666-6666-6666-6666-666666666608''
   )',
  8
);
SELECT tests.end_test('chore_instance: parent can SELECT own family instances');

-- ============================================================================
-- Test 2: Parent A CANNOT SELECT family B instances
-- ============================================================================
SELECT tests.begin_test('chore_instance: parent A cannot SELECT family B instance');
SELECT tests.set_as_parent(
  '22222222-2222-2222-2222-222222222221'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
SELECT tests.expect_rows(
  'SELECT * FROM chore_instance WHERE id = ''b6b6b6b6-b6b6-b6b6-b6b6-b6b6b6b6b601''',
  0
);
SELECT tests.end_test('chore_instance: parent A cannot SELECT family B instance');

-- ============================================================================
-- Test 3: Child can SELECT own instances only
-- ============================================================================
SELECT tests.begin_test('chore_instance: child can SELECT own instances');
SELECT tests.set_as_child(
  '33333333-3333-3333-3333-333333333331'::uuid,  -- Ava
  '11111111-1111-1111-1111-111111111111'::uuid
);
SELECT tests.expect_rows(
  'SELECT * FROM chore_instance WHERE id IN (
     ''66666666-6666-6666-6666-666666666601'',
     ''66666666-6666-6666-6666-666666666602''
   )',
  2  -- both are Ava's
);
SELECT tests.end_test('chore_instance: child can SELECT own instances');

-- ============================================================================
-- Test 4: Child CANNOT SELECT sibling's chore_instance
-- ============================================================================
SELECT tests.begin_test('chore_instance: child cannot SELECT sibling instance');
SELECT tests.set_as_child(
  '33333333-3333-3333-3333-333333333331'::uuid,  -- Ava
  '11111111-1111-1111-1111-111111111111'::uuid
);
-- 66..603 belongs to Kai
SELECT tests.expect_rows(
  'SELECT * FROM chore_instance WHERE id = ''66666666-6666-6666-6666-666666666603''',
  0
);
SELECT tests.end_test('chore_instance: child cannot SELECT sibling instance');

-- ============================================================================
-- Test 5: Child CANNOT SELECT family B instance
-- ============================================================================
SELECT tests.begin_test('chore_instance: child A cannot SELECT family B instance');
SELECT tests.set_as_child(
  '33333333-3333-3333-3333-333333333331'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
SELECT tests.expect_rows(
  'SELECT * FROM chore_instance WHERE id = ''b6b6b6b6-b6b6-b6b6-b6b6-b6b6b6b6b601''',
  0
);
SELECT tests.end_test('chore_instance: child A cannot SELECT family B instance');

-- ============================================================================
-- Test 6: anon CANNOT SELECT any chore_instance
-- ============================================================================
SELECT tests.begin_test('chore_instance: anon cannot SELECT any row');
SELECT tests.set_as_anon();
SELECT tests.expect_rows('SELECT * FROM chore_instance', 0);
SELECT tests.end_test('chore_instance: anon cannot SELECT any row');

-- ============================================================================
-- Test 7: Child CANNOT directly INSERT a chore_instance (edge fn uses service_role)
-- ============================================================================
SELECT tests.begin_test('chore_instance: child cannot INSERT chore_instance directly');
SELECT tests.set_as_child(
  '33333333-3333-3333-3333-333333333331'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
SELECT tests.expect_denied($$
  INSERT INTO chore_instance (id, template_id, user_id, scheduled_for, status)
  VALUES ('deadbeef-dead-beef-dead-beefdeadbe01',
          '44444444-4444-4444-4444-444444444401',
          '33333333-3333-3333-3333-333333333331',
          current_date + 1, 'completed')
$$);
SELECT tests.end_test('chore_instance: child cannot INSERT chore_instance directly');

-- ============================================================================
-- Test 8: Child CANNOT UPDATE chore_instance.status directly
-- ============================================================================
SELECT tests.begin_test('chore_instance: child cannot UPDATE chore_instance status');
SELECT tests.set_as_child(
  '33333333-3333-3333-3333-333333333331'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
SELECT tests.expect_denied($$
  UPDATE chore_instance SET status = 'approved'
  WHERE id = '66666666-6666-6666-6666-666666666602'
$$);
SELECT tests.end_test('chore_instance: child cannot UPDATE chore_instance status');

-- ============================================================================
-- Test 9: Parent can UPDATE chore_instance (approve/reject)
-- ============================================================================
SELECT tests.begin_test('chore_instance: parent can UPDATE chore_instance status');
SELECT tests.set_as_parent(
  '22222222-2222-2222-2222-222222222221'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
UPDATE chore_instance SET status = 'approved'
WHERE id = '66666666-6666-6666-6666-666666666606';  -- Zara's cats-fed
SELECT tests.expect_rows(
  'SELECT * FROM chore_instance WHERE id = ''66666666-6666-6666-6666-666666666606'' AND status = ''approved''',
  1
);
SELECT tests.end_test('chore_instance: parent can UPDATE chore_instance status');

-- ============================================================================
-- Test 10: Parent A CANNOT UPDATE family B instance
-- ============================================================================
SELECT tests.begin_test('chore_instance: parent A cannot UPDATE family B instance');
SELECT tests.set_as_parent(
  '22222222-2222-2222-2222-222222222221'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
UPDATE chore_instance SET status = 'approved'
WHERE id = 'b6b6b6b6-b6b6-b6b6-b6b6-b6b6b6b6b601';
-- row not visible, 0 rows updated
SET ROLE postgres;
SELECT tests.expect_rows(
  'SELECT * FROM chore_instance WHERE id = ''b6b6b6b6-b6b6-b6b6-b6b6-b6b6b6b6b601'' AND status = ''approved''',
  0
);
SELECT tests.end_test('chore_instance: parent A cannot UPDATE family B instance');

-- Cleanup
SET ROLE postgres;
DELETE FROM family WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

ROLLBACK;
