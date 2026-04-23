-- =============================================
-- Indalo Padel - Social/local open events
-- =============================================

CREATE TABLE IF NOT EXISTS app.padel_social_events (
  id SERIAL PRIMARY KEY,
  created_by INTEGER REFERENCES app.users(id) ON DELETE SET NULL,
  title VARCHAR(120) NOT NULL,
  description TEXT,
  venue_name VARCHAR(120),
  location VARCHAR(160),
  scheduled_date DATE NOT NULL,
  scheduled_time TIME NOT NULL,
  duration_minutes INTEGER NOT NULL DEFAULT 90,
  status VARCHAR(16) NOT NULL DEFAULT 'active',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (CHAR_LENGTH(BTRIM(title)) BETWEEN 1 AND 120),
  CHECK (duration_minutes BETWEEN 30 AND 480),
  CHECK (status IN ('active', 'cancelled'))
);

ALTER TABLE app.padel_chat_conversations
  ADD COLUMN IF NOT EXISTS social_event_id INTEGER
    REFERENCES app.padel_social_events(id) ON DELETE CASCADE;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'padel_chat_conversations_kind_check'
  ) THEN
    ALTER TABLE app.padel_chat_conversations
      DROP CONSTRAINT padel_chat_conversations_kind_check;
  END IF;

  ALTER TABLE app.padel_chat_conversations
    ADD CONSTRAINT padel_chat_conversations_kind_check
    CHECK (kind IN ('direct', 'group', 'event', 'social_event'));
END;
$$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'padel_chat_conversations_shape_check'
  ) THEN
    ALTER TABLE app.padel_chat_conversations
      DROP CONSTRAINT padel_chat_conversations_shape_check;
  END IF;

  ALTER TABLE app.padel_chat_conversations
    ADD CONSTRAINT padel_chat_conversations_shape_check
    CHECK (
      (kind = 'direct'
        AND direct_user_low_id IS NOT NULL
        AND direct_user_high_id IS NOT NULL
        AND direct_user_low_id < direct_user_high_id
        AND event_plan_id IS NULL
        AND social_event_id IS NULL)
      OR
      (kind = 'group'
        AND direct_user_low_id IS NULL
        AND direct_user_high_id IS NULL
        AND event_plan_id IS NULL
        AND social_event_id IS NULL)
      OR
      (kind = 'event'
        AND direct_user_low_id IS NULL
        AND direct_user_high_id IS NULL
        AND event_plan_id IS NOT NULL
        AND social_event_id IS NULL)
      OR
      (kind = 'social_event'
        AND direct_user_low_id IS NULL
        AND direct_user_high_id IS NULL
        AND event_plan_id IS NULL
        AND social_event_id IS NOT NULL)
    );
END;
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'padel_chat_conversations_social_event_key'
  ) THEN
    ALTER TABLE app.padel_chat_conversations
      ADD CONSTRAINT padel_chat_conversations_social_event_key
      UNIQUE (kind, social_event_id);
  END IF;
END;
$$;

CREATE INDEX IF NOT EXISTS idx_padel_social_events_schedule
  ON app.padel_social_events(status, scheduled_date, scheduled_time);

CREATE INDEX IF NOT EXISTS idx_padel_social_events_created_by
  ON app.padel_social_events(created_by);

CREATE INDEX IF NOT EXISTS idx_padel_chat_conversations_social_event
  ON app.padel_chat_conversations(social_event_id)
  WHERE social_event_id IS NOT NULL;

DROP TRIGGER IF EXISTS trg_padel_social_events_updated_at
  ON app.padel_social_events;
CREATE TRIGGER trg_padel_social_events_updated_at
BEFORE UPDATE ON app.padel_social_events
FOR EACH ROW
EXECUTE FUNCTION app.set_updated_at();

ALTER TABLE app.padel_social_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS padel_social_events_server_only
  ON app.padel_social_events;
CREATE POLICY padel_social_events_server_only
  ON app.padel_social_events
  FOR ALL
  USING (FALSE)
  WITH CHECK (FALSE);
