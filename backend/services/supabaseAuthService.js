import { pool } from '../db.js';

export class SupabaseAuthError extends Error {
  constructor(message, status = 502, code = 'SUPABASE_AUTH_ERROR') {
    super(message);
    this.name = 'SupabaseAuthError';
    this.status = status;
    this.code = code;
  }
}

function supabaseUrl() {
  const projectRef = (process.env.SUPABASE_PROJECT_REF || '').trim();
  if (projectRef) {
    return `https://${projectRef}.supabase.co`;
  }

  return (process.env.SUPABASE_URL || '').replace(/\/+$/, '');
}

function serviceRoleKey() {
  return (
    process.env.SUPABASE_SERVICE_ROLE_KEY ||
    process.env.SUPABASE_SERVICE_KEY ||
    ''
  );
}

function authApiKey() {
  return (
    process.env.SUPABASE_ANON_KEY ||
    process.env.SUPABASE_PUBLISHABLE_KEY ||
    serviceRoleKey()
  );
}

function authConfig({ requireServiceRole = false } = {}) {
  const url = supabaseUrl();
  const apiKey = authApiKey();
  const serviceKey = serviceRoleKey();

  if (!url || !apiKey || (requireServiceRole && !serviceKey)) {
    return null;
  }

  return { url, apiKey, serviceKey };
}

export function isSupabaseAuthConfigured() {
  return Boolean(authConfig({ requireServiceRole: true }));
}

async function readAuthError(response) {
  const text = await response.text().catch(() => '');
  if (!text) {
    return response.statusText || 'Supabase Auth error';
  }

  try {
    const json = JSON.parse(text);
    return json.msg || json.message || json.error_description || json.error || text;
  } catch {
    return text;
  }
}

async function requestJson(url, { method = 'GET', headers = {}, body } = {}) {
  const response = await fetch(url, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  });

  if (!response.ok) {
    throw new SupabaseAuthError(
      await readAuthError(response),
      response.status,
      'SUPABASE_AUTH_HTTP_ERROR',
    );
  }

  return response.json();
}

async function findAuthUserIdByEmail(client, email) {
  const result = await client.query(
    `SELECT id
     FROM auth.users
     WHERE lower(email) = lower($1)
     LIMIT 1`,
    [email],
  );

  return result.rows[0]?.id || null;
}

async function adminCreateUser({ email, password, nombre }) {
  const config = authConfig({ requireServiceRole: true });
  if (!config) {
    return null;
  }

  return requestJson(`${config.url}/auth/v1/admin/users`, {
    method: 'POST',
    headers: {
      apikey: config.serviceKey,
      Authorization: `Bearer ${config.serviceKey}`,
      'Content-Type': 'application/json',
    },
    body: {
      email,
      password,
      email_confirm: true,
      user_metadata: nombre ? { nombre } : {},
    },
  });
}

export async function updateSupabaseAuthPassword(authUserId, password) {
  const config = authConfig({ requireServiceRole: true });
  if (!config || !authUserId || !password) {
    return false;
  }

  await requestJson(`${config.url}/auth/v1/admin/users/${authUserId}`, {
    method: 'PUT',
    headers: {
      apikey: config.serviceKey,
      Authorization: `Bearer ${config.serviceKey}`,
      'Content-Type': 'application/json',
    },
    body: { password },
  });

  return true;
}

export async function deleteSupabaseAuthUser(authUserId) {
  const config = authConfig({ requireServiceRole: true });
  if (!config || !authUserId) {
    return false;
  }

  await requestJson(`${config.url}/auth/v1/admin/users/${authUserId}`, {
    method: 'DELETE',
    headers: {
      apikey: config.serviceKey,
      Authorization: `Bearer ${config.serviceKey}`,
    },
  });

  return true;
}

export async function ensureSupabaseAuthUserForAppUser(client, user, password) {
  const config = authConfig({ requireServiceRole: true });
  if (!config) {
    return null;
  }

  let authUserId = user.auth_user_id || null;

  if (!authUserId) {
    authUserId = await findAuthUserIdByEmail(client, user.email);
  }

  if (!authUserId) {
    try {
      const created = await adminCreateUser({
        email: user.email,
        password,
        nombre: user.nombre,
      });
      authUserId = created?.id || null;
    } catch (error) {
      if (error instanceof SupabaseAuthError && error.status === 422) {
        authUserId = await findAuthUserIdByEmail(client, user.email);
      } else {
        throw error;
      }
    }
  } else if (password) {
    await updateSupabaseAuthPassword(authUserId, password);
  }

  if (!authUserId) {
    throw new SupabaseAuthError(
      'No se pudo crear la cuenta de autenticación',
      502,
      'SUPABASE_AUTH_USER_MISSING',
    );
  }

  await client.query(
    `UPDATE app.users
     SET auth_user_id = $1,
         updated_at = NOW()
     WHERE id = $2
       AND (auth_user_id IS NULL OR auth_user_id = $1)`,
    [authUserId, user.id],
  );

  return authUserId;
}

function normalizeSession(data) {
  return {
    access_token: data.access_token,
    refresh_token: data.refresh_token,
    expires_in: data.expires_in,
    expires_at: data.expires_at,
    token_type: data.token_type,
  };
}

export async function createSupabasePasswordSession({ email, password }) {
  const config = authConfig();
  if (!config) {
    return null;
  }

  const data = await requestJson(
    `${config.url}/auth/v1/token?grant_type=password`,
    {
      method: 'POST',
      headers: {
        apikey: config.apiKey,
        Authorization: `Bearer ${config.apiKey}`,
        'Content-Type': 'application/json',
      },
      body: { email, password },
    },
  );

  return normalizeSession(data);
}

export async function refreshSupabaseSession(refreshToken) {
  const config = authConfig();
  if (!config) {
    throw new SupabaseAuthError(
      'Supabase Auth no está configurado',
      503,
      'SUPABASE_AUTH_NOT_CONFIGURED',
    );
  }

  const data = await requestJson(
    `${config.url}/auth/v1/token?grant_type=refresh_token`,
    {
      method: 'POST',
      headers: {
        apikey: config.apiKey,
        Authorization: `Bearer ${config.apiKey}`,
        'Content-Type': 'application/json',
      },
      body: { refresh_token: refreshToken },
    },
  );

  return normalizeSession(data);
}

export async function getSupabaseUser(accessToken) {
  const config = authConfig();
  if (!config) {
    return null;
  }

  return requestJson(`${config.url}/auth/v1/user`, {
    headers: {
      apikey: config.apiKey,
      Authorization: `Bearer ${accessToken}`,
    },
  });
}

export async function resolveAppUserFromSupabaseUser(supabaseUser) {
  const email = supabaseUser?.email || '';
  const authUserId = supabaseUser?.id || null;

  if (!authUserId) {
    return null;
  }

  const result = await pool.query(
    `UPDATE app.users
     SET auth_user_id = COALESCE(auth_user_id, $1)
     WHERE deleted_at IS NULL
       AND (
         auth_user_id = $1
         OR (auth_user_id IS NULL AND lower(email) = lower($2))
       )
     RETURNING id, email, nombre, auth_user_id`,
    [authUserId, email],
  );

  return result.rows[0] || null;
}
