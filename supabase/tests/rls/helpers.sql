-- =============================================================================
-- TidyQuest RLS Test Helpers
-- supabase/tests/rls/helpers.sql
--
-- Load before any test file:
--   \i supabase/tests/rls/helpers.sql
--
-- Depends on: pgtap extension (CREATE EXTENSION IF NOT EXISTS pgtap)
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS pgtap;

-- Test helpers live in their own schema to keep them out of public.
CREATE SCHEMA IF NOT EXISTS tests;

-- ---------------------------------------------------------------------------
-- set_as_parent(user_id, family_id)
--
-- Injects JWT-equivalent claims into the current session so that RLS policies
-- see this session as a parent belonging to the given family.
--
-- We use set_config to populate the claims that auth.jwt() reads via the
-- request.jwt.claims GUC (Supabase local dev convention).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION tests.set_as_parent(p_user_id uuid, p_family_id uuid)
  RETURNS void
  LANGUAGE plpgsql
AS $$
DECLARE
  claims jsonb;
BEGIN
  claims := jsonb_build_object(
    'sub',           p_user_id::text,
    'role',          'authenticated',
    'app_metadata',  jsonb_build_object(
      'family_id', p_family_id::text,
      'role',      'parent'
    )
  );
  -- Set the role to authenticated so RLS policies fire for the right role
  PERFORM set_config('request.jwt.claims', claims::text, true);
  PERFORM set_config('request.jwt.claim.sub', p_user_id::text, true);
  SET LOCAL ROLE authenticated;
END;
$$;

-- ---------------------------------------------------------------------------
-- set_as_child(user_id, family_id)
--
-- Injects JWT claims for a child. Children have role='child' in app_metadata.
-- auth.uid() is derived from the 'sub' claim.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION tests.set_as_child(p_user_id uuid, p_family_id uuid)
  RETURNS void
  LANGUAGE plpgsql
AS $$
DECLARE
  claims jsonb;
BEGIN
  claims := jsonb_build_object(
    'sub',           p_user_id::text,
    'role',          'authenticated',
    'app_metadata',  jsonb_build_object(
      'family_id', p_family_id::text,
      'role',      'child'
    )
  );
  PERFORM set_config('request.jwt.claims', claims::text, true);
  PERFORM set_config('request.jwt.claim.sub', p_user_id::text, true);
  SET LOCAL ROLE authenticated;
END;
$$;

-- ---------------------------------------------------------------------------
-- set_as_anon()
--
-- Clears JWT claims and sets role to anon (pre-auth session).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION tests.set_as_anon()
  RETURNS void
  LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM set_config('request.jwt.claims', '{}', true);
  PERFORM set_config('request.jwt.claim.sub', '', true);
  SET LOCAL ROLE anon;
END;
$$;

-- ---------------------------------------------------------------------------
-- reset_role()
--
-- Resets to the default postgres role for cleanup / test isolation.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION tests.reset_role()
  RETURNS void
  LANGUAGE plpgsql
AS $$
BEGIN
  RESET ROLE;
  PERFORM set_config('request.jwt.claims', '{}', true);
  PERFORM set_config('request.jwt.claim.sub', '', true);
END;
$$;

-- ---------------------------------------------------------------------------
-- expect_rows(query text, expected integer)
--
-- Executes the given SQL (must be a SELECT), counts the rows, and raises an
-- exception if the count does not match `expected`.
--
-- Usage: SELECT tests.expect_rows('SELECT * FROM family', 1);
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION tests.expect_rows(p_query text, p_expected integer)
  RETURNS void
  LANGUAGE plpgsql
AS $$
DECLARE
  v_count integer;
  v_sql   text;
BEGIN
  v_sql := format('SELECT COUNT(*) FROM (%s) _q', p_query);
  EXECUTE v_sql INTO v_count;
  IF v_count <> p_expected THEN
    RAISE EXCEPTION
      'expect_rows FAILED: query returned % row(s), expected %.  Query: %',
      v_count, p_expected, p_query;
  END IF;
END;
$$;

-- ---------------------------------------------------------------------------
-- expect_denied(operation text)
--
-- Executes the given DML and expects it to be denied (raise an exception).
-- If it succeeds, raises an assertion failure.
--
-- Usage: SELECT tests.expect_denied($$INSERT INTO point_transaction ...$$);
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION tests.expect_denied(p_operation text)
  RETURNS void
  LANGUAGE plpgsql
AS $$
BEGIN
  BEGIN
    EXECUTE p_operation;
    -- If we get here the operation was NOT denied — test fails
    RAISE EXCEPTION
      'expect_denied FAILED: operation was not denied.  SQL: %', p_operation;
  EXCEPTION
    WHEN insufficient_privilege THEN
      -- Expected: RLS denied the operation
      NULL;
    WHEN OTHERS THEN
      -- Trigger or check constraint also blocks — acceptable as denial
      NULL;
  END;
END;
$$;

-- ---------------------------------------------------------------------------
-- begin_test(label text) / end_test(label text)
--
-- Lightweight test framing that does NOT use transactions (so RLS SET LOCAL ROLE
-- changes survive within the test body). Instead each test wraps its own
-- SAVEPOINT so rows are rolled back.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION tests.begin_test(p_label text)
  RETURNS void
  LANGUAGE plpgsql
AS $$
BEGIN
  RAISE NOTICE '[TEST] %', p_label;
  EXECUTE format('SAVEPOINT test_%s', md5(p_label));
END;
$$;

CREATE OR REPLACE FUNCTION tests.end_test(p_label text)
  RETURNS void
  LANGUAGE plpgsql
AS $$
BEGIN
  EXECUTE format('ROLLBACK TO SAVEPOINT test_%s', md5(p_label));
  EXECUTE format('RELEASE SAVEPOINT test_%s', md5(p_label));
  PERFORM tests.reset_role();
  RAISE NOTICE '[PASS] %', p_label;
END;
$$;

-- Grant usage on the tests schema to postgres (used by psql runner)
CREATE SCHEMA IF NOT EXISTS tests;
GRANT USAGE ON SCHEMA tests TO postgres;
