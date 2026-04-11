-- =============================================
-- Indalo Padel - Player profile preferences
-- Sustituye preferred_side por preferencias multi-seleccionables.
-- =============================================

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'app'
      AND table_name = 'padel_player_profiles'
  ) THEN
    ALTER TABLE app.padel_player_profiles
      ADD COLUMN IF NOT EXISTS court_preferences TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
      ADD COLUMN IF NOT EXISTS dominant_hands TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
      ADD COLUMN IF NOT EXISTS availability_preferences TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
      ADD COLUMN IF NOT EXISTS match_preferences TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[];
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'app'
      AND table_name = 'padel_player_profiles'
      AND column_name = 'preferred_side'
  ) THEN
    UPDATE app.padel_player_profiles
    SET court_preferences = CASE preferred_side
      WHEN 'drive' THEN ARRAY['drive']::TEXT[]
      WHEN 'reves' THEN ARRAY['reves']::TEXT[]
      WHEN 'ambos' THEN ARRAY['ambos']::TEXT[]
      ELSE ARRAY[]::TEXT[]
    END
    WHERE COALESCE(array_length(court_preferences, 1), 0) = 0;

    ALTER TABLE app.padel_player_profiles
      DROP COLUMN preferred_side;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'padel_player_profiles_court_preferences_check'
  ) THEN
    ALTER TABLE app.padel_player_profiles
      ADD CONSTRAINT padel_player_profiles_court_preferences_check
      CHECK (court_preferences <@ ARRAY['drive', 'reves', 'ambos']::TEXT[]);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'padel_player_profiles_dominant_hands_check'
  ) THEN
    ALTER TABLE app.padel_player_profiles
      ADD CONSTRAINT padel_player_profiles_dominant_hands_check
      CHECK (dominant_hands <@ ARRAY['diestro', 'zurdo', 'ambidiestro']::TEXT[]);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'padel_player_profiles_availability_preferences_check'
  ) THEN
    ALTER TABLE app.padel_player_profiles
      ADD CONSTRAINT padel_player_profiles_availability_preferences_check
      CHECK (
        availability_preferences <@ ARRAY[
          'mananas',
          'mediodias',
          'tardes_noches',
          'flexible'
        ]::TEXT[]
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'padel_player_profiles_match_preferences_check'
  ) THEN
    ALTER TABLE app.padel_player_profiles
      ADD CONSTRAINT padel_player_profiles_match_preferences_check
      CHECK (
        match_preferences <@ ARRAY['amistoso', 'competitivo', 'americana']::TEXT[]
      );
  END IF;
END $$;
