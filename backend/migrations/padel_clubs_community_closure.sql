ALTER TABLE app.padel_venues
  ADD COLUMN IF NOT EXISTS is_bookable BOOLEAN NOT NULL DEFAULT TRUE;

UPDATE app.padel_venues
SET is_active = TRUE
WHERE is_active = FALSE;

UPDATE app.padel_venues
SET name = 'Marina de la Torre',
    is_bookable = TRUE,
    opening_time = '09:00',
    closing_time = '23:00',
    updated_at = NOW()
WHERE LOWER(BTRIM(name)) = LOWER(BTRIM('Hotel Servigroup Marina Playa'));

UPDATE app.padel_venues
SET is_bookable = CASE
    WHEN LOWER(BTRIM(name)) = LOWER(BTRIM('Marina de la Torre')) THEN TRUE
    ELSE FALSE
  END,
  updated_at = NOW();

DELETE FROM app.padel_venue_schedule_windows
WHERE venue_id IN (
  SELECT id
  FROM app.padel_venues
  WHERE LOWER(BTRIM(name)) = LOWER(BTRIM('Marina de la Torre'))
);

INSERT INTO app.padel_venue_schedule_windows (
  venue_id,
  day_of_week,
  start_time,
  end_time,
  label,
  is_active
)
SELECT
  v.id,
  day_value,
  '08:00',
  '23:59',
  'summer',
  TRUE
FROM app.padel_venues v
CROSS JOIN generate_series(1, 7) AS day_value
WHERE LOWER(BTRIM(v.name)) = LOWER(BTRIM('Marina de la Torre'));

INSERT INTO app.padel_venue_schedule_windows (
  venue_id,
  day_of_week,
  start_time,
  end_time,
  label,
  is_active
)
SELECT
  v.id,
  day_value,
  '09:00',
  '23:00',
  'winter',
  TRUE
FROM app.padel_venues v
CROSS JOIN generate_series(1, 7) AS day_value
WHERE LOWER(BTRIM(v.name)) = LOWER(BTRIM('Marina de la Torre'));

ALTER TABLE app.padel_community_plans
  ADD COLUMN IF NOT EXISTS closed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS closed_by INTEGER REFERENCES app.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS closed_reason VARCHAR(32),
  ADD COLUMN IF NOT EXISTS calendar_sync_status VARCHAR(20) NOT NULL DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS last_synced_at TIMESTAMPTZ;

UPDATE app.padel_community_plans
SET calendar_sync_status = COALESCE(calendar_sync_status, 'pending');

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'padel_community_plans_invite_state_check'
  ) THEN
    ALTER TABLE app.padel_community_plans
      DROP CONSTRAINT padel_community_plans_invite_state_check;
  END IF;

  ALTER TABLE app.padel_community_plans
    ADD CONSTRAINT padel_community_plans_invite_state_check
    CHECK (
      invite_state IN (
        'pending',
        'replacement_required',
        'reschedule_pending',
        'ready',
        'cancelled',
        'expired'
      )
    );
END;
$$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'padel_community_plans_reservation_state_check'
  ) THEN
    ALTER TABLE app.padel_community_plans
      DROP CONSTRAINT padel_community_plans_reservation_state_check;
  END IF;

  ALTER TABLE app.padel_community_plans
    ADD CONSTRAINT padel_community_plans_reservation_state_check
    CHECK (
      reservation_state IN (
        'pending',
        'retry',
        'confirmed',
        'cancelled',
        'expired'
      )
    );
END;
$$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'padel_community_plan_players_response_state_check'
  ) THEN
    ALTER TABLE app.padel_community_plan_players
      DROP CONSTRAINT padel_community_plan_players_response_state_check;
  END IF;

  ALTER TABLE app.padel_community_plan_players
    ADD CONSTRAINT padel_community_plan_players_response_state_check
    CHECK (
      response_state IN ('pending', 'accepted', 'declined', 'doubt')
    );
END;
$$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'padel_community_notifications_type_check'
  ) THEN
    ALTER TABLE app.padel_community_notifications
      DROP CONSTRAINT padel_community_notifications_type_check;
  END IF;

  ALTER TABLE app.padel_community_notifications
    ADD CONSTRAINT padel_community_notifications_type_check
    CHECK (
      type IN (
        'member_declined',
        'reschedule_proposed',
        'reservation_retry',
        'reservation_confirmed',
        'plan_invitation',
        'plan_ready',
        'plan_cancelled',
        'plan_expired',
        'retry_timeout',
        'conflict_warning',
        'result_ready'
      )
    );
END;
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'padel_community_plans_calendar_sync_status_check'
  ) THEN
    ALTER TABLE app.padel_community_plans
      ADD CONSTRAINT padel_community_plans_calendar_sync_status_check
      CHECK (calendar_sync_status IN ('pending', 'synced', 'error'));
  END IF;
END;
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'padel_community_plans_closed_reason_check'
  ) THEN
    ALTER TABLE app.padel_community_plans
      ADD CONSTRAINT padel_community_plans_closed_reason_check
      CHECK (
        closed_reason IS NULL
        OR closed_reason IN (
          'organizer_cancelled',
          'retry_timeout',
          'past_datetime'
        )
      );
  END IF;
END;
$$;

CREATE INDEX IF NOT EXISTS idx_padel_venues_is_bookable
  ON app.padel_venues(is_bookable);

CREATE INDEX IF NOT EXISTS idx_padel_community_plans_closed_at
  ON app.padel_community_plans(closed_at DESC);

CREATE INDEX IF NOT EXISTS idx_padel_community_plans_calendar_sync_status
  ON app.padel_community_plans(calendar_sync_status);
