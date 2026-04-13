ALTER TABLE app.users
  ADD COLUMN IF NOT EXISTS email_verified_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS email_verification_token_hash TEXT,
  ADD COLUMN IF NOT EXISTS email_verification_sent_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS email_verification_expires_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS password_reset_token_hash TEXT,
  ADD COLUMN IF NOT EXISTS password_reset_sent_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS password_reset_expires_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS deleted_reason VARCHAR(32),
  ADD COLUMN IF NOT EXISTS deleted_reason_other TEXT,
  ADD COLUMN IF NOT EXISTS deleted_email VARCHAR(100);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'users_deleted_reason_check'
  ) THEN
    ALTER TABLE app.users
      ADD CONSTRAINT users_deleted_reason_check
      CHECK (
        deleted_reason IS NULL
        OR deleted_reason IN (
          'no_uso_la_app',
          'no_me_gusta',
          'no_es_lo_que_buscaba',
          'otros'
        )
      );
  END IF;
END;
$$;

UPDATE app.users
SET email_verified_at = COALESCE(email_verified_at, created_at)
WHERE deleted_at IS NULL
  AND email_verified_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_users_email_verification_token_hash
  ON app.users(email_verification_token_hash)
  WHERE email_verification_token_hash IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_users_password_reset_token_hash
  ON app.users(password_reset_token_hash)
  WHERE password_reset_token_hash IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_users_deleted_at
  ON app.users(deleted_at)
  WHERE deleted_at IS NOT NULL;
