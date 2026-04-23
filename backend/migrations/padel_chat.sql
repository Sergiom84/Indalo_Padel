-- =============================================
-- Indalo Padel - Chat conversations/messages
-- =============================================

CREATE TABLE IF NOT EXISTS app.padel_chat_conversations (
  id SERIAL PRIMARY KEY,
  kind VARCHAR(16) NOT NULL,
  created_by INTEGER REFERENCES app.users(id) ON DELETE SET NULL,
  title VARCHAR(120),
  direct_user_low_id INTEGER REFERENCES app.users(id) ON DELETE CASCADE,
  direct_user_high_id INTEGER REFERENCES app.users(id) ON DELETE CASCADE,
  event_plan_id INTEGER REFERENCES app.padel_community_plans(id) ON DELETE CASCADE,
  last_message_id BIGINT,
  last_message_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS app.padel_chat_participants (
  id SERIAL PRIMARY KEY,
  conversation_id INTEGER NOT NULL REFERENCES app.padel_chat_conversations(id) ON DELETE CASCADE,
  user_id INTEGER NOT NULL REFERENCES app.users(id) ON DELETE CASCADE,
  role VARCHAR(16) NOT NULL DEFAULT 'member',
  last_read_message_id BIGINT,
  last_read_at TIMESTAMPTZ,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (conversation_id, user_id)
);

CREATE TABLE IF NOT EXISTS app.padel_chat_messages (
  id BIGSERIAL PRIMARY KEY,
  conversation_id INTEGER NOT NULL REFERENCES app.padel_chat_conversations(id) ON DELETE CASCADE,
  sender_user_id INTEGER NOT NULL REFERENCES app.users(id) ON DELETE CASCADE,
  body TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'padel_chat_conversations_kind_check'
  ) THEN
    ALTER TABLE app.padel_chat_conversations
      ADD CONSTRAINT padel_chat_conversations_kind_check
      CHECK (kind IN ('direct', 'group', 'event'));
  END IF;
END;
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'padel_chat_conversations_shape_check'
  ) THEN
    ALTER TABLE app.padel_chat_conversations
      ADD CONSTRAINT padel_chat_conversations_shape_check
      CHECK (
        (kind = 'direct'
          AND direct_user_low_id IS NOT NULL
          AND direct_user_high_id IS NOT NULL
          AND direct_user_low_id < direct_user_high_id
          AND event_plan_id IS NULL)
        OR
        (kind = 'group'
          AND direct_user_low_id IS NULL
          AND direct_user_high_id IS NULL
          AND event_plan_id IS NULL)
        OR
        (kind = 'event'
          AND direct_user_low_id IS NULL
          AND direct_user_high_id IS NULL
          AND event_plan_id IS NOT NULL)
      );
  END IF;
END;
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'padel_chat_conversations_group_title_check'
  ) THEN
    ALTER TABLE app.padel_chat_conversations
      ADD CONSTRAINT padel_chat_conversations_group_title_check
      CHECK (kind <> 'group' OR NULLIF(BTRIM(title), '') IS NOT NULL);
  END IF;
END;
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'padel_chat_conversations_direct_pair_key'
  ) THEN
    ALTER TABLE app.padel_chat_conversations
      ADD CONSTRAINT padel_chat_conversations_direct_pair_key
      UNIQUE (kind, direct_user_low_id, direct_user_high_id);
  END IF;
END;
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'padel_chat_conversations_event_key'
  ) THEN
    ALTER TABLE app.padel_chat_conversations
      ADD CONSTRAINT padel_chat_conversations_event_key
      UNIQUE (kind, event_plan_id);
  END IF;
END;
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'padel_chat_participants_role_check'
  ) THEN
    ALTER TABLE app.padel_chat_participants
      ADD CONSTRAINT padel_chat_participants_role_check
      CHECK (role IN ('owner', 'member'));
  END IF;
END;
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'padel_chat_messages_body_check'
  ) THEN
    ALTER TABLE app.padel_chat_messages
      ADD CONSTRAINT padel_chat_messages_body_check
      CHECK (CHAR_LENGTH(BTRIM(body)) BETWEEN 1 AND 4000);
  END IF;
END;
$$;

CREATE INDEX IF NOT EXISTS idx_padel_chat_conversations_last_message_at
  ON app.padel_chat_conversations(COALESCE(last_message_at, created_at) DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_padel_chat_conversations_created_by
  ON app.padel_chat_conversations(created_by);

CREATE INDEX IF NOT EXISTS idx_padel_chat_participants_user_id
  ON app.padel_chat_participants(user_id, conversation_id);

CREATE INDEX IF NOT EXISTS idx_padel_chat_messages_conversation_id
  ON app.padel_chat_messages(conversation_id, id DESC);

CREATE INDEX IF NOT EXISTS idx_padel_chat_messages_sender_user_id
  ON app.padel_chat_messages(sender_user_id, created_at DESC);

CREATE OR REPLACE FUNCTION app.padel_chat_validate_message_sender()
RETURNS TRIGGER AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM app.padel_chat_participants participant
    WHERE participant.conversation_id = NEW.conversation_id
      AND participant.user_id = NEW.sender_user_id
  ) THEN
    RAISE EXCEPTION
      'User % is not a participant in conversation %',
      NEW.sender_user_id,
      NEW.conversation_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
SET search_path = '';

CREATE OR REPLACE FUNCTION app.padel_chat_after_message_insert()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE app.padel_chat_conversations
  SET last_message_id = NEW.id,
      last_message_at = NEW.created_at,
      updated_at = NOW()
  WHERE id = NEW.conversation_id;

  UPDATE app.padel_chat_participants
  SET last_read_message_id = NEW.id,
      last_read_at = NEW.created_at,
      updated_at = NOW()
  WHERE conversation_id = NEW.conversation_id
    AND user_id = NEW.sender_user_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
SET search_path = '';

DROP TRIGGER IF EXISTS trg_padel_chat_conversations_updated_at
  ON app.padel_chat_conversations;
CREATE TRIGGER trg_padel_chat_conversations_updated_at
BEFORE UPDATE ON app.padel_chat_conversations
FOR EACH ROW
EXECUTE FUNCTION app.set_updated_at();

DROP TRIGGER IF EXISTS trg_padel_chat_participants_updated_at
  ON app.padel_chat_participants;
CREATE TRIGGER trg_padel_chat_participants_updated_at
BEFORE UPDATE ON app.padel_chat_participants
FOR EACH ROW
EXECUTE FUNCTION app.set_updated_at();

DROP TRIGGER IF EXISTS trg_padel_chat_messages_updated_at
  ON app.padel_chat_messages;
CREATE TRIGGER trg_padel_chat_messages_updated_at
BEFORE UPDATE ON app.padel_chat_messages
FOR EACH ROW
EXECUTE FUNCTION app.set_updated_at();

DROP TRIGGER IF EXISTS trg_padel_chat_validate_message_sender
  ON app.padel_chat_messages;
CREATE TRIGGER trg_padel_chat_validate_message_sender
BEFORE INSERT ON app.padel_chat_messages
FOR EACH ROW
EXECUTE FUNCTION app.padel_chat_validate_message_sender();

DROP TRIGGER IF EXISTS trg_padel_chat_after_message_insert
  ON app.padel_chat_messages;
CREATE TRIGGER trg_padel_chat_after_message_insert
AFTER INSERT ON app.padel_chat_messages
FOR EACH ROW
EXECUTE FUNCTION app.padel_chat_after_message_insert();

ALTER TABLE app.padel_chat_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.padel_chat_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.padel_chat_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS padel_chat_conversations_server_only
  ON app.padel_chat_conversations;
CREATE POLICY padel_chat_conversations_server_only
  ON app.padel_chat_conversations
  FOR ALL
  USING (FALSE)
  WITH CHECK (FALSE);

DROP POLICY IF EXISTS padel_chat_participants_server_only
  ON app.padel_chat_participants;
CREATE POLICY padel_chat_participants_server_only
  ON app.padel_chat_participants
  FOR ALL
  USING (FALSE)
  WITH CHECK (FALSE);

DROP POLICY IF EXISTS padel_chat_messages_server_only
  ON app.padel_chat_messages;
CREATE POLICY padel_chat_messages_server_only
  ON app.padel_chat_messages
  FOR ALL
  USING (FALSE)
  WITH CHECK (FALSE);
