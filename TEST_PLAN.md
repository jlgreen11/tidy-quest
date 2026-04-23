# TidyQuest — Test Plan

Produced by /autoplan Phase 3 (Eng Review). This is the minimum test matrix required before any non-self TestFlight user. See `PLAN_v0.1.md` §16 for rationale.

---

## Coverage targets (v0.1 gate)

| Layer | Tool | Target | Gate |
|---|---|---|---|
| iOS unit | Swift Testing 6+ | 70% of TidyQuestCore; 100% of economy logic | PR merge |
| UI snapshot | swift-snapshot-testing | 3 tiers × 4 states on every kid screen; parent critical flows | PR merge |
| Property-based | Swift Testing + fuzz | Every ledger invariant (below) | PR merge |
| Edge function | Deno test | Every endpoint, 5 cases each (below) | PR merge |
| RLS | Custom SQL suite | Every table × role × op combination | PR merge |
| Contract | iOS + staging | Canned family journey | Nightly |
| A11y | XCUITest + Accessibility Audit | VoiceOver + Reduce Motion on critical screens | Pre-release |
| E2E smoke | XCUITest | One family journey | Pre-TestFlight |

---

## Ledger invariants (property-based)

For any generated family state with N users and M transactions, these must hold:

1. **Balance identity.** `user.cached_balance == SUM(amount) WHERE user_id = user.id` for every user.
2. **Reason required on negative.** `FOR ALL tx WHERE amount < 0: tx.reason IS NOT NULL AND length(tx.reason) > 0`.
3. **No double-completion.** `FOR ALL chore_instance: COUNT(PointTransaction WHERE reference_id = chore_instance.id AND kind = 'chore_completion') <= 1`.
4. **Streak monotonicity.** Within an unbroken completion sequence for (user, chore_template), streak length is strictly increasing by 1 per day.
5. **Same-family FK integrity.** `ChoreInstance.user.family_id == ChoreInstance.template.family_id` always.
6. **Actor provenance.** `PointTransaction.created_by_user_id IS NOT NULL` for every transaction.
7. **Idempotency.** Two submissions with the same `idempotency_key` produce one transaction.
8. **Redemption atomicity.** `RedemptionRequest.status == 'fulfilled'` iff `resulting_transaction_id IS NOT NULL` and the corresponding PointTransaction exists.
9. **Reversal integrity.** `PointTransaction.reversed_by_transaction_id` references a transaction of kind `correction` with opposite sign.
10. **Balance cache staleness impossible.** `user.cached_balance_as_of_txn_id == MAX(id) FROM PointTransaction WHERE user_id = user.id`.

---

## Edge function test matrix

For each endpoint, 5 cases:

| # | Case | Expected behavior |
|---|---|---|
| 1 | Happy path | 200, correct state change |
| 2 | Idempotency (duplicate submit) | Same response as first; no second state change |
| 3 | Input validation failure | 400 + structured error |
| 4 | Rate limit exceeded | 429 |
| 5 | App Attest failure (sensitive only) | 403 |

**Endpoints:**

- `POST /chore-instance/complete` — kid marks done
- `POST /chore-instance/complete/batch` — offline drain (v0.2)
- `POST /chore-instance/approve` — parent approves pending
- `POST /chore-instance/reject` — parent rejects
- `POST /redemption/request` — kid requests reward
- `POST /redemption/approve` — parent approves (requires App Attest)
- `POST /redemption/deny` — parent denies
- `POST /point-transaction/fine` — parent issues fine (requires App Attest above threshold)
- `POST /family/create` — new family
- `POST /family/delete` — delete family (requires App Attest)
- `POST /user/add-kid` — parent adds kid profile
- `POST /user/pair-device` — generate pairing code
- `POST /user/claim-pair` — kid device claims code
- `POST /user/revoke-device` — parent revokes kid's device
- `POST /subscription/update` — StoreKit receipt update

---

## RLS test suite

Parameterized test runs against ephemeral Supabase project in CI.

**Roles tested:** `anon`, `authenticated` (parent in family A), `authenticated` (child in family A), `authenticated` (parent in family B), `service_role`.

**Tables tested:** Family, User, ChoreTemplate, ChoreInstance, PointTransaction, Reward, RedemptionRequest, Routine, Streak, Challenge, ApprovalRequest, Notification, AuditLog, Subscription, job_log.

**Operations:** SELECT, INSERT, UPDATE, DELETE.

**Critical expected denials (non-exhaustive):**
- child in family A cannot SELECT `PointTransaction` for sibling in family A (unless family opted-in transparency)
- child in family A cannot SELECT anything in family B
- child in family A cannot INSERT `PointTransaction` directly (must go through edge function)
- child in family A cannot UPDATE `ChoreInstance.status` directly
- parent in family A cannot SELECT family B
- `anon` cannot SELECT any Family
- even `service_role` UPDATE/DELETE on PointTransaction is rejected by trigger (only reversal path)

**Format:** each case is a single SQL block:
```sql
SET LOCAL role = 'authenticated';
SET LOCAL request.jwt.claims = '{"sub": "<family-a-child-uid>", "family_id": "<family-a-id>", "role": "child"}';
SELECT * FROM point_transactions WHERE user_id = '<family-a-sibling-uid>';
-- EXPECT: 0 rows
```

Script runs ~180 cases in < 30 seconds against a warm test DB.

---

## Snapshot test matrix (iOS UI)

**Kid home screen** (12 snapshots per tier × 3 tiers = 36):

- Tier × (empty, loading, 1/5 done, 5/5 done, pending-approval, offline error)
- Each at Dynamic Type sizes: `large`, `AX3`, `AX5`.

**Parent Today screen** (9 snapshots):

- Approval queue densities: 0, 5, 40.
- Dynamic Type × `large`, `AX3`, `AX5`.

**Parent Approvals tab** (6 snapshots):

- Queue densities: 0, 1, 5, 10, 40, 100.

**Rewards tab** (6 snapshots):

- Tiers × (no affordable, some affordable, all affordable, with saving-goal, cooldown-locked reward, empty).

**Settings 8-section IA** (8 snapshots, light + dark).

**Fine bottom sheet micro-interaction** (tier × reason text length): 6 snapshots.

Total: ~70 snapshots. Baseline freeze before TestFlight.

---

## A11y audit cases

- **VoiceOver rotor:** kid home → "Chore 1, make bed, 5 points, not started, button." Confirm each tile announces identifier + state + action.
- **Dynamic Type at AX5:** all critical text remains visible; no truncation on hero elements; scrolling not broken.
- **Reduce Motion on:** confetti replaced with fade; spring animations replaced with 150ms linear.
- **Dark Mode:** every surface has dark palette; no contrast below WCAG AA on AA/AAA text.
- **Color discrimination:** greyscale screenshot of per-kid color-coded ledger; kids remain distinguishable by icon shape alone.
- **Tap targets:** every interactive element ≥ 44×44pt (60×60 for Starter tier).

---

## E2E smoke test (XCUITest, runs pre-TestFlight)

Scripted family journey, 5-minute runtime:

1. Launch app, Sign in with Apple (test account).
2. Create family "Smoke Family."
3. Skip co-parent invite.
4. Add kid "Smoke Kid," age 9, Standard tier.
5. Skip device pairing (use same device).
6. Choose "8–10 Standard" preset pack.
7. Accept 5 prefilled chores.
8. Accept default reminder times.
9. Start 14-day trial (mock).
10. Switch to kid mode (PIN).
11. Complete a morning chore.
12. Verify tile animates, balance ticks up.
13. Switch to parent mode.
14. Verify Today screen shows completion.
15. Switch to kid mode, request a reward.
16. Switch to parent mode, approve.
17. Verify point deduction and reward marked redeemed.
18. Issue a behavior fine ("Rude to sibling," canned reason).
19. Verify balance ticks down with reason on ledger.
20. Delete test family (end-to-end teardown).

Any deviation fails the build.

---

## Contract test (nightly against staging)

Same as E2E smoke but against the real staging Supabase project, no mocks. Tests network path, edge function behavior, and end-to-end data integrity.

---

## Performance benchmarks (one-time gate before v1.0)

- **Kid home load-to-interactive:** < 400ms on iPhone 12 cold launch.
- **Approval queue render (40 items):** < 300ms.
- **Point transaction write latency (staging):** p95 < 250ms.
- **Realtime subscription delivery:** median < 500ms from DB change to UI update.
- **Widget timeline refresh:** < 100ms CPU budget per refresh.

---

## Release gate checklist

Before every TestFlight build to non-self users:

- [ ] All unit + property-based + snapshot tests pass.
- [ ] RLS suite passes (no merges allowed otherwise).
- [ ] Edge function suite passes.
- [ ] Smoke E2E passes on latest Xcode.
- [ ] No new Sentry-reported crashes in the last 72h.
- [ ] Migration lint clean.
- [ ] Staging environment reflects the PR.
- [ ] Release notes drafted.
