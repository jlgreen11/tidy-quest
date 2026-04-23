-- =============================================================================
-- RLS Tests: audit_log table
-- supabase/tests/rls/test_audit_log.sql
--
-- audit_log is append-only (like point_transaction).
-- Only service_role (via edge functions) can INSERT.
-- Only parents can SELECT (for transparency/dispute resolution).
-- No authenticated role can INSERT, UPDATE, or DELETE directly.
--
-- Assumed columns (A1 owns DDL):
--   id, family_id, actor_user_id, action, target,
--   payload jsonb, created_at
-- =============================================================================

\i supabase/tests/rls/helpers.sql

BEGIN;

-- Setup: seed some audit log entries as postgres
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

-- Family A audit entries (inserted by service_role during edge fn execution)
-- Note: `target` is a single text column per schema (e.g. 'point_transaction:<uuid>').
INSERT INTO audit_log (id, family_id, actor_user_id, action, target, payload, created_at)
VALUES
  ('e1e1e1e1-e1e1-e1e1-e1e1-e1e1e1e1e101',
   '11111111-1111-1111-1111-111111111111',
   '22222222-2222-2222-2222-222222222221',
   'point_transaction.large',
   'point_transaction:77777777-7777-7777-7777-777777777701',
   '{"amount": -5, "reason": "Rude to sibling"}',
   now() - interval '2 days'),

  ('e1e1e1e1-e1e1-e1e1-e1e1-e1e1e1e1e102',
   '11111111-1111-1111-1111-111111111111',
   '22222222-2222-2222-2222-222222222221',
   'redemption.approve',
   format('redemption_request:%s', gen_random_uuid()),
   '{"reward": "30 min tablet time"}',
   now() - interval '1 day'),

  -- Family B audit entry
  ('e1e1e1e1-e1e1-e1e1-e1e1-e1e1e1e1e103',
   'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
   'b2b2b2b2-b2b2-b2b2-b2b2-b2b2b2b2b221',
   'point_transaction.large',
   format('point_transaction:%s', gen_random_uuid()),
   '{"amount": -10}',
   now())
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- Test 1: Parent can SELECT audit_log entries in own family
-- ============================================================================
SELECT tests.begin_test('audit_log: parent can SELECT own family audit entries');
SELECT tests.set_as_parent(
  '22222222-2222-2222-2222-222222222221'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
SELECT tests.expect_rows(
  'SELECT * FROM audit_log WHERE family_id = ''11111111-1111-1111-1111-111111111111''',
  2
);
SELECT tests.end_test('audit_log: parent can SELECT own family audit entries');

-- ============================================================================
-- Test 2: Parent A CANNOT SELECT family B audit entries
-- ============================================================================
SELECT tests.begin_test('audit_log: parent A cannot SELECT family B audit entries');
SELECT tests.set_as_parent(
  '22222222-2222-2222-2222-222222222221'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
SELECT tests.expect_rows(
  'SELECT * FROM audit_log WHERE family_id = ''bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb''',
  0
);
SELECT tests.end_test('audit_log: parent A cannot SELECT family B audit entries');

-- ============================================================================
-- Test 3: Child CANNOT SELECT audit_log (even own family)
-- ============================================================================
SELECT tests.begin_test('audit_log: child cannot SELECT any audit_log row');
SELECT tests.set_as_child(
  '33333333-3333-3333-3333-333333333331'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
SELECT tests.expect_rows('SELECT * FROM audit_log', 0);
SELECT tests.end_test('audit_log: child cannot SELECT any audit_log row');

-- ============================================================================
-- Test 4: anon CANNOT SELECT any audit_log
-- ============================================================================
SELECT tests.begin_test('audit_log: anon cannot SELECT any audit_log');
SELECT tests.set_as_anon();
SELECT tests.expect_rows('SELECT * FROM audit_log', 0);
SELECT tests.end_test('audit_log: anon cannot SELECT any audit_log');

-- ============================================================================
-- Test 5: Parent CANNOT INSERT into audit_log directly (service_role only)
-- ============================================================================
SELECT tests.begin_test('audit_log: parent cannot INSERT directly');
SELECT tests.set_as_parent(
  '22222222-2222-2222-2222-222222222221'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
SELECT tests.expect_denied($$
  INSERT INTO audit_log (id, family_id, actor_user_id, action, target, payload)
  VALUES (gen_random_uuid(),
          '11111111-1111-1111-1111-111111111111',
          '22222222-2222-2222-2222-222222222221',
          'self_granted_points', 'point_transaction',
          gen_random_uuid(), '{"amount": 9999}')
$$);
SELECT tests.end_test('audit_log: parent cannot INSERT directly');

-- ============================================================================
-- Test 6: Child CANNOT INSERT into audit_log
-- ============================================================================
SELECT tests.begin_test('audit_log: child cannot INSERT audit_log');
SELECT tests.set_as_child(
  '33333333-3333-3333-3333-333333333331'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
SELECT tests.expect_denied($$
  INSERT INTO audit_log (id, family_id, actor_user_id, action, target, payload)
  VALUES (gen_random_uuid(),
          '11111111-1111-1111-1111-111111111111',
          '33333333-3333-3333-3333-333333333331',
          'fake_entry', 'point_transaction',
          gen_random_uuid(), '{}')
$$);
SELECT tests.end_test('audit_log: child cannot INSERT audit_log');

-- ============================================================================
-- Test 7: Parent CANNOT UPDATE audit_log (append-only)
-- ============================================================================
SELECT tests.begin_test('audit_log: parent cannot UPDATE audit_log');
SELECT tests.set_as_parent(
  '22222222-2222-2222-2222-222222222221'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
-- No UPDATE policy → silent denial (0 rows updated). Use a valid enum
-- value for 'action' — the point of the test is that RLS prevents the
-- update from sticking, not to test enum validation.
UPDATE audit_log SET action = 'family.delete'
WHERE id = 'e1e1e1e1-e1e1-e1e1-e1e1-e1e1e1e1e101';
SET ROLE postgres;
SELECT tests.expect_rows(
  'SELECT * FROM audit_log WHERE id = ''e1e1e1e1-e1e1-e1e1-e1e1-e1e1e1e1e101'' AND action = ''family.delete''',
  0
);
SELECT tests.end_test('audit_log: parent cannot UPDATE audit_log');

-- ============================================================================
-- Test 8: Parent CANNOT DELETE audit_log entries
-- ============================================================================
SELECT tests.begin_test('audit_log: parent cannot DELETE audit_log');
SELECT tests.set_as_parent(
  '22222222-2222-2222-2222-222222222221'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
);
DELETE FROM audit_log WHERE id = 'e1e1e1e1-e1e1-e1e1-e1e1-e1e1e1e1e101';
SET ROLE postgres;
SELECT tests.expect_rows(
  'SELECT * FROM audit_log WHERE id = ''e1e1e1e1-e1e1-e1e1-e1e1-e1e1e1e1e101''',
  1
);
SELECT tests.end_test('audit_log: parent cannot DELETE audit_log');

-- ============================================================================
-- Test 9: service_role (postgres) CAN INSERT into audit_log
-- ============================================================================
SELECT tests.begin_test('audit_log: service_role can INSERT audit_log');
SET ROLE postgres;
-- audit_log has 6 writable columns in this INSERT (id, family_id,
-- actor_user_id, action, target, payload). Compose target as a single text
-- value and use a real enum member for `action`.
INSERT INTO audit_log (id, family_id, actor_user_id, action, target, payload)
VALUES ('e1e1e1e1-e1e1-e1e1-e1e1-e1e1e1e1e199',
        '11111111-1111-1111-1111-111111111111',
        '22222222-2222-2222-2222-222222222221',
        'family.create',
        format('point_transaction:%s', gen_random_uuid()),
        '{}');
SELECT tests.expect_rows(
  'SELECT * FROM audit_log WHERE id = ''e1e1e1e1-e1e1-e1e1-e1e1-e1e1e1e1e199''',
  1
);
SELECT tests.end_test('audit_log: service_role can INSERT audit_log');

-- Cleanup — outer ROLLBACK discards everything inserted in this file,
-- so no explicit DELETE is needed (and DELETE FROM family would fail on
-- FK constraints from audit_log anyway).
ROLLBACK;
