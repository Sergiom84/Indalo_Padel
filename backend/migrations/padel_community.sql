CREATE TABLE IF NOT EXISTS app.padel_community_plans (
  id SERIAL PRIMARY KEY,
  created_by INTEGER NOT NULL REFERENCES app.users(id) ON DELETE CASCADE,
  venue_id INTEGER REFERENCES app.padel_venues(id) ON DELETE SET NULL,
  scheduled_date DATE NOT NULL,
  scheduled_time TIME NOT NULL,
  duration_minutes INTEGER NOT NULL DEFAULT 90 CHECK (duration_minutes BETWEEN 30 AND 240),
  invite_state VARCHAR(32) NOT NULL DEFAULT 'pending'
    CHECK (invite_state IN ('pending', 'declined', 'reschedule_pending', 'ready')),
  reservation_state VARCHAR(32) NOT NULL DEFAULT 'pending'
    CHECK (reservation_state IN ('pending', 'retry', 'confirmed')),
  reservation_handled_by INTEGER REFERENCES app.users(id) ON DELETE SET NULL,
  reservation_contact_phone VARCHAR(64),
  google_event_id TEXT,
  last_declined_by INTEGER REFERENCES app.users(id) ON DELETE SET NULL,
  last_reschedule_by INTEGER REFERENCES app.users(id) ON DELETE SET NULL,
  last_reschedule_date DATE,
  last_reschedule_time TIME,
  reservation_confirmed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS app.padel_community_plan_players (
  id SERIAL PRIMARY KEY,
  plan_id INTEGER NOT NULL REFERENCES app.padel_community_plans(id) ON DELETE CASCADE,
  user_id INTEGER NOT NULL REFERENCES app.users(id) ON DELETE CASCADE,
  role VARCHAR(16) NOT NULL DEFAULT 'player'
    CHECK (role IN ('organizer', 'player')),
  response_state VARCHAR(16) NOT NULL DEFAULT 'pending'
    CHECK (response_state IN ('pending', 'accepted', 'declined')),
  responded_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (plan_id, user_id)
);

CREATE TABLE IF NOT EXISTS app.padel_community_notifications (
  id SERIAL PRIMARY KEY,
  plan_id INTEGER NOT NULL REFERENCES app.padel_community_plans(id) ON DELETE CASCADE,
  user_id INTEGER NOT NULL REFERENCES app.users(id) ON DELETE CASCADE,
  type VARCHAR(32) NOT NULL
    CHECK (type IN ('member_declined', 'reschedule_proposed', 'reservation_retry', 'reservation_confirmed')),
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_padel_community_plans_created_by
  ON app.padel_community_plans(created_by);

CREATE INDEX IF NOT EXISTS idx_padel_community_plans_invite_state
  ON app.padel_community_plans(invite_state);

CREATE INDEX IF NOT EXISTS idx_padel_community_plans_reservation_state
  ON app.padel_community_plans(reservation_state);

CREATE INDEX IF NOT EXISTS idx_padel_community_plans_venue_id
  ON app.padel_community_plans(venue_id);

CREATE INDEX IF NOT EXISTS idx_padel_community_plan_players_plan_id
  ON app.padel_community_plan_players(plan_id);

CREATE INDEX IF NOT EXISTS idx_padel_community_plan_players_user_id
  ON app.padel_community_plan_players(user_id);

CREATE INDEX IF NOT EXISTS idx_padel_community_notifications_user_unread
  ON app.padel_community_notifications(user_id, is_read, created_at DESC);

DROP TRIGGER IF EXISTS trg_padel_community_plans_updated_at
  ON app.padel_community_plans;
CREATE TRIGGER trg_padel_community_plans_updated_at
BEFORE UPDATE ON app.padel_community_plans
FOR EACH ROW
EXECUTE FUNCTION app.set_updated_at();

DROP TRIGGER IF EXISTS trg_padel_community_plan_players_updated_at
  ON app.padel_community_plan_players;
CREATE TRIGGER trg_padel_community_plan_players_updated_at
BEFORE UPDATE ON app.padel_community_plan_players
FOR EACH ROW
EXECUTE FUNCTION app.set_updated_at();

ALTER TABLE app.padel_community_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.padel_community_plan_players ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.padel_community_notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS padel_community_plans_server_only
  ON app.padel_community_plans;
CREATE POLICY padel_community_plans_server_only
  ON app.padel_community_plans
  FOR ALL
  USING (FALSE)
  WITH CHECK (FALSE);

DROP POLICY IF EXISTS padel_community_plan_players_server_only
  ON app.padel_community_plan_players;
CREATE POLICY padel_community_plan_players_server_only
  ON app.padel_community_plan_players
  FOR ALL
  USING (FALSE)
  WITH CHECK (FALSE);

DROP POLICY IF EXISTS padel_community_notifications_server_only
  ON app.padel_community_notifications;
CREATE POLICY padel_community_notifications_server_only
  ON app.padel_community_notifications
  FOR ALL
  USING (FALSE)
  WITH CHECK (FALSE);
