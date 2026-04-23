# Chore Quest

Family chore-gamification for iPhone and iPad — a ledger-based economy your family will actually sustain past month two.

**Status:** planning / pre-MVP. No code yet. Solo builder, evenings.
**Target:** v0.1 TestFlight to 2–3 friend families in 10–14 weeks.

---

## What it is

Most chore apps are checklists with stickers bolted on. Chore Quest is built around the part that actually matters: a **real economy** a family can tune and a kid can learn from.

- **Append-only points ledger.** Every transaction is visible, reasoned, reversible. Kids see why they earned or lost points; parents can audit.
- **Preset packs by age band** so a family reaches their first completed chore in under 10 minutes — not after 30 minutes of configuring an empty spreadsheet.
- **Parent as coach, not nag.** Approval queues, pre-approval rules per co-parent, auto-approve-under-threshold — designed to prevent the "one parent never approves" churn trap.
- **Economy that holds up.** Target weekly earnings bands, inflation drift alerts at chore-creation time, spending caps. The economy is tuned, not hoped at.
- **COPPA-correct.** Kids are device-paired, not account-holders. Parent is the legal account holder. No third-party analytics on kid profiles. Ever.

## Why a new one

The competitive set — OurHome, Cozi, Joon, Greenlight, BusyKid, SkyLight — each solves a slice. Chore Quest's bet: the durable differentiator is **economy design quality**, not another checklist UI. A ledger that treats points like the small currency they are, with the tuning tools a power-parent actually wants.

See [`PLAN_v0.1.md`](PLAN_v0.1.md) §1 for the full framing.

## North Star

**D30 family retention** — families where any member completes any chore within 7 days of day 30.

- v0.1 friend-family target: 60%
- Public launch target: 40%
- Secondary: onboarding completion 80%, first-chore-within-24h 70%, kid-initiated sessions ≥ 4/week by week 3.

## Stack

| Layer | Choice |
|---|---|
| iOS / iPadOS | Swift + SwiftUI (Observable, iOS 17+) |
| Local storage | SwiftData |
| Backend | Supabase (Postgres + Auth + Realtime + Storage + Edge Functions) |
| Edge functions | TypeScript / Deno |
| Auth — parents | Sign in with Apple |
| Auth — kids | Device pairing (COPPA posture) |
| Payments | StoreKit 2 direct ($5.99/mo or $39.99/yr, 14-day trial) |
| Observability | Sentry (iOS, PII-scrubbed), structured `job_log` in Postgres |
| CI | GitHub Actions |

## Docs

| File | What |
|---|---|
| [PLAN_v0.1.md](PLAN_v0.1.md) | **Current plan.** Product + architecture + scope. 636 lines. |
| [PLAN.md](PLAN.md) | Original v0. Preserved unchanged for comparison. |
| [REVIEW.md](REVIEW.md) | Full audit (CEO + Design + Eng), dual-voice critique. |
| [DECISIONS.md](DECISIONS.md) | 48 auto-decisions, 3 user challenges, 6 taste decisions. |
| [TEST_PLAN.md](TEST_PLAN.md) | Ledger invariants, RLS matrix, snapshot + E2E specs. |

## Roadmap

- **v0.1 (~10–14 weeks evenings):** core ledger, 5-tab parent + 5-tab kid apps, preset packs, first-run under 10 min, pre-approval rules, photo proof (7-day retention), widgets (3 sizes), full a11y, subscription + trial, RLS-tested, CI on GitHub Actions.
- **v0.2 (+6–8 weeks):** iPad dedicated command-center layout, offline writes with conflict resolution, monthly/seasonal chores, routines as first-class objects (combos), saving goals, App Intents.
- **v1.0 (+8–12 weeks):** quests UI, surprise multipliers, family pool, streak freezes, economy inflation dashboard, Live Activities, App Store launch.
- **v1.5+:** Watch companion, iPad simultaneous-use mode.

## Open decisions

See [`PLAN_v0.1.md`](PLAN_v0.1.md) §13. Three unresolved items that gate coding:

1. **Kid specifics** — count, ages, device ownership. Shapes preset-pack defaults and MVP priorities.
2. **Apple Developer account** — required for TestFlight; $99/year.
3. **Name** — "Chore Quest" is a placeholder. Decide before App Store submission.

## Contact

Private repo. Author: [@jlgreen11](https://github.com/jlgreen11).

---

_Plan last reviewed 2026-04-22 via /autoplan (CEO + Design + Eng, dual voices)._
