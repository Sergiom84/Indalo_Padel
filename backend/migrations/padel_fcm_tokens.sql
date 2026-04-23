-- Tokens FCM para push notifications
CREATE TABLE IF NOT EXISTS app.padel_fcm_tokens (
  id          BIGSERIAL    PRIMARY KEY,
  user_id     INTEGER      NOT NULL REFERENCES app.users(id) ON DELETE CASCADE,
  token       TEXT         NOT NULL,
  platform    TEXT         NOT NULL DEFAULT 'android',  -- android | ios
  created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  CONSTRAINT padel_fcm_tokens_token_unique UNIQUE (token)
);

CREATE INDEX IF NOT EXISTS idx_padel_fcm_tokens_user_id ON app.padel_fcm_tokens(user_id);
