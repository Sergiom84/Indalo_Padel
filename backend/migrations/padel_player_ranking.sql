-- Ranking de jugadores basado en resultados consensuados.
-- Puntuacion: victoria = 3 puntos, derrota = 1 punto.

ALTER TABLE app.padel_player_profiles
  ADD COLUMN IF NOT EXISTS matches_lost INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS ranking_points INTEGER NOT NULL DEFAULT 0;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'padel_player_profiles_matches_lost_check'
  ) THEN
    ALTER TABLE app.padel_player_profiles
      ADD CONSTRAINT padel_player_profiles_matches_lost_check
      CHECK (matches_lost >= 0);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'padel_player_profiles_ranking_points_check'
  ) THEN
    ALTER TABLE app.padel_player_profiles
      ADD CONSTRAINT padel_player_profiles_ranking_points_check
      CHECK (ranking_points >= 0);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_padel_player_profiles_ranking
  ON app.padel_player_profiles(
    ranking_points DESC,
    matches_won DESC,
    matches_lost ASC,
    matches_played DESC
  );

CREATE OR REPLACE FUNCTION app.recalculate_player_ranking_stats()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  WITH profile_users AS (
    SELECT
      user_id,
      COALESCE(matches_played, 0) AS stored_played,
      COALESCE(matches_won, 0) AS stored_won
    FROM app.padel_player_profiles
  ),
  community_members AS (
    SELECT DISTINCT cpp.plan_id, cpp.user_id
    FROM app.padel_community_plan_players cpp
    JOIN app.padel_community_plans cp ON cp.id = cpp.plan_id
    WHERE cpp.response_state = 'accepted'
       OR cpp.user_id = cp.created_by

    UNION

    SELECT id AS plan_id, created_by AS user_id
    FROM app.padel_community_plans
  ),
  finished_community_plans AS (
    SELECT id
    FROM app.padel_community_plans
    WHERE reservation_state = 'confirmed'
      AND invite_state NOT IN ('cancelled', 'expired')
      AND reservation_state NOT IN ('cancelled', 'expired')
      AND (
        scheduled_date::timestamp
        + scheduled_time
        + make_interval(mins => COALESCE(duration_minutes, 90))
        + INTERVAL '1 minute'
      ) <= (NOW() AT TIME ZONE 'Europe/Madrid')
  ),
  community_played AS (
    SELECT cm.user_id, COUNT(DISTINCT cm.plan_id)::int AS total
    FROM community_members cm
    JOIN finished_community_plans fcp ON fcp.id = cm.plan_id
    GROUP BY cm.user_id
  ),
  legacy_played AS (
    SELECT mp.user_id, COUNT(DISTINCT m.id)::int AS total
    FROM app.padel_match_players mp
    JOIN app.padel_matches m ON m.id = mp.match_id
    WHERE mp.status <> 'abandonado'
      AND m.status = 'finalizado'
    GROUP BY mp.user_id
  ),
  result_members AS (
    SELECT DISTINCT
      mr.plan_id,
      winners.user_id,
      TRUE AS won
    FROM app.padel_match_results mr
    CROSS JOIN LATERAL UNNEST(
      CASE
        WHEN mr.winner_team = 1 THEN mr.team_a_user_ids
        WHEN mr.winner_team = 2 THEN mr.team_b_user_ids
        ELSE ARRAY[]::int[]
      END
    ) AS winners(user_id)
    WHERE mr.status = 'consensuado'

    UNION

    SELECT DISTINCT
      mr.plan_id,
      losers.user_id,
      FALSE AS won
    FROM app.padel_match_results mr
    CROSS JOIN LATERAL UNNEST(
      CASE
        WHEN mr.winner_team = 1 THEN mr.team_b_user_ids
        WHEN mr.winner_team = 2 THEN mr.team_a_user_ids
        ELSE ARRAY[]::int[]
      END
    ) AS losers(user_id)
    WHERE mr.status = 'consensuado'
  ),
  result_stats AS (
    SELECT
      user_id,
      COUNT(DISTINCT plan_id) FILTER (WHERE won)::int AS matches_won,
      COUNT(DISTINCT plan_id) FILTER (WHERE NOT won)::int AS matches_lost
    FROM result_members
    GROUP BY user_id
  ),
  final_stats AS (
    SELECT
      pu.user_id,
      GREATEST(
        pu.stored_played,
        COALESCE(cp.total, 0) + COALESCE(lp.total, 0),
        COALESCE(rs.matches_won, 0) + COALESCE(rs.matches_lost, 0)
      )::int AS matches_played,
      GREATEST(pu.stored_won, COALESCE(rs.matches_won, 0))::int
        AS matches_won,
      COALESCE(rs.matches_lost, 0)::int AS matches_lost
    FROM profile_users pu
    LEFT JOIN community_played cp ON cp.user_id = pu.user_id
    LEFT JOIN legacy_played lp ON lp.user_id = pu.user_id
    LEFT JOIN result_stats rs ON rs.user_id = pu.user_id
  )
  UPDATE app.padel_player_profiles pp
  SET matches_played = fs.matches_played,
      matches_won = fs.matches_won,
      matches_lost = fs.matches_lost,
      ranking_points = ((fs.matches_won * 3) + fs.matches_lost),
      updated_at = NOW()
  FROM final_stats fs
  WHERE pp.user_id = fs.user_id;
END;
$$;

CREATE OR REPLACE FUNCTION app.trg_recalculate_player_ranking_stats()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM app.recalculate_player_ranking_stats();
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_padel_match_results_recalculate_player_ranking_stats
  ON app.padel_match_results;
CREATE TRIGGER trg_padel_match_results_recalculate_player_ranking_stats
AFTER INSERT OR UPDATE OR DELETE ON app.padel_match_results
FOR EACH STATEMENT
EXECUTE FUNCTION app.trg_recalculate_player_ranking_stats();

SELECT app.recalculate_player_ranking_stats();
