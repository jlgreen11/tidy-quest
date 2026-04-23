# Chore Quest

Family chore-gamification for iPhone and iPad — a ledger-based economy your family will actually sustain past month two.

**Status:** planning / pre-MVP. No code yet. Solo builder, evenings.
**Target:** v0.1 TestFlight to 2–3 friend families in 10–14 weeks.
**Last review:** 2026-04-22 via `/autoplan` (CEO + Design + Eng, dual voices).

---

## Contents

- [The problem](#the-problem)
- [What Chore Quest does](#what-chore-quest-does)
- [Core concepts](#core-concepts)
- [Platforms & surfaces](#platforms--surfaces)
- [Architecture](#architecture)
- [Data model](#data-model)
- [Economy design](#economy-design)
- [Approval model](#approval-model)
- [Security & privacy](#security--privacy)
- [User journeys](#user-journeys)
- [North Star & metrics](#north-star--metrics)
- [Monetization](#monetization)
- [MVP scope](#mvp-scope)
- [Testing strategy](#testing-strategy)
- [CI/CD & environments](#cicd--environments)
- [Competitive landscape](#competitive-landscape)
- [Open decisions](#open-decisions)
- [Docs index](#docs-index)
- [How this plan was reviewed](#how-this-plan-was-reviewed)

---

## The problem

"Getting kids to do chores" is the surface problem. The real problems are deeper:

1. **Nagging fatigue.** One parent becomes the enforcement engine; every interaction risks becoming transactional. The app moves enforcement from the parent into a system the kid relates to directly. Parent shifts from nagger to coach.

2. **Invisible labor.** Kids (and often co-parents) don't perceive how much work runs a household. Making work visible — listed, completed, valued — is educational regardless of gamification.

3. **Delayed gratification & ownership.** A points→rewards loop is scaffolded training in earning, saving, spending, losing. Done well: early executive-function training. Done badly: a Skinner box that trains kids to do nothing without a payout.

4. **Predictability & routine.** Especially for younger and neurodivergent kids, a morning that runs itself because the kid knows the four things to do is calmer than one held together by parental willpower.

5. **Cold-start (the real killer).** A family that abandons during the first 10 minutes of setup, or a kid that never opens the app on day two, kills any chore app regardless of feature depth. This is a first-class design concern of the plan.

## What Chore Quest does

At its core: **kids complete chores, earn points, spend them on rewards**. Around that core, the app adds:

- **Preset packs by age band** (5–7 Starter, 8–10 Standard, 11–14 Standard, Teen Cash-focused) so a family reaches their first completed chore in under 10 minutes rather than after 30 minutes of empty-spreadsheet configuration.
- **Economy tuning dashboard** (target weekly earnings band, inflation drift alerts at chore-creation time) so the points system doesn't drift into meaninglessness over weeks.
- **Co-parent-aware approval** with per-parent pre-approval rules so one parent's inattention doesn't churn the whole family.
- **Streaks, routines, quests, surprise multipliers** — bonus mechanics that reward *finishing*, not grazing.
- **Reward categories** covering screen time, treats, outings, privileges, cash-out (IOU), and saving goals (delayed-gratification UX).
- **COPPA-correct kid profiles** via device pairing — kids don't have accounts in the legal sense; the parent is the account holder.
- **iPad family command center** designed to be glanced at from 6 feet away in the kitchen, with wake/claim flow for multi-kid shared use.
- **Home-screen widgets** (3 sizes) so a kid can see today's chores without opening the app.
- **App Intents / Siri** so a 5-year-old can say "I fed the dog" and have the chore marked.

## Core concepts

**The ledger.** A user's point balance is never a mutable number — it is always `SUM(amount) over PointTransaction WHERE user_id = X`. Every earn, bonus, redemption, fine, and correction is an append-only row with a timestamp, actor, reason (required on negative), and reference to the originating object (chore instance, redemption request, etc.). This matters because "why did I lose 10 points on Tuesday?" has an auditable answer, and because parent mistakes become explicit reverse transactions instead of silent edits.

**ChoreTemplate vs ChoreInstance.** A template defines the chore ("make your bed," 5 pts, daily, no photo). An instance is the specific occurrence on a specific day for a specific kid. This split is essential for streaks, history, and fair accounting when a parent edits the template later.

**Derived + cached balance.** The balance is computed from transactions but cached on the user row with an `as_of_txn_id`. A trigger maintains the cache; if it ever drifts (shouldn't be possible, but safety), it rebuilds from transactions.

**Routines as first-class objects.** "Morning routine" isn't just a filter over chores — it's an object with a completion event that can trigger bonuses. Combo-bonus on routine completion is the most powerful engagement mechanic because it rewards finishing.

**Complexity tiers.** Starter / Standard / Advanced. Never labeled by age in UI (kids hate being told they're getting the baby version). Control typography, iconography, mechanic visibility, and reward categories available.

## Platforms & surfaces

| Surface | Role | Notes |
|---|---|---|
| Parent iPhone | Admin, approval, tuning | 5 tabs: Today, Approvals, Family, Economy, Settings |
| Kid iPhone | Consumer, completion, redemption | 5 tabs: Home, Rewards, Quests, Me (Ledger inside) |
| iPad — scaled iPhone | MVP fallback | Works but looks like iPhone, stretched |
| iPad — dedicated command center | v0.2 | 6-foot-legible kitchen dashboard with wake/claim + ambient mode |
| Home-screen widgets | MVP (kid), v0.2 (parent) | 3 sizes; silent APNs refresh on data change |
| Lock-screen widget | v0.2 | Kid balance + next chore |
| App Intents / Siri | v0.2 (completion), v1.0 (queries) | "I fed the dog" marks chore done |
| Live Activities | v1.0 | Quest progress in Dynamic Island |
| Apple Watch | post-v1.0 | Tappable tiles + balance |

## Architecture

```
┌────────────────────────────────────────────────────────────────┐
│                          iOS Clients                            │
│  Parent iPhone · Kid iPhone · iPad · Widgets · Watch (later)   │
│         │                                                       │
│         └── ChoreQuestCore (shared Swift package)              │
│             ├── Observable repository layer                     │
│             ├── SwiftData local cache                           │
│             └── HTTPS + Supabase Realtime (WSS)                │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                 ┌─────────┴─────────┐
                 │  Supabase Edge    │   TypeScript (Deno)
                 │   Functions       │   idempotent, Zod-validated,
                 └──┬────────────┬───┘   App Attest on sensitive ops
                    │            │
           ┌────────▼──┐    ┌────▼──────────────┐
           │ Postgres  │    │ Supabase Storage  │
           │ + RLS     │    │ (private bucket,  │
           │ + pg_cron │    │  signed URLs,     │
           │ + triggers│    │  7-day retention) │
           └────────┬──┘    └───────────────────┘
                    │
        ┌───────────┴───────────┐
        │ Append-only ledger    │
        │ Derived + cached bal. │
        │ ChoreInstance state   │
        │ AuditLog              │
        │ job_log               │
        └───────────────────────┘

External:
  APNs (rich push, action buttons on lock screen)
  Sign in with Apple (parent auth)
  App Attest (sensitive edge functions)
  StoreKit 2 (subscriptions)
  Sentry (iOS crash, PII-scrubbed)
```

### Stack

| Layer | Choice | Why |
|---|---|---|
| iOS / iPadOS | Swift + SwiftUI (Observable, iOS 17+) | Solo-builder velocity; TCA overkill for this scope |
| Local storage | SwiftData | Matches Observable; iOS 17+ target; simpler greenfield migration |
| Backend | Supabase | Postgres + Auth + Realtime + Storage + Edge Functions in one managed service |
| Edge functions | TypeScript / Deno | Supabase-native; shared Zod schemas |
| Auth — parents | Sign in with Apple | Cleanest on iOS; stable identity |
| Auth — kids | Device pairing (8+ char, 10-min TTL, single-use, revocable) | COPPA posture: parent is legal account holder; kids aren't accounts |
| Payments | StoreKit 2 direct | $5.99/mo or $39.99/yr; 14-day trial; RevenueCat reserved for v0.2 if growth warrants |
| Observability | Sentry (client, PII-scrubbed); `job_log` table (server) | Supabase log retention is 24h on free; we own our infinite-retention logs |
| CI | GitHub Actions | Swift build + tests, RLS test suite, migration lint |
| Migrations | Supabase CLI, versioned SQL | Non-negotiable before any non-self TestFlight user |

### Key architecture decisions & rationale

- **Supabase over Firebase.** Ledger semantics fit Postgres; NoSQL is a poor fit for append-only ledger invariants.
- **Supabase over self-hosted / Vapor / Node.** Productivity-per-hour wins for a solo builder. All of auth, DB, realtime, storage, and functions in one service.
- **Append-only PointTransaction table.** Balance derivation is the single most important invariant. Parent corrections are explicit reverse transactions, never silent edits.
- **Device pairing for kids, not accounts.** COPPA-clean; also better UX (small kids can't manage passwords).
- **Online-first MVP.** Offline sync with conflict resolution on mutable ChoreInstance state is 1–2 weeks of work and a real retry/DLQ system. Moved to v0.2.
- **RLS + test suite.** RLS policies silently return zero rows when denied, which is a data-leak failure mode. A parameterized SQL test suite runs on every PR — no merge without passing.
- **Realtime scoped per-screen.** Broader "all changes in my family" subscriptions don't scale; per-screen scoping reduces WebSocket churn.

## Data model

Key entities (full detail in `PLAN_v0.1.md` §6):

- **Family** — id, timezone (IANA), daily_reset_time, subscription_tier, subscription_expires_at.
- **User** — id, family_id, role (parent | child | caregiver), display_name, avatar, color, complexity_tier, apple_sub (parents), device_pairing_code (kids), cached_balance, cached_balance_as_of_txn_id.
- **ChoreTemplate** — name, type (one_off | daily | weekly | monthly | seasonal), schedule, base_points, cutoff_time, requires_photo, requires_approval, on_miss_policy (decay | skip | deduct).
- **ChoreInstance** — template_id, user_id, scheduled_for (family-local date), status (pending | completed | missed | approved | rejected), completed_at, approved_at, proof_photo_id, awarded_points. Same-family FK check enforced by trigger.
- **PointTransaction** — user_id, amount (signed, capped −1000..1000), kind, reference_id, reason (required on negative), created_by_user_id (NOT NULL; system sentinel for automated), idempotency_key (unique). Partial unique index on `(chore_instance_id) WHERE kind = 'chore_completion'` prevents double-credit.
- **Reward**, **RedemptionRequest**, **Routine**, **Streak** (materialized, recomputed on trigger), **Challenge**, **ApprovalRequest**, **Notification**, **AuditLog**, **Subscription**, **job_log**.

Key integrity rules:

- Every negative transaction has a reason.
- Chore completion → exactly one PointTransaction of kind `chore_completion` (partial unique index).
- `created_by_user_id` never null (sentinel `00000000-…` for automated).
- Same-family across FK joins enforced at DB level.
- PointTransaction UPDATE/DELETE rejected by trigger except through privileged reversal path.
- Redemption approval (insert PointTransaction + update RedemptionRequest) happens in a single Postgres transaction. No half-state possible on flaky networks.

## Economy design

The economy is the heart of the product; get it wrong and the rest doesn't matter.

**Chore types.** One-off, daily, weekly, monthly/seasonal, routine-bound. All supported in the data model from day 1; UI ships progressively.

**Point values.** Integers only (no floats — "13 points" feels real; "0.75 points" doesn't). Typical daily chores 5–50 pts, weekly items up to 200, big seasonal projects higher. Preset packs pre-fill sensible values; parents tune.

**Target weekly earnings band.** Each preset pack has a band. App flags live "expected weekly earnings" at chore creation, warning if the economy drifts outside the band. **This check fires at chore-creation time** — inflation drift happens in weeks, not a year, and catching it quarterly is too late.

**Bonus mechanics.**

| Mechanic | When | Ship |
|---|---|---|
| Streaks | N-day on chore or routine | MVP (basic); freezes v1.0 |
| First-of-day | First chore completed each day | v0.2 |
| Combo / routine completion | All chores in a named routine | v0.2 (most powerful engagement mechanic) |
| Surprise multipliers | Occasional 2×; 1–2/week cap, disable-able | v1.0 |
| Family goal bonuses | Whole family hits collective target | v1.0 |

**Negative mechanics** — the hard part.

- **Separate debits from fines.** Missed daily chore → no points awarded (absence of gain is deterrent enough). Behavior fines (hitting sibling, screen-time override) are a separate category with parent-configured amounts and required reason.
- **Default on-miss policy: decay silently** (not deduct). Parents can opt into deductions per chore.
- **Canned reason picker.** "Rude to sibling," "Didn't follow instruction," "Screen-time override," "Incomplete homework," "Other (free text)." Typing reasons 40 times turns them into "bad" — canned options preserve audit meaning.
- **Caps.** Default: −50/day and −150/week per kid. The app enforces this and surfaces it as a feature.
- **No push notifications for fines.** In-app bottom sheet only. Re-inflaming a kid on their lock screen is bad UX.

**Rewards.** Screen time, treats, outings, privileges, cash-out (IOU), saving goals. Each has a price, optional cooldown, optional auto-approve-under threshold. Parents can pre-approve categories so they don't get interrupted during work meetings.

**Saving goals.** Kid picks a big-ticket reward; points accumulate visibly with a progress ring. Points earmarked toward the goal are optionally spend-locked (visually separated from spendable balance) so impulse purchases don't erase weeks of saving. The single most valuable mechanic for teaching delayed gratification.

**Anti-abuse (designed into the economy, not bolted on).**

- Photo proof per-chore (gameable chores, not gameable kids).
- Per-user rate limit on chore completions (server-side, 20/60s).
- Random audit prompts — trust level decays audit frequency over time.
- Server-side uniqueness prevents double-completion.
- PIN on iPad for cross-kid attribution; AuditLog captures `completed_by_device` + `completed_as_user` separately.
- Device token revocable from parent app; pairing codes single-use with 10-min TTL.
- App Attest on sensitive operations (redemption approval, fines over threshold, family delete).

## Approval model

Per-chore configuration, one of three patterns:

1. **Honor system** (default). Kid marks done; it counts. Fast, zero-friction, good for most daily routine chores.
2. **Parent verification.** Kid marks done; parent gets notification; points awarded only on approval.
3. **Photo proof.** Kid marks done with required photo; parent sees thumbnail in approval queue before approving.

**Co-parent pre-approval rules** — each parent configures thresholds ("any screen-time reward under 30 min auto-approved"). If either parent pre-approved, the redemption auto-fires. Prevents the "one parent never approves → kid churns" trap.

**Auto-approve-under-threshold** — available from MVP (was v0.2 in v0). Low-stakes items auto-approve after N hours with parent notification. Stale approvals are a top-three cold-start killer.

## Security & privacy

The app handles children's data; the bar is higher.

- **Data minimization.** Kid profiles: display name, avatar, color, birthdate, optional photo. No email, no last name.
- **COPPA posture.** Parent is legal account holder; children are sub-profiles under parental control. No third-party analytics touch kid profiles, ever.
- **No third-party ad trackers.** No Facebook SDK, no AdMob, no Firebase Analytics.
- **Photo retention.** 7 days (down from v0's 90). Private Supabase bucket. Signed URLs with <5-min TTL. UUID-named objects (no guessable path patterns). Content reminder in kid UI before camera opens: "Only photos of what you did — no people, no faces."
- **Data export.** Settings → Export → full family JSON. COPPA right and trust signal.
- **Data deletion.** Family delete has 30-day recovery window then permanent. Child profile removal is immediate.
- **Encryption.** TLS in transit. Postgres at rest (Supabase default). Device tokens in iOS Keychain.
- **App Attest** on sensitive edge functions.
- **Rate limiting** per user on state-mutating endpoints.
- **Parental audit log** visible to parents in Settings → History.
- **RLS test suite in CI** — every table × role × op combination tested. No RLS change merges without passing.

## User journeys

Three representative vignettes (full set in `PLAN_v0.1.md` §4):

**Morning routine.** 7:12 AM, Tuesday. Maya (9) wakes. The iPad on the kitchen counter shows her morning routine: bed, dressed, teeth, breakfast dishes, lunchbox. Each is a big tile. She taps "bed." Tile flips to a checkmark with a +5 animation; balance pill ticks up. No push to the parent — daily routine defaults to honor system. If she completes all five by 8:00 AM, the routine bonus (+15) fires automatically.

**After-school photo-proof chore.** 3:45 PM. Theo (6) gets home. Three chores today. Dog-feeding requires photo proof (Theo has claimed to feed the dog six times without doing it). He takes the photo; tile shows "Waiting for mom" with a yellow clock. Rich push to mom with thumbnail: "Theo says he fed the dog — tap to verify." She approves from the lock screen without opening the app. Theo sees +10 ticker on balance.

**Fine + repair.** Theo hits his sister. Mom issues a −10 fine via her phone, canned reason "Rude to sibling." Theo's balance pill animates 1.5s countdown with red pulse (no push notification — pushing a fine to his lock screen would re-inflame). An in-app bottom sheet appears with a neutral balance-scale icon, the reason string in mom's words, the amount, and a "Talk to mom" button that creates an ApprovalRequest back to mom. Ledger shows a red left-border pill tagged "Fine." Tiles do NOT turn red. The mechanic is conversational, not punitive UI.

## North Star & metrics

**North Star: D30 family retention.** A family is retained on day 30 if any family member completed any chore in the past 7 days.

| Metric | v0.1 target | Public launch target |
|---|---|---|
| D30 family retention | 60% (3 of 5 pilot) | 40% |
| First-session onboarding completion | 80% | 80% |
| First-chore-within-24h | 70% | 70% |
| Kid-initiated sessions per week | median 4+ by week 3 | median 4+ by week 3 |
| Parent approval median latency (photo proof) | <6h | <4h |
| Inflation drift incidents per family per month | <1 | <1 |
| Trial → paid conversion | 25% | 40% |

Server-side instrumentation only. No client analytics on kid profiles. Aggregate per-family metrics in a `app_metric` Postgres table. Parents see their own family's streak-of-daily-use; no cross-family benchmarking.

## Monetization

**$5.99/month** OR **$39.99/year** (44% yearly savings). One subscription per family, covers all members and devices.

- **14-day free trial** on first family creation.
- **Paywall placement:** onboarding step 9 (soft gate, skippable); after trial expiry (blocking modal; read-only history access continues).
- **Implementation:** StoreKit 2 direct. Transaction listener posts receipts to edge function; server-side validation; writes `Subscription` row; updates `Family.subscription_tier` and `subscription_expires_at`.
- **Reminder push** 3 days before expiry (daily pg_cron job scans Families).
- **Restore purchases** in Settings → Account.
- **Feature gating in MVP:** none. All features enabled in trial. Gating may add tiers post-v1.0.

## MVP scope

**v0.1 (~10–14 weeks evenings):**

- Family creation, parent Sign in with Apple, kid profile, device pairing (rotatable, TTL'd).
- Subscription paywall + 14-day trial + StoreKit 2 + receipt validation.
- Chore templates: one-off, daily, weekly. ChoreInstance generation on daily reset (idempotent).
- PointTransaction ledger, partial unique index, cached balance with trigger, same-family CHECK.
- Rewards catalog, RedemptionRequest with atomic approval transaction.
- Co-parent pre-approval rules.
- Earnings-band hard check at chore creation.
- Preset packs (4 age bands).
- First-run onboarding spec (<10 min target).
- Day-2 re-engagement push.
- Parent app: 5 tabs (Today, Approvals, Family, Economy, Settings).
- Kid app: 5 tabs (Home, Rewards, Quests, Me w/ Ledger).
- iPad: scaled iPhone layout.
- Rich push notifications with inline actions.
- Basic streaks (current, longest; no freezes).
- Photo proof per chore (camera flow, 7-day retention, content reminder).
- Kid home-screen widget (3 sizes).
- Accessibility parity (WCAG AA, VoiceOver, Dynamic Type, Reduce Motion, Dark Mode).
- Localization infrastructure (English only ships).
- GitHub Actions CI: Swift build + test, RLS test suite, migration lint.
- Staging Supabase project + separate build scheme.
- Sentry (PII-scrubbed).

**v0.2 (+6–8 weeks):**

- **iPad dedicated command-center layout** (6-foot legibility, wake/claim, ambient mode, per-kid PIN).
- Offline writes with conflict resolution and dead-letter queue.
- Monthly / seasonal chore types (UI).
- Routines as first-class (combo bonus).
- Saving goals.
- App Intent for chore completion.
- Lock Screen widget + parent widget.

**v1.0 (+8–12 weeks):**

- Quests / challenges UI.
- Surprise multipliers, first-of-day, family pool.
- Streak freezes.
- Economy inflation-drift alerts (smart; not just band check).
- Live Activities.
- Audit log UI, data export UI.
- App Store launch.

**v1.5+:**

- Watch companion.
- iPad simultaneous-use mode (split-screen per kid).

## Testing strategy

Full matrix in `TEST_PLAN.md`. Summary:

| Layer | Tool | Coverage target |
|---|---|---|
| iOS unit | Swift Testing | ≥70% of `ChoreQuestCore`; 100% of economy logic |
| UI snapshot | swift-snapshot-testing | 3 tiers × 4 states on kid screens; 3 densities on parent queue; Light + Dark; Dynamic Type AX1 + AX5 |
| Property-based | Swift Testing + fuzz | 10 ledger invariants (balance identity, idempotency, monotonic streaks, actor NOT NULL, atomic redemption, reversal integrity, same-family FK, reason-required-on-negative, no double-payment, cache staleness) |
| Edge function | Deno test | Every endpoint × 5 cases (happy, idempotency replay, validation failure, rate limit, App Attest reject) |
| RLS | Postgres test script in CI | ~180 cases across roles × tables × ops |
| Contract | Swift + staging | Canned family journey nightly |
| A11y | XCUITest + Accessibility Audit | VoiceOver labels, Reduce Motion, Dynamic Type |
| E2E smoke | XCUITest | One full family journey per TestFlight build |

## CI/CD & environments

**Workflows (GitHub Actions):**

- `ci.yml` on every PR: Swift build + tests, Deno edge function tests, Supabase migration lint, RLS test suite.
- `deploy-staging.yml` on `main` merge: deploy edge functions + migrations to staging; run contract test.
- `testflight.yml` on `v*` tag: archive + upload to TestFlight.

**Environments:**

- `chore-quest-local` (ephemeral dev)
- `chore-quest-staging` (persistent; friend-family TestFlight connects here)
- `chore-quest-prod` (persistent; App Store builds connect here)

iOS build scheme selects backend URL via `Info.plist` build configuration; never from source.

## Competitive landscape

| App | Lane | Chore Quest's angle |
|---|---|---|
| SkyLight | Shared family calendar + stickers, dedicated wall device | Shallow economy; parent-centric; device-bound |
| OurHome | Free, clean, solid economy | Real competitor; must beat on preset-pack quality + economy-tuning depth |
| Joon | Clinical ADHD positioning; $9.99/mo | Higher willingness-to-pay; Chore Quest keeps ADHD pivot as an open option if v0.1 metrics justify |
| Greenlight / BusyKid | Real-money rewards + bank | Not our lane; compliance swamp; IOU-only in our plan |
| Cozi | Family coordination | Adjacent, not core |
| Homey | European, well-designed | Pattern reference |

**Durable moat.** Plan-as-written has no moat against an Apple "Family Chores" feature in iOS 26 (plausible given Family Sharing + Screen Time + Apple Cash). Primary defense: preset-pack quality + economy-tuning dashboard (power-parent moat). Secondary option preserved: pivot to ADHD/executive-function clinical lane if v0.1 metrics underperform.

## Open decisions

Three unresolved items that gate coding. See `PLAN_v0.1.md` §13:

1. **Kid specifics.** Count, ages, device ownership. Shapes preset-pack defaults and MVP priorities (a 5-year-old without a device needs iPad prioritized earlier).
2. **Apple Developer account.** Required for TestFlight and App Store. $99/year + a day of setup.
3. **Name.** "Chore Quest" is a placeholder. Decide before App Store submission — affects icon, marketing, ASO keywords.

## Docs index

| File | Lines | What |
|---|---|---|
| [PLAN_v0.1.md](PLAN_v0.1.md) | ~680 | Current plan (after /autoplan review) |
| [PLAN.md](PLAN.md) | 496 | Original v0 (preserved for comparison) |
| [REVIEW.md](REVIEW.md) | 483 | Full 3-phase audit (CEO + Design + Eng) |
| [DECISIONS.md](DECISIONS.md) | 111 | Auto-decisions, user challenges, taste decisions |
| [TEST_PLAN.md](TEST_PLAN.md) | 197 | Ledger invariants, RLS matrix, snapshot + E2E |

## How this plan was reviewed

On 2026-04-22, `/autoplan` ran three review phases with dual voices (Claude subagent primary; Codex unavailable on host → tagged `[subagent-only]`):

- **Phase 1 — CEO review** scored 5/10 overall. Seven findings: wrong buyer (power-parent bias); zero user research; iPad command center risk (reverted per user override); no competitive moat; timeline optimistic; no monetization (now fixed); cold-start blind spot (now fixed).
- **Phase 2 — Design review** scored 2.3/10. Thirteen findings: inverted kid-home hierarchy, missing states, age-tier UI underspecified, approvals queue placement, iPad ambient mode, a11y absence, onboarding absence, tab count violation, notification UI, settings IA, photo capture, widget design, localization.
- **Phase 3 — Eng review** scored 4/10. Seventeen findings: redemption atomicity, idempotency constraint, RLS test suite absence, nullable actor provenance, streak reconstruction, daily reset idempotency, rate limiting, photo URL patterns, offline conflict, Core Data/SwiftData equivocation, migration strategy, staging absence, photo purge missing, cost estimate wrong, DST handling, device token rotation.

**Outcomes:** 48 auto-decisions taken per 6-principle framework. 3 user challenges surfaced (iPad command center cut — **reverted**; monetization added; offline cut to v0.2). 6 taste decisions taken with recommendations (buyer persona, behavior-fine default, SwiftData over Core Data, tier palette, motion density, sibling ledger visibility).

Full audit trail in `REVIEW.md`. Decision log in `DECISIONS.md`.

## Contact

Private repo. Author: [@jlgreen11](https://github.com/jlgreen11).

---

_Last plan review: 2026-04-22 · Branch `autoplan-v0` → see PR #1._
