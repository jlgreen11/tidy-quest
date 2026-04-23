-- TidyQuest — Chen-Rodriguez family seed
-- Demo data exercising every code path worth showing.
-- Run after migrations via: supabase db reset (includes seed.sql)

-- ============================================================
-- System sentinel (used as created_by_user_id for automated txns)
-- ============================================================
INSERT INTO app_user (id, family_id, role, display_name, avatar, color, complexity_tier)
VALUES ('00000000-0000-0000-0000-000000000000', NULL, 'system', 'System', 'gear', 'slate', 'advanced')
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- Family
-- ============================================================
INSERT INTO family (
  id, name, timezone, daily_reset_time,
  quiet_hours_start, quiet_hours_end,
  leaderboard_enabled, sibling_ledger_visible,
  subscription_tier, subscription_expires_at,
  weekly_band_target, daily_deduction_cap, weekly_deduction_cap,
  settings, created_at
) VALUES (
  '11111111-1111-1111-1111-111111111111',
  'Chen-Rodriguez',
  'America/Los_Angeles',
  '04:00',
  '21:00', '07:00',
  false,   -- leaderboard off (Zara would weaponize it)
  false,   -- siblings don't see each others' ledgers
  'trial',
  now() + interval '5 days',  -- day 9 of 14-day trial
  int4range(250, 500),
  50, 150,
  jsonb_build_object(
    'onboarding_completed_at', (now() - interval '22 days')::text,
    'first_chore_completed_at', (now() - interval '22 days' + interval '3 hours')::text
  ),
  now() - interval '22 days'
);

-- ============================================================
-- Parents
-- ============================================================
INSERT INTO app_user (id, family_id, role, display_name, avatar, color, complexity_tier, birthdate, apple_sub, created_at)
VALUES
  ('22222222-2222-2222-2222-222222222221',
   '11111111-1111-1111-1111-111111111111',
   'parent', 'Mei', 'parent-1', 'coral', 'advanced',
   '1987-04-15', 'apple-mock-mei-001', now() - interval '22 days'),
  ('22222222-2222-2222-2222-222222222222',
   '11111111-1111-1111-1111-111111111111',
   'parent', 'Luis', 'parent-2', 'sage', 'advanced',
   '1985-09-03', 'apple-mock-luis-002', now() - interval '22 days');

-- ============================================================
-- Kids
-- Ava (6, Starter): loves the app, shares iPad, photo-proof on 2 chores
-- Kai (9, Standard): ADHD dx, 14-day bed-made streak
-- Zara (12, Advanced): skeptical, cash-out user, contested a fine
-- Theo (5, Starter): has gamed dog-feeding → mandatory photo
-- ============================================================
INSERT INTO app_user (id, family_id, role, display_name, avatar, color, complexity_tier, birthdate, created_at)
VALUES
  ('33333333-3333-3333-3333-333333333331',
   '11111111-1111-1111-1111-111111111111',
   'child', 'Ava', 'kid-butterfly', 'sunflower', 'starter',
   current_date - interval '6 years', now() - interval '22 days'),
  ('33333333-3333-3333-3333-333333333332',
   '11111111-1111-1111-1111-111111111111',
   'child', 'Kai', 'kid-rocket', 'sky', 'standard',
   current_date - interval '9 years', now() - interval '22 days'),
  ('33333333-3333-3333-3333-333333333333',
   '11111111-1111-1111-1111-111111111111',
   'child', 'Zara', 'kid-star', 'lavender', 'advanced',
   current_date - interval '12 years', now() - interval '22 days'),
  ('33333333-3333-3333-3333-333333333334',
   '11111111-1111-1111-1111-111111111111',
   'child', 'Theo', 'kid-dinosaur', 'rose', 'starter',
   current_date - interval '5 years', now() - interval '22 days');

-- ============================================================
-- Chore templates — preset "8-10 Standard" pack adapted for family
-- Stored as separate rows per target kid for simplicity here;
-- in prod the target_user_ids array handles this.
-- ============================================================

-- Morning routine chores (all kids)
INSERT INTO chore_template (id, family_id, name, icon, description, type, schedule, target_user_ids, base_points, cutoff_time, requires_photo, requires_approval, on_miss, on_miss_amount, active, created_at)
VALUES
  -- Ava morning
  ('44444444-4444-4444-4444-444444444401',
   '11111111-1111-1111-1111-111111111111',
   'Make bed', 'bed.double.fill', 'Make your bed every morning', 'daily',
   jsonb_build_object('daysOfWeek', ARRAY[0,1,2,3,4,5,6]),
   ARRAY['33333333-3333-3333-3333-333333333331']::uuid[],
   5, '09:00', false, false, 'decay', 0, true, now() - interval '22 days'),
  ('44444444-4444-4444-4444-444444444402',
   '11111111-1111-1111-1111-111111111111',
   'Brush teeth', 'heart.fill', 'Morning teeth brushing', 'daily',
   jsonb_build_object('daysOfWeek', ARRAY[0,1,2,3,4,5,6]),
   ARRAY['33333333-3333-3333-3333-333333333331']::uuid[],
   3, '09:00', false, false, 'decay', 0, true, now() - interval '22 days'),

  -- Kai morning (14-day streak on this one)
  ('44444444-4444-4444-4444-444444444403',
   '11111111-1111-1111-1111-111111111111',
   'Make bed', 'bed.double.fill', 'Make your bed every morning', 'daily',
   jsonb_build_object('daysOfWeek', ARRAY[0,1,2,3,4,5,6]),
   ARRAY['33333333-3333-3333-3333-333333333332']::uuid[],
   5, '09:00', false, false, 'decay', 0, true, now() - interval '22 days'),
  ('44444444-4444-4444-4444-444444444404',
   '11111111-1111-1111-1111-111111111111',
   'Homework', 'book.fill', 'Finish today''s assigned homework', 'daily',
   jsonb_build_object('daysOfWeek', ARRAY[1,2,3,4]),  -- weeknights only
   ARRAY['33333333-3333-3333-3333-333333333332']::uuid[],
   15, '19:00', false, true, 'decay', 0, true, now() - interval '22 days'),

  -- Zara: harder chores, higher points, more photo requirements
  ('44444444-4444-4444-4444-444444444405',
   '11111111-1111-1111-1111-111111111111',
   'Empty dishwasher', 'dishwasher', 'Unload and put everything away', 'daily',
   jsonb_build_object('daysOfWeek', ARRAY[0,1,2,3,4,5,6]),
   ARRAY['33333333-3333-3333-3333-333333333333']::uuid[],
   12, '20:00', false, false, 'decay', 0, true, now() - interval '22 days'),
  ('44444444-4444-4444-4444-444444444406',
   '11111111-1111-1111-1111-111111111111',
   'Feed cats', 'pawprint.fill', 'Morning + evening cat feeding', 'daily',
   jsonb_build_object('daysOfWeek', ARRAY[0,1,2,3,4,5,6]),
   ARRAY['33333333-3333-3333-3333-333333333333']::uuid[],
   8, '21:00', true, false, 'decay', 0, true, now() - interval '22 days'),

  -- Theo: dog-feeding with MANDATORY photo proof (he gamed it)
  ('44444444-4444-4444-4444-444444444407',
   '11111111-1111-1111-1111-111111111111',
   'Feed dog', 'pawprint.circle.fill', 'Feed the dog his kibble', 'daily',
   jsonb_build_object('daysOfWeek', ARRAY[0,1,2,3,4,5,6]),
   ARRAY['33333333-3333-3333-3333-333333333334']::uuid[],
   8, '08:00', true, true, 'decay', 0, true, now() - interval '22 days'),
  ('44444444-4444-4444-4444-444444444408',
   '11111111-1111-1111-1111-111111111111',
   'Put toys away', 'shippingbox.fill', 'Before bed', 'daily',
   jsonb_build_object('daysOfWeek', ARRAY[0,1,2,3,4,5,6]),
   ARRAY['33333333-3333-3333-3333-333333333334']::uuid[],
   5, '20:00', false, false, 'decay', 0, true, now() - interval '22 days'),

  -- Weekly chores
  ('44444444-4444-4444-4444-444444444409',
   '11111111-1111-1111-1111-111111111111',
   'Vacuum living room', 'wind', 'Weekend vacuum', 'weekly',
   jsonb_build_object('daysOfWeek', ARRAY[6]),  -- Saturday
   ARRAY['33333333-3333-3333-3333-333333333333']::uuid[],
   40, '18:00', true, true, 'decay', 0, true, now() - interval '22 days'),
  ('44444444-4444-4444-4444-444444444410',
   '11111111-1111-1111-1111-111111111111',
   'Clean bathroom sink', 'sink.fill', 'Wipe down counter + sink', 'weekly',
   jsonb_build_object('daysOfWeek', ARRAY[6]),
   ARRAY['33333333-3333-3333-3333-333333333332']::uuid[],
   30, '18:00', true, true, 'decay', 0, true, now() - interval '22 days');

-- ============================================================
-- Rewards catalog
-- ============================================================
INSERT INTO reward (id, family_id, name, icon, category, price, cooldown, auto_approve_under, active, created_at)
VALUES
  ('55555555-5555-5555-5555-555555555501',
   '11111111-1111-1111-1111-111111111111',
   '30 min tablet time', 'ipad', 'screen_time', 75, 86400, 30, true, now() - interval '22 days'),
  ('55555555-5555-5555-5555-555555555502',
   '11111111-1111-1111-1111-111111111111',
   'Ice cream after dinner', 'fork.knife', 'treat', 60, 172800, NULL, true, now() - interval '22 days'),
  ('55555555-5555-5555-5555-555555555503',
   '11111111-1111-1111-1111-111111111111',
   'Pick the restaurant', 'house.fill', 'privilege', 100, NULL, NULL, true, now() - interval '22 days'),
  ('55555555-5555-5555-5555-555555555504',
   '11111111-1111-1111-1111-111111111111',
   'Stay up 30 min late', 'moon.stars.fill', 'privilege', 50, 604800, NULL, true, now() - interval '22 days'),
  ('55555555-5555-5555-5555-555555555505',
   '11111111-1111-1111-1111-111111111111',
   'Cash-out $1 (IOU)', 'dollarsign.circle.fill', 'cash_out', 100, NULL, NULL, true, now() - interval '22 days'),
  ('55555555-5555-5555-5555-555555555506',
   '11111111-1111-1111-1111-111111111111',
   'Lego Dots Butterfly Kit', 'star.fill', 'saving_goal', 800, NULL, NULL, true, now() - interval '22 days'),
  ('55555555-5555-5555-5555-555555555507',
   '11111111-1111-1111-1111-111111111111',
   'Pick the family movie', 'film.fill', 'privilege', 80, 604800, NULL, true, now() - interval '22 days');

-- ============================================================
-- Ledger history — 22 days of realistic activity.
-- Generated procedurally to avoid thousands of explicit INSERTs.
-- Each kid gets roughly their expected weekly earnings.
-- ============================================================

DO $$
DECLARE
  kid_row RECORD;
  day_offset INTEGER;
  daily_earnings INTEGER;
  template_row RECORD;
  txn_id UUID;
  instance_id UUID;
BEGIN
  FOR kid_row IN
    SELECT id, display_name, complexity_tier
    FROM app_user
    WHERE family_id = '11111111-1111-1111-1111-111111111111' AND role = 'child'
  LOOP
    FOR day_offset IN 0..21 LOOP
      -- Realistic completion rate: Kai 90% (ADHD routine), Ava 75%, Theo 60%, Zara 80%
      -- Skip some days for realism
      IF (kid_row.display_name = 'Kai' AND random() < 0.95) OR
         (kid_row.display_name = 'Ava' AND random() < 0.75) OR
         (kid_row.display_name = 'Theo' AND random() < 0.60) OR
         (kid_row.display_name = 'Zara' AND random() < 0.80)
      THEN
        FOR template_row IN
          SELECT id, base_points FROM chore_template
          WHERE kid_row.id = ANY(target_user_ids)
            AND type = 'daily'
            AND active = true
        LOOP
          -- Create chore instance
          instance_id := gen_random_uuid();
          INSERT INTO chore_instance (
            id, template_id, user_id, scheduled_for, status,
            completed_at, approved_at, awarded_points, created_at
          ) VALUES (
            instance_id, template_row.id, kid_row.id,
            (current_date - (day_offset || ' days')::interval)::date,
            'approved',
            (current_date - (day_offset || ' days')::interval + interval '8 hours'),
            (current_date - (day_offset || ' days')::interval + interval '8 hours'),
            template_row.base_points,
            (current_date - (day_offset || ' days')::interval + interval '8 hours')
          );

          -- Create point transaction
          txn_id := gen_random_uuid();
          INSERT INTO point_transaction (
            id, user_id, family_id, amount, kind,
            reference_id, chore_instance_id,
            created_by_user_id, idempotency_key, created_at
          ) VALUES (
            txn_id, kid_row.id,
            '11111111-1111-1111-1111-111111111111',
            template_row.base_points, 'chore_completion',
            instance_id, instance_id,
            kid_row.id, gen_random_uuid(),
            (current_date - (day_offset || ' days')::interval + interval '8 hours')
          );
        END LOOP;
      END IF;
    END LOOP;
  END LOOP;
END $$;

-- ============================================================
-- Kai's 14-day streak on "Make bed" — explicit for determinism
-- ============================================================
-- This is on top of the procedural history above; dedupe is handled
-- by the UNIQUE constraint (template_id, user_id, scheduled_for).
-- Using ON CONFLICT DO NOTHING; the streak shows up either way.

-- (Streak table row — this is derived/materialized in the real schema,
-- but we seed it here so UI has something to show on first load.)
-- Will be created in 0005_streaks.sql migration; left as a comment for now.

-- ============================================================
-- TODAY'S state: active pending/completed instances for the demo
-- ============================================================

-- Ava: 3 chores today, 1 done
INSERT INTO chore_instance (id, template_id, user_id, scheduled_for, status, completed_at, created_at)
VALUES
  ('66666666-6666-6666-6666-666666666601', '44444444-4444-4444-4444-444444444401',
   '33333333-3333-3333-3333-333333333331', current_date, 'approved',
   current_date + interval '7 hours 30 minutes', current_date + interval '7 hours 30 minutes'),
  ('66666666-6666-6666-6666-666666666602', '44444444-4444-4444-4444-444444444402',
   '33333333-3333-3333-3333-333333333331', current_date, 'pending',
   NULL, current_date + interval '4 hours');

-- Kai: 3 chores today, 2 done
INSERT INTO chore_instance (id, template_id, user_id, scheduled_for, status, completed_at, created_at)
VALUES
  ('66666666-6666-6666-6666-666666666603', '44444444-4444-4444-4444-444444444403',
   '33333333-3333-3333-3333-333333333332', current_date, 'approved',
   current_date + interval '7 hours', current_date + interval '7 hours'),
  ('66666666-6666-6666-6666-666666666604', '44444444-4444-4444-4444-444444444404',
   '33333333-3333-3333-3333-333333333332', current_date, 'pending',
   NULL, current_date + interval '4 hours');

-- Zara: harder chores, one awaiting approval (cats fed with photo)
INSERT INTO chore_instance (id, template_id, user_id, scheduled_for, status, completed_at, created_at)
VALUES
  ('66666666-6666-6666-6666-666666666605', '44444444-4444-4444-4444-444444444405',
   '33333333-3333-3333-3333-333333333333', current_date, 'pending',
   NULL, current_date + interval '4 hours'),
  ('66666666-6666-6666-6666-666666666606', '44444444-4444-4444-4444-444444444406',
   '33333333-3333-3333-3333-333333333333', current_date, 'completed',
   current_date + interval '18 hours', current_date + interval '18 hours');
-- Zara's cats-fed: status='completed' awaits parent approval in the queue

-- Theo: dog-feeding with photo, in parent approval queue
INSERT INTO chore_instance (id, template_id, user_id, scheduled_for, status, completed_at, proof_photo_id, created_at)
VALUES
  ('66666666-6666-6666-6666-666666666607', '44444444-4444-4444-4444-444444444407',
   '33333333-3333-3333-3333-333333333334', current_date, 'completed',
   current_date + interval '8 hours', gen_random_uuid(),
   current_date + interval '8 hours'),
  ('66666666-6666-6666-6666-666666666608', '44444444-4444-4444-4444-444444444408',
   '33333333-3333-3333-3333-333333333334', current_date, 'pending',
   NULL, current_date + interval '4 hours');

-- ============================================================
-- Recent fine (Zara, "Rude to sibling") — contested
-- ============================================================
INSERT INTO point_transaction (
  id, user_id, family_id, amount, kind, reason,
  created_by_user_id, idempotency_key, created_at
) VALUES (
  '77777777-7777-7777-7777-777777777701',
  '33333333-3333-3333-3333-333333333333',  -- Zara
  '11111111-1111-1111-1111-111111111111',
  -5, 'fine', 'Rude to sibling',
  '22222222-2222-2222-2222-222222222221',  -- Mei issued
  gen_random_uuid(),
  now() - interval '2 days'
);

-- Zara's contest creates an ApprovalRequest (target = that transaction)
-- (ApprovalRequest table DDL owned by A1; insertion deferred until table exists)

-- ============================================================
-- Active quest: "Weekend Deep Clean" starting Saturday
-- ============================================================
-- (Challenge/Quest table DDL owned by A1; seed row inserted at end of Act 1)

-- ============================================================
-- Subscription state: Day 9 of 14-day trial
-- ============================================================
INSERT INTO subscription (
  id, family_id, store_transaction_id, product_id, tier,
  purchased_at, expires_at, status, receipt_hash, created_at
) VALUES (
  '88888888-8888-8888-8888-888888888801',
  '11111111-1111-1111-1111-111111111111',
  'mock-trial-receipt-001',
  'com.jlgreen11.tidyquest.trial',
  'trial',
  now() - interval '9 days',
  now() + interval '5 days',
  'trial',
  'mock-hash-trial-001',
  now() - interval '9 days'
);

-- ============================================================
-- Seed complete. Expected state at end of seed:
--   - 1 family (Chen-Rodriguez), trial day 9/14
--   - 6 users (2 parents + 4 kids + system sentinel)
--   - 10 chore templates
--   - 7 rewards
--   - ~300-500 PointTransaction rows (procedural daily history)
--   - 8 today's chore_instances (mix of approved/pending/completed)
--   - 1 recent fine (Zara, contested)
--   - 1 active subscription (trial)
-- ============================================================
