ALTER TABLE app.padel_community_plans
  ADD COLUMN IF NOT EXISTS modality VARCHAR(16),
  ADD COLUMN IF NOT EXISTS capacity INTEGER,
  ADD COLUMN IF NOT EXISTS post_padel_plan VARCHAR(160),
  ADD COLUMN IF NOT EXISTS notes TEXT;

UPDATE app.padel_community_plans
SET modality = COALESCE(NULLIF(BTRIM(modality), ''), 'amistoso')
WHERE modality IS NULL OR BTRIM(modality) = '';

UPDATE app.padel_community_plans
SET capacity = CASE
  WHEN COALESCE(NULLIF(BTRIM(modality), ''), 'amistoso') = 'americana' THEN 8
  ELSE COALESCE(capacity, 4)
END
WHERE capacity IS NULL OR capacity <= 0;

ALTER TABLE app.padel_community_plans
  ALTER COLUMN modality SET DEFAULT 'amistoso',
  ALTER COLUMN modality SET NOT NULL,
  ALTER COLUMN capacity SET DEFAULT 4,
  ALTER COLUMN capacity SET NOT NULL;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'padel_community_plans_modality_check'
  ) THEN
    ALTER TABLE app.padel_community_plans
      DROP CONSTRAINT padel_community_plans_modality_check;
  END IF;

  ALTER TABLE app.padel_community_plans
    ADD CONSTRAINT padel_community_plans_modality_check
    CHECK (modality IN ('amistoso', 'competitivo', 'americana'));
END;
$$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'padel_community_plans_capacity_check'
  ) THEN
    ALTER TABLE app.padel_community_plans
      DROP CONSTRAINT padel_community_plans_capacity_check;
  END IF;

  ALTER TABLE app.padel_community_plans
    ADD CONSTRAINT padel_community_plans_capacity_check
    CHECK (capacity IN (4, 8));
END;
$$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'padel_community_plans_modality_capacity_check'
  ) THEN
    ALTER TABLE app.padel_community_plans
      DROP CONSTRAINT padel_community_plans_modality_capacity_check;
  END IF;

  ALTER TABLE app.padel_community_plans
    ADD CONSTRAINT padel_community_plans_modality_capacity_check
    CHECK (
      (modality = 'americana' AND capacity = 8)
      OR (modality IN ('amistoso', 'competitivo') AND capacity = 4)
    );
END;
$$;

CREATE INDEX IF NOT EXISTS idx_padel_community_plans_modality
  ON app.padel_community_plans(modality);

ALTER TABLE app.padel_player_profiles
  DROP CONSTRAINT IF EXISTS padel_player_profiles_availability_preferences_check;

ALTER TABLE app.padel_player_profiles
  ADD CONSTRAINT padel_player_profiles_availability_preferences_check
  CHECK (
    availability_preferences <@ ARRAY[
      'laborables',
      'fin_de_semana',
      'cualquiera',
      'mananas',
      'mediodias',
      'tardes_noches',
      'flexible'
    ]::TEXT[]
  );
