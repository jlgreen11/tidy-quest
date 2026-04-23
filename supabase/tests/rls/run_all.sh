#!/usr/bin/env bash
# =============================================================================
# TidyQuest RLS Test Runner
# supabase/tests/rls/run_all.sh
#
# Runs every RLS test file via `psql` against the local Supabase stack.
# Exits non-zero on any failure.
#
# Usage:
#   bash supabase/tests/rls/run_all.sh          # local (supabase start required)
#   bash supabase/tests/rls/run_all.sh --ci      # CI mode: quieter output
#
# Requirements:
#   - psql in PATH (ships with postgresql-client on ubuntu; brew install libpq on mac)
#   - `supabase start` already running (local dev) — exposes db on 127.0.0.1:54322
#   - Seed data loaded (supabase db reset applies seed.sql automatically)
#
# Override DB URL with DATABASE_URL env var if needed.
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
# Supabase local defaults (supabase/config.toml db.port = 54322 by default;
# user postgres, password postgres, database postgres).
DB_URL="${DATABASE_URL:-postgresql://postgres:postgres@127.0.0.1:54322/postgres}"
CI_MODE=false

for arg in "$@"; do
  case $arg in
    --ci) CI_MODE=true ;;
  esac
done

# Colors (disabled in CI mode or when not a TTY)
if [[ "${CI_MODE}" == "true" ]] || [[ ! -t 1 ]]; then
  RED=""
  GREEN=""
  YELLOW=""
  RESET=""
else
  RED="\033[0;31m"
  GREEN="\033[0;32m"
  YELLOW="\033[0;33m"
  RESET="\033[0m"
fi

# ---------------------------------------------------------------------------
# Verify psql is available
# ---------------------------------------------------------------------------
if ! command -v psql &>/dev/null; then
  echo "${RED}ERROR: psql not found. Install postgresql-client (apt) or libpq (brew).${RESET}"
  exit 1
fi

# ---------------------------------------------------------------------------
# Verify local Supabase db is reachable
# ---------------------------------------------------------------------------
if ! psql "${DB_URL}" -c "SELECT 1" &>/dev/null; then
  echo "${YELLOW}WARNING: cannot connect to ${DB_URL}${RESET}"
  echo "${YELLOW}Ensure 'supabase start' is running, or override DATABASE_URL.${RESET}"
  echo "${YELLOW}Attempting to run tests anyway...${RESET}"
fi

# ---------------------------------------------------------------------------
# Test files — ordered for dependency clarity
# ---------------------------------------------------------------------------
TEST_FILES=(
  "${SCRIPT_DIR}/test_family.sql"
  "${SCRIPT_DIR}/test_app_user.sql"
  "${SCRIPT_DIR}/test_chore_template.sql"
  "${SCRIPT_DIR}/test_chore_instance.sql"
  "${SCRIPT_DIR}/test_point_transaction.sql"
  "${SCRIPT_DIR}/test_reward.sql"
  "${SCRIPT_DIR}/test_redemption_request.sql"
  "${SCRIPT_DIR}/test_audit_log.sql"
)

# ---------------------------------------------------------------------------
# Run tests
# ---------------------------------------------------------------------------
PASS=0
FAIL=0
ERRORS=()

echo ""
echo "TidyQuest RLS Test Suite"
echo "========================"
echo ""

for test_file in "${TEST_FILES[@]}"; do
  test_name="$(basename "${test_file}")"

  if [[ ! -f "${test_file}" ]]; then
    echo "${RED}[MISSING]${RESET} ${test_name}"
    ERRORS+=("${test_name}: file not found")
    ((FAIL++)) || true
    continue
  fi

  printf "Running %-45s " "${test_name}..."

  # Run the test file via psql. ON_ERROR_STOP=1 makes any SQL error fail the run.
  tmp_err="$(mktemp)"
  if [[ "${CI_MODE}" == "true" ]]; then
    tmp_out="$(mktemp)"
    if psql "${DB_URL}" -v ON_ERROR_STOP=1 -f "${test_file}" \
         >"${tmp_out}" 2>"${tmp_err}"; then
      echo "${GREEN}PASS${RESET}"
      ((PASS++)) || true
      rm -f "${tmp_out}" "${tmp_err}"
    else
      echo "${RED}FAIL${RESET}"
      ERRORS+=("${test_name}")
      ((FAIL++)) || true
      echo "--- stdout ---"
      cat "${tmp_out}"
      echo "--- stderr ---"
      cat "${tmp_err}"
      rm -f "${tmp_out}" "${tmp_err}"
    fi
  else
    if psql "${DB_URL}" -v ON_ERROR_STOP=1 -f "${test_file}" \
         2>"${tmp_err}"; then
      echo "${GREEN}PASS${RESET}"
      ((PASS++)) || true
      rm -f "${tmp_err}"
    else
      echo "${RED}FAIL${RESET}"
      ERRORS+=("${test_name}")
      ((FAIL++)) || true
      echo "--- stderr ---"
      cat "${tmp_err}"
      rm -f "${tmp_err}"
    fi
  fi
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "Results: ${GREEN}${PASS} passed${RESET}, ${RED}${FAIL} failed${RESET}"
echo ""

if [[ ${FAIL} -gt 0 ]]; then
  echo "${RED}Failed tests:${RESET}"
  for err in "${ERRORS[@]}"; do
    echo "  - ${err}"
  done
  echo ""
  exit 1
fi

echo "${GREEN}All RLS tests passed.${RESET}"
echo ""
exit 0
