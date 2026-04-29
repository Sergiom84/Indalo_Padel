import crypto from 'crypto';
import { pool } from '../db.js';

// Token OAuth2 cacheado para reutilizar durante su vida útil
let cachedToken = null;
let tokenExpiresAt = 0;

function getServiceAccount() {
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (!raw) return null;
  try {
    return JSON.parse(raw);
  } catch {
    console.error('❌ FIREBASE_SERVICE_ACCOUNT_JSON no es JSON válido');
    return null;
  }
}

function buildJwt(serviceAccount) {
  const now = Math.floor(Date.now() / 1000);
  const header = Buffer.from(JSON.stringify({ alg: 'RS256', typ: 'JWT' })).toString('base64url');
  const payload = Buffer.from(JSON.stringify({
    iss: serviceAccount.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  })).toString('base64url');

  const sign = crypto.createSign('RSA-SHA256');
  sign.update(`${header}.${payload}`);
  const signature = sign.sign(serviceAccount.private_key, 'base64url');

  return `${header}.${payload}.${signature}`;
}

async function getAccessToken() {
  if (cachedToken && Date.now() < tokenExpiresAt) return cachedToken;

  const sa = getServiceAccount();
  if (!sa) return null;

  const jwt = buildJwt(sa);
  const body = new URLSearchParams({
    grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
    assertion: jwt,
  });

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: body.toString(),
  });

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Error obteniendo token OAuth2: ${err}`);
  }

  const json = await res.json();
  cachedToken = json.access_token;
  tokenExpiresAt = Date.now() + (json.expires_in - 60) * 1000;
  console.log('🔔 Firebase token OAuth2 obtenido');
  return cachedToken;
}

function normalizeBadgeCount(value) {
  const parsed = Number.parseInt(value, 10);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : null;
}

function resolveBadgeCountForUser(badgeCountByUser, userId, fallback) {
  if (!badgeCountByUser) {
    return normalizeBadgeCount(fallback);
  }

  if (badgeCountByUser instanceof Map) {
    return normalizeBadgeCount(badgeCountByUser.get(Number(userId)) ?? fallback);
  }

  return normalizeBadgeCount(
    badgeCountByUser[Number(userId)] ??
      badgeCountByUser[String(userId)] ??
      fallback,
  );
}

/**
 * Registra o actualiza el token FCM de un dispositivo.
 */
export async function upsertFcmToken({ userId, token, platform = 'android' }) {
  await pool.query(
    `
      INSERT INTO app.padel_fcm_tokens (user_id, token, platform, updated_at)
      VALUES ($1, $2, $3, NOW())
      ON CONFLICT (token)
        DO UPDATE SET user_id = $1, platform = $3, updated_at = NOW()
    `,
    [userId, token, platform],
  );
}

/**
 * Elimina un token FCM (logout del dispositivo).
 */
export async function deleteFcmToken({ userId, token }) {
  await pool.query(
    'DELETE FROM app.padel_fcm_tokens WHERE user_id = $1 AND token = $2',
    [userId, token],
  );
}

/**
 * Envía push a todos los dispositivos activos de los usuarios indicados.
 * Fire-and-forget: no interrumpe el flujo principal si falla.
 */
export async function sendPushToUsers({
  userIds,
  title,
  body,
  data = {},
  badgeCount = null,
  badgeCountByUser = null,
}) {
  if (!userIds?.length) return;

  const sa = getServiceAccount();
  if (!sa) return;

  const { rows } = await pool.query(
    'SELECT user_id, token FROM app.padel_fcm_tokens WHERE user_id = ANY($1)',
    [userIds],
  );
  if (!rows.length) return;

  let accessToken;
  try {
    accessToken = await getAccessToken();
  } catch (err) {
    console.error('❌ Push omitido, no se pudo autenticar con Firebase:', err.message);
    return;
  }

  const projectId = sa.project_id;
  const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
  const invalidTokens = [];
  let ok = 0;

  await Promise.all(rows.map(async ({ user_id: rowUserId, token }) => {
    const normalizedBadgeCount = resolveBadgeCountForUser(
      badgeCountByUser,
      rowUserId,
      badgeCount,
    );
    const payloadData = {
      ...data,
      ...(normalizedBadgeCount ? { badge_count: normalizedBadgeCount } : {}),
    };

    try {
      const res = await fetch(url, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          message: {
            token,
            notification: { title, body },
            data: Object.fromEntries(
              Object.entries(payloadData).map(([k, v]) => [k, String(v)]),
            ),
            android: {
              priority: 'high',
              notification: {
                channel_id: 'indalo_alerts',
                ...(normalizedBadgeCount
                  ? { notification_count: normalizedBadgeCount }
                  : {}),
              },
            },
            ...(normalizedBadgeCount
              ? {
                  apns: {
                    payload: {
                      aps: {
                        badge: normalizedBadgeCount,
                        sound: 'default',
                      },
                    },
                  },
                }
              : {}),
          },
        }),
      });

      if (res.ok) {
        ok++;
      } else {
        const err = await res.json().catch(() => ({}));
        const status = err?.error?.status;
        if (status === 'UNREGISTERED' || status === 'INVALID_ARGUMENT') {
          invalidTokens.push(token);
        }
      }
    } catch {
      // error de red en un token concreto, ignorar
    }
  }));

  if (invalidTokens.length) {
    await pool.query(
      'DELETE FROM app.padel_fcm_tokens WHERE token = ANY($1)',
      [invalidTokens],
    ).catch(() => {});
  }

  console.log(`🔔 Push: ${ok} enviados, ${rows.length - ok} fallidos`);
}
