-- Resultados de partido para convocatorias de comunidad.
-- Cada jugador envía su propia versión (pareja, equipo ganador, sets) y cuando
-- todas coinciden se consolida en padel_match_results con status='consensuado'.

CREATE TABLE IF NOT EXISTS app.padel_match_result_submissions (
  id SERIAL PRIMARY KEY,
  plan_id INTEGER NOT NULL REFERENCES app.padel_community_plans(id) ON DELETE CASCADE,
  user_id INTEGER NOT NULL REFERENCES app.users(id) ON DELETE CASCADE,
  partner_user_id INTEGER REFERENCES app.users(id) ON DELETE SET NULL,
  winner_team SMALLINT NOT NULL CHECK (winner_team IN (1, 2)),
  sets JSONB NOT NULL,
  submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (plan_id, user_id)
);

CREATE TABLE IF NOT EXISTS app.padel_match_results (
  id SERIAL PRIMARY KEY,
  plan_id INTEGER NOT NULL UNIQUE REFERENCES app.padel_community_plans(id) ON DELETE CASCADE,
  status VARCHAR(16) NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'consensuado', 'disputa')),
  team_a_user_ids INTEGER[] NOT NULL DEFAULT '{}',
  team_b_user_ids INTEGER[] NOT NULL DEFAULT '{}',
  winner_team SMALLINT CHECK (winner_team IN (1, 2)),
  sets JSONB,
  resolved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_padel_match_result_submissions_plan_id
  ON app.padel_match_result_submissions(plan_id);

CREATE INDEX IF NOT EXISTS idx_padel_match_result_submissions_user_id
  ON app.padel_match_result_submissions(user_id);

CREATE INDEX IF NOT EXISTS idx_padel_match_results_status
  ON app.padel_match_results(status);

DROP TRIGGER IF EXISTS trg_padel_match_result_submissions_updated_at
  ON app.padel_match_result_submissions;
CREATE TRIGGER trg_padel_match_result_submissions_updated_at
BEFORE UPDATE ON app.padel_match_result_submissions
FOR EACH ROW
EXECUTE FUNCTION app.set_updated_at();

DROP TRIGGER IF EXISTS trg_padel_match_results_updated_at
  ON app.padel_match_results;
CREATE TRIGGER trg_padel_match_results_updated_at
BEFORE UPDATE ON app.padel_match_results
FOR EACH ROW
EXECUTE FUNCTION app.set_updated_at();

ALTER TABLE app.padel_match_result_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.padel_match_results ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS padel_match_result_submissions_server_only
  ON app.padel_match_result_submissions;
CREATE POLICY padel_match_result_submissions_server_only
  ON app.padel_match_result_submissions
  FOR ALL
  USING (FALSE)
  WITH CHECK (FALSE);

DROP POLICY IF EXISTS padel_match_results_server_only
  ON app.padel_match_results;
CREATE POLICY padel_match_results_server_only
  ON app.padel_match_results
  FOR ALL
  USING (FALSE)
  WITH CHECK (FALSE);
