# Chore Quest — Product & Technical Plan (v0)

A working planning document for a family chore-gamification app on iPhone and iPad with a shared backend. Written as if a senior PM and a staff engineer sat down together for an afternoon and wrote down what they believe. Some of this is opinion; the last section lists decisions that still need input.

---

## 1. Vision & problem framing

The surface problem is "getting kids to do chores." The real problems are several layers deeper, and naming them properly is the difference between building another checklist app and building something that actually changes family life.

The first real problem is **nagging fatigue**. In most families, one parent ends up holding the mental model of what needs doing, by whom, and whether it was done — and then has to ask, remind, re-ask, and enforce. The cognitive load of *being the enforcement engine* is exhausting in a way that is easy to underestimate, and it poisons the parent-child relationship because every interaction risks becoming transactional. A good app moves the enforcement function from the parent into a system that the kid relates to directly. The parent's role shifts from nagger to coach.

The second real problem is **invisible labor**. Kids (and frankly, many co-parents) genuinely do not perceive how much work runs a household. Making work visible — chores listed, completed, valued — is educational in itself, regardless of the gamification layer.

The third real problem is **teaching delayed gratification and ownership**. The "points → rewards" loop is a scaffolded experience of earning, saving, spending, and sometimes losing. Done well, it is an early, low-stakes training ground for executive function and basic economics. Done badly, it is a Skinner box that trains kids to do nothing without a payout.

The fourth real problem is **predictability and routine**. Kids, especially younger ones and neurodivergent ones, thrive on visible routine. A morning that runs itself because the kid knows the four things to do and what they add up to is calmer than a morning held together by parental willpower.

SkyLight Calendar is a useful reference point but a shallow one. SkyLight is, at its core, a shared family calendar with chore checkboxes bolted on and a modest sticker/reward affordance. It has three limitations that this product should directly address:

- **Shallow economy.** Points (or "stickers") are effectively cosmetic; there is no real ledger, no configurable reward store, no way to model that a Lego set costs 800 points and a family movie night costs 200.
- **Weak customization.** Chore values, schedules, and reward definitions are limited. There's no concept of streaks, combos, seasonal chores, or challenges.
- **Device-bound and parent-centric.** SkyLight is a wall device. Kids can't interact with it from wherever they are, parents can't tune the economy from the couch, and there's no real kid-facing mobile experience. The iPhone/iPad combination changes this: the iPad becomes an optional family command center mounted in the kitchen; the iPhone is the kid's agent and the parent's admin console.

Being honest about what is actually novel: the chore-tracking piece is table stakes. Many apps do it. What is genuinely differentiated is the *economy design* — a real ledger, configurable pricing, compound mechanics (streaks, combos, quests), negative-point mechanics that don't destroy engagement, and a parent tuning console that treats this as the small economy it actually is. Everything else (push notifications, widgets, kid-friendly UI) is execution quality, which matters enormously but is not conceptually novel.

**Audience.** Primary persona is a parent in a two-parent household with 1–4 kids aged roughly 5 to 14. The app should gracefully span that age range because siblings span it. Under 5, kids can't really self-serve the app and the parent operates it for them. Over 14 or so, the gamification framing starts to feel infantilizing and the app should either offer a "teen mode" (more utilitarian, cash-focused) or gracefully let the kid age out. Secondary persona is a single-parent household. Tertiary is a co-parenting / split-custody household, which is an important edge case because it introduces a second parent account that doesn't live with the first.

---

## 2. Core mechanics

The points economy is the heart of the product. Get this wrong and the rest doesn't matter. This section is long on purpose.

### 2.1 Chore types

Chores come in five shapes, and the data model needs to handle all of them from day one, even if the UI ships them progressively:

- **One-off.** "Help Dad carry groceries in today." Created ad-hoc, expires if not done, cannot recur.
- **Daily recurring.** "Make your bed." Lives on a daily schedule with an optional cutoff time. Resets at a family-local reset time (see §7.7).
- **Weekly recurring.** "Take out trash on Tuesday." Has a day-of-week binding and a window.
- **Monthly / seasonal.** "Help rake leaves" or "Clean room deep-clean on the 1st." Needed for realism.
- **Routine-bound.** Chores that only exist as part of a named routine (e.g., morning routine, bedtime routine). Routines are not just a UI grouping; they are first-class so that "completed morning routine" is itself an event that can trigger bonuses.

A chore is defined by a **ChoreTemplate**; a specific occurrence of it on a specific day is a **ChoreInstance**. This split is essential for streaks, history, and fair accounting when a parent edits the template later.

### 2.2 Point values and how parents tune them

Each chore template has a base point value. Parents need to be able to set these easily, but most parents will not have good intuition for what numbers to pick. The app should ship with **preset packs** by age band ("5–7 starter", "8–10 standard", "11–14 standard", "teen cash-focused") that prefill sensible values and a suggested reward catalog. Parents can then tune.

The economy should have a **target weekly earnings band** per kid, configurable — e.g., "in a typical week an 8-year-old should earn roughly 300–500 points if they do most of their chores." The app should show a live "expected weekly earnings" estimate as parents add/edit chores, so they notice when they're accidentally making the economy too tight or too generous. This is a small feature with outsized value; it's the difference between an economy that works and one the family abandons after two weeks.

Point values should be **integers**, not floats. "13 points" feels like a real thing; "0.75 points" does not. I'd cap typical daily chores around 5–50 points and bigger weekly things up to 200, with big seasonal projects going higher. Parents can override.

### 2.3 Bonus mechanics

Bonuses are the thing that makes a points system feel alive rather than like payroll. Ship these progressively; not all are MVP.

- **Streaks.** N-day streaks on a specific chore or a routine produce multiplicative or additive bonuses. Important: streak-breaking should have a "freeze" mechanic (one free miss per week, or a consumable "streak freeze" kids can buy from the reward store) to avoid the death-spiral where one sick day destroys two months of progress and the kid disengages. Streaks should also cap; an unbounded streak becomes stressful.
- **First-of-day.** Small bonus for the first chore completed each day, to pull kids into the morning routine.
- **Combo / routine completion.** Completing all chores in a named routine pays a bonus larger than the sum of parts. This is the single most powerful engagement mechanic because it rewards *finishing* rather than grazing.
- **Surprise multipliers.** Occasional, random, low-frequency ("today, making your bed pays 2×"). Variable rewards are psychologically potent but easy to overdo; cap them to once or twice a week and make them parent-configurable or disable-able per family, because some kids (especially anxious ones) find randomness destabilizing rather than fun.
- **Family goal bonuses.** If the whole family hits a collective target, every kid gets a flat bonus. Encourages cooperation.

### 2.4 Negative mechanics — the hard part

This is where most chore apps either go too soft ("never deduct, it'll discourage them!") or too hard ("fines for everything, welcome to debt at age 7"). Both are wrong.

Loss aversion is real: losing 10 points feels roughly twice as bad as gaining 10. That is useful for changing behavior but dangerous if applied carelessly. A kid who ends the day at -20 for a single bad behavior will not engage tomorrow. Three design choices make negative mechanics work:

**Separate "chore debits" from "behavior fines."** A missed daily chore can simply *fail to award* the points rather than deducting; the absence of gain is itself a deterrent without the emotional sting. Behavior fines (hitting a sibling, screen-time override, being rude) are a separate, explicit category, with parent-configured amounts, always logged with a reason.

**Cap how negative a balance can go per day and per week.** The app enforces a floor — e.g., no more than -50 points in a single day regardless of infractions — and surfaces this as a feature, not a bug. The goal is behavior change, not financial ruin.

**Make deductions visible and recoverable.** Every deduction shows a reason string written by the parent. Kids can earn "redemption bonuses" — a specific chore or behavior that offsets a recent fine. This transforms the mechanic from punishment into a repair loop, which is the emotionally healthier framing and also, not coincidentally, better behavioral science.

One more pattern worth considering: **missed-chore decay instead of deduction.** A chore that goes uncompleted for N days might just disappear from the list and not award anything — rather than charge a penalty. This is gentler and works well for younger kids. The app should let parents pick per-chore-type: "miss this" → award nothing / deduct X / decay silently.

### 2.5 Reward store

Rewards are the other half of the economy and deserve as much thought as chores.

Reward **categories** the parent can populate:

- **Screen time.** "30 minutes of tablet" = 75 points. The app tracks redemption but does not actually enforce the iOS screen-time limit; that lives in parental controls. (Discussion of whether to integrate with Screen Time API in §12.)
- **Treats and small items.** Ice cream, a specific snack, a small toy.
- **Outings and experiences.** "Pick the restaurant this weekend," "Trip to bookstore with $15 budget."
- **Privileges.** "Stay up 30 minutes late," "Pick the family movie," "Sit in the front seat."
- **Cash-out.** 100 points = $1, or whatever ratio the parent sets. Optional; see §12 on whether real payments are involved.
- **Saving goal.** Kid picks a big-ticket reward (a Lego set, a gaming accessory) and points accumulate visibly toward it. The UI shows a progress bar. This is arguably the single most valuable mechanic for teaching delayed gratification.

**Pricing.** Parents set prices; the app suggests starting prices based on the weekly earnings target (e.g., "a daily treat should cost ~15% of a typical day's earnings"). Prices can be edited anytime; edits only affect future redemptions.

**Cooldowns.** Some rewards need rate limits — "screen time bonus" once per day, not six times. Cooldowns are a property of the reward template.

**Approval flow.** When a kid requests a reward redemption, it creates a **RedemptionRequest** in "pending" state, which notifies the parent, who approves or denies. On approval, points are deducted and the reward is marked redeemed. A parent can also pre-approve categories ("any screen time reward under 30 minutes is auto-approved, subject to cooldown") — this matters a lot for a parent who doesn't want to be interrupted by five push notifications during a work meeting.

**Reserve / "spend-locked" points.** When a kid has a saving goal, points earmarked toward it should be visually separated from spendable points, so impulse purchases don't erase weeks of saving. This should be opt-in per kid.

### 2.6 Challenges and quests

A challenge is a time-boxed bundle of related chores with a bonus payout for completing all of them. Examples:

- **Weekend deep-clean quest.** Five chores; finish all by Sunday 8pm for a +100 bonus.
- **Spring cleaning.** A multi-week slow quest with interim milestones.
- **No-screens-before-noon week.** A behavior quest rather than a chore quest.

Quests are first-class objects with a start date, end date, member list (which kids are participating), constituent chores or behaviors, and a bonus payout. They can be solo or family-wide. Family-wide quests where kids cooperate toward a shared reward are particularly good for sibling dynamics because they replace competition with collaboration.

### 2.7 Family-wide vs per-kid mechanics

Points are per-kid. But the app needs both competitive and cooperative modes:

- **Per-kid leaderboard** (opt-in). Some kids love it, some hate it; some sibling dynamics get poisoned by it. Off by default.
- **Family pool** (opt-in). A separate points pool the family earns into collectively — perhaps a share of every chore completion goes to the family pool — which can be spent on family rewards (a movie night, a trip to get ice cream).
- **Per-kid independent economies.** This is the default: each kid's ledger is their own.

### 2.8 Age-appropriateness

A 6-year-old and a 13-year-old should not use the same interface. Per-kid settings control:

- **Complexity tier.** Simple (big buttons, bright icons, voice prompts for non-readers) vs standard vs teen (utility-focused, more text, cash-focused rewards).
- **Mechanic visibility.** Streaks and combos may be confusing for a 5-year-old; hide them.
- **Reward categories available.** Cash-out hidden for the youngest; screen-time maybe hidden for the oldest.
- **Photo-proof requirement.** Younger kids need less; older kids may need more because they're better at gaming the system (see §10).

A subtle point: the app should not label these tiers by age visibly. Call them "Starter / Standard / Advanced." Kids of any age dislike being told they're getting the baby version.

---

## 3. User roles and permissions

Five roles, with the caveat that the MVP should ship with only the first three.

- **Primary parent (owner).** Creates the family, full admin. Can do everything.
- **Co-parent.** Equal permissions to owner, except cannot delete the family or remove the owner. In practice the two are indistinguishable day-to-day.
- **Child.** Can see own chores, mark them complete, request redemptions, see own ledger, see own saving goal, see family-wide challenges they're part of. Cannot see other kids' ledgers by default (a setting parents can flip). Cannot edit chores, prices, or point values. Cannot self-approve redemptions.
- **Caregiver / grandparent (post-MVP).** Read-only plus the ability to mark specific chores complete or give behavior bonuses/fines. Cannot change the economy or approve redemptions unless granted.
- **Observer (post-MVP).** Pure read-only, e.g., a grandparent who just wants to see progress.

**Approval model.** Three patterns the family can choose between per chore:

- **Honor system.** Kid marks done; it counts.
- **Parent verification.** Kid marks done; parent gets a notification and approves/rejects. Points awarded only on approval.
- **Photo proof.** Kid marks done with a required photo; parent sees thumbnail in approval queue.

Default is honor system, with periodic random audits (see §10) and specific high-value chores (deep clean) set to photo-proof.

---

## 4. Key user journeys

Journeys are where a product's design decisions reveal themselves. These are realistic vignettes, each picked to pressure-test a specific decision.

**Morning routine.** 7:12 AM, Tuesday. Maya (age 9) wakes up. The iPad on the kitchen counter shows her morning routine: bed, dressed, teeth, breakfast dishes in sink, lunchbox packed. Each is tappable as a big tile. She taps "bed" and the tile flips to a checkmark with a +5 animation. Under the hood this creates a PointTransaction and a ChoreInstance completion. No push to the parent; daily routine chores default to honor system. If she completes all five by 8:00 AM, the routine bonus (+15) fires automatically. The key design decision here: low friction, no parent in the loop for ordinary things.

**After-school chores.** 3:45 PM. Maya's little brother Theo (age 6) gets home and opens his iPhone app. Three chores for today: feed dog, put backpack away, one piece of homework. The dog-feeding tile has a photo-proof requirement (because Theo has claimed to feed the dog six times without doing it). He takes the photo, it uploads, the request goes into his mom's approval queue. Push to mom: "Theo says he fed the dog — tap to verify." The design decision: photo proof is per-chore, not per-kid, because it's specific chores that are gameable.

**Weekend deep-clean quest.** Saturday morning. Mom activates the "Saturday reset" quest — a pre-built bundle of five chores for each kid, with a family bonus if all are done by 6 PM. Kids see a quest card on their home screen with a progress ring. As chores are completed, the ring fills. The parent sees an aggregate family progress view on the iPad. Design decision: quests are visible as a distinct UI element, not just as chores with a bonus tag, because the framing matters.

**Kid wants to spend points.** Maya has 420 points and wants to spend 100 on "pick the restaurant." She taps the reward, confirms, a RedemptionRequest goes to her parent. Parent approves from their phone in 30 seconds. Maya's balance ticks down. Design decision: requests, not auto-spends, for anything non-cooldown-exempt. Pre-approval rules exist for parents who don't want interruptions.

**Kid lost points and is upset.** Theo got a -10 fine for hitting his sister. His balance ticks down on his screen with a reason string ("hitting is not okay — mom"). He opens the ledger view and sees the deduction, timestamped, with the reason. He's upset. The parent and kid can look at the ledger together; the transparency of the deduction (with a specific reason) is both healthier emotionally and helpful conversationally. Design decision: every deduction is a first-class transaction with a required reason field. Never a silent subtraction. A "contest this" button creates an ApprovalRequest going back to the parent, which parents can ignore or act on. The kid having a channel matters.

**Parent sets up a new chore.** Dad, on his iPhone during a commute, wants to add "empty the dishwasher" for the older kid. Flow: tap +, choose "Daily recurring," name, pick target kid(s), pick days of week, pick point value (with a suggested value based on similar chores), optional cutoff time, optional photo requirement, done. Under 60 seconds. Design decision: chore creation must be ruthlessly fast because parents will abandon the app otherwise. Bulk import from a preset pack handles the initial setup.

**New child added.** Aunt moves in with her 7-year-old nephew for the summer. Parent adds a child: name, age, color, avatar, complexity tier. Choose whether to start from a preset or copy chores from another kid. Choose starting point balance (0 is default; some families want a starting grubstake). Pair the kid's device or generate a kid login PIN. Design decision: a new-kid flow shouldn't require a new Apple ID or email for the kid — see §7.3 on auth for under-13s.

---

## 5. Information architecture and screens

There are effectively three experiences: the parent experience (iPhone admin), the kid experience (iPhone consumer), and the iPad family-command-center view. They share a codebase and most of the data model, but the UIs are different surfaces.

### 5.1 Parent app (iPhone)

- **Today.** What's happening today across all kids. Completion state, pending approvals, recent ledger events. The default landing screen for parents. Pull-to-refresh, but also realtime updates.
- **Approvals.** A queue of things awaiting parent action: chore completions flagged for review, redemption requests, kid-initiated contests. Should be a badge-bearing tab; the number of pending items is what a parent glances at six times a day.
- **Kids.** One card per kid with balance, today's progress, recent activity. Drill in for the kid's full ledger, edit kid settings, see streaks.
- **Chores.** Master list of chore templates. Filter by kid, by type. Bulk edit. This is where a power-parent spends time during setup.
- **Rewards.** Reward catalog. Same pattern.
- **Economy.** The tuning dashboard: expected weekly earnings per kid, reward affordability analysis, streak participation. This is the killer feature for quantitatively-minded parents and is skippable for others.
- **Settings.** Family settings, reset time, notification preferences, co-parent invite, data export.

### 5.2 Kid app (iPhone)

- **Home / Today.** Big tiles for today's chores, with completion state. Balance at the top. Active quest ribbon if one is running. Should be navigable by a non-strong-reader — icons + single words. This is the hardest UX problem in the app.
- **Rewards.** Browse the catalog, filtered to what's affordable, with a "saving goal" section up top. Tap to request.
- **Ledger.** Paginated transaction history with reason strings. Younger kids may never open this; older kids will scrutinize it.
- **Quests.** Current and upcoming.
- **Me.** Avatar, color, streaks, achievements. Cosmetic but motivating.

The hardest UX problem is the kid home screen for a non-reader. The pattern I'd ship: every chore tile has an icon (parent picks from a library), a one-word label, a point value badge, and a completion state. Voice playback of the chore name is available on tap-and-hold. The tile size is large enough to tap reliably on a sleepy morning.

### 5.3 iPad family command center

iPad gets a genuinely different layout, not just scaled iPhone. Think kitchen-counter dashboard:

- Left column: kid cards, each showing today's progress ring, balance, next chore.
- Center: a large "today" panel showing family-wide activity, quests, upcoming.
- Right column: pending approvals, recent ledger activity across all kids.

It should look great from 6 feet away because that's where it'll be mounted. Font sizes large. Colors high-contrast. Glanceable. Optional "ambient mode" that cycles through kid progress every 10 seconds.

A subtle point: the iPad version needs to handle the case where multiple kids are using the same physical device. A kid mode on iPad should require a per-kid PIN to mark chores as a specific kid. Otherwise Theo will mark Maya's chores done.

---

## 6. Data model

Entities, key fields, and invariants. Types are conceptual, not literal schema.

- **Family.** id, name, timezone, daily_reset_time, settings (JSON), created_at.
- **User.** id, family_id, role (parent | child | caregiver), display_name, avatar, color, complexity_tier (starter | standard | advanced), birthdate (nullable; used for defaults, not identity), apple_sub (nullable; for parent Sign in with Apple), device_pairing_code (for kids without Apple IDs), created_at.
- **ChoreTemplate.** id, family_id, name, icon, description, target_user_ids (array — a chore can be assigned to multiple kids as independent instances), type (one_off | daily | weekly | monthly | seasonal), schedule (JSON: days of week, day of month, etc.), base_points, cutoff_time (nullable), requires_photo (bool), requires_approval (bool), on_miss_policy (skip | decay | deduct), on_miss_amount, active, created_at, archived_at.
- **ChoreInstance.** id, template_id, user_id, scheduled_for (date), window_start, window_end, status (pending | completed | missed | approved | rejected), completed_at, approved_at, proof_photo_id (nullable), awarded_points, created_at.
- **PointTransaction.** id, user_id, family_id, amount (signed integer), kind (chore_completion | chore_bonus | streak_bonus | combo_bonus | surprise_multiplier | quest_completion | redemption | fine | adjustment | correction), reference_id (nullable FK to the originating object), reason (required text for negative transactions), created_by_user_id, created_at, reversed_by_transaction_id (nullable).
- **Reward.** id, family_id, name, icon, category, price, cooldown, auto_approve_under (nullable), active, created_at, archived_at.
- **RedemptionRequest.** id, user_id, reward_id, requested_at, status (pending | approved | denied | fulfilled), approved_by_user_id, approved_at, resulting_transaction_id, notes.
- **Routine.** id, family_id, name, chore_template_ids (ordered), bonus_points, active_for_user_ids, time_window.
- **Streak.** derived view over ChoreInstance; materialized for fast access but always reconstructable. Fields: user_id, chore_template_id or routine_id, current_length, longest_length, last_completed_date, freezes_remaining.
- **Challenge / Quest.** id, family_id, name, description, start_at, end_at, participant_user_ids, constituent_chore_template_ids (or criteria), bonus_points, status (upcoming | active | completed | expired).
- **ApprovalRequest.** generalization; can reference a ChoreInstance, a RedemptionRequest, or a contested transaction.
- **Notification.** id, user_id, kind, payload, sent_at, read_at. (Plus APNs-side delivery, but the app persists its own copy so users can see history.)
- **AuditLog.** id, family_id, actor_user_id, action, target, payload, created_at. Everything sensitive writes here.

### 6.1 Point balance is derived, not stored

The single most important invariant: a user's point balance is `SUM(amount) over PointTransaction WHERE user_id = X`. It is never stored as a mutable field on the user row.

Why this matters: balances will be contested. "Why did I lose 10 points on Tuesday?" requires an auditable answer. A mutable balance with no history makes this impossible; an append-only ledger makes it trivial. Also, correction transactions (when a parent realizes they fined the wrong kid) should be explicit reverse transactions, not silent edits, so the history tells the truth about what happened.

For performance, the balance can be cached — either materialized per-user or computed from snapshots + delta — but the cache is a derived view, not the source of truth, and it can be rebuilt from transactions at any time.

Other invariants:

- Every negative transaction has a non-empty reason.
- Chore completion → exactly one PointTransaction of kind `chore_completion`, plus optional bonus transactions.
- A ChoreInstance never double-pays (idempotency: creation and approval each create exactly one transaction, and there is a uniqueness constraint).
- A redemption cannot take a user below their configured minimum balance (defaults to 0; some families may set a lower floor).
- Chore templates are never hard-deleted; archiving sets `archived_at` so historical instances remain interpretable.

---

## 7. Backend architecture

The backend decision should be optimized for a **solo iOS developer building in evenings**. That tips the scales firmly toward managed services, minimal custom infrastructure, and a stack where the same person can own everything without a DevOps hobby.

### 7.1 Recommendation

**Supabase** (Postgres + Auth + Realtime + Storage + Edge Functions) for MVP, with application logic written in TypeScript (Deno) edge functions for anything non-trivial, and Postgres RLS (row-level security) enforcing the family-boundary authorization model.

**Why Supabase over other options:**

- **Vapor (Swift on server).** Tempting because of language sharing with iOS, but the Vapor ecosystem is small, hosting isn't push-button, and the productivity win doesn't pay back the operational cost for a solo dev. Revisit in v2 if the app grows.
- **Node/NestJS.** Solid but heavyweight; NestJS's ceremony is overkill for this scope. A simpler Hono or Fastify stack is fine but then you're picking an ORM, building auth, building realtime, etc. Supabase gives you all of that.
- **Python/FastAPI.** Great DX, but you still have to solve auth, realtime, hosting, migrations. Same issue as Node.
- **Go.** Excellent runtime, verbose for domain logic. Overkill here.
- **Firebase.** Viable, but the NoSQL data model is a poor fit for a ledger-centric app. The invariants are much easier to enforce in Postgres.

Supabase is the highest productivity-per-hour choice for a family-scale app. If the product ever needs to leave Supabase, the Postgres database is portable and the edge-function logic is mostly plain TypeScript.

### 7.2 Schema highlights

Postgres with standard choices: UUIDs (v7 for sortability), `timestamptz` throughout, `CHECK` constraints for enum-like fields, partial indexes for common queries (`WHERE status = 'pending'`). RLS policies enforce "user can only see rows in their own family" as the core rule, with per-table refinements (kids can read their own transactions; parents can read all transactions in their family; etc.).

The PointTransaction table is append-only by convention and by a trigger that rejects `UPDATE` or `DELETE` except via a privileged reversal path.

### 7.3 Auth

**Parents: Sign in with Apple.** Cleanest path on iOS; no password management; gives a stable user identity.

**Kids: device pairing, not accounts.** Children under 13 have strict privacy rules (COPPA in the US, similar elsewhere). The cleanest and most legally defensible pattern is that kids do not have their own accounts at all in the backend's legal sense. Instead:

- The parent creates a "kid profile" inside the family.
- The parent pairs the kid's device with a one-time code (scanned from the parent's phone or entered manually). This device gets a long-lived device token scoped to that kid profile, stored in the iOS keychain.
- The kid's profile has no email, no third-party logins, no PII beyond a display name and birthdate.
- If a kid loses access to the device, the parent re-pairs from their phone.

This keeps the parent as the legal account holder, which is the correct COPPA posture. It also happens to be the best UX: small children can't be expected to manage passwords.

**Family Sharing interplay.** Apple Family Sharing is useful for discovering potential family members when inviting a co-parent or child, but it should not be a hard dependency because not every family uses it. Offer it as an accelerator in the add-kid and add-co-parent flows.

### 7.4 Realtime / sync

The app has real but modest realtime needs. Things that need to feel instant:

- Parent approves a redemption → kid's balance ticks down.
- Kid completes a chore → parent's approval queue updates.
- iPad command center updates as activity happens.

**Recommendation: Supabase Realtime (Postgres CDC over WebSocket) for in-app updates, with APNs for out-of-app notifications.**

Tradeoffs considered:

- **Pure APNs-driven pull.** Works, but UI feels laggy when both parent and kid are actively in the app.
- **CloudKit.** Tempting for an iOS-only app (free, automatic, battery-efficient), but the data model is a poor fit for a relational ledger, multi-user permission boundaries are awkward, and escaping CloudKit later is painful. Rejected.
- **WebSocket + database change streams (Supabase Realtime).** Right tradeoff for this app: active users stay in sync, RLS applies to the subscription, and it degrades to no-op when no client is connected.

Apply a simple rule: the client is always authoritative about its own UI state, but server events drive updates. Conflicts are rare (kids don't typically edit data) but when they occur, last-write-wins on ChoreInstance status with an audit log entry is fine; the ledger itself never has conflicts because transactions are append-only.

### 7.5 Push notifications

APNs via Supabase Edge Functions triggered by database events. The notification logic has to be careful not to become spam — a parent who gets pinged every time a kid taps a chore will mute the app within a day.

Defaults:

- Parent gets pushed for: pending approvals, redemption requests, end-of-day summary if any chores are incomplete, opt-in weekly economy digest.
- Parent does **not** get pushed for: routine chore completions, honor-system completions with no approval needed.
- Kid gets pushed for: morning routine reminder (once), afternoon reminder, "you have pending rewards to pick up," new quest available, point bonuses awarded.
- All push settings are granular and overridable per-parent and per-kid.

Quiet hours are a family-wide setting (default 9 PM–7 AM) during which no pushes are sent except high-priority items (explicitly flagged by the parent).

### 7.6 Hosting

Supabase hosts the Postgres, auth, realtime, storage, and edge functions. Free tier accommodates a family-of-4 workload with ease; paid tier ($25/month) if traffic grows. No other hosting needed for MVP.

Photo proof storage goes to Supabase Storage, with a retention policy (default 90 days, parent-configurable) since these are casual proof shots not meant to be archived.

### 7.7 Background jobs

Three periodic jobs, implemented as Supabase scheduled edge functions (or pg_cron):

- **Daily reset** at the family's configured reset time (e.g., 4 AM local). Rolls over yesterday's incomplete chores into "missed" status, applies on_miss policies, generates today's ChoreInstances from templates.
- **Streak maintenance.** Runs after the daily reset. Updates streak records for each user based on yesterday's completions; applies streak freezes if the user has them.
- **Challenge/quest lifecycle.** Activates upcoming quests that hit their start, finalizes completed quests and awards bonuses, expires unfinished quests.

Family-local time is important here. Store reset_time as a wall-clock time (e.g., `04:00`) plus the family's IANA timezone; compute the next UTC firing at dispatch.

### 7.8 Observability and backups

Supabase handles daily Postgres backups automatically. For observability, Sentry for client crash reporting, and Supabase's built-in logs for edge functions. Minimal custom observability needed at this scale; add OpenTelemetry later if the app grows.

### 7.9 Cost estimate

For a family of 4, realistic steady-state:

- Database: a few MB, well within free tier.
- Realtime: a handful of concurrent connections, well within free tier.
- Storage: photo proofs at ~200 KB × maybe 50/month = 10 MB/month, well within free tier.
- Auth: negligible.
- APNs: Apple's free.
- Apple Developer account: $99/year, required to publish to TestFlight and App Store.

**Total: $99/year** (Apple developer fee) for a single family. Even with 10 families piloting, still free tier. Supabase Pro becomes warranted only if this reaches hundreds of families.

---

## 8. iOS / iPadOS client architecture

**Language/UI: Swift and SwiftUI.** UIKit bridging only for the handful of things SwiftUI still doesn't do well.

**State management: Observable (iOS 17+) with a thin repository layer.** TCA is powerful but adds learning overhead for a solo builder; vanilla Observable with a well-structured model layer is plenty. If the app grows, revisit.

**Shared Swift package across iPhone, iPad, and Watch targets.** Domain types, API client, local persistence live in a `ChoreQuestCore` package that all three targets consume.

**Offline support.** Core Data or SwiftData as a local cache. Kids will mark chores done in the car, on a plane, in a bad-wifi basement. Writes queue locally and sync when connectivity returns. Conflict resolution is mostly trivial because of the append-only ledger (a duplicate completion is idempotent by ChoreInstance id; a late-arriving write doesn't overwrite anything).

**Widgets.** This is a multiplier feature.

- **Home Screen widget for kids** showing today's chores and balance. Tap to open app. Small/medium/large variants. In MVP this is probably the second most important surface after the app itself — it removes the "have to open the app" friction.
- **Home Screen widget for parents** showing pending approvals count and recent activity. Medium/large.
- **Lock Screen widget** for kids showing balance + next chore.
- **Smart Stack integration** so the widget surfaces at relevant times (morning, after school).

**App Intents / Siri.** "Hey Siri, I fed the dog" → marks the chore done. High-leverage for young kids who can talk but struggle to navigate. Also "what chores do I have?" and "how many points do I have?" MVP should ship at least the completion intents; queries can wait.

**Live Activities.** For active quests, show progress in Dynamic Island / Lock Screen. Post-MVP but compelling.

**Apple Watch companion.** Tappable chore tiles + balance. Genuinely useful for kids who own an Apple Watch. Post-MVP — maybe v1.5 — because it adds meaningful complexity and a minority of target kids have one.

**What's MVP vs later:**

- MVP: Parent app, kid app, iPad layout, Home Screen widget (kid), push notifications, offline support.
- v0.2: App Intents (completion only), Lock Screen widget, parent widget.
- v1.0: Full Siri/App Intents, Live Activities, Watch companion, richer animations.

---

## 9. Security and privacy

The app handles children's data, which raises the bar.

- **Data minimization.** Kids' profiles contain display name, avatar, color, birthdate, optional photo. No email, no last name, no other identifiers unless the parent explicitly adds them. Birthdate is used only to derive defaults and is never exposed externally.
- **COPPA compliance.** The app's legal posture is that parents are the account holders and kids are sub-profiles under parental control. Children's data is processed only for the service and never shared with third parties. No third-party analytics SDKs touch child profiles. (If analytics are used at all, they are aggregate parent-side only, and explicitly opt-in.)
- **No third-party ad trackers, ever.** No Facebook SDK, no AdMob, no Firebase Analytics on kid profiles. Sentry for crash reporting can be used but configured to strip PII.
- **Photo-proof images** are stored in Supabase Storage, accessible only to family members by RLS, and automatically purged after 90 days by default.
- **Data export.** A parent can export their family's entire dataset as JSON at any time via a Settings → Export button. This is both a COPPA right and a trust signal.
- **Data deletion.** A parent can delete their family, which permanently removes all associated data within 30 days (during which period they can recover it). Child data is deleted immediately when a child profile is removed.
- **Encryption.** TLS in transit; Postgres at rest (Supabase default). Device tokens stored in iOS keychain.
- **Never leaves the device.** Photo proofs could optionally be device-only (stored in iCloud via CloudKit assets rather than uploaded to the server) for families who want maximum privacy. This is a toggle.
- **Parental audit.** Audit log is visible to parents under Settings → History, showing every action on the family.

---

## 10. Anti-abuse / anti-gaming

Kids are clever. The economy will be gamed unless it's designed with gaming in mind. The main attack vectors:

- **Fake completions.** Kid marks a chore done that they didn't do. Countermeasure: per-chore photo-proof toggle; random audit prompts ("Mom will spot-check — is the trash actually out?"); per-kid audit rate based on age and history. Over time, a kid with clean audits earns a trust level that lowers audit frequency.
- **Stale approvals.** Parent gets busy, doesn't approve for two days, kid loses motivation. Countermeasure: auto-approve after N hours for low-stakes items (configurable); reminders to the parent.
- **Sibling sabotage.** Older sibling marks younger sibling's chore done (to mess with them) or the reverse. Countermeasure: kid profiles on the iPad require PIN; the completion action records which device and which user performed it, and a parent can roll it back with one tap.
- **Double-completion.** Kid finds a way to mark the same chore done twice. Countermeasure: server-side uniqueness on (instance_id, status=completed) so the second write is rejected.
- **Point hoarding into reward-economy break.** A kid saves 2000 points over six months, then spends them all at once on rewards the parent can't actually deliver. Countermeasure: explicit saving-goal UI that makes large balances legible and conversational; reward inventory limits per day/week for expensive items; parent approval required above a threshold.
- **Inflation drift.** Parent keeps adjusting values upward; economy becomes meaningless. Countermeasure: the "expected weekly earnings" dashboard surfaces drift. Optional "freeze economy" toggle that prevents changes from taking effect for 7 days.
- **Punitive spiral.** Parent in a bad mood issues lots of fines; kid disengages. Countermeasure: the daily/weekly deduction cap; a gentle "you've issued 5 fines today — consider checking in with your kid" nudge on the parent side.
- **Lost device / transfer.** Kid loses phone; a stranger finds it. Countermeasure: device token revocable from parent app; kid PIN on sensitive actions (redemptions).

---

## 11. MVP scope

A solo builder working evenings can reasonably ship a credible **v0.1 in 8–10 weeks** if scope is held brutally. My proposed cut:

**v0.1 (TestFlight to self + 2–3 friend families, 8–10 weeks):**

- Family creation, parent Sign in with Apple, kid profile with device pairing.
- Chore templates: one-off, daily, weekly (skip monthly/seasonal, no routines, no photo proof).
- ChoreInstance generation on daily reset.
- PointTransaction ledger, balance derivation.
- Rewards catalog, RedemptionRequest with parent approval.
- Parent app: Today, Approvals, Kids, Chores, Rewards, Settings.
- Kid app: Home, Rewards, Ledger.
- iPad: working but just a scaled iPhone layout (no dedicated command center yet).
- Push notifications: approvals, redemption requests, morning reminder.
- Basic streaks (current length, longest length; no freezes yet).
- No quests, no challenges, no combos, no surprise multipliers, no family pool.
- No widgets, no App Intents, no Watch.
- Offline reads; basic offline writes (chore completion only).

**v0.2 (+4 weeks):**

- Photo proof per chore.
- Routines as first-class objects; combo bonus.
- Home Screen widget (kid).
- App Intent for chore completion.
- Monthly and seasonal chore types.
- Saving goals.
- Pre-approval rules for rewards.
- iPad dedicated command-center layout.

**v1.0 (+6–10 weeks):**

- Quests and challenges.
- Surprise multipliers, first-of-day bonus, family pool.
- Streak freezes.
- Economy tuning dashboard.
- Live Activities.
- Watch companion (stretch).
- Data export, audit log UI.
- App Store launch.

This is honest pacing for evenings-and-weekends work. It can compress if the builder goes full-time, expand if life gets in the way.

---

## 12. Build vs. buy on the critical paths

- **Auth: buy** (Sign in with Apple + Supabase Auth).
- **Database: buy** (Supabase Postgres).
- **Realtime: buy** (Supabase Realtime).
- **Push: buy** (APNs directly; no OneSignal needed at this scale).
- **Photo storage: buy** (Supabase Storage).
- **Ledger and economy logic: build.** This is the core of the product; off-the-shelf abstractions don't fit.
- **Chore scheduling: build.** Specific enough that a generic scheduler would fight you.
- **Cash-out payments: defer, and if built, buy.** Do not build payment rails. If real-money reward cash-out is ever a feature, use Apple Pay to a parent-controlled account, or simply log an "IOU" the parent settles offline. Integrating Stripe to send money to a kid is a compliance swamp not worth entering for v1.
- **Screen Time enforcement: do not build.** The app logs screen-time *rewards* (30 minutes tablet) but does not enforce the time limit. iOS Screen Time API is available but the integration is tricky, platform-locked, and not necessary for the value prop. A family can honor-system this like every other reward.
- **Analytics: skip for MVP.** If used later, aggregate parent-side only, opt-in.

---

## 13. Open questions and decisions needed from you

These are things I made assumptions about or deferred. Pulling them out explicitly so we can work through them before code gets written:

- **Kids.** How many, what ages, and which of them have their own iOS device? This affects MVP scope (a 5-year-old without a device needs the iPad to be prioritized earlier) and age-band defaults.
- **Co-parent.** Is there one, and do they need equal access? If yes, the invite flow is MVP; if no, we can defer.
- **iPad.** Is there an iPad intended to live on the kitchen counter as a command center? If so, the iPad-specific layout moves up in priority.
- **Apple Developer account.** Do you have one? If not, budget $99/year and a day of setup; required for TestFlight and App Store.
- **Real money.** Will rewards ever be real cash? If yes, decide early whether it's informal IOU (simple) or integrated (complex, not recommended for v1).
- **Screen time.** Is "30 minutes tablet time" meant to be enforced by the app or just tracked? My assumption is tracked-only.
- **Self-host vs managed.** My recommendation is Supabase managed. If you have a strong preference to self-host (privacy concerns, hobbyist interest in running the stack), the architecture works on self-hosted Supabase or on your own Postgres, but adds meaningful ops overhead.
- **Photo proof.** Comfortable with server-uploaded photos, or would you prefer device-only with iCloud sync? The former is simpler; the latter is a better privacy posture.
- **Behavior fines.** Are you committed to wanting deductions, and how squeamish are you about the punitive framing? If strongly committed, the "missed chore = no gain" default may feel too soft; if uncertain, start soft and add strictness later.
- **Siblings' visibility into each other's ledgers.** Default is off. Confirm?
- **Under-13 policy scope.** If any kid is over 13, you may want to give them a teen-mode account with their own Apple ID. Worth deciding in advance because the data model splits slightly.
- **Name.** "Chore Quest" is a placeholder. Naming affects icon, marketing, App Store metadata. Worth picking something you like before the TestFlight invites start going out.

None of these are blocking for starting the design work, but several of them shape the MVP cut, and it's cheaper to decide now than to rework later.

---

## Closing note

This plan is opinionated in places where I think the right answer is clearer (ledger over mutable balance, device pairing for kids over kid accounts, Supabase over Vapor for a solo builder) and deliberately neutral where the choice depends on family taste (how punitive the mechanics are, whether competition or cooperation is emphasized, whether cash is involved). The bigger risk in a project like this is not technical — nothing here is hard — it is designing an economy the family will actually sustain beyond month two. That's why the most important sections are §2 (core mechanics) and §5 (screens, especially the kid home screen), and why the economy-tuning dashboard is more valuable than it looks. If you build this, protect those.
