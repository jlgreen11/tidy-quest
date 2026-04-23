# Chore Quest — Decision Log (/autoplan v0.1)

**Date:** 2026-04-22 | **Branch:** autoplan-v0 | **Plan v0 commit:** d34c0b4

This is the final-gate log for the /autoplan review. Per standing auto-accept preference, all recommended options were taken; each is surfaced below so it can be redirected.

---

## Review Scores

| Phase | Score | Voices | Consensus |
|---|---|---|---|
| CEO (strategy) | 5/10 | Subagent: 7 critical/high findings | 6/6 dimensions flagged |
| Design (UI) | 2.3/10 | Subagent: 7 critical/high; Claude primary: +7 additional | 13 dimensions, 4 confirmed critical |
| Eng (architecture) | 4/10 | Subagent: 6 critical/high; Claude primary: +14 | 6/6 dimensions flagged |
| DX | skipped | no dev-facing scope | N/A |

Codex voice unavailable (`codex` binary not installed on this host). Review proceeded `[subagent-only]` for all phases. If Codex is installed later, rerunning adds a second independent perspective.

---

## User Challenges (both voices recommend changing user's stated direction)

All three are accepted per auto-accept preference. Each can be reverted.

### UC1: ~~Cut the iPad command center from MVP and v0.2~~ — **REVERTED 2026-04-22**

**You said:** iPad command center is a key surface; ship "scaled iPhone" in v0.1, dedicated layout in v0.2.

**Both voices recommended:** Cut the dedicated iPad layout entirely through v1.0.

**Why the recommendation:** Mounted-iPad category is shallower than it looks; burns 4 weeks; widgets cover 80% of the need.

**User override:** Restore iPad command-center layout to v0.2. User has context we lacked (likely: own iPad mounted in kitchen, primary personal use case).

**Final decision:** **iPad dedicated command-center layout ships v0.2** per original plan. v0.1 remains scaled iPhone only. Design-review findings incorporated so the spec is production-grade: explicit type ladder (72/60/32/24pt), WCAG AAA contrast, ambient mode that hides balances after 10 min, wake/claim flow with per-kid PIN, simultaneous-use mode deferred to v1.5. See `PLAN_v0.1.md` §5.3.

---

### UC2: Choose monetization model before writing code

**You said:** Nothing. §7.9 = "$99/year Apple fee, free-tier Supabase." §12 mentions no business model.

**Both voices recommend:** Decide now. Recommended: free 14-day trial → $5.99/month or $39.99/year subscription. Architect paywall + RevenueCat (or StoreKit 2 direct) into data model from commit #1.

**Why:** App Store category, keywords, screenshots, and subscription entitlement sync are decisions that touch the data model. Retrofitting a paywall after launch typically means a migration and a feature-gating rewrite.

**Missing context:** You might intend this as a hobby / family-only app with no commercial aim. If so, model doesn't apply.

**If wrong, cost:** You over-engineer for a hobby; 2–3 weeks of paywall wiring wasted.

**Decision taken:** Commercial model — $5.99/mo or $39.99/yr with 14-day trial. Paywall architecture in MVP. See PLAN_v0.1.md §14.

---

### UC3: Cut offline writes from MVP

**You said:** §11 v0.1 includes "basic offline writes (chore completion only)."

**Both voices recommend:** Ship online-first v0.1. Offline writes move to v0.2. Conflict resolution on mutable ChoreInstance.status is not trivial (last-write-wins corrupts parent rejections).

**Why:** Offline sync is 1–2 weeks of code, a real retry/DLQ system, and a contract test suite. Not "basic." Ship a clean online error state first; learn whether kids actually complete chores offline (they mostly don't — morning routine is wifi-present).

**Missing context:** If your kids use the app primarily in a wifi-dead zone (basement, car, grandma's house), online-only is worse UX than we assume.

**If wrong, cost:** A family using the app offline sees "Can't connect. Retry?" for 2–6 weeks until v0.2.

**Decision taken:** Online-first MVP. Offline writes in v0.2. See PLAN_v0.1.md §11.

---

## Taste Decisions (reasonable people could disagree)

All 6 accepted with recommendation. Change any by editing PLAN_v0.1.md.

| # | Decision | Recommendation (taken) | Alternative |
|---|---|---|---|
| TD1 | Primary buyer persona | Power-parent with preset packs for median-parent | Full ADHD/executive-function pivot (Joon-adjacent) — higher willingness to pay but narrower market |
| TD2 | Default behavior-fine strictness | Missed chore = no award (soft); behavior fines opt-in, cap −50/day | Shipped strict: missed = −5 automatic |
| TD3 | iOS local storage | SwiftData (iOS 17+, matches Observable) | Core Data (more mature migrations) |
| TD4 | Tier palette | Starter = illustrated icons, Standard = SF Symbols colored, Advanced = SF Symbols mono | Custom illustration system for all tiers (costlier) |
| TD5 | Motion density default | "Standard" with automatic reduce-motion respect | Reduced by default; opt-in to confetti |
| TD6 | Siblings see each other's ledgers | Off by default (plan §13 open question confirmed) | Opt-in family transparency mode |

---

## Auto-Decisions (48 total — 6 principles applied)

Full list in REVIEW.md. Summary:

**Phase 1 (CEO) — 14 decisions:**
Scope-ins: first-run spec, day-2 push, auto-approve-under-threshold (MVP), earnings-band hard check (MVP), co-parent pre-approval rules (MVP), canned fine-reasons, App Store launch strategy, North Star metric (D30 family retention).
Scope-outs / changes: photo retention 7d (was 90d), preset packs mandatory MVP.

**Phase 2 (Design) — 11 decisions:**
Tabs 7→5, kid home hierarchy inverted (tile hero, balance in nav pill), all screen states spec'd, a11y section added (WCAG AA, VoiceOver, Dynamic Type, Reduce Motion, Dark Mode), onboarding / first-run spec added, notification rich UI with inline actions, settings IA → 8 sections, localization from day 1, color+icon pairing (colorblind safety), photo capture flow spec, widget design (3 sizes).

**Phase 3 (Eng) — 18 decisions:**
Redemption atomic in single tx, `UNIQUE(chore_instance_id) WHERE kind='chore_completion'` partial index, RLS test suite in CI, `created_by_user_id NOT NULL`, streak recompute trigger, daily reset `ON CONFLICT DO NOTHING`, explicit job chaining, Supabase CLI migrations, staging project, photo purge pg_cron, signed-URL photo access (TTL <5min), per-user rate limit on completions, 8+ char single-use pairing codes, same-family CHECK across FK joins, balance cache via triggered `cached_balance + as_of_txn_id`, AuditLog taxonomy enumerated, batch completion API, Swift Testing + property-based + snapshot + RLS tests, GitHub Actions CI, Zod input validation on edge functions, App Attest on sensitive ops, per-screen Realtime subscription scoping.

---

## Restore Point

Original plan preserved at:
- Git: commit `d34c0b4` on `main`
- File copy: `~/.gstack/projects/chorequestplan/autoplan-restore-20260422-200948.md`

To revert: `git checkout main && git branch -D autoplan-v0`.
