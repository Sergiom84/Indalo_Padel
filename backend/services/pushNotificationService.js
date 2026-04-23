import { pool } from '../db.js';

let firebaseAdmin = null;

async function getAdmin() {
  if (firebaseAdmin) return firebaseAdmin;

  const raw = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (!raw) {
    console.warn('⚠️  FIREBASE_SERVICE_ACCOUNT_JSON no configurado — push notifications desactivadas');
    return null;
  }

  try {
    // Import dinámico para no fallar el arranque si el paquete no está instalado
    const admin = (await import('firebase-admin')).default;
    const serviceAccount = JSON.parse(raw);

    if (!admin.apps.length) {
      admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
    }

    firebaseAdmin = admin;
    console.log('🔔 Firebase Admin inicializado');
    return admin;
  } catch (err) {
    console.error('❌ Error inicializando Firebase Admin:', err.message);
    return null;
  }
}

// Inicializa de forma eager si la variable está disponible
(async () => {
  if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
    await getAdmin();
  }
})();

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
 * Envía una push notification a todos los dispositivos activos de los usuarios indicados.
 * Falla de forma silenciosa para no interrumpir el flujo principal.
 */
export async function sendPushToUsers({ userIds, title, body, data = {} }) {
  if (!userIds?.length) return;

  const admin = await getAdmin();
  if (!admin) return;

  try {
    const { rows } = await pool.query(
      'SELECT token FROM app.padel_fcm_tokens WHERE user_id = ANY($1)',
      [userIds],
    );

    if (!rows.length) return;

    const messages = rows.map(({ token }) => ({
      token,
      notification: { title, body },
      data: Object.fromEntries(
        Object.entries(data).map(([k, v]) => [k, String(v)]),
      ),
      android: {
        priority: 'high',
        notification: { channelId: 'indalo_padel_default' },
      },
    }));

    const response = await admin.messaging().sendEach(messages);

    // Limpiar tokens inválidos de la BD
    const invalidTokens = [];
    response.responses.forEach((res, i) => {
      if (!res.success) {
        const code = res.error?.code;
        if (
          code === 'messaging/registration-token-not-registered' ||
          code === 'messaging/invalid-registration-token'
        ) {
          invalidTokens.push(rows[i].token);
        }
      }
    });

    if (invalidTokens.length) {
      await pool.query(
        'DELETE FROM app.padel_fcm_tokens WHERE token = ANY($1)',
        [invalidTokens],
      );
    }

    console.log(
      `🔔 Push enviado: ${response.successCount} ok, ${response.failureCount} fallidos`,
    );
  } catch (err) {
    console.error('❌ Error enviando push notifications (no bloqueante):', err.message);
  }
}
