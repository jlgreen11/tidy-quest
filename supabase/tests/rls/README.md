# TidyQuest RLS Test Suite

Row-Level Security tests for every sensitive table. Each test file covers the full role × operation matrix: parent, child, anon, and service_role.

## Prerequisites

```bash
# Install supabase CLI
brew install supabase/tap/supabase

# Start the local stack (Docker must be running)
supabase start

# Apply migrations and seed data
supabase db reset
```

## Running locally

```bash
# From the repo root:
bash supabase/tests/rls/run_all.sh
```

Expected output:

```
TidyQuest RLS Test Suite
========================

Running test_family.sql ...                         PASS
Running test_app_user.sql ...                       PASS
Running test_chore_template.sql ...                 PASS
Running test_chore_instance.sql ...                 PASS
Running test_point_transaction.sql ...              PASS
Running test_reward.sql ...                         PASS
Running test_redemption_request.sql ...             PASS
Running test_audit_log.sql ...                      PASS

Results: 8 passed, 0 failed

All RLS tests passed.
```

## Running a single test file

```bash
supabase db psql -f supabase/tests/rls/test_point_transaction.sql
```

## Running in CI

The GitHub Actions workflow at `.github/workflows/ci.yml` runs:

```yaml
- name: RLS tests
  run: bash supabase/tests/rls/run_all.sh --ci
```

The `--ci` flag suppresses colors and buffers stdout, making log output cleaner for GitHub Actions.

## Test structure

Every test file follows this pattern:

1. `\i supabase/tests/rls/helpers.sql` — load helpers
2. `BEGIN;` — wrap everything in a transaction so seed mutations roll back
3. `SET ROLE postgres;` — insert cross-family fixture data as service_role equivalent
4. Individual test blocks using `begin_test` / `end_test` helpers
5. Each test block:
   - Sets role via `tests.set_as_parent()`, `tests.set_as_child()`, or `tests.set_as_anon()`
   - Asserts expected row counts with `tests.expect_rows()`
   - Asserts denied operations with `tests.expect_denied()`
6. `ROLLBACK;` — clean up

## Helper functions

Defined in `helpers.sql`:

| Function | Purpose |
|---|---|
| `tests.set_as_parent(user_id, family_id)` | Set JWT claims for a parent session |
| `tests.set_as_child(user_id, family_id)` | Set JWT claims for a child session |
| `tests.set_as_anon()` | Clear claims, set role to anon |
| `tests.reset_role()` | Reset to postgres role (called by end_test) |
| `tests.expect_rows(query, n)` | Fail if query returns != n rows |
| `tests.expect_denied(sql)` | Fail if SQL does NOT raise an error |
| `tests.begin_test(label)` | Log test start, create savepoint |
| `tests.end_test(label)` | Rollback to savepoint, log PASS |

## Coverage

| Table | Tests | Key scenarios |
|---|---|---|
| `family` | 10 | Parent CRUD, child read-only, anon denied, cross-family isolation |
| `app_user` | 12 | Child self-only, sentinel globally readable, parent scoped INSERT |
| `chore_template` | 11 | Child sees own templates only, parent CRUD, cross-family isolation |
| `chore_instance` | 10 | Child cannot INSERT/UPDATE directly, parent approve/reject, cross-family |
| `point_transaction` | 12 | Append-only (trigger + RLS), child self-only, sibling isolation, service_role trigger test |
| `reward` | 10 | Child read catalog, child cannot INSERT/UPDATE, parent CRUD |
| `redemption_request` | 10 | Child INSERT own only, child cannot INSERT for sibling, parent approve |
| `audit_log` | 9 | Parent read-only, child no access, append-only, service_role can INSERT |

**Total: 84 test cases**

## Critical security invariants tested

- Child in family A CANNOT SELECT `point_transaction` for a sibling (sibling_ledger_visible=false).
- Child in family A CANNOT SELECT ANYTHING in family B.
- Child CANNOT INSERT `point_transaction` directly — must go through edge function.
- Child CANNOT UPDATE `chore_instance.status` directly.
- Parent in family A CANNOT SELECT family B's rows.
- `anon` CANNOT SELECT any family row.
- Even `service_role` (postgres) CANNOT UPDATE `point_transaction` — trigger blocks it.
- Child can SELECT own `point_transaction`, own `chore_instance`, full `reward` catalog, own `redemption_request`.

## Troubleshooting

**"failed to inspect container health"** — Docker is not running. Start Docker Desktop and re-run `supabase start`.

**"relation does not exist"** — Migrations have not been applied. Run `supabase db reset`.

**Test fails with "expect_rows FAILED"** — The policy may have a bug, or the seed data count has changed. Check `seed.sql` row counts match test expectations (family A has 7 rewards, 10 chore templates, 6 users, 8 today-instances).

**"SAVEPOINT does not exist"** — An earlier test threw an unhandled exception inside a savepoint block. Run the failing test file in isolation with `supabase db psql -f <file>` to see the full error.

## Schema ownership

RLS policies live in `supabase/migrations/20260422000004_rls_policies.sql` (this agent, A2).
Table DDL lives in `supabase/migrations/20260422000001_initial_schema.sql` (agent A1).
Triggers live in `supabase/migrations/20260422000002_triggers.sql` (agent A1).

If A1 uses different column names for `redemption_request`, `audit_log`, or other tables, update both the RLS migration and the corresponding test file accordingly.
