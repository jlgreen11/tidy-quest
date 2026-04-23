# TidyQuest — Architectural Contracts (frozen at sprint-v0.1-alpha start)

This file is the **single source of truth** every implementation agent in the sprint consumes. If anything here conflicts with PLAN_v0.1.md, this file wins — PLAN_v0.1.md is the planning doc; ARCHITECTURE.md is the implementation contract.

**Nothing in this file changes after Act 1 gate passes without conductor approval.**

---

## Project structure

```
tidy-quest/
├── supabase/
│   ├── migrations/          # Versioned SQL; filename = <timestamp>_<slug>.sql
│   ├── functions/           # Deno edge functions; one dir per function
│   ├── tests/
│   │   └── rls/             # Parameterized SQL tests
│   ├── seed.sql             # Chen-Rodriguez family seed
│   └── config.toml
├── ios/
│   ├── TidyQuest.xcworkspace
│   ├── ParentApp/           # Xcode target
│   ├── KidApp/              # Xcode target
│   ├── WidgetBundle/        # Xcode target (v0.2; stub only tonight)
│   └── TidyQuestCore/       # Swift package (SwiftPM)
│       ├── Package.swift
│       └── Sources/TidyQuestCore/
├── .github/workflows/
│   ├── ci.yml
│   └── deploy-staging.yml
├── PLAN_v0.1.md
├── ARCHITECTURE.md          # this file
├── README.md
└── REVIEW.md, DECISIONS.md, TEST_PLAN.md
```

## Naming conventions

- **Bundle ID base:** `com.jlgreen11.tidyquest`
  - Parent app: `com.jlgreen11.tidyquest.parent`
  - Kid app: `com.jlgreen11.tidyquest.kid`
  - Widgets: `com.jlgreen11.tidyquest.widgets`
- **Supabase project name:** `tidy-quest-staging` and `tidy-quest-prod`
- **Edge function names:** dot-separated, e.g., `chore-instance.complete`, `redemption.approve`
- **Postgres tables:** `snake_case`, singular (`user`, not `users`)
- **Postgres enums:** `snake_case`, suffix `_kind` or `_status`
- **Swift types:** `UpperCamelCase`, match Postgres table names (`ChoreInstance`, not `ChoreInstances`)
- **Swift files:** one public type per file, filename matches type
- **iOS scheme names:** `ParentApp-Staging`, `ParentApp-Prod`, same for Kid

---

## Data model — authoritative

All tables live in schema `public`. All IDs are `uuid` (generated client-side as UUIDv7 via Swift `Foundation.UUID` extension in `TidyQuestCore`; Postgres `gen_random_uuid()` is UUIDv4 — use it only if client doesn't supply an ID).

### `family`
```sql
CREATE TABLE family (
  id                      uuid PRIMARY KEY,
  name                    text NOT NULL CHECK (length(name) BETWEEN 1 AND 100),
  timezone                text NOT NULL,  -- IANA, e.g., 'America/Los_Angeles'
  daily_reset_time        time NOT NULL DEFAULT '04:00',
  quiet_hours_start       time NOT NULL DEFAULT '21:00',
  quiet_hours_end         time NOT NULL DEFAULT '07:00',
  leaderboard_enabled     boolean NOT NULL DEFAULT false,
  sibling_ledger_visible  boolean NOT NULL DEFAULT false,
  subscription_tier       text NOT NULL DEFAULT 'trial' CHECK (subscription_tier IN ('trial','monthly','yearly','expired','grace')),
  subscription_expires_at timestamptz,
  weekly_band_target      int4range,      -- e.g., '[300, 500]'
  daily_deduction_cap     integer NOT NULL DEFAULT 50,
  weekly_deduction_cap    integer NOT NULL DEFAULT 150,
  settings                jsonb NOT NULL DEFAULT '{}',
  created_at              timestamptz NOT NULL DEFAULT now(),
  deleted_at              timestamptz
);
```

### `app_user`
Named `app_user` (not `user` — collides with Postgres reserved keyword).
```sql
CREATE TABLE app_user (
  id                           uuid PRIMARY KEY,
  family_id                    uuid NOT NULL REFERENCES family(id) ON DELETE CASCADE,
  role                         text NOT NULL CHECK (role IN ('parent','child','caregiver','observer','system')),
  display_name                 text NOT NULL,
  avatar                       text NOT NULL,     -- asset identifier
  color                        text NOT NULL,     -- hex, palette-safe (see tokens)
  complexity_tier              text NOT NULL DEFAULT 'standard' CHECK (complexity_tier IN ('starter','standard','advanced')),
  birthdate                    date,
  apple_sub                    text UNIQUE,       -- parents only
  device_pairing_code          text,              -- kids; rotated; cleared after claim
  device_pairing_expires_at    timestamptz,
  cached_balance               integer NOT NULL DEFAULT 0,
  cached_balance_as_of_txn_id  uuid,
  created_at                   timestamptz NOT NULL DEFAULT now(),
  deleted_at                   timestamptz
);

-- System sentinel (inserted by migration):
-- id = '00000000-0000-0000-0000-000000000000', role = 'system', family_id = NULL
-- RLS policy: system sentinel is globally readable but never modifiable
```

### `chore_template`
```sql
CREATE TYPE chore_type_kind AS ENUM ('one_off','daily','weekly','monthly','seasonal','routine_bound');
CREATE TYPE on_miss_policy AS ENUM ('skip','decay','deduct');

CREATE TABLE chore_template (
  id                   uuid PRIMARY KEY,
  family_id            uuid NOT NULL REFERENCES family(id) ON DELETE CASCADE,
  name                 text NOT NULL,
  icon                 text NOT NULL,
  description          text,
  type                 chore_type_kind NOT NULL,
  schedule             jsonb NOT NULL,  -- { daysOfWeek: [0..6], dayOfMonth: n, ... }
  target_user_ids      uuid[] NOT NULL,
  base_points          integer NOT NULL CHECK (base_points >= 0 AND base_points <= 500),
  cutoff_time          time,
  requires_photo       boolean NOT NULL DEFAULT false,
  requires_approval    boolean NOT NULL DEFAULT false,
  on_miss              on_miss_policy NOT NULL DEFAULT 'decay',
  on_miss_amount       integer NOT NULL DEFAULT 0,
  active               boolean NOT NULL DEFAULT true,
  created_at           timestamptz NOT NULL DEFAULT now(),
  archived_at          timestamptz
);
```

### `chore_instance`
```sql
CREATE TYPE chore_instance_status AS ENUM ('pending','completed','missed','approved','rejected');

CREATE TABLE chore_instance (
  id               uuid PRIMARY KEY,
  template_id      uuid NOT NULL REFERENCES chore_template(id),
  user_id          uuid NOT NULL REFERENCES app_user(id),
  scheduled_for    date NOT NULL,       -- family-local calendar date
  window_start     time,
  window_end       time,
  status           chore_instance_status NOT NULL DEFAULT 'pending',
  completed_at     timestamptz,
  approved_at      timestamptz,
  proof_photo_id   uuid,
  awarded_points   integer,
  completed_by_device  text,            -- for iPad multi-kid attribution
  completed_as_user    uuid,            -- who the device claimed to be
  created_at       timestamptz NOT NULL DEFAULT now(),
  UNIQUE (template_id, user_id, scheduled_for)  -- idempotency of daily reset
);

-- Same-family check:
CREATE TRIGGER chore_instance_same_family
BEFORE INSERT OR UPDATE ON chore_instance
FOR EACH ROW EXECUTE FUNCTION check_chore_instance_same_family();
```

### `point_transaction` — the ledger
```sql
CREATE TYPE point_txn_kind AS ENUM (
  'chore_completion','chore_bonus','streak_bonus','combo_bonus',
  'surprise_multiplier','quest_completion','redemption','fine',
  'adjustment','correction','system_grant'
);

CREATE TABLE point_transaction (
  id                        uuid PRIMARY KEY,
  user_id                   uuid NOT NULL REFERENCES app_user(id),
  family_id                 uuid NOT NULL REFERENCES family(id),
  amount                    integer NOT NULL CHECK (amount BETWEEN -1000 AND 1000),
  kind                      point_txn_kind NOT NULL,
  reference_id              uuid,
  reason                    text,
  created_by_user_id        uuid NOT NULL REFERENCES app_user(id),
  idempotency_key           uuid NOT NULL UNIQUE,
  chore_instance_id         uuid REFERENCES chore_instance(id),
  created_at                timestamptz NOT NULL DEFAULT now(),
  reversed_by_transaction_id uuid REFERENCES point_transaction(id),
  CHECK (amount >= 0 OR (reason IS NOT NULL AND length(reason) > 0))
);

-- Critical: prevent double-credit
CREATE UNIQUE INDEX pt_no_double_completion
  ON point_transaction (chore_instance_id)
  WHERE kind = 'chore_completion';

-- Lookup index for balance computation
CREATE INDEX pt_user_id_idx ON point_transaction (user_id, created_at);

-- UPDATE/DELETE blocked except via privileged reversal function
CREATE TRIGGER pt_append_only
BEFORE UPDATE OR DELETE ON point_transaction
FOR EACH ROW EXECUTE FUNCTION enforce_append_only();

-- Cached balance maintained via trigger
CREATE TRIGGER pt_update_cached_balance
AFTER INSERT ON point_transaction
FOR EACH ROW EXECUTE FUNCTION update_cached_balance();
```

### `reward`, `redemption_request`, `routine`, `streak`, `challenge`, `approval_request`, `notification`, `audit_log`, `subscription`, `job_log`

Full DDL in `supabase/migrations/0001_initial_schema.sql` (Act 1 agent A1 writes this).

Key constraints:

- **Every table with `family_id`** has RLS policies: `family_id = request.jwt.claim.family_id` (parent/caregiver) or `user_id = auth.uid() AND family_id = ...` (child).
- **Every FK pair within a family** has a same-family trigger check.
- **`audit_log`** append-only via trigger (like `point_transaction`).
- **`subscription`** one row per family, updated via `subscription.update` edge function only.
- **`job_log`** row per pg_cron invocation; no retention limit.

---

## RLS policy patterns

Three roles matter: `anon` (pre-auth), `authenticated` (JWT with `role` claim), and `service_role` (edge functions only).

Every table has:
- **SELECT:** `family_id = request.jwt.family_id` for parents/caregivers; child sees own rows only (plus family-wide rows opted-in via `family.sibling_ledger_visible`).
- **INSERT:** denied for children on all tables except `chore_instance.status` transitions (and even that goes through an edge function — direct INSERT is denied).
- **UPDATE/DELETE:** parents only, scoped by `family_id`. Further restricted per-table (e.g., can't update `point_transaction` at all).

Edge functions use `service_role` to bypass RLS for atomic multi-step operations, then insert into `audit_log` for every sensitive action.

---

## Edge function API contracts

All edge functions live at `/supabase/functions/<name>/index.ts`. Every function:

1. Accepts JSON body matching its **Zod schema** (file: `<name>/schema.ts`).
2. Returns JSON matching its **response schema**.
3. Accepts `Idempotency-Key: <uuid>` header; replays return cached result.
4. Validates `Authorization: Bearer <jwt>` (parent) or `X-Device-Token: <token>` (kid).
5. Returns structured errors: `{ error: { code: string, message: string, details?: object } }`.
6. Rate-limits per-user via `point_transaction` count or a new `rate_limit` table (TBD per function).
7. Sensitive operations require `X-App-Attest: <assertion>` header (tonight: mock-validate).

### Catalog (authoritative list — agents MUST implement exactly these)

| Function | Method | Auth | Sensitive | Rate limit |
|---|---|---|---|---|
| `family.create` | POST | Bearer (Apple JWT) | No | 1/60s |
| `family.delete` | POST | Bearer | **Yes** | 1/86400s |
| `family.update` | POST | Bearer | No | 10/60s |
| `user.add-kid` | POST | Bearer | No | 5/60s |
| `user.pair-device` | POST | Bearer | No | 3/60s |
| `user.claim-pair` | POST | anon (pairing code validates) | No | 3/60s |
| `user.revoke-device` | POST | Bearer | Yes | 5/60s |
| `chore-template.create` | POST | Bearer | No | 30/60s |
| `chore-template.update` | POST | Bearer | No | 60/60s |
| `chore-template.archive` | POST | Bearer | No | 30/60s |
| `chore-instance.complete` | POST | Bearer or Device | No | 20/60s |
| `chore-instance.approve` | POST | Bearer | No | 100/60s |
| `chore-instance.reject` | POST | Bearer | No | 100/60s |
| `redemption.request` | POST | Bearer or Device | No | 10/60s |
| `redemption.approve` | POST | Bearer | **Yes** | 60/60s |
| `redemption.deny` | POST | Bearer | No | 60/60s |
| `point-transaction.fine` | POST | Bearer | **Yes** (> 25 pts) | 30/60s |
| `point-transaction.reverse` | POST | Bearer | **Yes** | 30/60s |
| `subscription.update` | POST | Bearer | No | 10/60s |

### Request/response shapes (key endpoints)

#### `chore-instance.complete`
```typescript
// Request
{
  instance_id: string,          // UUID
  completed_at: string,         // ISO8601
  proof_photo_id?: string,      // UUID if photo uploaded
  completed_by_device?: string  // iPad multi-kid attribution
}
// Response (happy path)
{
  instance: ChoreInstance,
  transaction?: PointTransaction,  // null if requires_approval
  balance_after?: number
}
// Response (error)
{ error: { code: "CHORE_ALREADY_COMPLETED" | "OUTSIDE_WINDOW" | "INVALID_INSTANCE", message: string } }
```

#### `redemption.approve` (atomic transaction required)
```typescript
// Request
{ request_id: string }
// Implementation (inside Postgres transaction):
//   1. SELECT redemption_request FOR UPDATE
//   2. Verify kid balance >= price
//   3. INSERT point_transaction (amount = -price, kind = 'redemption')
//   4. UPDATE redemption_request SET status = 'fulfilled', resulting_transaction_id = ...
//   5. INSERT audit_log
//   6. COMMIT
// Any failure rolls back; balance and request stay in sync.
```

#### `point-transaction.fine`
```typescript
// Request
{
  user_id: string,
  amount: number,          // positive; will be negated
  reason: string,          // required; from canned list or free-text
  canned_reason_key?: string
}
// Response
{ transaction: PointTransaction, balance_after: number }
// Enforces: family.daily_deduction_cap and family.weekly_deduction_cap (409 if exceeded)
```

---

## iOS client contracts

### `TidyQuestCore` package structure

```
TidyQuestCore/
├── Sources/TidyQuestCore/
│   ├── Domain/           # Pure value types (Family, AppUser, ChoreTemplate, ...)
│   ├── Models/           # SwiftData @Model classes
│   ├── API/
│   │   ├── APIClient.swift        # Protocol
│   │   ├── SupabaseAPIClient.swift # Impl
│   │   └── Requests/              # one file per endpoint
│   ├── Realtime/
│   │   ├── RealtimeSubscription.swift
│   │   └── Scope.swift            # per-screen subscription scopes
│   ├── Auth/
│   │   └── AuthController.swift
│   └── Tiers/
│       └── Tier.swift             # starter/standard/advanced tokens
└── Tests/TidyQuestCoreTests/
```

### Key contracts

- **`APIClient` protocol:** one method per edge function. Async throws. Returns typed decoded responses.
- **SwiftData models:** parallel to Postgres tables. Client caches for offline reads only (online-first writes per PLAN §7.4).
- **`Tier` enum:** `starter | standard | advanced`. Holds color palette, typography tokens, icon set, motion density flag. UI agents consume this; no tier logic lives in UI code.
- **`Observable` repository:** one per feature area (ChoreRepository, LedgerRepository, FamilyRepository). Views bind to these.

### Tier tokens (agents C1–C4 read these exactly)

```swift
public enum Tier {
    case starter, standard, advanced

    public var tileCornerRadius: CGFloat {
        switch self {
        case .starter: 28
        case .standard: 20
        case .advanced: 14
        }
    }

    public var headlineFont: Font {
        switch self {
        case .starter: .system(size: 28, weight: .bold, design: .rounded)
        case .standard: .system(size: 22, weight: .semibold, design: .rounded)
        case .advanced: .system(size: 17, weight: .semibold, design: .default)
        }
    }

    public var minTapTarget: CGFloat {
        switch self {
        case .starter: 60
        case .standard: 56
        case .advanced: 44
        }
    }

    public var useIllustratedIcons: Bool { self == .starter }
    public var showNumericBalance: Bool { self != .starter }   // Starter sees jar metaphor
    public var motionDensity: MotionDensity { self == .advanced ? .reduced : .standard }
}
```

### Color palette (colorblind-safe, 8 entries)

Kid colors paired with icons (never color alone):
```swift
public enum KidColor: String, CaseIterable {
    case coral, sunflower, sage, sky, lavender, rose, olive, slate
    public var hex: String { /* values below */ }
    public var icon: String { /* SF Symbol fallback */ }
}
```
| Key | Hex | Paired icon |
|---|---|---|
| coral | `#FF6B6B` | `star.fill` |
| sunflower | `#FFD93D` | `sun.max.fill` |
| sage | `#6BCB77` | `leaf.fill` |
| sky | `#4D96FF` | `cloud.fill` |
| lavender | `#B983FF` | `moon.stars.fill` |
| rose | `#FF8FB1` | `heart.fill` |
| olive | `#8BA888` | `tree.fill` |
| slate | `#6C757D` | `circle.grid.3x3.fill` |

### Realtime subscription scopes

Each UI screen registers a scope via `RealtimeSubscription.scope(for: Screen)`:

- **Parent Today:** `chore_instance` (today), `redemption_request` (pending), `point_transaction` (today's transactions).
- **Parent Approvals:** `chore_instance` (status='pending'), `redemption_request` (status='pending').
- **Kid Home:** own `chore_instance` (today), own `point_transaction`.
- **Kid Rewards:** `reward`, own `redemption_request`.

Scopes are cancelled on view disappear.

---

## Environments & secrets

Each agent reads from `.env.local` (gitignored) with:
```
SUPABASE_URL=https://<project>.supabase.co
SUPABASE_ANON_KEY=...
SUPABASE_SERVICE_ROLE_KEY=...  # server only; NEVER in iOS client
APNS_KEY_ID=...
APNS_TEAM_ID=...
APNS_AUTH_KEY_PATH=...
```

iOS builds read backend URL from `Info.plist` key `SupabaseURL`, populated via xcconfig per scheme:
- `ParentApp-Staging.xcconfig` → staging URL
- `ParentApp-Prod.xcconfig` → prod URL
- Never hard-coded in Swift source.

---

## Conventions that prevent merge conflicts

- **One agent owns one top-level directory.** Agents never edit files outside their assigned path.
- **Swift imports:** all agents import `TidyQuestCore` as the shared module. No cross-agent direct imports.
- **Generated code:** none. No code-gen tools in MVP.
- **Shared model types:** only in `TidyQuestCore/Domain/`. UI agents don't invent new domain types.
- **Edge function agents:** each owns one `supabase/functions/<name>/` directory. Shared Zod schemas live in `supabase/functions/_shared/schemas.ts` — one agent owns that file (B4).

---

## Phase 1 schema gate (must pass before Act 2)

- [ ] `supabase start` launches clean local stack
- [ ] `supabase db push` applies migrations with no errors
- [ ] All tables exist, all enums exist, all indexes created
- [ ] Seed script loads Chen-Rodriguez family without errors
- [ ] RLS test suite: 100% pass (zero regressions)
- [ ] Xcode workspace opens; all targets build (empty UI OK)
- [ ] GitHub Actions CI runs migration lint successfully

---

## Escalation

If any agent hits an ambiguity not covered by this document, the agent must:
1. **STOP** — do not guess.
2. Write a single-line `ESCALATE:` comment in its output describing the ambiguity.
3. Return to conductor.

Conductor resolves (by editing this file if contract needs clarification) before agent resumes.
