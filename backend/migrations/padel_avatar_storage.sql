-- =============================================
-- Indalo Padel - Avatar storage safety
-- Evita volver a guardar imagenes base64 en Postgres.
-- =============================================

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'app'
      AND table_name = 'padel_player_profiles'
  ) THEN
    UPDATE app.padel_player_profiles
    SET avatar_url = NULL
    WHERE avatar_url ~* '^data:image/.+;base64,';
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'app'
      AND table_name = 'padel_player_profiles'
  ) AND NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'padel_player_profiles_avatar_url_storage_check'
  ) THEN
    ALTER TABLE app.padel_player_profiles
      ADD CONSTRAINT padel_player_profiles_avatar_url_storage_check
      CHECK (
        avatar_url IS NULL
        OR avatar_url = ''
        OR (
          length(avatar_url) <= 2048
          AND avatar_url !~* '^data:'
        )
      );
  END IF;
END $$;
