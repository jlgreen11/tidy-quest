# CI Reference

## Overview

TidyQuest CI runs on GitHub Actions. There are two workflow files:

| File | Trigger | Purpose |
|------|---------|---------|
| `.github/workflows/ci.yml` | push/PR to `main` or `sprint-*` | Build, unit test, schema lint |
| `.github/workflows/deploy-staging.yml` | push to `main` only | Deploy migrations + edge functions to staging |

---

## Jobs in `ci.yml`

### `swift-core` — Swift build & test

- **Runner**: `macos-15` (Xcode 16.x, Swift 6)
- **What runs**: `swift build -c release` then `swift test` on `ios/TidyQuestCore/Package.swift`
- **What is excluded**: The `ios/TidyQuestCore/Sources/TidyQuestCore/Models/` directory (SwiftData macros require Xcode's macro plugin binary; excluded in `Package.swift` via `exclude: ["Models"]`)
- **Why not `macos-14`**: macOS-14 runners ship Swift 5.10 toolchain. `Package.swift` requires `swift-tools-version: 6.0` so the build fails with an incompatibility error.
- **PR vs main**: runs on both

### `migration-lint` — Supabase schema lint

- **Runner**: `ubuntu-latest`
- **Condition**: skipped when `SUPABASE_ACCESS_TOKEN` secret is not set (e.g., forks, sprint branches without secrets)
- **What runs**: `supabase db lint` against the staging project
- **PR vs main**: runs on both (when secrets are present)

### `deno-functions` — Deno edge function schema tests

- **Runner**: `ubuntu-latest`
- **What runs**: `deno test --allow-env --filter "schema:" .` in `supabase/functions/`
- **What is excluded**: Integration tests that make HTTP requests to `localhost:54321` (a running Supabase stack). These are the tests named with prefixes like `family.create — happy path`. They require a full local Supabase stack (Docker) and are intentionally excluded from CI.
- **PR vs main**: runs on both

---

## Jobs in `deploy-staging.yml`

### `deploy-staging`

- **Condition**: only runs when `SUPABASE_ACCESS_TOKEN` secret is present; skips silently otherwise
- **Trigger**: push to `main` only (not PRs)
- **What runs**:
  1. `supabase db push` — applies pending migrations to staging
  2. `supabase functions deploy` — deploys all edge functions
  3. `supabase secrets set` — syncs APNS and service-role secrets

---

## Required Secrets

Configure these in **GitHub repo Settings > Secrets and variables > Actions**:

| Secret | Required by | Description |
|--------|------------|-------------|
| `SUPABASE_ACCESS_TOKEN` | `migration-lint`, `deploy-staging` | Personal access token from supabase.com/dashboard |
| `SUPABASE_PROJECT_ID_STAGING` | `migration-lint`, `deploy-staging` | Project ref for `tidy-quest-staging` |
| `SUPABASE_SERVICE_ROLE_KEY_STAGING` | `deploy-staging` | service_role key — server-only, never embed in iOS |
| `APNS_KEY_ID` | `deploy-staging` | Apple Push Notification key ID |
| `APNS_TEAM_ID` | `deploy-staging` | Apple Developer team ID |

Without these secrets, `migration-lint` and `deploy-staging` skip gracefully. `swift-core` and `deno-functions` always run and require no secrets.

---

## Reproducing CI Failures Locally

### Swift build/test failure

```bash
cd ios/TidyQuestCore
swift build -c release
swift test
```

Requires Swift 6 toolchain. Install via Xcode 16+ or `swiftly`.

### Deno schema test failure

```bash
cd supabase/functions
deno test --allow-env --filter "schema:" .
```

No Supabase stack needed. These tests validate Zod schemas only.

### Deno integration test failure (not run in CI)

To run the full integration test suite locally:

```bash
# Start the local Supabase stack
supabase start

# Run all Deno tests (including integration)
cd supabase/functions
deno test --allow-env --allow-net .

# Stop when done
supabase stop
```

### Migration lint failure

```bash
export SUPABASE_ACCESS_TOKEN=<your-pat>
supabase db lint --project-id <staging-project-ref>
```

### RLS test suite (local only — not in CI)

```bash
supabase start
bash supabase/tests/rls/run_all.sh --ci
supabase stop
```

The RLS tests use `supabase db psql` and require a fully running local stack. They are not part of the CI pipeline.
