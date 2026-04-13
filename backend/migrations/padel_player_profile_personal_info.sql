-- =============================================
-- Indalo Padel - Player profile personal info
-- Añade genero, fecha de nacimiento y telefono opcional al perfil.
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
      ADD COLUMN IF NOT EXISTS gender VARCHAR(24),
      ADD COLUMN IF NOT EXISTS birth_date DATE,
      ADD COLUMN IF NOT EXISTS phone VARCHAR(20);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'padel_player_profiles_gender_check'
  ) THEN
    ALTER TABLE app.padel_player_profiles
      ADD CONSTRAINT padel_player_profiles_gender_check
      CHECK (gender IN ('masculino', 'femenino', 'otro', 'prefiero_no_decirlo'));
  END IF;
END $$;
