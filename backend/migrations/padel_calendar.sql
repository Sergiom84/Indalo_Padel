-- =============================================
-- Indalo Padel - Google Calendar reservations
-- Extends the existing schema with booking participants
-- and calendar sync state.
-- =============================================

ALTER TABLE app.padel_bookings
  ADD COLUMN IF NOT EXISTS duration_minutes INTEGER,
  ADD COLUMN IF NOT EXISTS google_event_id TEXT,
  ADD COLUMN IF NOT EXISTS calendar_sync_status VARCHAR(20) DEFAULT 'pendiente',
  ADD COLUMN IF NOT EXISTS last_synced_at TIMESTAMPTZ;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'padel_bookings_calendar_sync_status_check'
  ) THEN
    ALTER TABLE app.padel_bookings
      ADD CONSTRAINT padel_bookings_calendar_sync_status_check
      CHECK (calendar_sync_status IN ('pendiente', 'sincronizada', 'error'));
  END IF;
END;
$$;

UPDATE app.padel_bookings
SET duration_minutes = COALESCE(
  duration_minutes,
  GREATEST(
    30,
    COALESCE(
      ROUND(EXTRACT(EPOCH FROM (end_time - start_time)) / 60.0)::INTEGER,
      90
    )
  )
);

UPDATE app.padel_bookings
SET calendar_sync_status = COALESCE(calendar_sync_status, 'pendiente');

ALTER TABLE app.padel_bookings
  ALTER COLUMN duration_minutes SET DEFAULT 90,
  ALTER COLUMN duration_minutes SET NOT NULL,
  ALTER COLUMN calendar_sync_status SET DEFAULT 'pendiente',
  ALTER COLUMN calendar_sync_status SET NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_padel_bookings_google_event_id
  ON app.padel_bookings(google_event_id)
  WHERE google_event_id IS NOT NULL;

ALTER TABLE app.padel_bookings
  ALTER COLUMN notes TYPE TEXT;

CREATE TABLE IF NOT EXISTS app.padel_booking_players (
  id SERIAL PRIMARY KEY,
  booking_id INTEGER NOT NULL REFERENCES app.padel_bookings(id) ON DELETE CASCADE,
  user_id INTEGER NOT NULL REFERENCES app.users(id) ON DELETE CASCADE,
  role VARCHAR(20) NOT NULL DEFAULT 'guest',
  invite_status VARCHAR(20) NOT NULL DEFAULT 'pendiente',
  google_response_status VARCHAR(20) NOT NULL DEFAULT 'needsAction',
  responded_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(booking_id, user_id),
  CHECK (role IN ('organizer', 'guest')),
  CHECK (invite_status IN ('pendiente', 'aceptada', 'rechazada', 'cancelada')),
  CHECK (google_response_status IN ('needsAction', 'accepted', 'declined', 'tentative', 'cancelled'))
);

CREATE INDEX IF NOT EXISTS idx_padel_booking_players_booking ON app.padel_booking_players(booking_id);
CREATE INDEX IF NOT EXISTS idx_padel_booking_players_user ON app.padel_booking_players(user_id);

DROP TRIGGER IF EXISTS trg_booking_players_updated_at ON app.padel_booking_players;
CREATE TRIGGER trg_booking_players_updated_at
BEFORE UPDATE ON app.padel_booking_players
FOR EACH ROW EXECUTE FUNCTION app.set_updated_at();

CREATE TABLE IF NOT EXISTS app.padel_calendar_sync_state (
  calendar_id TEXT PRIMARY KEY,
  sync_token TEXT,
  last_synced_at TIMESTAMPTZ,
  last_error TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

DROP TRIGGER IF EXISTS trg_calendar_sync_state_updated_at ON app.padel_calendar_sync_state;
CREATE TRIGGER trg_calendar_sync_state_updated_at
BEFORE UPDATE ON app.padel_calendar_sync_state
FOR EACH ROW EXECUTE FUNCTION app.set_updated_at();

INSERT INTO app.padel_calendar_sync_state (calendar_id)
VALUES ('primary')
ON CONFLICT (calendar_id) DO NOTHING;
