-- =============================================================================
-- TidyQuest — Row Level Security Policies
-- Migration: 20260422000004_rls_policies.sql
-- Depends on: 20260422000001_initial_schema.sql, 20260422000002_triggers.sql
--
-- Role model:
--   anon          — pre-auth; no SELECT on any table
--   authenticated — JWT with custom claims: family_id (uuid), role (text)
--   service_role  — edge functions; bypasses RLS by default
--
-- JWT claim helpers:
--   auth.uid()                                       → user's UUID
--   (auth.jwt() -> 'app_metadata' ->> 'family_id')  → family_id string
--   (auth.jwt() -> 'app_metadata' ->> 'role')        → 'parent'|'child'|...
--
-- Convention: claim extraction is wrapped in helper functions defined at the
-- bottom of this file to keep policy bodies readable.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Helper functions (stable, security definer so they can read jwt())
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.tq_family_id()
  RETURNS uuid
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
AS $$
  SELECT (auth.jwt() -> 'app_metadata' ->> 'family_id')::uuid;
$$;

CREATE OR REPLACE FUNCTION public.tq_user_role()
  RETURNS text
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
AS $$
  SELECT auth.jwt() -> 'app_metadata' ->> 'role';
$$;

CREATE OR REPLACE FUNCTION public.tq_is_parent()
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
AS $$
  SELECT tq_user_role() IN ('parent', 'caregiver');
$$;

CREATE OR REPLACE FUNCTION public.tq_is_child()
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
AS $$
  SELECT tq_user_role() = 'child';
$$;

-- Returns true when the authenticated child's family has sibling_ledger_visible=true
CREATE OR REPLACE FUNCTION public.tq_sibling_ledger_visible()
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
AS $$
  SELECT COALESCE(
    (SELECT sibling_ledger_visible FROM family WHERE id = tq_family_id()),
    false
  );
$$;

-- =============================================================================
-- TABLE: family
-- =============================================================================
ALTER TABLE family ENABLE ROW LEVEL SECURITY;

-- Parents/caregivers: full CRUD on their own family row
CREATE POLICY "family_select_parent"
  ON family FOR SELECT
  TO authenticated
  USING (tq_is_parent() AND id = tq_family_id());

CREATE POLICY "family_insert_parent"
  ON family FOR INSERT
  TO authenticated
  WITH CHECK (tq_is_parent() AND id = tq_family_id());

CREATE POLICY "family_update_parent"
  ON family FOR UPDATE
  TO authenticated
  USING (tq_is_parent() AND id = tq_family_id())
  WITH CHECK (tq_is_parent() AND id = tq_family_id());

CREATE POLICY "family_delete_parent"
  ON family FOR DELETE
  TO authenticated
  USING (tq_is_parent() AND id = tq_family_id());

-- Children: SELECT own family row only (need timezone, sibling_ledger_visible, etc.)
-- No INSERT/UPDATE/DELETE for children.
CREATE POLICY "family_select_child"
  ON family FOR SELECT
  TO authenticated
  USING (tq_is_child() AND id = tq_family_id());

-- anon: no access (no policy = deny)

-- =============================================================================
-- TABLE: app_user
-- =============================================================================
ALTER TABLE app_user ENABLE ROW LEVEL SECURITY;

-- System sentinel (id=all-zeros, family_id=NULL): globally readable by authenticated
CREATE POLICY "app_user_select_sentinel"
  ON app_user FOR SELECT
  TO authenticated
  USING (id = '00000000-0000-0000-0000-000000000000'::uuid);

-- Parents: SELECT all family members
CREATE POLICY "app_user_select_parent"
  ON app_user FOR SELECT
  TO authenticated
  USING (tq_is_parent() AND family_id = tq_family_id());

-- Parents: INSERT new family members (add-kid flow; edge fn uses service_role in practice)
CREATE POLICY "app_user_insert_parent"
  ON app_user FOR INSERT
  TO authenticated
  WITH CHECK (tq_is_parent() AND family_id = tq_family_id());

-- Parents: UPDATE family members they own
CREATE POLICY "app_user_update_parent"
  ON app_user FOR UPDATE
  TO authenticated
  USING (tq_is_parent() AND family_id = tq_family_id())
  WITH CHECK (tq_is_parent() AND family_id = tq_family_id());

-- Parents: soft-delete (DELETE) family members
CREATE POLICY "app_user_delete_parent"
  ON app_user FOR DELETE
  TO authenticated
  USING (tq_is_parent() AND family_id = tq_family_id());

-- Children: SELECT own row only
-- Note: sibling_ledger_visible does NOT grant child access to sibling app_user rows;
-- it only governs point_transaction visibility.
CREATE POLICY "app_user_select_child_self"
  ON app_user FOR SELECT
  TO authenticated
  USING (tq_is_child() AND id = auth.uid());

-- Children: no INSERT/UPDATE/DELETE on app_user

-- =============================================================================
-- TABLE: chore_template
-- =============================================================================
ALTER TABLE chore_template ENABLE ROW LEVEL SECURITY;

-- Parents: full CRUD scoped to family
CREATE POLICY "chore_template_select_parent"
  ON chore_template FOR SELECT
  TO authenticated
  USING (tq_is_parent() AND family_id = tq_family_id());

CREATE POLICY "chore_template_insert_parent"
  ON chore_template FOR INSERT
  TO authenticated
  WITH CHECK (tq_is_parent() AND family_id = tq_family_id());

CREATE POLICY "chore_template_update_parent"
  ON chore_template FOR UPDATE
  TO authenticated
  USING (tq_is_parent() AND family_id = tq_family_id())
  WITH CHECK (tq_is_parent() AND family_id = tq_family_id());

CREATE POLICY "chore_template_delete_parent"
  ON chore_template FOR DELETE
  TO authenticated
  USING (tq_is_parent() AND family_id = tq_family_id());

-- Children: SELECT templates where they are a target user (to render their chore list)
CREATE POLICY "chore_template_select_child"
  ON chore_template FOR SELECT
  TO authenticated
  USING (
    tq_is_child()
    AND family_id = tq_family_id()
    AND auth.uid() = ANY(target_user_ids)
  );

-- Children: no INSERT/UPDATE/DELETE on chore_template

-- =============================================================================
-- TABLE: chore_instance
-- =============================================================================
ALTER TABLE chore_instance ENABLE ROW LEVEL SECURITY;

-- Parents: SELECT all instances in family (join to chore_template for family_id check)
CREATE POLICY "chore_instance_select_parent"
  ON chore_instance FOR SELECT
  TO authenticated
  USING (
    tq_is_parent()
    AND EXISTS (
      SELECT 1 FROM chore_template ct
      WHERE ct.id = chore_instance.template_id
        AND ct.family_id = tq_family_id()
    )
  );

-- Parents: INSERT (daily reset edge fn uses service_role; this covers direct parent ops)
CREATE POLICY "chore_instance_insert_parent"
  ON chore_instance FOR INSERT
  TO authenticated
  WITH CHECK (
    tq_is_parent()
    AND EXISTS (
      SELECT 1 FROM chore_template ct
      WHERE ct.id = chore_instance.template_id
        AND ct.family_id = tq_family_id()
    )
  );

-- Parents: UPDATE (approve/reject chore)
CREATE POLICY "chore_instance_update_parent"
  ON chore_instance FOR UPDATE
  TO authenticated
  USING (
    tq_is_parent()
    AND EXISTS (
      SELECT 1 FROM chore_template ct
      WHERE ct.id = chore_instance.template_id
        AND ct.family_id = tq_family_id()
    )
  )
  WITH CHECK (
    tq_is_parent()
    AND EXISTS (
      SELECT 1 FROM chore_template ct
      WHERE ct.id = chore_instance.template_id
        AND ct.family_id = tq_family_id()
    )
  );

-- Parents: DELETE (rare; soft-delete preferred)
CREATE POLICY "chore_instance_delete_parent"
  ON chore_instance FOR DELETE
  TO authenticated
  USING (
    tq_is_parent()
    AND EXISTS (
      SELECT 1 FROM chore_template ct
      WHERE ct.id = chore_instance.template_id
        AND ct.family_id = tq_family_id()
    )
  );

-- Children: SELECT own instances only
-- (chore-instance.complete edge fn uses service_role for the actual write)
CREATE POLICY "chore_instance_select_child_self"
  ON chore_instance FOR SELECT
  TO authenticated
  USING (
    tq_is_child()
    AND user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM chore_template ct
      WHERE ct.id = chore_instance.template_id
        AND ct.family_id = tq_family_id()
    )
  );

-- Children: no INSERT/UPDATE/DELETE directly; all writes via edge functions (service_role)

-- =============================================================================
-- TABLE: point_transaction — the append-only ledger
-- =============================================================================
ALTER TABLE point_transaction ENABLE ROW LEVEL SECURITY;

-- Parents: SELECT all transactions in family
CREATE POLICY "point_transaction_select_parent"
  ON point_transaction FOR SELECT
  TO authenticated
  USING (tq_is_parent() AND family_id = tq_family_id());

-- Parents: INSERT (fine, adjustment, correction via edge fn; policy permits direct for
-- edge cases; actual enforcement happens in edge fn with service_role)
CREATE POLICY "point_transaction_insert_parent"
  ON point_transaction FOR INSERT
  TO authenticated
  WITH CHECK (tq_is_parent() AND family_id = tq_family_id());

-- UPDATE: explicitly denied for all authenticated roles (defense-in-depth;
-- trigger enforce_append_only also blocks this at the trigger layer)
-- No UPDATE policy created → RLS denies all UPDATE attempts from authenticated users.

-- DELETE: explicitly denied for all authenticated roles (defense-in-depth)
-- No DELETE policy created → RLS denies all DELETE attempts from authenticated users.

-- Children: SELECT own transactions only (default: sibling_ledger_visible=false)
CREATE POLICY "point_transaction_select_child_self"
  ON point_transaction FOR SELECT
  TO authenticated
  USING (
    tq_is_child()
    AND family_id = tq_family_id()
    AND user_id = auth.uid()
  );

-- Children: SELECT sibling transactions when sibling_ledger_visible=true
CREATE POLICY "point_transaction_select_child_sibling"
  ON point_transaction FOR SELECT
  TO authenticated
  USING (
    tq_is_child()
    AND family_id = tq_family_id()
    AND tq_sibling_ledger_visible()
  );

-- Children: no INSERT/UPDATE/DELETE directly (edge fn uses service_role)
-- No INSERT/UPDATE/DELETE policies for children → denied by RLS.

-- =============================================================================
-- TABLE: reward
-- =============================================================================
ALTER TABLE reward ENABLE ROW LEVEL SECURITY;

-- Parents: full CRUD scoped to family
CREATE POLICY "reward_select_parent"
  ON reward FOR SELECT
  TO authenticated
  USING (tq_is_parent() AND family_id = tq_family_id());

CREATE POLICY "reward_insert_parent"
  ON reward FOR INSERT
  TO authenticated
  WITH CHECK (tq_is_parent() AND family_id = tq_family_id());

CREATE POLICY "reward_update_parent"
  ON reward FOR UPDATE
  TO authenticated
  USING (tq_is_parent() AND family_id = tq_family_id())
  WITH CHECK (tq_is_parent() AND family_id = tq_family_id());

CREATE POLICY "reward_delete_parent"
  ON reward FOR DELETE
  TO authenticated
  USING (tq_is_parent() AND family_id = tq_family_id());

-- Children: SELECT all rewards in family (they need to see the full catalog)
CREATE POLICY "reward_select_child"
  ON reward FOR SELECT
  TO authenticated
  USING (tq_is_child() AND family_id = tq_family_id());

-- Children: no INSERT/UPDATE/DELETE

-- =============================================================================
-- TABLE: redemption_request
-- =============================================================================
ALTER TABLE redemption_request ENABLE ROW LEVEL SECURITY;

-- Parents: SELECT all redemption_requests in family
CREATE POLICY "redemption_request_select_parent"
  ON redemption_request FOR SELECT
  TO authenticated
  USING (tq_is_parent() AND family_id = tq_family_id());

-- Parents: UPDATE (approve/deny)
CREATE POLICY "redemption_request_update_parent"
  ON redemption_request FOR UPDATE
  TO authenticated
  USING (tq_is_parent() AND family_id = tq_family_id())
  WITH CHECK (tq_is_parent() AND family_id = tq_family_id());

-- Parents: DELETE (rare)
CREATE POLICY "redemption_request_delete_parent"
  ON redemption_request FOR DELETE
  TO authenticated
  USING (tq_is_parent() AND family_id = tq_family_id());

-- Children: SELECT own requests only
CREATE POLICY "redemption_request_select_child_self"
  ON redemption_request FOR SELECT
  TO authenticated
  USING (
    tq_is_child()
    AND family_id = tq_family_id()
    AND user_id = auth.uid()
  );

-- Children: INSERT their own redemption request (this is the one direct write children
-- are allowed; edge fn is preferred but RLS permits it for simplicity)
-- In practice redemption.request edge function uses service_role; this policy is
-- defense-in-depth but scoped safely.
CREATE POLICY "redemption_request_insert_child_self"
  ON redemption_request FOR INSERT
  TO authenticated
  WITH CHECK (
    tq_is_child()
    AND family_id = tq_family_id()
    AND user_id = auth.uid()
  );

-- Children: no UPDATE/DELETE (status changes go through edge fn with service_role)

-- =============================================================================
-- TABLE: audit_log — append-only, like point_transaction
-- =============================================================================
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;

-- Parents: SELECT audit log for their family
CREATE POLICY "audit_log_select_parent"
  ON audit_log FOR SELECT
  TO authenticated
  USING (tq_is_parent() AND family_id = tq_family_id());

-- INSERT: service_role only (edge functions). Authenticated roles cannot insert directly.
-- No INSERT policy for authenticated → denied.

-- UPDATE/DELETE: denied for all (append-only enforced by trigger AND rls).
-- No UPDATE/DELETE policies → denied.

-- Children: no access to audit_log

-- =============================================================================
-- TABLE: subscription
-- =============================================================================
ALTER TABLE subscription ENABLE ROW LEVEL SECURITY;

-- Parents: SELECT their family's subscription
CREATE POLICY "subscription_select_parent"
  ON subscription FOR SELECT
  TO authenticated
  USING (tq_is_parent() AND family_id = tq_family_id());

-- Children: SELECT family subscription (needed for tier-based UI gating)
CREATE POLICY "subscription_select_child"
  ON subscription FOR SELECT
  TO authenticated
  USING (tq_is_child() AND family_id = tq_family_id());

-- INSERT/UPDATE/DELETE: service_role only (subscription.update edge fn)
-- No authenticated INSERT/UPDATE/DELETE policies → denied.

-- =============================================================================
-- TABLE: job_log
-- =============================================================================
ALTER TABLE job_log ENABLE ROW LEVEL SECURITY;

-- Parents: SELECT job logs (useful for debugging daily resets)
CREATE POLICY "job_log_select_parent"
  ON job_log FOR SELECT
  TO authenticated
  USING (tq_is_parent() AND family_id = tq_family_id());

-- All write operations: service_role only (pg_cron jobs)
-- No INSERT/UPDATE/DELETE policies for authenticated → denied.

-- =============================================================================
-- TABLE: notification (if exists; may be added by A1)
-- =============================================================================
-- Guard: only create if table exists. If A1 did not create this table,
-- this block is a no-op.
DO $$
BEGIN
  IF EXISTS (
    SELECT FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'notification'
  ) THEN
    EXECUTE 'ALTER TABLE notification ENABLE ROW LEVEL SECURITY';

    -- Parents: SELECT notifications for family members
    EXECUTE $pol$
      CREATE POLICY "notification_select_parent"
        ON notification FOR SELECT
        TO authenticated
        USING (tq_is_parent() AND family_id = tq_family_id())
    $pol$;

    -- Children: SELECT own notifications
    EXECUTE $pol$
      CREATE POLICY "notification_select_child_self"
        ON notification FOR SELECT
        TO authenticated
        USING (tq_is_child() AND family_id = tq_family_id() AND user_id = auth.uid())
    $pol$;

    -- Children: UPDATE own notifications (mark as read)
    EXECUTE $pol$
      CREATE POLICY "notification_update_child_self"
        ON notification FOR UPDATE
        TO authenticated
        USING (tq_is_child() AND family_id = tq_family_id() AND user_id = auth.uid())
        WITH CHECK (tq_is_child() AND family_id = tq_family_id() AND user_id = auth.uid())
    $pol$;

    -- INSERT/DELETE: service_role only
  END IF;
END $$;

-- =============================================================================
-- TABLE: approval_request (if exists)
-- =============================================================================
DO $$
BEGIN
  IF EXISTS (
    SELECT FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'approval_request'
  ) THEN
    EXECUTE 'ALTER TABLE approval_request ENABLE ROW LEVEL SECURITY';

    -- Parents: SELECT/UPDATE approval requests for family
    EXECUTE $pol$
      CREATE POLICY "approval_request_select_parent"
        ON approval_request FOR SELECT
        TO authenticated
        USING (tq_is_parent() AND family_id = tq_family_id())
    $pol$;

    EXECUTE $pol$
      CREATE POLICY "approval_request_update_parent"
        ON approval_request FOR UPDATE
        TO authenticated
        USING (tq_is_parent() AND family_id = tq_family_id())
        WITH CHECK (tq_is_parent() AND family_id = tq_family_id())
    $pol$;

    -- Children: SELECT own approval requests
    EXECUTE $pol$
      CREATE POLICY "approval_request_select_child_self"
        ON approval_request FOR SELECT
        TO authenticated
        USING (
          tq_is_child()
          AND family_id = tq_family_id()
          AND requester_user_id = auth.uid()
        )
    $pol$;

    -- INSERT: child can open a contest (edge fn preferred; direct also scoped)
    EXECUTE $pol$
      CREATE POLICY "approval_request_insert_child_self"
        ON approval_request FOR INSERT
        TO authenticated
        WITH CHECK (
          tq_is_child()
          AND family_id = tq_family_id()
          AND requester_user_id = auth.uid()
        )
    $pol$;
  END IF;
END $$;

-- =============================================================================
-- TABLE: streak (if exists)
-- =============================================================================
DO $$
BEGIN
  IF EXISTS (
    SELECT FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'streak'
  ) THEN
    EXECUTE 'ALTER TABLE streak ENABLE ROW LEVEL SECURITY';

    EXECUTE $pol$
      CREATE POLICY "streak_select_parent"
        ON streak FOR SELECT
        TO authenticated
        USING (tq_is_parent() AND family_id = tq_family_id())
    $pol$;

    -- Children: SELECT own streaks; siblings if sibling_ledger_visible
    EXECUTE $pol$
      CREATE POLICY "streak_select_child_self"
        ON streak FOR SELECT
        TO authenticated
        USING (
          tq_is_child()
          AND family_id = tq_family_id()
          AND (user_id = auth.uid() OR tq_sibling_ledger_visible())
        )
    $pol$;
  END IF;
END $$;

-- =============================================================================
-- TABLE: challenge (if exists)
-- =============================================================================
DO $$
BEGIN
  IF EXISTS (
    SELECT FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'challenge'
  ) THEN
    EXECUTE 'ALTER TABLE challenge ENABLE ROW LEVEL SECURITY';

    EXECUTE $pol$
      CREATE POLICY "challenge_select_parent"
        ON challenge FOR SELECT
        TO authenticated
        USING (tq_is_parent() AND family_id = tq_family_id())
    $pol$;

    EXECUTE $pol$
      CREATE POLICY "challenge_insert_parent"
        ON challenge FOR INSERT
        TO authenticated
        WITH CHECK (tq_is_parent() AND family_id = tq_family_id())
    $pol$;

    EXECUTE $pol$
      CREATE POLICY "challenge_update_parent"
        ON challenge FOR UPDATE
        TO authenticated
        USING (tq_is_parent() AND family_id = tq_family_id())
        WITH CHECK (tq_is_parent() AND family_id = tq_family_id())
    $pol$;

    EXECUTE $pol$
      CREATE POLICY "challenge_select_child"
        ON challenge FOR SELECT
        TO authenticated
        USING (tq_is_child() AND family_id = tq_family_id())
    $pol$;
  END IF;
END $$;

-- =============================================================================
-- Grant EXECUTE on helper functions to authenticated role
-- =============================================================================
GRANT EXECUTE ON FUNCTION public.tq_family_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.tq_user_role() TO authenticated;
GRANT EXECUTE ON FUNCTION public.tq_is_parent() TO authenticated;
GRANT EXECUTE ON FUNCTION public.tq_is_child() TO authenticated;
GRANT EXECUTE ON FUNCTION public.tq_sibling_ledger_visible() TO authenticated;
