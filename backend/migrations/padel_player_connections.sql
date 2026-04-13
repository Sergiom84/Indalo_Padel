-- =============================================
-- Indalo Padel - Player connections / network
-- =============================================

CREATE TABLE IF NOT EXISTS app.padel_player_connections (
  id SERIAL PRIMARY KEY,
  user_a_id INTEGER NOT NULL REFERENCES app.users(id) ON DELETE CASCADE,
  user_b_id INTEGER NOT NULL REFERENCES app.users(id) ON DELETE CASCADE,
  requested_by INTEGER NOT NULL REFERENCES app.users(id) ON DELETE CASCADE,
  responded_by INTEGER REFERENCES app.users(id) ON DELETE SET NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'pending',
  requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  responded_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (user_a_id != user_b_id),
  CHECK (user_a_id < user_b_id),
  CHECK (requested_by IN (user_a_id, user_b_id)),
  CHECK (responded_by IS NULL OR responded_by IN (user_a_id, user_b_id)),
  CHECK (status IN ('pending', 'accepted', 'rejected')),
  CHECK (
    (status = 'pending' AND responded_by IS NULL AND responded_at IS NULL) OR
    (status IN ('accepted', 'rejected') AND responded_by IS NOT NULL AND responded_at IS NOT NULL)
  )
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_padel_player_connections_pair
  ON app.padel_player_connections(user_a_id, user_b_id);

CREATE INDEX IF NOT EXISTS idx_padel_player_connections_status
  ON app.padel_player_connections(status, requested_at DESC);

CREATE INDEX IF NOT EXISTS idx_padel_player_connections_requested_by
  ON app.padel_player_connections(requested_by, status);

DROP TRIGGER IF EXISTS trg_player_connections_updated_at ON app.padel_player_connections;
CREATE TRIGGER trg_player_connections_updated_at
BEFORE UPDATE ON app.padel_player_connections
FOR EACH ROW EXECUTE FUNCTION app.set_updated_at();

ALTER TABLE app.padel_player_connections ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS player_connections_server_only ON app.padel_player_connections;
CREATE POLICY player_connections_server_only ON app.padel_player_connections
  FOR ALL
  USING (false)
  WITH CHECK (false);
