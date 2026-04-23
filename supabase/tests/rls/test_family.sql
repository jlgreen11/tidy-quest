-- =============================================================================
-- RLS Tests: family table
-- supabase/tests/rls/test_family.sql
--
-- Seed IDs (Chen-Rodriguez family):
--   Family A:  11111111-1111-1111-1111-111111111111
--   Parent Mei: 22222222-2222-2222-2222-222222222221
--   Child Zara: 33333333-3333-3333-3333-333333333333
--
-- Family B (injected locally for cross-family tests):
--   Family B:  bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb
--   Parent B:  b2b2b2b2-b2b2-b2b2-b2b2-b2b2b2b2b221
-- =============================================================================

\i supabase/tests/rls/helpers.sql

BEGIN;

-- ---------------------------------------------------------------------------
-- Setup: insert a second family for cross-family isolation tests
-- (done as postgres / service_role before tests run)
-- ---------------------------------------------------------------------------
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

-- ============================================================================
-- Test 1: Parent can SELECT own family row
-- ============================================================================
SELECT tests.begin_test('family: parent can SELECT own family row');
SELECT tests.set_as_parent(
  '22222222-2222-2222-2222-222222222221'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
SELECT tests.expect_rows(
  'SELECT * FROM family WHERE id = ''11111111-1111-1111-1111-111111111111''',
  1
);
SELECT tests.end_test('family: parent can SELECT own family row');

-- ============================================================================
-- Test 2: Parent in family A CANNOT SELECT family B row
-- ============================================================================
SELECT tests.begin_test('family: parent A cannot SELECT family B');
SELECT tests.set_as_parent(
  '22222222-2222-2222-2222-222222222221'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
SELECT tests.expect_rows(
  'SELECT * FROM family WHERE id = ''bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb''',
  0
);
SELECT tests.end_test('family: parent A cannot SELECT family B');

-- ============================================================================
-- Test 3: anon CANNOT SELECT any family row
-- ============================================================================
SELECT tests.begin_test('family: anon cannot SELECT any row');
SELECT tests.set_as_anon();
SELECT tests.expect_rows('SELECT * FROM family', 0);
SELECT tests.end_test('family: anon cannot SELECT any row');

-- ============================================================================
-- Test 4: Child can SELECT own family row
-- ============================================================================
SELECT tests.begin_test('family: child can SELECT own family row');
SELECT tests.set_as_child(
  '33333333-3333-3333-3333-333333333333'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
SELECT tests.expect_rows(
  'SELECT * FROM family WHERE id = ''11111111-1111-1111-1111-111111111111''',
  1
);
SELECT tests.end_test('family: child can SELECT own family row');

-- ============================================================================
-- Test 5: Child CANNOT SELECT family B row
-- ============================================================================
SELECT tests.begin_test('family: child A cannot SELECT family B');
SELECT tests.set_as_child(
  '33333333-3333-3333-3333-333333333333'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
SELECT tests.expect_rows(
  'SELECT * FROM family WHERE id = ''bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb''',
  0
);
SELECT tests.end_test('family: child A cannot SELECT family B');

-- ============================================================================
-- Test 6: Parent can UPDATE own family row
-- ============================================================================
SELECT tests.begin_test('family: parent can UPDATE own family');
SELECT tests.set_as_parent(
  '22222222-2222-2222-2222-222222222221'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
UPDATE family SET leaderboard_enabled = true
WHERE id = '11111111-1111-1111-1111-111111111111';
-- Verify update was applied (in this savepoint)
SELECT tests.expect_rows(
  'SELECT * FROM family WHERE id = ''11111111-1111-1111-1111-111111111111'' AND leaderboard_enabled = true',
  1
);
SELECT tests.end_test('family: parent can UPDATE own family');

-- ============================================================================
-- Test 7: Parent A CANNOT UPDATE family B
-- ============================================================================
SELECT tests.begin_test('family: parent A cannot UPDATE family B');
SELECT tests.set_as_parent(
  '22222222-2222-2222-2222-222222222221'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
-- UPDATE on a row not visible via RLS is a silent no-op (0 rows updated), not an error
UPDATE family SET leaderboard_enabled = true
WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
SELECT tests.expect_rows(
  'SELECT * FROM family WHERE id = ''bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'' AND leaderboard_enabled = true',
  0
);
SELECT tests.end_test('family: parent A cannot UPDATE family B');

-- ============================================================================
-- Test 8: Child CANNOT UPDATE own family row
-- ============================================================================
SELECT tests.begin_test('family: child cannot UPDATE family row');
SELECT tests.set_as_child(
  '33333333-3333-3333-3333-333333333333'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
SELECT tests.expect_denied($$
  UPDATE family SET leaderboard_enabled = true
  WHERE id = '11111111-1111-1111-1111-111111111111'
$$);
SELECT tests.end_test('family: child cannot UPDATE family row');

-- ============================================================================
-- Test 9: Child CANNOT INSERT a new family
-- ============================================================================
SELECT tests.begin_test('family: child cannot INSERT family row');
SELECT tests.set_as_child(
  '33333333-3333-3333-3333-333333333333'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
SELECT tests.expect_denied($$
  INSERT INTO family (id, name, timezone, daily_reset_time, quiet_hours_start,
                      quiet_hours_end, leaderboard_enabled, sibling_ledger_visible,
                      subscription_tier, daily_deduction_cap, weekly_deduction_cap, settings)
  VALUES ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'Evil Family', 'UTC',
          '04:00', '21:00', '07:00', false, false, 'trial', 50, 150, '{}')
$$);
SELECT tests.end_test('family: child cannot INSERT family row');

-- ============================================================================
-- Test 10: Parent can soft-delete own family (UPDATE deleted_at)
--   Note: hard DELETE from `family` is blocked by FK constraints whenever
--   child rows exist (point_transaction.family_id has no ON DELETE CASCADE
--   because the ledger is append-only). Product intent is soft-delete via
--   the `deleted_at` column; that path is what RLS needs to allow.
-- ============================================================================
SELECT tests.begin_test('family: parent can soft-delete own family');
SELECT tests.set_as_parent(
  '22222222-2222-2222-2222-222222222221'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
UPDATE family
  SET deleted_at = now()
  WHERE id = '11111111-1111-1111-1111-111111111111';
SET ROLE postgres;
SELECT tests.expect_rows(
  'SELECT * FROM family WHERE id = ''11111111-1111-1111-1111-111111111111'' AND deleted_at IS NOT NULL',
  1
);
SELECT tests.end_test('family: parent can soft-delete own family');

-- Cleanup (families inserted at top are discarded by the outer ROLLBACK).
ROLLBACK;
