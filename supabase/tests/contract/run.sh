#!/usr/bin/env bash
# run.sh — execute the Chen-Rodriguez contract test against deployed cloud staging
# Usage: bash supabase/tests/contract/run.sh
set -euo pipefail
cd "$(dirname "$0")"

# Resolve deno from common install paths
DENO="${DENO_BIN:-}"
if [ -z "$DENO" ]; then
  for candidate in \
    "$(command -v deno 2>/dev/null)" \
    "$HOME/.deno/bin/deno" \
    "/opt/homebrew/bin/deno" \
    "/usr/local/bin/deno"; do
    if [ -x "$candidate" ]; then
      DENO="$candidate"
      break
    fi
  done
fi

if [ -z "$DENO" ]; then
  echo "ERROR: deno not found. Install with: brew install deno"
  exit 1
fi

echo "Using deno: $DENO ($($DENO --version | head -1))"
echo "Target:     https://kppjiikoshywiybylkws.supabase.co"
echo ""

$DENO test \
  --allow-net=kppjiikoshywiybylkws.supabase.co \
  --allow-env \
  --allow-read \
  chen-rodriguez-journey.ts
