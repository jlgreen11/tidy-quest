# Chore Quest — Product & Technical Plan (v0.1)

A family chore-gamification app for iPhone and iPad with a shared backend. This is v0.1, revised after a full /autoplan pass (CEO + Design + Eng reviews with dual-voice critique). v0 lives at `PLAN.md` for comparison; the review and decisions are in `REVIEW.md` and `DECISIONS.md`.

The changes from v0 are concentrated in: strategic constraints (§0, new), cold-start / first-run (§4.0, new), accessibility (§5.4, new), tab architecture (§5.1, revised), data-model constraints (§6, expanded), backend details (§7, expanded), MVP scope (§11, rescoped), monetization (§14, new), metrics (§15, new), test infrastructure (§16, new), and release engineering (§17, new). The spine of the original plan — ledger-first architecture, device-pairing for kids, Supabase managed stack, SwiftUI on iOS — is unchanged and validated.

---

## 0. Strategic constraints (v0.1 additions)

Three strategic decisions are load-bearing for everything else. They were under-specified in v0 and are now pinned.

**0.1 Primary buyer: power-parent, with preset packs for median-parent.** The economy-design framing of this product serves a parent who will tune the ledger; that parent is the buyer. But median parents must complete onboarding in under 10 minutes, so preset packs by age-band (see §2.2) are mandatory in MVP and must feel like "it just works" out of the box. We are not pivoting to a full ADHD/executive-function positioning in v0.1 (though the design doesn't close that door; see §13).

**0.2 Monetization: $5.99/month or $39.99/year, 14-day free trial.** Paywall architecture is integrated from commit #1. See §14. Apple Developer account ($99/year) is required regardless.

**0.3 North Star metric: D30 family retention.** A family "retained" is any family with at least one chore completion on day 30. Secondary metrics: kid-initiated sessions per week, parent approval median latency, first-session completion rate. See §15. Every feature decision in v0.1 is justified against D30 retention.

---

## 1. Vision & problem framing

The surface problem is "getting kids to do chores." The real problems are several layers deeper.

**Nagging fatigue.** One parent holds the mental model and becomes the enforcement engine. A good app moves enforcement from the parent into a system the kid relates to directly. The parent shifts from nagger to coach.

**Invisible labor.** Kids (and many co-parents) don't perceive how much work runs a household. Making work visible is educational regardless of the gamification layer.

**Delayed gratification & ownership.** The "points → rewards" loop is scaffolded earning/saving/spending training. Done well, early executive-function training. Done badly, a Skinner box.

**Predictability and routine.** A morning that runs itself because the kid knows the four things to do is calmer than one held together by parental willpower.

**The cold-start problem (added in v0.1).** The first 10 minutes and the second day are where families die. A parent must invest setup time before any value; a kid has no history, streak, or balance on day one and needs an intrinsic reason to open on day two. Cold-start design is a first-class concern of this plan, not an afterthought.

**Competitive landscape (revised in v0.1).** SkyLight is one reference but not the only one. OurHome (free, large install base), Homey (European, well-designed), Joon (clinical ADHD positioning with $9.99/month willingness-to-pay), Greenlight/BusyKid/RoosterMoney (real-money rewards, bank relationships), Cozi (adjacent family coordination). Before any code, the builder runs through onboarding on OurHome, Joon, and one Greenlight-lane product, producing a 1-page competitive teardown.

**Primary persona.** Two-parent household with 1–4 kids aged 5 to 14. Siblings span the range. Under 5, parent operates the app for the kid. Over 14, teen mode or graceful age-out. Secondary: single-parent. Tertiary: co-parenting/split custody.

**Durable moat (revised).** The plan as written has no durable moat against OurHome or an Apple "Family Chores" iOS 26 feature. The two candidates for defensible positioning are: (a) preset-pack quality and economy-tuning dashboard (power-parent moat), (b) ADHD/executive-function lane (clinical moat, highest willingness-to-pay). v0.1 commits to (a) and leaves (b) open for a pivot if v0.1 metrics underperform (see §15).

---

## 2. Core mechanics

### 2.1 Chore types

Five shapes; all supported in the data model from day one:

- **One-off.** "Help Dad carry groceries in today." Ad-hoc; expires if not done.
- **Daily recurring.** "Make your bed." Resets at family-local reset time.
- **Weekly recurring.** "Take out trash on Tuesday." Day-of-week binding.
- **Monthly / seasonal.** "Rake leaves" or "deep-clean on the 1st." (Post-MVP UI.)
- **Routine-bound.** Chores that only exist as part of a named routine (morning, bedtime). Routines are first-class objects; "completed routine" is an event that can trigger bonuses.

A chore is a **ChoreTemplate**; a specific occurrence on a specific day is a **ChoreInstance**. This split is essential for streaks, history, and fair accounting when templates change.

### 2.2 Point values and preset packs

Each template has a base point value (integer, no floats). Preset packs ship with the app for age bands — "5–7 Starter," "8–10 Standard," "11–14 Standard," "Teen cash-focused" — each with ~15 prefilled chores at sensible values and a suggested reward catalog.

**Target weekly earnings band (MVP-required, was v1.0 in v0).** Each preset pack has a target weekly earnings band. As the parent adds or edits chores, the app surfaces live "expected weekly earnings" and flags when the economy drifts outside the band. The hard check fires at chore creation time, not quarterly. **Why promoted to MVP:** inflation drift happens in weeks, not a year.

Typical daily chores cap around 5–50 points; bigger weekly items up to 200; large seasonal projects higher. Parents can override.

### 2.3 Bonus mechanics

- **Streaks** (MVP: current length and longest; streak freezes in v1.0). N-day streaks on a specific chore or routine add multiplicative bonuses. Streaks cap; unbounded becomes stressful.
- **First-of-day** (v0.2). Small bonus for first chore completed each day.
- **Combo / routine completion** (v0.2). Completing a full named routine pays a bonus larger than the sum. The single most powerful engagement mechanic.
- **Surprise multipliers** (v1.0). Random low-frequency 2×. Cap at 1–2/week; parent-configurable or disable-able (some anxious kids find randomness destabilizing).
- **Family goal bonuses** (v1.0). Whole family hits a target, every kid gets a flat bonus.

### 2.4 Negative mechanics

Loss aversion is real but dangerous if applied carelessly. Three design choices make this work:

**Separate chore debits from behavior fines.** Missed daily chore → no points awarded (no deduction). Behavior fines (hitting sibling, screen-time override, rude) are a separate category with parent-configured amounts and required reason.

**Cap deductions.** Per-family floor, default: no more than −50/day and −150/week regardless of infractions. This is a feature, not a bug.

**Make deductions visible and recoverable.** Every deduction shows a reason string. Kids can earn "redemption bonuses" that offset recent fines. Transforms punishment into a repair loop.

**Default on-miss policy per chore: decay silently** (not deduct). Taste decision TD2 — parents who want strictness can opt into deductions per chore. See `DECISIONS.md` to change the default.

**Canned reason picker (new in v0.1).** Negative transactions require a reason, but typing "hit sister" 40 times over a year is both lossy (reasons become meaningless) and friction (parent stops issuing). Ship a canned-reason picker: "Rude to sibling," "Didn't follow instruction," "Screen-time override," "Incomplete homework," "Other (free text)." Audit log is preserved; parent fatigue reduced.

### 2.5 Reward store

Categories the parent populates:

- **Screen time.** "30 min tablet" = 75 pts. App tracks redemption; does not enforce iOS Screen Time (§12).
- **Treats and small items.** Ice cream, snack, toy.
- **Outings and experiences.** "Pick the restaurant," "Trip to bookstore with $15 budget."
- **Privileges.** "Stay up 30 min late," "Pick family movie."
- **Cash-out** (optional per family). 100 pts = $1 or whatever ratio. Tracked; not paid out by app.
- **Saving goal.** Kid picks big-ticket reward; points accumulate visibly.

**Pricing.** Parents set; app suggests starting prices based on weekly earnings target. Edits affect future redemptions only.

**Cooldowns.** Per-reward rate limits.

**Approval flow.** Redemption creates a **RedemptionRequest** in pending. Parent approves/denies; on approval, points are deducted and reward is marked redeemed — **atomically in a single Postgres transaction** (critical correctness fix from v0 review; see §7.2).

**Pre-approval rules (MVP-required, was v0.2 in v0).** Parent can configure: "Any screen-time reward under 30 minutes auto-approved, subject to cooldown." Granular per-category. **Why MVP:** stale approvals are a top-three cold-start killer.

**Reserved / "spend-locked" points.** Saving-goal points visually separated from spendable balance. Opt-in per kid.

### 2.6 Challenges and quests

Time-boxed bundles of related chores with a bonus payout. MVP ships simple quest data model; quest UI is v1.0.

### 2.7 Family-wide vs per-kid

- **Per-kid ledger** (default).
- **Per-kid leaderboard** (opt-in, off by default). Can poison sibling dynamics.
- **Family pool** (v1.0, opt-in). Collective points toward family rewards.

### 2.8 Age-appropriateness

Per-kid complexity tier controls:

- **Typography and icons.** Starter uses illustrated icons + SF Rounded 22pt+. Standard uses colored SF Symbols + SF Pro Rounded 17pt. Advanced uses mono SF Symbols + SF Pro Text 15pt. See §5.4.
- **Mechanic visibility.** Streaks/combos hidden in Starter.
- **Reward categories available.** Cash-out hidden for youngest; Screen Time hidden for oldest.
- **Photo-proof defaults.** Younger: fewer. Older: more.

Tiers are never labeled by age in UI. "Starter / Standard / Advanced."

---

## 3. User roles and permissions

MVP roles: Primary Parent (owner), Co-parent, Child. Post-MVP: Caregiver/grandparent, Observer.

**Approval model (per chore):** Honor system (default) / Parent verification / Photo proof. Periodic random audits (see §10).

**Co-parent pre-approval rules (MVP-required, new in v0.1).** Each parent sets their own pre-approval thresholds. If both parents have pre-approved a redemption category, it auto-fires; if only one has, the other still sees it as a fait-accompli notification. Prevents the "one parent never approves → kid churns" failure mode.

---

## 4. Key user journeys

### 4.0 First-run / onboarding (new in v0.1 — MVP-critical)

**Success criteria.** A first-time family completes onboarding in under 10 minutes and has one chore completed within 24 hours. These are the first two metrics tracked (see §15).

**Parent flow (target: ≤8 minutes):**

1. **Welcome + value prop** (30s). "Turn chores into a game your kids will actually play. Works for ages 5–14."
2. **Sign in with Apple** (15s). Creates Family record.
3. **Optional co-parent invite** (30s, skippable). "Invite your partner by phone or Apple ID."
4. **Add first kid** (60s). Name, age, avatar (parent picks from 24 illustrated options), color (palette: 8 colorblind-safe). Complexity tier inferred from age (Starter <8, Standard 8–11, Advanced 12+). Editable.
5. **Pair kid's device** (90s) OR **Skip and use iPad/this phone only** (15s). Pairing: show 8-digit code on parent's phone; kid enters on their device. Device gets a keychain token scoped to this kid profile. (Alternative: QR scan. Post-MVP.)
6. **Choose preset pack** (30s). Age-band pack recommended; parent can browse or customize later. Pre-fills 5 chores + 4 rewards.
7. **Review chores** (60s). Swipe to accept / remove / edit each. Points pre-set per pack.
8. **First reminder cadence** (15s). Morning push time (default 7:00 AM local); afternoon reminder (default 3:30 PM). Editable.
9. **Subscription gate** (60s). "Your free trial starts now — 14 days, then $5.99/month or save with yearly." Skippable to return later; paywall re-gates after day 14. See §14.
10. **You're done** (30s). "Here's your kid's first day. Ask them to open the app tonight — they'll see their morning chores."

Kid flow (after parent pair or shared device): 60-second tutorial. Tap a chore tile → tile animates, checkmark appears, balance ticks up. "That's it. Tomorrow you'll have new chores."

**Day-2 re-engagement (new in v0.1).** 24 hours after first completion, kid gets a push: "[Kid name], you earned 15 points yesterday! You have 3 chores today — tap to get started." Delivered at morning-reminder time, not the 24-hour mark exactly (kids don't want a 7:12 AM notification if their day starts at 7:30). **Why:** day-2 silence is the predictable churn point.

### 4.1 Morning routine (unchanged from v0)

Maya, 9, wakes 7:12 AM. iPad shows morning routine: bed, dressed, teeth, dishes, lunchbox. Big tiles. Taps "bed," tile animates, +5 badge floats up, balance in nav pill ticks up. Routine completion (all 5 by 8:00 AM) fires +15 bonus. No push to parent; honor system.

### 4.2 After-school chores (unchanged)

Theo, 6, opens iPhone app. 3 chores today. Dog-feeding requires photo proof (kid has gamed it). Takes photo, tile shows "Waiting for mom" yellow clock. Push to mom with photo thumbnail: "Theo says he fed the dog — tap to verify." Mom approves from lock screen.

### 4.3 Weekend quest (unchanged)

Saturday. Mom activates "Saturday reset" quest — 5 chores per kid, family bonus if done by 6 PM. Kids see quest card with progress ring. Parent sees aggregate progress on iPad.

### 4.4 Redemption (updated)

Maya has 420 points. Taps "Pick the restaurant" (100 pts). Creates RedemptionRequest. If parent pre-approved this category: auto-fires, point deduction and reward-marked-redeemed in the same Postgres transaction. Otherwise: request sits in parent approval queue; parent approves in 30 seconds.

### 4.5 Fine (updated)

Theo gets −10 fine, reason "Rude to sibling" (canned). Balance in nav pill animates 1.5s countdown with red pulse. In-app bottom sheet slides up (no push notification for fines — re-inflaming a kid is bad UX): neutral balance-scale icon, reason string in mom's words, amount, "Talk to mom" button creating an ApprovalRequest back to mom. Ledger entry has red left-border pill tagged "Fine" with reason inline. Tiles do NOT turn red. Balance stays visible. The mechanic is conversational, not punitive UI.

### 4.6 Parent adds chore on commute (updated)

Dad on iPhone. Tap +, choose "Daily recurring," name, pick target kid(s), days of week, point value (suggested: similar chores). Optional cutoff time, optional photo proof. **Economy-band check fires:** if this chore takes the target kid over weekly band by > 20%, Dad sees a gentle "This will push [Kid]'s weekly earnings above the 8–11 band." Option to accept (one-tap) or edit points. Under 60 seconds total.

### 4.7 New child added (updated)

Aunt moves in with 7-year-old for summer. Parent adds child: name, age, color, avatar, tier. Preset pack choice or copy-from-sibling. Starting balance default 0. Device pair or skip.

---

## 5. Information architecture and screens

Three experiences: parent iPhone (admin), kid iPhone (consumer), iPad (command center — "scaled iPhone" only in v0.1; see §11 scope cut). Shared SwiftUI codebase, SwiftData for offline cache (see §8 for iOS local storage decision TD3).

### 5.1 Parent app — 5 tabs (revised from 7 in v0)

iOS HIG caps tab bars at 5 before "More." v0's 7 tabs violated this. Revised architecture:

- **Today.** Default landing. Top 2–3 pending approvals inline. Today's activity across kids. Recent ledger events. Realtime updates.
- **Approvals.** Queue. Badge on tab icon. Group by kid. Batch "Approve all from X" action. Swipe-to-approve per item. Empty state: "All caught up."
- **Family.** Segmented control at top: Kids / Chores / Rewards. Was three separate tabs in v0. A power-parent spends time here during setup; day-to-day only briefly.
- **Economy.** Tuning dashboard: expected weekly earnings per kid, reward affordability analysis, streak participation, inflation drift alerts. **This is the killer feature for quantitatively-minded parents and the single best retention hook for the power-parent persona.**
- **Settings.** 8-section IA: Family (name, timezone, reset, quiet hours), Kids (roster + per-kid), Chore defaults, Reward defaults, Notifications (granular per role), Economy (band targets, caps), Privacy & Data (export, delete, retention), Account (sign-in, subscription, sign-out).

### 5.2 Kid app — 5 tabs

- **Home / Today.** Hero = first incomplete chore tile (60% of above-fold). Progress ring. Active quest ribbon below hero if active. Balance as a pill in nav bar (NOT a hero element — kid glances to answer "what do I do next," not "how rich am I"). See §5.4 for tile state spec.
- **Rewards.** Saving-goal card at top with animated progress ring. Affordable rewards full-color; unaffordable at 60% opacity with "X more points" badge. Tap to request.
- **Quests.** Current and upcoming.
- **Me.** Avatar, color, streaks, achievements. Ledger accessed as a subscreen of Me (Ledger as a top-level tab was over-promoted for a 7-year-old).

### 5.3 iPad

v0.1: scaled iPhone layout only. Dedicated command-center layout deferred past v1.0 (see §11 scope cut and DECISIONS.md UC1).

### 5.4 Accessibility, states, and micro-interactions (new in v0.1)

Was absent from v0. v0.1 promotes to first-class design constraints.

**Accessibility targets (required before v0.1 TestFlight):**

- WCAG AA contrast minimums for all text/background pairs.
- **VoiceOver** labels on every interactive element. Kid home screen tiles announce "[Chore name], [points] points, [status], tap to complete."
- **Dynamic Type** support on all text (supports up to `accessibility5`).
- **Reduce Motion** respected automatically (via `UIAccessibility.isReduceMotionEnabled`) — confetti and springs replaced with fades.
- **Dark Mode** at parity with Light.
- Color is never the sole discriminator; every color-coded element has a paired icon/shape.
- Minimum tap target: 60×60pt for Starter tier (iOS HIG minimum is 44pt).

**Required screen states (every screen):**

- Empty state (new family, no chores yet; no rewards yet; no approvals pending).
- Loading state (network slow, skeleton UI).
- Error state (network failed, permissions denied).
- Partial state (offline writes queued; photo uploading).
- Pending-approval state (kid-side chore tile: yellow clock icon, "Waiting for [parent]").

**Kid home tile micro-interaction (Standard tier):**

- Tap → immediate medium-impact haptic, 0.3s spring animation, tile flips to checkmark, "+5" number badge floats upward 40pt over 0.8s fading in, short success sound (< 0.5s).
- Double-tap on completed tile → soft error haptic, tile jiggles, tooltip "Already done!" — no double-credit.
- Routine completion → confetti burst + louder chime (once per routine per day).

**Starter tier differences:** balance shown as a jar-filling metaphor (not an integer), all icons illustrated (not SF Symbols), confetti more prominent, no streak visible, larger everything.

**Advanced tier differences:** mono SF Symbols, reduced animation, checkmark instead of confetti, progress bar instead of ring, full ledger visible from Me tab.

**Notification UI (rich):**

- Parent approval push: thumbnail (photo-proof chore), kid name, chore name, inline "Approve" and "View" action buttons usable from lock screen.
- Redemption request push: reward name, point cost, inline "Approve" / "Deny" actions.
- Kid day-2 push: no rich UI, simple opener.
- Fine (to parent, logging): silent — no push for fines; in-app record only.
- No push to the kid for fines ever (re-inflaming on lock screen is bad UX; see §4.5).

**Widget design (MVP, kid side):**

- Small widget: balance + single next chore title.
- Medium widget: balance + 3 chore tiles + progress ring.
- Large widget: full today panel with all incomplete chores.
- Refresh: silent APNs triggers `WidgetCenter.shared.reloadAllTimelines()` on data change, plus BGTaskScheduler every 30 min as fallback.

---

## 6. Data model

Entities, key fields, and invariants. Types conceptual. All IDs are UUID (v7 via Swift-generated or custom Postgres function; `gen_random_uuid()` is v4 and loses sort order — see §7 for the decision).

**Family.** id, name, timezone (IANA), daily_reset_time (wall-clock), settings JSON, subscription_tier, subscription_expires_at, created_at.

**User.** id, family_id, role (parent | child | caregiver), display_name, avatar, color, complexity_tier, birthdate (nullable; used for defaults, not identity), apple_sub (nullable; parent auth), device_pairing_code (kids), cached_balance, cached_balance_as_of_txn_id (see §6.1), created_at.

**ChoreTemplate.** id, family_id, name, icon, description, target_user_ids (array), type, schedule JSON, base_points, cutoff_time, requires_photo, requires_approval, on_miss_policy (default `decay`), on_miss_amount, active, created_at, archived_at.

**ChoreInstance.** id, template_id, user_id, scheduled_for (family-local calendar date), window_start, window_end, status (pending | completed | missed | approved | rejected), completed_at, approved_at, proof_photo_id, awarded_points, created_at. Same-family check: `user.family_id = template.family_id` enforced by trigger.

**PointTransaction.** id, user_id, family_id, amount (signed integer, bounded −1000 ≤ x ≤ 1000 per-tx), kind, reference_id, reason (required text for amount < 0), created_by_user_id (**NOT NULL**; system sentinel for automated), created_at, reversed_by_transaction_id, idempotency_key (client-generated UUID; unique).

**Reward.** id, family_id, name, icon, category, price, cooldown, auto_approve_under, active, created_at, archived_at.

**RedemptionRequest.** id, user_id, reward_id, requested_at, status, approved_by_user_id, approved_at, resulting_transaction_id, notes.

**Routine.** id, family_id, name, chore_template_ids (ordered), bonus_points, active_for_user_ids, time_window.

**Streak.** materialized; user_id, chore_template_id or routine_id, current_length, longest_length, last_completed_date, freezes_remaining. Recomputed on ChoreInstance status change via trigger (§7).

**Challenge / Quest.** id, family_id, name, description, start_at, end_at, participant_user_ids, constituent_chore_template_ids, bonus_points, status.

**ApprovalRequest.** generalization; can reference ChoreInstance, RedemptionRequest, or contested transaction.

**Notification.** id, user_id, kind, payload, sent_at, read_at.

**AuditLog.** id, family_id, actor_user_id, action (enum, see taxonomy below), target, payload, created_at.

**Subscription.** id, family_id, store_transaction_id, product_id, tier, purchased_at, expires_at, status (trial | active | grace | expired), receipt_hash.

### 6.1 Point balance: derived + cached, never mutable silently

Balance = `SUM(amount) over PointTransaction WHERE user_id = X`. Never a silent mutable field.

Cache strategy: `User.cached_balance` + `User.cached_balance_as_of_txn_id`. A trigger on `PointTransaction INSERT` updates the cache. On read, client checks that `as_of_txn_id` matches the latest transaction for that user; if divergent (should be impossible, but safety), cache rebuilds from transactions. Drift is logged to AuditLog.

### 6.2 Integrity constraints (required in initial migration)

- `PointTransaction`: partial unique index `(chore_instance_id) WHERE kind = 'chore_completion'`. Prevents double-credit on flaky retry.
- `PointTransaction`: client-generated `idempotency_key` UUID unique index. Edge function does `ON CONFLICT DO NOTHING`.
- `PointTransaction`: CHECK constraint: amount between −1000 and 1000.
- `PointTransaction`: CHECK constraint: amount >= 0 OR reason IS NOT NULL.
- `PointTransaction`: `created_by_user_id NOT NULL`. System-generated uses sentinel user `00000000-0000-0000-0000-000000000000`.
- `ChoreInstance`: BEFORE INSERT/UPDATE trigger verifying `template.family_id = user.family_id`.
- Every table with `family_id`: CHECK that FK references stay within family.
- PointTransaction table: rejects UPDATE and DELETE via trigger except through a privileged reversal path (logged).

### 6.3 AuditLog event taxonomy

Logged events: `family.create`, `family.delete`, `family.recovery`, `user.add`, `user.remove`, `user.role_change`, `point_transaction.large` (amount > 100 abs), `point_transaction.reversal`, `redemption.approve`, `redemption.deny`, `rls.deny`, `auth.failed`, `auth.device_pair`, `auth.device_revoke`, `subscription.state_change`, `photo.upload`, `photo.purge`.

---

## 7. Backend architecture

Supabase (Postgres + Auth + Realtime + Storage + Edge Functions). Managed services; TypeScript (Deno) edge functions; Postgres RLS for family-boundary authz. Rationale unchanged from v0: highest productivity-per-hour for a solo builder; portable if needed.

### 7.1 Migration strategy (new in v0.1)

Supabase CLI migrations, versioned SQL files in `/supabase/migrations`. Every schema change is a numbered file. CI runs migrations against the ephemeral test DB on every PR. Rollback via `supabase db reset` on staging. Production migrations require manual approval before `supabase db push`.

### 7.2 Edge function conventions

- **Idempotency:** every mutation endpoint accepts a client-generated `idempotency_key` header; edge function upserts with `ON CONFLICT DO NOTHING` and returns cached result on replay.
- **Atomic writes:** operations touching multiple rows use an explicit Postgres transaction block. Redemption approval does `BEGIN; INSERT PointTransaction; UPDATE RedemptionRequest; COMMIT` in a single `rpc` call.
- **Input validation:** shared Zod schemas per endpoint. Reject with 400 + structured error payload on invalid input.
- **Rate limiting:** Postgres-level per-user rate check in the completion endpoint. `SELECT count FROM point_transactions WHERE user_id = $1 AND created_at > now() - interval '60 seconds'` — reject with 429 if > 20.
- **App Attest:** sensitive operations (`redemption.approve`, `point_transaction.fine` over threshold, `family.delete`) require a valid Apple App Attest assertion in request header.

### 7.3 Auth

**Parents: Sign in with Apple.** Cleanest on iOS.

**Kids: device pairing, not accounts (unchanged from v0; COPPA-correct).** Revised detail: pairing codes are 8+ alphanumeric chars, cryptographically random, single-use, 10-minute TTL. Parent revokes per-device from Settings → Kids → [kid] → Devices.

### 7.4 Realtime / sync

Supabase Realtime (Postgres CDC over WebSocket) for in-app. APNs for out-of-app. Subscriptions are per-screen scoped (not family-wide) to reduce server load: approval queue subscribes to `RedemptionRequest` + `ChoreInstance` changes for its family; kid home subscribes to own user's `PointTransaction` and today's `ChoreInstance`.

Offline sync moved out of MVP (§11). Online-only v0.1. Graceful error states when offline.

### 7.5 Push notifications

APNs via edge functions triggered by DB events. Rich notifications with action buttons where applicable (approve, view). Quiet hours 9 PM–7 AM default, family-wide, override per high-priority event.

Defaults:
- Parent: pending approvals, redemption requests, end-of-day summary if chores incomplete, weekly economy digest (opt-in).
- Kid: morning routine reminder, afternoon reminder, new quest available, bonus awarded, day-2 re-engagement (§4.0). **Never** fine notifications.

### 7.6 Hosting

Supabase hosts all backend. Free tier accommodates a solo-family workload; paid tier ($25/month) warranted around **~50 families** (not "hundreds" — v0's cost estimate was wrong; see §7.9).

Photo storage: private bucket. Signed URLs, TTL < 5 minutes, regenerated on display. Object paths use UUIDs; no guessable patterns. **7-day retention** (revised down from v0's 90 days for privacy; see §9).

### 7.7 Background jobs

Four pg_cron jobs in explicit order:

- **Daily reset** (04:00 family-local, offset per timezone). Rolls yesterday's incomplete chores → missed; applies on_miss policies; generates today's ChoreInstances. Idempotent: `INSERT ... ON CONFLICT (template_id, user_id, scheduled_for) DO NOTHING`.
- **Streak maintenance** (04:05). Updates streak records; applies freezes. Gated on daily reset completion.
- **Challenge/quest lifecycle** (04:10). Activates, finalizes, expires.
- **Photo purge** (daily 03:00 UTC). Deletes storage objects where `ChoreInstance.completed_at < now() - interval '7 days'`.

Each job writes a row to `job_log` (Postgres table) with outcome, duration, error. Infinite-retention observability at zero cost; Supabase free tier log retention is 24h.

### 7.8 Observability

- **Sentry Swift SDK** client-side, PII scrubbed.
- **job_log** server-side.
- **AuditLog** for sensitive events (§6.3).
- **RLS deny logging:** middleware wrapper logs RLS denials as structured warnings (not silent zero-row returns).

### 7.9 Cost estimate (revised)

Single family: negligible, free tier fine. **~50 families: hits free-tier storage ceiling due to photo proofs.** 50 families × ~50 photos/month × 500KB × 7-day retention ≈ 200MB accumulation; still within free 1GB tier for first few months but past free tier inside a quarter.

Recommendation: upgrade to Supabase Pro ($25/mo) at ~30 families. Total cost at that inflection point: $99/year Apple + $25×12 = $399/year + Apple fee = $498 annual. At $5.99/month × 30 families = ~$2,160/year gross. Positive contribution margin from family #20 onward.

---

## 8. iOS / iPadOS client architecture

**Language/UI:** Swift, SwiftUI. UIKit bridging only where SwiftUI gaps remain (widgets, activity views).

**State management:** Observable (iOS 17+) with a thin repository layer. TCA explicitly declined for solo-builder velocity.

**Shared package:** `ChoreQuestCore` Swift package consumed by iPhone, iPad, Watch (post-v1), widget targets.

**Local storage: SwiftData** (not Core Data). Taste decision TD3. Rationale: iOS 17+ target, matches Observable, simpler migration for greenfield. Core Data kept in reserve if SwiftData migrations become a blocker.

**Offline:** v0.1 is online-only (see §11). Future offline support (v0.2+) will write-queue in SwiftData with explicit conflict resolution (conditional UPDATE with `WHERE status = expected_status`); a failed sync surfaces to the user as a dead-letter inspector in Settings, not silent drop.

**Widgets:** MVP kid home-screen widget (3 sizes). See §5.4.

**App Intents / Siri:** v0.2. Completion-only first; queries later.

**Live Activities:** v1.0. Quest progress in Dynamic Island / Lock Screen.

**Watch:** post-v1.0.

**StoreKit 2:** See §14.

---

## 9. Security and privacy

The app handles children's data; the bar is higher.

- **Data minimization.** Kid profiles: display_name, avatar, color, birthdate, optional photo. No email, no last name.
- **COPPA posture.** Parent is the legal account holder; children are sub-profiles under parental control. No third-party analytics on kid profiles.
- **No third-party ad trackers.** Ever.
- **Photo proofs.** 7-day retention (revised from 90 in v0). Private Supabase bucket. Signed URLs with <5-min TTL. UUID-named objects. Content reminder in kid UI: "Only photos of what you did — no people, no faces."
- **Data export.** Settings → Export. Full JSON of family.
- **Data deletion.** Parent can delete family; 30-day recovery window; then permanent. Child profile removal is immediate.
- **Encryption.** TLS in transit. Postgres at rest (Supabase default). Device tokens in iOS Keychain.
- **App Attest** on sensitive edge functions (§7.2).
- **Rate limiting** per-user (§7.2).
- **Parental audit.** AuditLog visible to parents in Settings → History.
- **RLS test suite** in CI (§16). No RLS change merges without passing tests.

---

## 10. Anti-abuse / anti-gaming

Unchanged from v0. Adds:

- **Rate limiting** (new in v0.1). Server rejects > 20 completions/60s per user.
- **App Attest** (new in v0.1). Script-based completion forgery blocked.
- **Device pairing code rotation** (new in v0.1). 10-min TTL; single use.
- **Photo content reminder** (new in v0.1). Kid UI displays guidance before camera opens.

---

## 11. MVP scope (revised)

v0 promised 8–10 weeks evenings. With adds (CI, tests, migrations, staging, onboarding spec, a11y) and cuts (offline, iPad command center, some mechanics), the revised target is **10–14 weeks evenings**. Honest; not compressed.

**v0.1 (TestFlight to self + 2–3 friend families, 10–14 weeks):**

- Family creation, parent Sign in with Apple, kid profile, device pairing (8+ char, TTL'd, rotatable).
- **Subscription paywall + 14-day trial + StoreKit 2 + receipt validation.** See §14. Gated in onboarding step 9.
- Chore templates: one-off, daily, weekly (skip monthly/seasonal UI).
- ChoreInstance generation on daily reset (idempotent).
- PointTransaction ledger, partial unique index, cached balance with trigger.
- Same-family CHECK across FK tables.
- Rewards catalog, RedemptionRequest with atomic approval transaction.
- **Co-parent pre-approval rules** (was v0.2 in v0).
- **Earnings-band hard check at chore creation** (was v1.0 in v0).
- **Preset packs, 4 age bands** (was implicit in v0; now mandatory).
- **First-run onboarding spec** (new; see §4.0).
- **Day-2 re-engagement push** (new; see §4.0).
- Parent app: 5 tabs (Today, Approvals, Family, Economy, Settings).
- Kid app: 5 tabs (Home, Rewards, Quests, Me w/ Ledger).
- iPad: scaled iPhone layout only.
- Rich push notifications with inline actions.
- Basic streaks (current, longest; no freezes).
- Photo proof per chore (including camera flow, 7-day retention, content reminder).
- Kid home-screen widget (3 sizes, WidgetKit + APNs refresh).
- Accessibility parity (WCAG AA, VoiceOver, Dynamic Type, Reduce Motion, Dark Mode).
- Localization infrastructure (strings extractable; English only ships; Spanish post-MVP).
- GitHub Actions CI: Swift build + test, RLS test suite, Supabase migration lint.
- Staging Supabase project + separate build scheme.
- Sentry client-side crash reporting (PII-scrubbed).
- **NO:** offline writes, iPad command-center layout, quests UI, combos, surprise multipliers, family pool, streak freezes, Watch, App Intents, saving goals (v0.2).

**v0.2 (+4–6 weeks):**

- Offline writes with conflict resolution and dead-letter queue.
- Monthly / seasonal chore types (UI).
- Routines as first-class (combo bonus).
- Saving goals.
- App Intent for chore completion.
- Lock Screen widget.
- Parent widget.
- Fine-level refinements based on v0.1 feedback.

**v1.0 (+8–12 weeks):**

- Quests/challenges UI.
- Surprise multipliers, first-of-day, family pool.
- Streak freezes.
- Economy inflation-drift alerts (smart; not just band check).
- Live Activities.
- Audit log UI.
- Data export UI.
- App Store launch (non-TestFlight).

**v1.5+:**

- Watch companion.
- Optional iPad dedicated command center layout (only if v1.0 data shows iPad is primary surface for > 30% of families).

---

## 12. Build vs buy

Unchanged from v0. Reaffirmed:

- Auth, DB, Realtime, Push, Storage: buy (Supabase).
- Ledger, chore scheduling, economy: build.
- Cash-out payments: defer. If ever built: Apple Pay to parent account or IOU-only.
- Screen Time enforcement: do not build.
- Analytics: skip MVP; Sentry only.

**New in v0.1:**

- **StoreKit 2: build.** Direct (not RevenueCat) for v0.1 simplicity. RevenueCat considered for v0.2 if subscription logic grows.
- **App Attest: buy** (Apple-native).

---

## 13. Open questions (closed in v0.1)

Most of v0's open questions are decided in DECISIONS.md. Still open:

- **Kids.** Specifics (how many, ages, device ownership) — user input needed before coding.
- **Apple Developer account.** User confirmation needed. ($99/year.)
- **Under-13 policy scope.** If any kid is over 13 and wants own Apple ID, data model needs a teen-mode variant. Defer.
- **ADHD pivot.** Left open. v0.1 metrics (D30 retention, parent satisfaction) may signal a pivot to clinical positioning. Reassess after 3 months of TestFlight data.
- **Name.** "Chore Quest" is still a placeholder. Decide before App Store submission.

---

## 14. Monetization architecture (new in v0.1)

$5.99/month OR $39.99/year (save 44%). 14-day free trial on first family creation. One subscription per family; covers all members and devices.

**Paywall placement:**
- Onboarding step 9 (soft gate; can skip).
- After trial expiry: blocking modal. Read-only access continues (family can see history) but writes are gated.

**Implementation:**
- StoreKit 2 direct. `Product.products(for: ["cq.monthly", "cq.yearly"])`.
- Transaction listener posts receipts to `POST /subscription/update` edge function.
- Edge function validates with Apple's verifyReceipt (or StoreKit 2 server-side signed receipts).
- Writes `Subscription` row; updates `Family.subscription_tier` and `subscription_expires_at`.
- Daily pg_cron job: scan Families with expiring subscriptions, send reminder push 3 days before expiry.

**Feature gating (MVP):** all features enabled in trial; no feature-gating by tier. Commercial features may add tiers post-v1.0.

**Restore purchases:** Settings → Account → Restore Purchases. Standard StoreKit 2 flow.

**App Store review considerations:**
- Subscription must be clearly disclosed pre-trial.
- Auto-renewal language in onboarding step 9 exactly matches Apple requirements.
- Privacy labels accurate; children's data properly declared.

---

## 15. Metrics & North Star (new in v0.1)

**North Star: D30 family retention.** A family is "retained" on day 30 if any family member completed any chore in the past 7 days as of day 30. Target for v0.1 friend-families: 60% (3 of 5 pilot families retained). Public launch target: 40%.

**Secondary metrics:**
- First-session completion rate (family completes onboarding flow): target 80%.
- First-chore-within-24h rate: target 70%.
- Kid-initiated sessions per week (kid opens app without parent prompt): target median 4+ by week 3.
- Parent approval median latency (photo-proof completion → approved): target < 6 hours.
- Inflation drift incidents per family per month: target < 1.
- Subscription conversion rate (trial → paid): target 25% for v0.1, 40% for v1.0.

**Instrumentation:**
- Server-side only; no client analytics on kid profiles.
- Stored in a parent-side `app_metric` Postgres table at aggregate (family-level) granularity.
- Parents see their own family's "your streak of daily use" but no cross-family benchmarking.
- Sentry captures crash/perf separately, PII-scrubbed.

---

## 16. Test infrastructure (new in v0.1)

v0 had no test plan. v0.1 requires a working test suite before TestFlight to any non-self user.

**iOS unit tests (Swift Testing 6+).** `ChoreQuestCore` package targets ≥70% coverage. Economy logic (balance computation, streak computation, on-miss policy application) at 100% coverage.

**Property-based tests (Swift Testing + fuzz).** Economy invariants:
- `balance(user) == sum(transactions for user)` always
- `all negative_transactions have non-empty reason`
- `no ChoreInstance has > 1 PointTransaction of kind chore_completion`
- `streak length is monotonic within an unbroken completion sequence`

**UI snapshot tests (swift-snapshot-testing).** Kid home screen × 3 tiers × 4 states (empty, partial, complete, error). Parent Today × 3 approval-queue densities (0, 5, 40). Every tier at Dynamic Type AX1 and AX5.

**Edge function tests (Deno test).** Each function: happy path, idempotency (double-submit returns same result), input validation rejection, rate-limit rejection, App Attest rejection (for sensitive endpoints).

**RLS test suite.** Parameterized SQL test: 12 roles × 15 tables × {select, insert, update, delete}. Runs against an ephemeral Supabase project in CI. No merge without passing.

**Contract tests.** iOS client generates a test family via edge function, runs a canned journey (add chore → kid completes → parent approves → kid redeems → parent approves), verifies end state in DB. Runs nightly against staging.

**A11y tests.** XCUITest + Accessibility Audit. Every interactive element has a VoiceOver label. Reduce Motion respected on every animated transition.

**E2E smoke.** One full family journey per TestFlight build via XCUITest. 5 minutes runtime.

---

## 17. Release engineering & CI/CD (new in v0.1)

**GitHub Actions workflows:**

- `ci.yml` on every PR: Swift build + tests, Deno edge function tests, Supabase migration lint (`supabase db lint`), RLS test suite.
- `deploy-staging.yml` on `main` merge: deploy edge functions and migrations to staging Supabase project; run contract test.
- `testflight.yml` on `v*` tag: Fastlane or xcodebuild archive + upload to TestFlight.

**Environments:**

- `chore-quest-local` (CLI, ephemeral dev).
- `chore-quest-staging` (persistent Supabase project; friend-family TestFlight connects here).
- `chore-quest-prod` (persistent Supabase project; App Store builds connect here).
- iOS build scheme selects the backend via `Info.plist` build configuration.

**Migrations:** Supabase CLI versioned SQL. Every PR that touches schema includes a migration. CI refuses merges that fail lint. Production migrations manually approved and applied via `supabase db push --linked`.

**Release cadence:** TestFlight build per-week during active dev; friend-family builds gated on smoke test pass. Public App Store launch at v1.0 earliest.

---

## Closing note

v0's architectural spine is sound. v0.1 tightens strategy (buyer, monetization, North Star), design (onboarding, a11y, states, tab count), and engineering (constraints, tests, CI, migrations, staging). The two hardest problems that v0.1 adds to the "hard-problems" list — alongside v0's "economy sustained beyond month two" — are:

1. **The first 10 minutes.** Everything else is downstream of a family that didn't abandon onboarding.
2. **Day 2.** A kid opening the app on day 2 without being asked is the moment that proves the mechanic.

If the builder solves those two, the economy-design advantage actually matters. If they don't, the ledger is the world's most beautifully-designed abandoned data structure.

Restore point: `git checkout main` to see v0. `REVIEW.md` for the full audit. `DECISIONS.md` for the gate log.
