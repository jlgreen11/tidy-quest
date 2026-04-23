-- =============================================================================
-- TidyQuest — pg_cron Background Jobs
-- 20260422000003_pgcron_jobs.sql
--
-- Schedules four recurring jobs via pg_cron.
-- Must run after migrations 0001 and 0002.
--
-- NOTE: pg_cron schedules are in UTC. Each family has its own timezone, so
-- the daily_reset job runs every hour and self-gates on which families need
-- to fire (i.e., families whose current local time = daily_reset_time ± 1 min).
-- This avoids one-schedule-per-family complexity while keeping sub-minute
-- accuracy for a reasonably-sized user base.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- JOB 1 FUNCTION: daily_reset_family
--
-- Runs each minute; for each family checks whether now() in the family's
-- timezone equals daily_reset_time (within a 1-minute window). When matched:
--   1. Rolls yesterday's 'pending' instances to 'missed'; applies on_miss policy.
--   2. Creates today's ChoreInstances (idempotent ON CONFLICT DO NOTHING).
--   3. Logs to job_log.
--
-- Gating: the job checks job_log to avoid double-fire within the same
-- reset window (any success within the last 55 minutes for that family).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_daily_reset_family()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_family        RECORD;
  v_log_id        uuid;
  v_started       timestamptz;
  v_today         date;
  v_yesterday     date;
  v_rows_affected integer := 0;
  v_template      RECORD;
  v_target_uid    uuid;
  v_err_message   text;
BEGIN
  v_started := clock_timestamp();

  -- Insert a log row immediately so we can track long-running resets
  INSERT INTO job_log (job_name, started_at, status, metadata)
  VALUES ('daily_reset_family', v_started, 'failure'::job_status,
          jsonb_build_object('families_processed', 0))
  RETURNING id INTO v_log_id;

  BEGIN  -- inner block for exception handling
    FOR v_family IN
      SELECT f.id,
             f.timezone,
             f.daily_reset_time,
             (now() AT TIME ZONE f.timezone)::date AS local_today
        FROM family f
       WHERE f.deleted_at IS NULL
         -- Family's local time is within [daily_reset_time, daily_reset_time + 1 min)
         AND (now() AT TIME ZONE f.timezone)::time
               >= f.daily_reset_time
         AND (now() AT TIME ZONE f.timezone)::time
               <  f.daily_reset_time + interval '1 minute'
         -- Guard: no successful reset already ran for this family in the past 55 minutes
         AND NOT EXISTS (
               SELECT 1 FROM job_log jl
                WHERE jl.job_name = 'daily_reset_family'
                  AND jl.status = 'success'
                  AND jl.started_at > now() - interval '55 minutes'
                  AND (jl.metadata->>'family_id')::text = f.id::text
             )
    LOOP
      v_today     := v_family.local_today;
      v_yesterday := v_today - 1;

      -- Step 1: Roll yesterday's pending instances to missed
      UPDATE chore_instance ci
         SET status = 'missed'
       WHERE ci.user_id IN (
               SELECT id FROM app_user
                WHERE family_id = v_family.id AND deleted_at IS NULL
             )
         AND ci.scheduled_for = v_yesterday
         AND ci.status = 'pending';

      v_rows_affected := v_rows_affected + 1;

      -- Step 2: Apply on_miss deductions where policy = 'deduct'
      INSERT INTO point_transaction (
        id, user_id, family_id, amount, kind, reason,
        chore_instance_id, created_by_user_id, idempotency_key
      )
      SELECT
        uuid_generate_v7(),
        ci.user_id,
        v_family.id,
        -ct.on_miss_amount,
        'fine',
        'Missed chore: ' || ct.name,
        ci.id,
        '00000000-0000-0000-0000-000000000000',  -- system sentinel
        uuid_generate_v7()
      FROM chore_instance ci
      JOIN chore_template ct ON ct.id = ci.template_id
      WHERE ci.user_id IN (
              SELECT id FROM app_user
               WHERE family_id = v_family.id AND deleted_at IS NULL
            )
        AND ci.scheduled_for = v_yesterday
        AND ci.status = 'missed'
        AND ct.on_miss = 'deduct'
        AND ct.on_miss_amount > 0;

      -- Step 3: Generate today's ChoreInstances for all active daily/weekly templates
      FOR v_template IN
        SELECT ct.id AS template_id,
               ct.target_user_ids,
               ct.type,
               ct.schedule
          FROM chore_template ct
         WHERE ct.family_id = v_family.id
           AND ct.active = true
           AND ct.archived_at IS NULL
           AND ct.type IN ('daily','weekly','monthly','routine_bound')
      LOOP
        FOREACH v_target_uid IN ARRAY v_template.target_user_ids
        LOOP
          -- Weekly: only insert on matching day-of-week
          IF v_template.type = 'weekly' THEN
            IF NOT (
              ARRAY[EXTRACT(DOW FROM v_today)::int]
              <@ ARRAY(
                    SELECT jsonb_array_elements_text(v_template.schedule->'daysOfWeek')::int
                 )
            ) THEN
              CONTINUE;
            END IF;
          END IF;

          -- Daily / routine_bound: check daysOfWeek if present
          IF v_template.type IN ('daily','routine_bound')
             AND v_template.schedule ? 'daysOfWeek' THEN
            IF NOT (
              ARRAY[EXTRACT(DOW FROM v_today)::int]
              <@ ARRAY(
                    SELECT jsonb_array_elements_text(v_template.schedule->'daysOfWeek')::int
                 )
            ) THEN
              CONTINUE;
            END IF;
          END IF;

          INSERT INTO chore_instance (
            id, template_id, user_id, scheduled_for, status, created_at
          ) VALUES (
            uuid_generate_v7(),
            v_template.template_id,
            v_target_uid,
            v_today,
            'pending',
            now()
          )
          ON CONFLICT (template_id, user_id, scheduled_for) DO NOTHING;

        END LOOP;
      END LOOP;

      -- Update job log to record this family's reset (overwrite metadata)
      UPDATE job_log
         SET metadata = metadata || jsonb_build_object(
               'family_id', v_family.id,
               'local_today', v_today::text
             )
       WHERE id = v_log_id;

    END LOOP;  -- family loop

    -- Mark success
    UPDATE job_log
       SET status = 'success'::job_status,
           finished_at = clock_timestamp(),
           rows_affected = v_rows_affected,
           metadata = metadata || jsonb_build_object('families_processed', v_rows_affected)
     WHERE id = v_log_id;

  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_err_message = MESSAGE_TEXT;
    UPDATE job_log
       SET status = 'failure'::job_status,
           finished_at = clock_timestamp(),
           error_message = v_err_message
     WHERE id = v_log_id;
    RAISE;
  END;
END;
$$;

-- ---------------------------------------------------------------------------
-- JOB 2 FUNCTION: streak_maintenance
--
-- Runs at 04:05 family-local-ish (scheduled at :05 past every hour, matching
-- the daily reset pattern). Gated: only runs after daily_reset_family has
-- successfully completed for each family today.
--
-- For families whose reset just ran, checks each user's streaks:
--   - If last_completed_date is yesterday or earlier and no completion today,
--     streak is not broken yet (the day isn't over).
--   - If last_completed_date is 2+ days ago, reset current_length to 0.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_streak_maintenance()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_log_id      uuid;
  v_started     timestamptz;
  v_rows        integer := 0;
  v_err_message text;
  v_family      RECORD;
BEGIN
  v_started := clock_timestamp();

  INSERT INTO job_log (job_name, started_at, status, metadata)
  VALUES ('streak_maintenance', v_started, 'failure'::job_status, '{}')
  RETURNING id INTO v_log_id;

  BEGIN
    FOR v_family IN
      SELECT f.id,
             (now() AT TIME ZONE f.timezone)::date AS local_today
        FROM family f
       WHERE f.deleted_at IS NULL
         -- Only families that have already had a daily reset today
         AND EXISTS (
               SELECT 1 FROM job_log jl
                WHERE jl.job_name = 'daily_reset_family'
                  AND jl.status = 'success'
                  AND jl.started_at > now() - interval '65 minutes'
                  AND (jl.metadata->>'family_id')::text = f.id::text
             )
         -- And haven't had streak maintenance yet today
         AND NOT EXISTS (
               SELECT 1 FROM job_log jl
                WHERE jl.job_name = 'streak_maintenance'
                  AND jl.status = 'success'
                  AND jl.started_at > now() - interval '55 minutes'
                  AND (jl.metadata->>'family_id')::text = f.id::text
             )
    LOOP
      -- Break streaks where gap > 1 day (user missed yesterday entirely)
      UPDATE streak s
         SET current_length = 0,
             updated_at     = now()
        FROM app_user u
       WHERE u.id = s.user_id
         AND u.family_id = v_family.id
         AND s.last_completed_date < v_family.local_today - interval '1 day'
         AND s.current_length > 0;

      v_rows := v_rows + 1;

      UPDATE job_log
         SET metadata = metadata || jsonb_build_object('family_id', v_family.id)
       WHERE id = v_log_id;
    END LOOP;

    UPDATE job_log
       SET status = 'success'::job_status,
           finished_at = clock_timestamp(),
           rows_affected = v_rows
     WHERE id = v_log_id;

  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_err_message = MESSAGE_TEXT;
    UPDATE job_log
       SET status = 'failure'::job_status,
           finished_at = clock_timestamp(),
           error_message = v_err_message
     WHERE id = v_log_id;
    RAISE;
  END;
END;
$$;

-- ---------------------------------------------------------------------------
-- JOB 3 FUNCTION: photo_purge
--
-- Runs daily at 03:00 UTC.
-- Clears proof_photo_id from chore_instance rows where completed_at is older
-- than 7 days. The actual Storage object deletion is handled by the
-- photo.purge edge function triggered by audit_log events; this job nulls
-- the Postgres reference and writes the audit record so the edge function
-- can pick up the work.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_photo_purge()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_log_id        uuid;
  v_started       timestamptz;
  v_rows_affected integer := 0;
  v_err_message   text;
  v_ci            RECORD;
BEGIN
  v_started := clock_timestamp();

  INSERT INTO job_log (job_name, started_at, status, metadata)
  VALUES ('photo_purge', v_started, 'failure'::job_status, '{}')
  RETURNING id INTO v_log_id;

  BEGIN
    -- Collect rows to purge first, then update
    FOR v_ci IN
      SELECT ci.id,
             ci.user_id,
             ci.proof_photo_id,
             ci.template_id,
             (SELECT ct.family_id FROM chore_template ct WHERE ct.id = ci.template_id) AS family_id
        FROM chore_instance ci
       WHERE ci.proof_photo_id IS NOT NULL
         AND ci.completed_at < now() - interval '7 days'
    LOOP
      -- Write audit record (edge function watches this to delete Storage object)
      INSERT INTO audit_log (family_id, actor_user_id, action, target, payload)
      VALUES (
        v_ci.family_id,
        '00000000-0000-0000-0000-000000000000',  -- system sentinel
        'photo.purge',
        'chore_instance:' || v_ci.id::text,
        jsonb_build_object(
          'proof_photo_id',    v_ci.proof_photo_id,
          'chore_instance_id', v_ci.id,
          'user_id',           v_ci.user_id
        )
      );

      -- Null out the photo reference
      UPDATE chore_instance
         SET proof_photo_id = NULL
       WHERE id = v_ci.id;

      v_rows_affected := v_rows_affected + 1;
    END LOOP;

    UPDATE job_log
       SET status = 'success'::job_status,
           finished_at = clock_timestamp(),
           rows_affected = v_rows_affected,
           metadata = jsonb_build_object('photos_purged', v_rows_affected)
     WHERE id = v_log_id;

  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_err_message = MESSAGE_TEXT;
    UPDATE job_log
       SET status = 'failure'::job_status,
           finished_at = clock_timestamp(),
           error_message = v_err_message
     WHERE id = v_log_id;
    RAISE;
  END;
END;
$$;

-- ---------------------------------------------------------------------------
-- Schedule the three jobs via pg_cron
--
-- NOTE: pg_cron requires the database name. On local Supabase it is 'postgres'.
-- On hosted Supabase it matches the project database name. We use 'postgres'
-- here as that is the Supabase default (both local and hosted).
-- ---------------------------------------------------------------------------

-- Job 1: daily_reset_family — runs every minute (function self-gates per family)
SELECT cron.schedule(
  'daily_reset_family',
  '* * * * *',   -- every minute; gating is inside fn_daily_reset_family()
  $$SELECT fn_daily_reset_family();$$
);

-- Job 2: streak_maintenance — runs every minute (function self-gates after reset)
SELECT cron.schedule(
  'streak_maintenance',
  '* * * * *',
  $$SELECT fn_streak_maintenance();$$
);

-- Job 3: photo_purge — runs daily at 03:00 UTC
SELECT cron.schedule(
  'photo_purge',
  '0 3 * * *',
  $$SELECT fn_photo_purge();$$
);

-- Verify registrations
DO $$
BEGIN
  IF (SELECT count(*) FROM cron.job WHERE jobname IN ('daily_reset_family','streak_maintenance','photo_purge')) <> 3 THEN
    RAISE EXCEPTION 'pg_cron job registration incomplete';
  END IF;
END $$;
