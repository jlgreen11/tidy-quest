# Contract Tests — Chen-Rodriguez Journey

End-to-end contract tests that exercise the deployed edge functions on
the cloud staging project (`kppjiikoshywiybylkws.supabase.co`).

## Prerequisites

- [Deno](https://deno.com) >= 2.x: `brew install deno`
- Network access to Supabase cloud staging (no VPN required)
- Seed data present: Chen-Rodriguez family (family_id `11111111-…`)

## Running

```bash
bash supabase/tests/contract/run.sh
```

Or directly:

```bash
cd supabase/tests/contract
deno test --allow-net --allow-env --allow-read chen-rodriguez-journey.ts
```

## Journey steps

| Step | Description | Endpoint |
|------|-------------|----------|
| 1 | Verify seed — Chen-Rodriguez family exists in DB | PostgREST REST |
| 2 | Complete Kai's Homework chore instance | `chore-instance-complete` |
| 3 | Parent approves the chore | `chore-instance-approve` |
| 4 | Kai requests "30 min tablet time" reward | `redemption-request` |
| 5 | Parent approves the redemption | `redemption-approve` |
| 6 | Parent issues a 5-point fine to Kai | `point-transaction-fine` |
| 7 | Verify ledger: sum(transactions) matches cached_balance | PostgREST REST |
| 8 | Cleanup: reset all test mutations | PostgREST REST |

## Auth model (mock — pre-production)

- **Bearer**: `apple-mock-<apple_sub>` — accepted by `parseAppleJwt` in `_shared/auth.ts`
- **Device**: `device-token-<user_id>|<family_id>` — accepted by `parseDeviceToken`
- **App Attest**: any non-empty string passes the mock validator

## Known infrastructure bugs surfaced by this test

### Bug 1 (B1 stub): `authenticateBearer` returns undefined `user_id` and `family_id`

`_shared/auth.ts` `authenticateBearer()` calls `parseAppleJwt()` which only
returns `{ apple_sub }`, then tries to destructure `parsed.user_id`,
`parsed.family_id`, and `parsed.role` — none of which exist.

```ts
// auth.ts line 298–305 — BUG
return {
  ok: true,
  user: {
    user_id:   parsed.user_id,   // always undefined
    family_id: parsed.family_id || "",  // always ""
    role:      parsed.role || "parent",
  },
};
```

Every Bearer-authenticated endpoint that checks `template.family_id !== user.family_id`
evaluates `"11111111-…" !== ""` → 403 Forbidden.

**Affected steps:** 3, 5, 6 (all Bearer calls with family guard).

**Fix:** `authenticateBearer` must SELECT from `app_user WHERE apple_sub = parsed.apple_sub`
to resolve `user_id`, `family_id`, and `role`. The TODO at auth.ts line 276 acknowledges this.

### Bug 2: `checkRateLimit` return shape mismatch

`checkRateLimit` returns `{ allowed: boolean }` but ALL call sites check `rl.ok`:

```ts
// Every edge function (e.g. chore-instance-complete/index.ts line 47)
const rl = await checkRateLimit(user.id, "chore-instance.complete", 20);
if (!rl.ok) return errorResponse(429, ...);  // BUG: rl.ok is always undefined
```

Since `rl.ok === undefined` is falsy, every call site returns 429 Rate Limited
regardless of the actual rate limit state.

**Affected steps:** 2, 3, 4, 5, 6 (all endpoints using checkRateLimit).

**Fix:** Change `if (!rl.ok)` → `if (!rl.allowed)` in all 22 edge function files.
OR: add `.ok` alias to the return type in `checkRateLimit`.

### Bug 3: `checkRateLimit` called with wrong number of arguments

All edge functions call `checkRateLimit(user.id, endpoint, maxRequests)` (3 args)
but the shared implementation signature is:
```ts
checkRateLimit(supabase, userKey, endpoint, maxRequests, windowSeconds)  // 5 args
```

With wrong arity the `supabase` param receives `user.id` (a string), causing
`supabase.from(...)` to throw TypeError inside the rate limit helper.
The catch block fails open (`return { allowed: true }`) — so the 429 from Bug 2
actually fires before this error is ever reached (Bug 2 dominates).

### Bug 4: Step 1 + 7 — RLS blocks anon reads

`app_user`, `family`, and `point_transaction` tables have RLS policies that
require role `authenticated` (a real Supabase Auth JWT), not `anon`. The test
degrades gracefully to warnings for these steps rather than failing.

### Bug 5: `canned_reason_key: null` fails Zod validation

`PointTransactionFineRequest` schema defines `canned_reason_key` as
`z.string().min(1).max(100).optional()` — `null` is not valid, only `undefined`
(i.e., omit the field). Sending `null` returns 400. Fixed in Step 6 of this test.

## Idempotency

The test is designed to be safely re-run:
- Uses stable seed IDs (no new users created)
- Step 8 cleans up all mutations
- Step 2 tolerates 409 if the chore was already completed in a prior run

> Note: cleanup uses the anon key which is subject to RLS. If cleanup fails,
> run the manual SQL shown in the cleanup step output via the Supabase dashboard.
