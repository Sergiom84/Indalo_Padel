-- =============================================
-- Indalo Padel - Chat media attachments
-- Stores chat media in Supabase Storage, not Postgres.
-- =============================================

INSERT INTO storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
VALUES (
  'chat-media',
  'chat-media',
  FALSE,
  3145728,
  ARRAY[
    'image/webp',
    'audio/aac',
    'audio/mp4',
    'audio/mpeg',
    'audio/ogg',
    'audio/webm',
    'audio/wav'
  ]
)
ON CONFLICT (id)
DO UPDATE
  SET public = EXCLUDED.public,
      file_size_limit = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types,
      updated_at = NOW();

ALTER TABLE app.padel_chat_messages
  ADD COLUMN IF NOT EXISTS message_type VARCHAR(16) NOT NULL DEFAULT 'text';

UPDATE app.padel_chat_messages
SET message_type = 'text'
WHERE message_type IS NULL;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'padel_chat_messages_message_type_check'
  ) THEN
    ALTER TABLE app.padel_chat_messages
      DROP CONSTRAINT padel_chat_messages_message_type_check;
  END IF;

  ALTER TABLE app.padel_chat_messages
    ADD CONSTRAINT padel_chat_messages_message_type_check
    CHECK (message_type IN ('text', 'image', 'voice'));
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'padel_chat_messages_body_check'
  ) THEN
    ALTER TABLE app.padel_chat_messages
      DROP CONSTRAINT padel_chat_messages_body_check;
  END IF;

  ALTER TABLE app.padel_chat_messages
    ADD CONSTRAINT padel_chat_messages_body_check
    CHECK (
      (
        message_type = 'text'
        AND CHAR_LENGTH(BTRIM(body)) BETWEEN 1 AND 4000
      )
      OR
      (
        message_type IN ('image', 'voice')
        AND CHAR_LENGTH(body) <= 4000
      )
    );
END $$;

CREATE TABLE IF NOT EXISTS app.padel_chat_attachments (
  id BIGSERIAL PRIMARY KEY,
  message_id BIGINT NOT NULL UNIQUE REFERENCES app.padel_chat_messages(id) ON DELETE CASCADE,
  conversation_id INTEGER NOT NULL REFERENCES app.padel_chat_conversations(id) ON DELETE CASCADE,
  uploader_user_id INTEGER NOT NULL REFERENCES app.users(id) ON DELETE CASCADE,
  kind VARCHAR(16) NOT NULL,
  bucket TEXT NOT NULL DEFAULT 'chat-media',
  object_path TEXT NOT NULL UNIQUE,
  mime_type TEXT NOT NULL,
  size_bytes INTEGER NOT NULL,
  width INTEGER,
  height INTEGER,
  duration_seconds INTEGER,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'padel_chat_attachments_kind_check'
  ) THEN
    ALTER TABLE app.padel_chat_attachments
      ADD CONSTRAINT padel_chat_attachments_kind_check
      CHECK (kind IN ('image', 'voice'));
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'padel_chat_attachments_size_check'
  ) THEN
    ALTER TABLE app.padel_chat_attachments
      ADD CONSTRAINT padel_chat_attachments_size_check
      CHECK (size_bytes > 0 AND size_bytes <= 3145728);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'padel_chat_attachments_voice_duration_check'
  ) THEN
    ALTER TABLE app.padel_chat_attachments
      ADD CONSTRAINT padel_chat_attachments_voice_duration_check
      CHECK (
        kind <> 'voice'
        OR (
          duration_seconds IS NOT NULL
          AND duration_seconds BETWEEN 1 AND 60
        )
      );
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_padel_chat_attachments_conversation_id
  ON app.padel_chat_attachments(conversation_id, id DESC);

CREATE INDEX IF NOT EXISTS idx_padel_chat_attachments_message_id
  ON app.padel_chat_attachments(message_id);

DROP TRIGGER IF EXISTS trg_padel_chat_attachments_updated_at
  ON app.padel_chat_attachments;
CREATE TRIGGER trg_padel_chat_attachments_updated_at
BEFORE UPDATE ON app.padel_chat_attachments
FOR EACH ROW
EXECUTE FUNCTION app.set_updated_at();

ALTER TABLE app.padel_chat_attachments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS padel_chat_attachments_server_only
  ON app.padel_chat_attachments;
CREATE POLICY padel_chat_attachments_server_only
  ON app.padel_chat_attachments
  FOR ALL
  USING (FALSE)
  WITH CHECK (FALSE);
