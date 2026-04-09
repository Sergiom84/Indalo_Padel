-- =============================================
-- Indalo Padel - Venue deduplication
-- Limpia sedes repetidas generadas por reruns de seed_data
-- y evita que vuelvan a aparecer duplicados activos.
-- =============================================

CREATE TEMP TABLE tmp_padel_venue_dedup AS
WITH venue_stats AS (
  SELECT
    v.id,
    v.name,
    v.location,
    COUNT(c.id) FILTER (WHERE c.is_active = true) AS active_court_count
  FROM app.padel_venues v
  LEFT JOIN app.padel_courts c
    ON c.venue_id = v.id
  WHERE v.is_active = true
  GROUP BY v.id, v.name, v.location
),
ranked AS (
  SELECT
    id AS duplicate_id,
    active_court_count,
    FIRST_VALUE(id) OVER (
      PARTITION BY LOWER(BTRIM(name)), LOWER(BTRIM(location))
      ORDER BY active_court_count DESC, id ASC
    ) AS canonical_id,
    ROW_NUMBER() OVER (
      PARTITION BY LOWER(BTRIM(name)), LOWER(BTRIM(location))
      ORDER BY active_court_count DESC, id ASC
    ) AS row_num
  FROM venue_stats
)
SELECT duplicate_id, canonical_id, active_court_count
FROM ranked
WHERE row_num > 1;

UPDATE app.padel_player_profiles p
SET preferred_venue_id = d.canonical_id
FROM tmp_padel_venue_dedup d
WHERE p.preferred_venue_id = d.duplicate_id;

UPDATE app.padel_matches m
SET venue_id = d.canonical_id
FROM tmp_padel_venue_dedup d
WHERE m.venue_id = d.duplicate_id;

DELETE FROM app.padel_venues v
USING tmp_padel_venue_dedup d
WHERE v.id = d.duplicate_id
  AND d.active_court_count = 0;

UPDATE app.padel_venues v
SET is_active = false,
    updated_at = NOW()
FROM tmp_padel_venue_dedup d
WHERE v.id = d.duplicate_id
  AND d.active_court_count > 0;

DROP TABLE tmp_padel_venue_dedup;

CREATE UNIQUE INDEX IF NOT EXISTS idx_padel_venues_unique_active_name_location
  ON app.padel_venues (LOWER(BTRIM(name)), LOWER(BTRIM(location)))
  WHERE is_active = true;
