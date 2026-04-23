# Chore Quest — /autoplan Review Report

**Reviewed:** 2026-04-22 | **Plan file:** PLAN.md | **Branch:** autoplan-v0
**Methodology:** /autoplan (CEO → Design → Eng) with dual voices (Claude primary + Claude independent subagent; Codex unavailable → tagged `[subagent-only]`)
**Decision framework:** 6 principles (Completeness, Boil Lakes, Pragmatic, DRY, Explicit over Clever, Bias toward Action)

---

## Phase 1: CEO Review (Strategy & Scope)

### Step 0A — Premise Challenge

The plan rests on eight premises. Three are well-grounded, three are assumed, two are wrong-shape.

| # | Premise | Stated or assumed? | Verdict |
|---|---|---|---|
| P1 | Primary pain is "nagging fatigue" | Assumed | **Contestable.** Real buyer motivation may be allowance-mgmt, executive-function coaching, or just "stop the whining." |
| P2 | "Chore tracking is table stakes; economy design is the differentiator" | Asserted | **Half-right.** Economy matters but is the power-user differentiator. Median-parent differentiator is setup speed + kid engagement. |
| P3 | "SkyLight is the reference competitor" | Asserted | **Incomplete.** Ignores OurHome (free, large install base), Joon (ADHD angle), BusyKid/Greenlight (real-money moat). |
| P4 | Target audience spans ages 5–14 | Stated | **Too broad.** A 5-year-old and a 13-year-old need different apps. Plan gestures at tiers but doesn't commit. |
| P5 | Solo dev ships v0.1 in 8–10 weeks evenings | Asserted | **Optimistic by ~1.5–2x.** Offline sync + COPPA device pairing + 6-tab parent app + 3-tab kid app is not 80 hours. |
| P6 | iPad command center is a key surface | Asserted | **Fantasy.** Mounted-iPad category is real but shallow; v0.2 scheduling is premature. |
| P7 | Parents want configurable economies | Assumed | **Power-parent bias.** Median parent wants "it works." |
| P8 | Kids will open the app | Assumed | **Cold-start blind spot.** No cold-start design; no day-two re-engagement plan. |

### Step 0B — What Already Exists (Competitive Leverage Map)

The plan treats this as greenfield. It isn't.

| Sub-problem | Existing solution | Leverage |
|---|---|---|
| Chore tracking UX | OurHome, Homey, Cozi | **Download and study first**; many patterns already solved. |
| Gamification + economy | OurHome, Joon | Joon's ADHD framing is defensible moat; OurHome's free tier is a wall. |
| Real-money rewards | Greenlight, BusyKid, RoosterMoney | **Don't compete here** without a bank relationship; plan's "informal IOU" is correct. |
| Family coordination | Cozi, SkyLight, Apple Family | Adjacent; not core to this pitch. |
| COPPA-compliant kid profiles | Many (Khan Academy Kids, etc.) | Device-pairing pattern is well-established. |
| Sign in with Apple | Apple | Plan correct. |

**Action:** Before writing code, the author should install OurHome, Joon, and one of Greenlight/BusyKid, run through onboarding, and produce a 1-page teardown. Estimated 2 hours. Saves weeks.

### Step 0C — Dream State Delta

```
CURRENT STATE (April 2026)
   Parent: nagging, one-sided enforcement, no shared model
   Kid:    checklist-deaf, no feedback loop
   App:    sticker chart on fridge OR abandoned family calendar

THIS PLAN (October 2026, if shipped as written)
   Parent: configured a 60-field economy, gets push notifications,
           approves redemptions, watches earnings dashboard
   Kid:    opens app at parent's prompt, completes chores, sees points,
           requests rewards with parent approval
   App:    full ledger, 5 chore types, 6 reward categories, streaks,
           routines, quests (v1.0), iPad command center, widgets

12-MONTH IDEAL (April 2027)
   Parent: opens app 2x/week, glances, approves batch in 30 seconds;
           feels the app made home calmer
   Kid:    opens app daily without prompt; morning routine runs itself;
           saving goal visible and motivating
   App:    proven D30 retention, chosen monetization, 100+ families paying
```

**Delta (this plan → 12-month ideal):** The plan builds the machinery but has no line of sight to the behavior change. The gap is not features; the gap is validation that the loop works. Cold-start design, first-session experience, and day-two re-engagement are unspecified.

### Step 0C-bis — Implementation Alternatives

| # | Approach | Effort (CC-assisted) | Risk | Pros | Cons |
|---|---|---|---|---|---|
| A | **Plan as written** (ledger-first, full economy, iPad) | 12–16 wk evenings | High scope risk | Covers power-parent buyer; differentiated on paper | Misses mass market; cold-start unaddressed |
| B | **ADHD executive-function pivot** (Joon-adjacent) | 10–12 wk | Narrower but deeper market | 5–10x willingness to pay; clear App Store positioning | Requires clinical affinity / user population access |
| C | **Checklist-first MVP** (ship honor-system only; add economy in v0.2) | 4–6 wk to v0.1 | Low; proves core engagement first | Fast validation; economy added only if families show demand | Abandons differentiator upfront; risks "just another checklist app" |
| D | **Allowance-integrated** (Greenlight-lane) | 16+ wk | High regulatory + financial complexity | Strong retention hook | Compliance swamp; plan correctly defers |

**Recommendation:** Hybrid of A+C. Ship the **ledger architecture** (data model, transactions, audit) but launch v0.1 with a **thinner UI surface** — honor system, 1 chore type (daily), 2 reward categories (treats + privilege), no iPad command center, no streaks. Prove family D30 retention > 40% before building the full economy UI. This is the "boil the lake that matters" version.

### Step 0D — Mode Selection: SELECTIVE EXPANSION

Hold scope on: core ledger architecture, parent-approval model, COPPA device pairing, the economy-as-ledger-not-mutable-balance invariant.

Cherry-pick expansion on: cold-start UX, first-session spec, monetization architecture (paywall-from-day-one), inflation drift countermeasures, competitive teardown.

Defer (scope reduction): iPad command center (cut through v1.0), offline sync (cut MVP — online-only with clear offline error), surprise multipliers (cut to v1.5).

### Step 0E — Temporal Interrogation

- **Hour 1** (family opens app): Does a parent reach "first chore configured" in under 8 minutes? Plan doesn't say.
- **Day 1**: Does a kid complete one chore with parent witnessing? Plan doesn't spec.
- **Day 2**: Does the kid open the app without being asked? **This is where most families die.** Plan has no day-2 hook.
- **Week 1**: Does the family do this every day? Plan's streak mechanic helps but requires streak-freeze to avoid death spiral.
- **Month 1**: Does the parent still approve within 2 hours? Plan flags "stale approvals" but countermeasure (auto-approve under threshold) is v0.2. Should be MVP.
- **Month 3**: Does inflation drift kill the economy? Plan's earnings dashboard is v1.0. Too late.
- **Month 6**: Does a co-parent who never opened the app sabotage approvals? Plan doesn't discuss.

### Step 0F — Mode Confirmed: SELECTIVE EXPANSION

---

### Step 0.5 — Dual Voices

**CODEX SAYS (CEO — strategy challenge)** — `[codex-unavailable]` (binary not installed)

**CLAUDE SUBAGENT (CEO — strategic independence)** — `[subagent-only]`

Summary of subagent's 7 findings (full text in decision log):
1. Wrong buyer / misidentified target — power parent ≠ mass buyer [HIGH]
2. Zero user research — critical gap [CRITICAL]
3. iPad command center is regret-in-waiting — cut it [HIGH]
4. Competitive moat nonexistent vs OurHome/Joon/Greenlight [HIGH]
5. Timeline optimistic by 1.5–2x [MEDIUM]
6. No business model / monetization [CRITICAL]
7. Hardest problem is cold-start, not economy sustainability [HIGH]

**CLAUDE PRIMARY (me)** — complementary findings not in subagent:
- **A.** Power-parent vs median-parent tension — "Mint for chores" risk [CRITICAL]
- **B.** First-session spec missing; 40–60% consumer-iOS install→engage drop [CRITICAL]
- **E.** Inflation drift is a weeks-problem, not a year-problem [HIGH]
- **F.** "Reason required" on negative transactions will fatigue parents [MEDIUM]
- **G.** Multi-child non-participation (not just sabotage) [MEDIUM]
- **H.** App Store launch strategy missing [MEDIUM]
- **I.** Photo proof privacy creep — 90d retention too long [MEDIUM]
- **J.** No North Star metric — propose D30 family retention [MEDIUM]

### CEO Dual Voices — Consensus Table

```
═══════════════════════════════════════════════════════════════════
  Dimension                                   Claude  Subagent  Consensus
  ───────────────────────────────────────────  ──────  ────────  ─────────
  1. Premises valid?                           NO      NO        CONFIRMED
  2. Right problem to solve?                   PARTIAL PARTIAL   CONFIRMED (reframing warranted)
  3. Scope calibration correct?                NO      NO        CONFIRMED (scope too broad)
  4. Alternatives sufficiently explored?       NO      NO        CONFIRMED
  5. Competitive/market risks covered?         NO      NO        CONFIRMED
  6. 6-month trajectory sound?                 NO      NO        CONFIRMED
═══════════════════════════════════════════════════════════════════
  Both voices agree: the plan is architecturally thoughtful but
  strategically under-examined. Six of six dimensions flagged.
  Zero disagreements between voices.
```

### Error & Rescue Registry (CEO-surfaced)

| # | Error pattern | Blast radius | Rescue |
|---|---|---|---|
| E1 | Family abandons at setup (cold-start) | Kills v0.1 adoption | Ship preset packs + ≤10-min setup flow in MVP |
| E2 | Kid opens app day 1, never again | Kills any app retention | Day-2 push + visible streak start + small "welcome bonus" earned |
| E3 | Parent approval queue grows stale | Kid disengages | Auto-approve-under-threshold in MVP, not v0.2 |
| E4 | Inflation drift (parent adds high-value chore) | Economy collapses by month 2 | Hard earnings-band check at chore creation in MVP |
| E5 | Co-parent friction (one parent never approves) | Family churns by month 1 | Per-parent pre-approval rules + shared view |
| E6 | One sibling participates, one refuses | Poisons engaged sibling's experience | Per-kid opt-in economies visible in UI; no forced comparison |
| E7 | Kid uploads inappropriate photo | Privacy / relational harm | Shorter retention (7d), content reminder in kid UI, auto-delete on reject |
| E8 | Apple ships Family Chores in iOS 26 | Existential | Defensive positioning: ADHD angle or clinical app store category |
| E9 | TestFlight → 0 paying users | Hobby trap | Decide monetization pre-code: $5.99/mo with 14-day trial; paywall from day 1 |
| E10 | Kid "reason" field becomes "bad" × 40 | Audit log meaningless | Canned reasons + optional free-text |

### Failure Modes Registry (CEO-surfaced)

| Mode | Likelihood | Impact | Mitigation in plan? |
|---|---|---|---|
| Setup tax kills onboarding | High | Critical | **No** — add first-session spec |
| Cold-start kid engagement | High | Critical | **No** — add day-2 hook |
| Inflation drift | High | High | Partial — countermeasure scheduled too late |
| Co-parent misalignment | Medium | High | **No** — add pre-approval rules to MVP |
| App Store silence | Medium | High | **No** — add launch strategy |
| Photo privacy incident | Low | High | Partial — retention + moderation |
| Apple sherlocks feature | Low | Critical | **No** — add defensive moat (ADHD?) |

### NOT in scope (deferred)

| Item | Why deferred | Owner / where tracked |
|---|---|---|
| Full ADHD pivot (mode B) | Would require market validation; user hasn't signaled appetite | TODOS, taste decision |
| Allowance/real-money lane (mode D) | Plan correctly rejects; compliance swamp | Plan §12 |
| Apple Watch companion | Minority of target kids; post-v1 | Plan §8 |
| Full offline support MVP | Online-first drops 1–2 weeks off timeline | Proposed cut |
| iPad command center v0.2 | Defer to v1.5 or cut entirely | Proposed cut |

### What Already Exists

This plan is greenfield code but not greenfield market. The author must map every proposed feature against what OurHome, Homey, Joon, Cozi, and BusyKid already ship. Proposed 1-hour competitive teardown before any code.

### CEO Completion Summary

| Dimension | Rating | Top concern |
|---|---|---|
| Premise soundness | 4/10 | Multiple assumed; no validation |
| Scope discipline | 5/10 | MVP bloat (iPad, streaks, offline, photo) |
| Alternatives explored | 3/10 | Single reframing offered; competitive set under-examined |
| Competitive moat | 2/10 | None articulated |
| Cold-start design | 1/10 | Absent |
| Monetization | 0/10 | Absent |
| Timeline realism | 4/10 | Optimistic |
| **Overall** | **5/10** | Thoughtful architecture, weak strategy layer |

**Auto-decisions logged:** 14 (see Decision Audit Trail at end).
**Taste decisions surfaced for gate:** 4 (see Phase 4).
**User challenges:** 2 (see Phase 4).

---

## Phase 2: Design Review (UI scope confirmed)

### Step 0 — Design Scope

Plan §5 specifies three surfaces (parent iPhone, kid iPhone, iPad command center). No DESIGN.md exists. No design system referenced. No Figma link. Completeness rating for current design spec: **3/10** — described at wireframe level, production-ready at zero screens.

### Step 0.5 — Dual Voices

**CODEX SAYS (design — UX challenge)** — `[codex-unavailable]`

**CLAUDE SUBAGENT (design — independent review)** — `[subagent-only]`

Subagent findings (full text in decision log):
1. Kid home hierarchy wrong — balance should not be hero [CRITICAL, 3/10]
2. Missing states everywhere — 6 named states unspecified [CRITICAL, 2/10]
3. Kid journey per-tier underspecified [HIGH, 4/10]
4. Approvals queue placement + 40-item triage missing [HIGH, 3/10]
5. iPad command center has no type/contrast/ambient-mode spec [HIGH, 2/10]
6. Age-spanning UI: no typography/iconography/motion diff between tiers [CRITICAL, 2/10]
7. Negative mechanics micro-interaction entirely unspecified [CRITICAL, 2/10]

**CLAUDE PRIMARY (me) — additional findings:**

- **D1. Tab count violates iOS HIG.** Parent app has 7 tabs (Today, Approvals, Kids, Chores, Rewards, Economy, Settings). iOS tab bar caps at 5 before collapsing into "More." Users hate "More." Fix: consolidate to 5 — **Today, Approvals, Family** (Kids + Chores + Rewards under one tab with segmented control), **Economy, Settings**. [HIGH]

- **D2. Accessibility is absent.** No mention of VoiceOver labels, Dynamic Type, Reduce Motion, Dark Mode, color contrast, or SF Symbols. For an app with users aged 5–14, some of whom are neurodivergent (plan's own target), this is a showstopper for adoption and for App Review rejection risk. Fix: a11y section in spec with explicit targets — WCAG AA, VoiceOver for every interactive element, Dynamic Type support on text, Reduce Motion alternative for confetti/springs, Dark Mode at parity. [CRITICAL]

- **D3. Onboarding / first-run is entirely unspecified.** Plan §4 describes the "add a new chore" journey but assumes a family is already set up. The single most important UI surface — the first-run walkthrough — gets zero ink. Fix: add §4.0 spec covering: welcome → create family → Sign in with Apple → invite co-parent (skippable) → add first kid → pair kid's device (QR or code) → choose preset pack (age-band) → review 5 prefilled chores → tune or accept → first-run tutorial on Today screen → "completed first chore" celebration. Target: **under 10 minutes** wall-clock. [CRITICAL]

- **D4. Notification UI unspecified.** Plan §7.5 defines when to notify but not what the rich notification looks like. iOS supports action buttons on push (Approve / View / Dismiss). A parent who can approve a chore from the lock screen without opening the app is a massive UX win. Fix: spec rich notifications with inline Approve action for low-stakes items, with photo thumbnail for photo-proof items. [HIGH]

- **D5. Settings IA is a single bucket.** Plan §5.1 lumps everything under "Settings" with no hierarchy. Power parents configure 30+ things. Fix: 8-section settings hierarchy — **Family** (name, timezone, reset time, quiet hours), **Kids** (list + per-kid config), **Chore defaults**, **Reward defaults**, **Notifications** (granular per-role), **Economy** (inflation controls, earnings band), **Privacy & Data** (export, deletion, retention), **Account** (Sign in with Apple, subscription, sign out). [MEDIUM]

- **D6. Localization / extractable strings.** Zero mention. Plan's target is US but the first App Store review will ask for Spanish. Fix: design for string extraction from day 1; no hardcoded UI strings in Swift source. [MEDIUM]

- **D7. Per-kid color system lacks colorblind-safe guarantees.** Plan says each kid has a color. With two siblings of red-green colorblindness (~8% of boys), the color-coded ledger becomes confusing. Fix: color + icon pairing; color is never the sole discriminator. [MEDIUM]

- **D8. Photo capture flow absent.** Plan requires photo proof but no spec for: camera permission prompt timing, in-app camera vs photo picker, post-capture review/retake, resolution target (1024×1024 JPEG Q70 sufficient; don't upload 12MP originals), compression. [HIGH]

- **D9. Reward affordability + saving-goal UI missing.** Plan mentions "filtered to what's affordable" but no spec. Fix: affordable rewards render full-color; unaffordable render 60% opacity with a small "X more points" badge. Saving-goal section is a dedicated hero card at top of Rewards tab with animated progress ring. [MEDIUM]

- **D10. Widget UI (MVP kid home widget) entirely unspecified.** Plan §8 commits to this as MVP but no design. Fix: 3 widget sizes — small (balance + single next chore), medium (balance + 3 chore tiles + progress ring), large (full today panel). [HIGH]

### Design Litmus Scorecard (consensus)

```
═══════════════════════════════════════════════════════════════════════
  Dimension                              Claude  Subagent  Consensus
  ──────────────────────────────────────  ──────  ────────  ─────────
  1. Information hierarchy (kid home)     3/10    3/10      CONFIRMED
  2. State coverage (empty/error/partial) 2/10    2/10      CONFIRMED
  3. Age-spanning UI specifics            2/10    2/10      CONFIRMED
  4. Parent approvals UX                  3/10    3/10      CONFIRMED
  5. iPad ambient & type specs            2/10    2/10      CONFIRMED
  6. Negative mechanics micro-interaction 2/10    2/10      CONFIRMED
  7. Accessibility (a11y)                 0/10    —         CLAUDE-ONLY CRITICAL
  8. Onboarding / first-run               0/10    —         CLAUDE-ONLY CRITICAL
  9. Tab architecture (iOS HIG)           4/10    —         CLAUDE-ONLY HIGH
  10. Notification rich UI                3/10    —         CLAUDE-ONLY HIGH
  11. Photo capture flow                  2/10    —         CLAUDE-ONLY HIGH
  12. Settings IA                         4/10    —         CLAUDE-ONLY MEDIUM
  13. Widget design                       0/10    —         CLAUDE-ONLY HIGH
═══════════════════════════════════════════════════════════════════════
  Overall design completeness: 2.3/10
  CONFIRMED critical gaps: 4
  CLAUDE-ONLY findings: 7 (subagent's scope was narrower by design)
```

### Design Completion Summary

| Dimension | Rating | Top concern |
|---|---|---|
| Hierarchy | 3/10 | Kid home hierarchy inverted |
| States | 2/10 | Every screen missing states |
| Journey specificity | 3/10 | No feedback, haptic, sound specs |
| A11y | 0/10 | Absent |
| Responsive / iPad | 2/10 | No type ladder, no ambient mode |
| Polish micro-interactions | 2/10 | Most critical (fine, celebration) unspecified |
| Onboarding | 0/10 | Missing entirely |
| **Overall** | **2.3/10** | Strong mechanics spec, production-hostile UI spec |

**Auto-decisions logged in Phase 2:** 11.
**Taste decisions surfaced for gate:** 2 (tier color/icon palette choice; motion density default).

---

## Phase 3: Eng Review (Architecture, Data Model, Security, Tests)

### Step 0 — Scope Challenge + What Exists

Per CEO Phase 1, proposed scope cuts for MVP:
- Cut iPad command center (retain as "scaled iPhone" only through v1.0)
- Cut MVP offline sync (ship online-first with clear error states)
- Cut streak freezes (v1.0); basic streaks remain
- Keep: ledger architecture, device-pairing auth, RLS boundary, approval flow

### Step 0.5 — Dual Voices

**CODEX SAYS (eng — architecture challenge)** — `[codex-unavailable]`

**CLAUDE SUBAGENT (eng — independent review)** — `[subagent-only]`

Subagent's triaged findings (17 total, top 6 criticals/highs):
1. **Redemption atomicity missing** — two-step write not in a Postgres transaction; balance/reward can diverge on flaky networks [CRITICAL, 1h]
2. **Idempotency constraint on PointTransaction is prose, not schema** — need `UNIQUE(chore_instance_id) WHERE kind='chore_completion'` [CRITICAL, 2h]
3. **RLS has no test suite** — silent zero-row returns instead of errors; children's data leak risk [HIGH, 2–4h]
4. **Actor provenance (`created_by_user_id`) nullable** — must be NOT NULL with system-user sentinel [HIGH, 30min]
5. **Streak not recomputed on parent undo** — retroactive ChoreInstance edits silently corrupt streaks [HIGH, 4–8h]
6. **Daily reset job not idempotent** — double-fire duplicates ChoreInstances [HIGH, 1h]

Plus 11 medium/high items (rate limiting, photo URL pattern/TTL, offline status conflict, Core Data vs SwiftData, migration strategy, staging env, photo purge job, cost estimate, DST, device token rotation).

**CLAUDE PRIMARY (me) — additional findings:**

- **E1. UUID v7 not native in Postgres 15/16.** Plan §7.2 specifies "UUIDs (v7 for sortability)." Supabase runs Postgres 15. `gen_random_uuid()` is v4. v7 requires either a client-generated value (iOS can do this with a Swift impl) or a custom SQL function. Must pick and document. [MEDIUM]

- **E2. Cross-table same-family CHECK missing.** A ChoreInstance references both a User and a ChoreTemplate. Both must be in the same family. Without a DB-level check (or server enforcement), a bug could credit a kid from one family with points from another family's chore. Fix: add a trigger or a CHECK via generated column ensuring `user.family_id = chore_template.family_id` on insert. [HIGH]

- **E3. No batch completion API.** Kid drains offline queue as N sequential POSTs. At 20 queued chores after a weekend, that's 20 round-trips each incurring Supabase connection setup. Fix: a single `POST /completions/batch` endpoint accepting an array; edge function inserts in a single transaction with client-generated idempotency keys. [MEDIUM]

- **E4. Balance cache strategy unspecified.** §6.1 says "balance can be cached." But: where? On User row? Separate `balance_snapshot` table? Redis? Postgres `GENERATED` column? Each has different invalidation semantics. A ledger/cache drift means a kid sees a different number than they actually have. Fix: decide now. Recommend a Postgres trigger that maintains `user.cached_balance` + `user.cached_balance_as_of_txn_id`; if divergence detected on read, rebuild from transactions. Explicit over clever. [HIGH]

- **E5. AuditLog scope ambiguous.** §6 defines AuditLog but says "everything sensitive writes here." Which events? Fix: enumerate — family create/delete, user add/remove, role change, point transaction with amount > 100 (threshold configurable), redemption approve/deny, RLS denial, failed login. Write a taxonomy in the plan. [MEDIUM]

- **E6. ChoreInstance.scheduled_for timezone ambiguity.** Is it a UTC date, a local-calendar date, or a timestamptz with local-noon? Daily reset logic depends on this. Fix: store as `date` (family-local calendar date) with explicit comment. Reset job computes "which families reset at this UTC instant" via timezone conversion on `Family.timezone`. [HIGH]

- **E7. No test infrastructure specified.** Plan §11 lists features but no "tests." For a ledger app, testing invariants should be structural:
  - **Property-based tests** (Swift Testing 6+ with fuzz) for: balance = sum(transactions), no negative transaction without reason, no double-payment per instance, streaks are monotonic.
  - **Snapshot tests** for UI at each tier (Starter/Standard/Advanced).
  - **Contract tests** against Supabase staging for every edge function.
  - **RLS test suite** (subagent finding) — concrete script.
  No tests in the plan is a red flag for a ledger-centric app. [HIGH]

- **E8. Widget refresh strategy absent.** Plan §8 makes the kid home-screen widget MVP but doesn't address: how often does it refresh? WidgetKit with BGTaskScheduler on wake? Push-driven refresh on data change (via CloudKit Public DB, which requires entitlements the plan doesn't specify)? Stale widget shows yesterday's balance, user loses trust. Fix: on-completion server push wakes widget reload via `WidgetCenter.shared.reloadAllTimelines()` triggered by silent APNs. [HIGH]

- **E9. StoreKit 2 / RevenueCat entitlement sync missing.** If monetization is a subscription (CEO finding), the plan needs: subscription state in Supabase (`family.subscription_tier`, `family.subscription_expires_at`), StoreKit 2 transaction listener on iOS that POSTs to an edge function on purchase/renewal/expiry, server-side receipt validation with Apple, RevenueCat as middleware optional. [HIGH]

- **E10. Input validation unspecified across edge functions.** Every edge function must validate: point amounts within sane bounds (−1000 ≤ x ≤ 1000, parent-tunable cap), reason string length (≤ 500 chars), photo size (≤ 5MB), MIME type (jpeg/heic only). Plan has none of this. Fix: shared Zod schema for every edge-function input. [HIGH]

- **E11. N+1 in approval queue list view.** Fetching 40 pending approvals with kid name, chore name, thumbnail URL, and completion time is trivially expressable as one JOIN but easy to write as 40 lookups. Fix: enforce a single edge-function query that joins and returns a denormalized payload; contract-test the row count on query. [MEDIUM]

- **E12. No CI/CD.** No GitHub Actions, no Xcode Cloud, no lint gate. Solo builder ships untested code to TestFlight. Fix: GitHub Actions workflow with (a) Swift build + test, (b) Supabase migration lint, (c) RLS test suite, (d) TestFlight build on `main` tag. [HIGH]

- **E13. App Attest / DeviceCheck for sensitive ops.** Redemption approvals, large fines, family delete — these mutate currency-like state. Apple's App Attest API attests a request came from your app on a real device, not a jailbroken client or a script. Plan has zero mention. Fix: require App Attest token on edge functions for (a) redemption approval, (b) fines > threshold, (c) family deletion. [MEDIUM]

- **E14. Realtime subscription scope too broad.** Plan §7.4 "server events drive updates" with no scoping. The iOS client likely subscribes to all changes in its family. Quieter default: per-screen scoped subscriptions (approval queue subscribes only to `RedemptionRequest` and `ChoreInstance` status changes). [MEDIUM]

### Eng Dual Voices — Consensus Table

```
═══════════════════════════════════════════════════════════════════
  Dimension                                   Claude  Subagent  Consensus
  ───────────────────────────────────────────  ──────  ────────  ─────────
  1. Architecture sound?                       MOSTLY  MOSTLY    CONFIRMED (Supabase OK)
  2. Test coverage sufficient?                 NO      NO        CONFIRMED (no tests)
  3. Performance risks addressed?              NO      NO        CONFIRMED
  4. Security threats covered?                 NO      NO        CONFIRMED
  5. Error paths handled?                      NO      NO        CONFIRMED
  6. Deployment risk manageable?               NO      NO        CONFIRMED (no migrations/CI)
═══════════════════════════════════════════════════════════════════
  Both voices agree: architecture choice is correct,
  execution details are production-hostile.
  6/6 dimensions flagged.
```

### Architecture (ASCII) — Component Map

```
┌───────────────────────────────────────────────────────────────────────┐
│                           iOS Clients                                  │
│  ┌──────────────┐ ┌──────────────┐ ┌────────────────────────────┐   │
│  │ Parent iPhone│ │  Kid iPhone  │ │  iPad (scaled iPhone, v0.1)│   │
│  │   (SwiftUI)  │ │   (SwiftUI)  │ │       (SwiftUI)             │   │
│  └──────┬───────┘ └──────┬───────┘ └─────────────┬──────────────┘   │
│         │                 │                       │                    │
│         └────────── ChoreQuestCore (Swift Pkg) ───┘                    │
│                     │                                                   │
│                     ├─ Repository layer (Observable)                    │
│                     ├─ SwiftData local cache                            │
│                     ├─ Offline write queue (retry + DLQ)                │
│                     └─ HTTPS + Supabase Realtime (WSS)                  │
└─────────────────────────────┬─────────────────────────────────────────┘
                              │
                     ┌────────┴────────┐
                     │  Supabase Edge  │     ← TypeScript (Deno)
                     │    Functions    │       idempotent, validated,
                     └────┬──────┬─────┘       App Attest for sensitive ops
                          │      │
                  ┌───────┘      └─────────┐
                  │                         │
          ┌───────▼────────┐      ┌─────────▼────────┐
          │  Postgres 15   │      │  Supabase Storage │
          │  + RLS         │      │  (private bucket, │
          │  + pg_cron     │      │   signed URLs)    │
          │  + triggers    │      │  + purge job      │
          └────────────────┘      └───────────────────┘
                  │
       ┌──────────┴───────────┐
       │  Append-only ledger  │
       │  Materialized streak │
       │  ChoreInstance state │
       │  AuditLog            │
       └──────────────────────┘

External:
  - APNs (push) ← driven by edge function DB triggers
  - Sign in with Apple (parent auth)
  - Sentry (iOS client crash reporting, PII-stripped)
  - App Store Connect / TestFlight (release)
```

### Test Plan (artifact)

Full test plan written to `TEST_PLAN.md` in this repo (see Phase 4 deliverables). Summary:

| Layer | Tool | Coverage target |
|---|---|---|
| iOS unit | Swift Testing | 70% of ChoreQuestCore |
| iOS UI snapshot | swift-snapshot-testing | All 3 tiers × key screens |
| Property-based | Swift Testing + fuzz | Ledger invariants |
| Edge function | Deno test | Each edge function, happy + error paths |
| RLS | Postgres test script in CI | All 12+ table×role combos |
| Contract | Supabase staging + Swift | Every client↔edge round-trip |
| A11y | XCUITest + Accessibility Audit | VoiceOver on kid + parent home |
| E2E smoke | XCUITest | One full family journey per TestFlight build |

### NOT in scope (engineering deferrals)

| Item | Why | Risk |
|---|---|---|
| Offline writes MVP | Deferred to v0.2 per CEO scope cut | Low — online-only is clearer UX |
| iPad command center | Deferred v1.5 per CEO scope cut | Low — scaled iPhone OK |
| Apple Watch | Post-v1 | Low |
| Real-money payments | Plan correct to defer | Zero |
| CloudKit photo-proof opt-in | Not worth the complexity | Low |
| Real-time collaborative editing | Not needed | Zero |

### What Already Exists (engineering)

- **Supabase CLI** — migrations, local dev, staging projects. Use it.
- **Swift Testing 6** — use over XCTest for new code (iOS 18+).
- **RevenueCat** — subscription infra if StoreKit 2 direct feels heavy.
- **Sentry Swift SDK** — crash reporting with PII scrubbing out of the box.
- **swift-log** — structured logging standard.

### Eng Completion Summary

| Dimension | Rating | Top concern |
|---|---|---|
| Architecture correctness | 7/10 | Mostly sound; RLS composition untested |
| Data model correctness | 5/10 | Missing constraints (idempotency, actor, cross-table) |
| Test infrastructure | 1/10 | Absent entirely |
| Security posture | 4/10 | RLS untested; no rate limit; no App Attest |
| Observability | 3/10 | Log retention insufficient; no structured job log |
| Deployment | 2/10 | No migrations, no staging, no CI |
| **Overall** | **4/10** | Strong conceptual model, production-hostile details |

**Auto-decisions logged in Phase 3:** 18 (see Decision Audit Trail).
**Taste decisions surfaced for gate:** 2 (Core Data vs SwiftData; monetization model).
**User challenges:** 1 (scope cut: offline sync out of MVP).

---

## Cross-Phase Themes

Concerns flagged independently in 2+ phases:

1. **"Plan is thoughtful but strategically/production-hostile"** — CEO + Eng both rated 4–5/10 overall with the same structural complaint: great concepts, missing execution discipline.

2. **"MVP scope is too wide for 8–10 weeks"** — CEO (timeline optimistic) + Eng (no CI, no tests, no staging, no migrations → easily +4 weeks). Both propose cuts.

3. **"User research / validation is absent"** — CEO (zero interviews) + Design (no prototype testing). Both gate v0.1 behind a validation pass.

4. **"The first 10 minutes and day 2 are undesigned"** — CEO (cold-start, first-session) + Design (onboarding gap). Single most consequential UX gap.

5. **"Age-tier differentiation is named but never specified"** — CEO (power vs median parent) + Design (Starter/Standard/Advanced UI differences absent). Structural gap.

6. **"Critical safety & privacy details handwaved"** — Design (photo capture UX) + Eng (photo URL patterns, retention, TTL, purge job). Both flag same underlying handwave.

7. **"Monetization architecture must be decided pre-code"** — CEO + Eng both require this; paywall state and RevenueCat wiring touch data model.

