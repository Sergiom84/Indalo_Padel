-- Bridge between legacy app.users integer IDs and Supabase Auth UUID users.

ALTER TABLE app.users
  ADD COLUMN IF NOT EXISTS auth_user_id UUID;

CREATE UNIQUE INDEX IF NOT EXISTS users_auth_user_id_unique
  ON app.users (auth_user_id)
  WHERE auth_user_id IS NOT NULL;

UPDATE app.users u
SET auth_user_id = au.id
FROM auth.users au
WHERE u.auth_user_id IS NULL
  AND lower(u.email) = lower(au.email);
