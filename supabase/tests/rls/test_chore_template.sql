-- =============================================================================
-- RLS Tests: chore_template table
-- supabase/tests/rls/test_chore_template.sql
--
-- Seed IDs:
--   Family A:  11111111-1111-1111-1111-111111111111
--   Parent Mei: 22222222-2222-2222-2222-222222222221
--   Child Ava (target of 401,402): 33333333-3333-3333-3333-333333333331
--   Child Zara (target of 405,406,409): 33333333-3333-3333-3333-333333333333
--   Template 401 (Ava make-bed): 44444444-4444-4444-4444-444444444401
-- =============================================================================

\i supabase/tests/rls/helpers.sql

BEGIN;

-- Setup: family B + template B
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

INSERT INTO chore_template (id, family_id, name, icon, description, type, schedule,
                            target_user_ids, base_points, requires_photo, requires_approval,
                            on_miss, on_miss_amount, active)
VALUES ('b4b4b4b4-b4b4-b4b4-b4b4-b4b4b4b4b401',
        'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
        'Wash Dishes B', 'dishwasher', 'Family B chore', 'daily',
        '{"daysOfWeek":[1,2,3,4,5]}',
        ARRAY['b2b2b2b2-b2b2-b2b2-b2b2-b2b2b2b2b221']::uuid[],
        10, false, false, 'decay', 0, true)
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- Test 1: Parent can SELECT all templates in own family
-- ============================================================================
SELECT tests.begin_test('chore_template: parent can SELECT own family templates');
SELECT tests.set_as_parent(
  '22222222-2222-2222-2222-222222222221'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
-- Family A has 10 templates in seed
SELECT tests.expect_rows(
  'SELECT * FROM chore_template WHERE family_id = ''11111111-1111-1111-1111-111111111111''',
  10
);
SELECT tests.end_test('chore_template: parent can SELECT own family templates');

-- ============================================================================
-- Test 2: Parent A CANNOT SELECT family B templates
-- ============================================================================
SELECT tests.begin_test('chore_template: parent A cannot SELECT family B templates');
SELECT tests.set_as_parent(
  '22222222-2222-2222-2222-222222222221'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
SELECT tests.expect_rows(
  'SELECT * FROM chore_template WHERE family_id = ''bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb''',
  0
);
SELECT tests.end_test('chore_template: parent A cannot SELECT family B templates');

-- ============================================================================
-- Test 3: Child can SELECT templates where they are a target
-- ============================================================================
SELECT tests.begin_test('chore_template: child can SELECT own templates');
SELECT tests.set_as_child(
  '33333333-3333-3333-3333-333333333331'::uuid,  -- Ava: targets 401, 402
  '11111111-1111-1111-1111-111111111111'::uuid
);
SELECT tests.expect_rows(
  'SELECT * FROM chore_template WHERE ''33333333-3333-3333-3333-333333333331'' = ANY(target_user_ids)',
  2  -- 401 + 402
);
SELECT tests.end_test('chore_template: child can SELECT own templates');

-- ============================================================================
-- Test 4: Child CANNOT SELECT sibling's templates
-- ============================================================================
SELECT tests.begin_test('chore_template: child cannot SELECT sibling templates');
SELECT tests.set_as_child(
  '33333333-3333-3333-3333-333333333331'::uuid,  -- Ava
  '11111111-1111-1111-1111-111111111111'::uuid
);
-- Kai is target of 403, 404
SELECT tests.expect_rows(
  'SELECT * FROM chore_template WHERE id = ''44444444-4444-4444-4444-444444444403''',
  0
);
SELECT tests.end_test('chore_template: child cannot SELECT sibling templates');

-- ============================================================================
-- Test 5: Child CANNOT SELECT family B templates
-- ============================================================================
SELECT tests.begin_test('chore_template: child A cannot SELECT family B templates');
SELECT tests.set_as_child(
  '33333333-3333-3333-3333-333333333331'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
SELECT tests.expect_rows(
  'SELECT * FROM chore_template WHERE family_id = ''bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb''',
  0
);
SELECT tests.end_test('chore_template: child A cannot SELECT family B templates');

-- ============================================================================
-- Test 6: anon CANNOT SELECT any chore_template
-- ============================================================================
SELECT tests.begin_test('chore_template: anon cannot SELECT any row');
SELECT tests.set_as_anon();
SELECT tests.expect_rows('SELECT * FROM chore_template', 0);
SELECT tests.end_test('chore_template: anon cannot SELECT any row');

-- ============================================================================
-- Test 7: Parent can INSERT new template
-- ============================================================================
SELECT tests.begin_test('chore_template: parent can INSERT template');
SELECT tests.set_as_parent(
  '22222222-2222-2222-2222-222222222221'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
INSERT INTO chore_template (id, family_id, name, icon, description, type, schedule,
                            target_user_ids, base_points, requires_photo, requires_approval,
                            on_miss, on_miss_amount, active)
VALUES ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeee01',
        '11111111-1111-1111-1111-111111111111',
        'New Chore', 'star.fill', 'Test chore', 'daily',
        '{"daysOfWeek":[1,2,3,4,5]}',
        ARRAY['33333333-3333-3333-3333-333333333331']::uuid[],
        20, false, false, 'decay', 0, true);
SELECT tests.expect_rows(
  'SELECT * FROM chore_template WHERE id = ''eeeeeeee-eeee-eeee-eeee-eeeeeeeeee01''',
  1
);
SELECT tests.end_test('chore_template: parent can INSERT template');

-- ============================================================================
-- Test 8: Child CANNOT INSERT a chore_template
-- ============================================================================
SELECT tests.begin_test('chore_template: child cannot INSERT template');
SELECT tests.set_as_child(
  '33333333-3333-3333-3333-333333333331'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
SELECT tests.expect_denied($$
  INSERT INTO chore_template (id, family_id, name, icon, type, schedule,
                              target_user_ids, base_points, requires_photo, requires_approval,
                              on_miss, on_miss_amount, active)
  VALUES ('ffffffff-ffff-ffff-ffff-ffffffffffff',
          '11111111-1111-1111-1111-111111111111',
          'Self-Assigned Chore', 'star', 'daily', '{"daysOfWeek":[1]}',
          ARRAY['33333333-3333-3333-3333-333333333331']::uuid[],
          500, false, false, 'skip', 0, true)
$$);
SELECT tests.end_test('chore_template: child cannot INSERT template');

-- ============================================================================
-- Test 9: Child CANNOT UPDATE a chore_template
-- ============================================================================
SELECT tests.begin_test('chore_template: child cannot UPDATE template');
SELECT tests.set_as_child(
  '33333333-3333-3333-3333-333333333331'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
SELECT tests.expect_denied($$
  UPDATE chore_template SET base_points = 9999
  WHERE id = '44444444-4444-4444-4444-444444444401'
$$);
SELECT tests.end_test('chore_template: child cannot UPDATE template');

-- ============================================================================
-- Test 10: Parent can UPDATE own family template
-- ============================================================================
SELECT tests.begin_test('chore_template: parent can UPDATE own template');
SELECT tests.set_as_parent(
  '22222222-2222-2222-2222-222222222221'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
UPDATE chore_template SET base_points = 10
WHERE id = '44444444-4444-4444-4444-444444444401';
SELECT tests.expect_rows(
  'SELECT * FROM chore_template WHERE id = ''44444444-4444-4444-4444-444444444401'' AND base_points = 10',
  1
);
SELECT tests.end_test('chore_template: parent can UPDATE own template');

-- ============================================================================
-- Test 11: Parent A CANNOT UPDATE family B template
-- ============================================================================
SELECT tests.begin_test('chore_template: parent A cannot UPDATE family B template');
SELECT tests.set_as_parent(
  '22222222-2222-2222-2222-222222222221'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
UPDATE chore_template SET base_points = 999
WHERE id = 'b4b4b4b4-b4b4-b4b4-b4b4-b4b4b4b4b401';
-- Row not visible → 0 rows updated → family B template unchanged
SET ROLE postgres;
SELECT tests.expect_rows(
  'SELECT * FROM chore_template WHERE id = ''b4b4b4b4-b4b4-b4b4-b4b4-b4b4b4b4b401'' AND base_points = 999',
  0
);
SELECT tests.end_test('chore_template: parent A cannot UPDATE family B template');

-- Cleanup
SET ROLE postgres;
DELETE FROM family WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

ROLLBACK;
