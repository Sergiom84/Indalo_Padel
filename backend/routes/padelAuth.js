import express from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { pool } from '../db.js';
import { authenticateToken } from '../middleware/auth.js';
import { validate } from '../middleware/validate.js';
import {
  emailActionSchema,
  loginSchema,
  registerSchema,
  resetPasswordSchema,
} from '../validators/authValidators.js';
import {
  generateOneTimeToken,
  hashOneTimeToken,
  sendPasswordResetEmail,
  sendVerificationEmail,
} from '../services/authEmailService.js';

const router = express.Router();

const EMAIL_VERIFICATION_TTL_MS = 24 * 60 * 60 * 1000;
const PASSWORD_RESET_TTL_MS = 60 * 60 * 1000;

function isProduction() {
  return process.env.NODE_ENV === 'production';
}

function buildJwt(user) {
  return jwt.sign(
    { userId: user.id, email: user.email },
    process.env.JWT_SECRET,
    { expiresIn: '7d' }
  );
}

function buildVerificationResponse(delivery) {
  return {
    message:
      'Registro completado. Revisa tu correo y valida la cuenta antes de iniciar sesión.',
    requires_email_verification: true,
    ...(delivery.delivered || isProduction()
      ? {}
      : { debug_verification_url: delivery.debugUrl }),
  };
}

function buildPasswordResetResponse(delivery) {
  return {
    message:
      'Si existe una cuenta con ese correo, te hemos enviado un enlace para restablecer la contraseña.',
    ...(delivery.delivered || isProduction()
      ? {}
      : { debug_reset_url: delivery.debugUrl }),
  };
}

function renderAuthPage({
  title,
  heading,
  message,
  tone = 'success',
  extra = '',
}) {
  const accent = tone === 'success' ? '#7ed7c1' : '#ff8c82';

  return `<!doctype html>
<html lang="es">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>${title}</title>
    <style>
      :root {
        color-scheme: dark;
      }
      body {
        margin: 0;
        min-height: 100vh;
        display: grid;
        place-items: center;
        background: radial-gradient(circle at top, #162235 0%, #0b1320 55%, #050a12 100%);
        color: #f6f8fb;
        font-family: Arial, sans-serif;
        padding: 24px;
      }
      main {
        max-width: 520px;
        width: 100%;
        background: rgba(17, 25, 40, 0.92);
        border: 1px solid rgba(126, 215, 193, 0.16);
        border-radius: 24px;
        padding: 32px;
        box-shadow: 0 20px 60px rgba(0, 0, 0, 0.35);
      }
      .eyebrow {
        color: ${accent};
        font-size: 12px;
        letter-spacing: 1px;
        text-transform: uppercase;
        font-weight: 700;
      }
      h1 {
        margin: 14px 0 10px;
        font-size: 30px;
        line-height: 1.15;
      }
      p {
        margin: 0;
        color: #c2cfdd;
        line-height: 1.6;
      }
      form {
        margin-top: 24px;
      }
      label {
        display: block;
        margin-bottom: 8px;
        font-size: 14px;
        color: #c2cfdd;
      }
      input {
        width: 100%;
        box-sizing: border-box;
        border-radius: 14px;
        border: 1px solid #32455f;
        background: #0f1828;
        color: #f6f8fb;
        padding: 14px 16px;
        font-size: 15px;
      }
      button,
      a.button {
        display: inline-flex;
        justify-content: center;
        align-items: center;
        margin-top: 18px;
        width: 100%;
        border: 0;
        border-radius: 999px;
        background: ${accent};
        color: #08131f;
        text-decoration: none;
        padding: 14px 20px;
        font-size: 15px;
        font-weight: 700;
        cursor: pointer;
      }
      .hint {
        margin-top: 18px;
        font-size: 13px;
        color: #8fa2ba;
      }
      .error {
        margin-top: 14px;
        padding: 12px 14px;
        border-radius: 14px;
        background: rgba(255, 140, 130, 0.12);
        border: 1px solid rgba(255, 140, 130, 0.24);
        color: #ffd3cf;
      }
    </style>
  </head>
  <body>
    <main>
      <div class="eyebrow">Indalo Padel</div>
      <h1>${heading}</h1>
      <p>${message}</p>
      ${extra}
    </main>
  </body>
</html>`;
}

async function storeEmailVerificationToken(client, userId) {
  const token = generateOneTimeToken();
  const sentAt = new Date();
  const expiresAt = new Date(Date.now() + EMAIL_VERIFICATION_TTL_MS);

  await client.query(
    `UPDATE app.users
     SET email_verified_at = NULL,
         email_verification_token_hash = $1,
         email_verification_sent_at = $2,
         email_verification_expires_at = $3,
         updated_at = NOW()
     WHERE id = $4`,
    [hashOneTimeToken(token), sentAt, expiresAt, userId]
  );

  return token;
}

async function storePasswordResetToken(client, userId) {
  const token = generateOneTimeToken();
  const sentAt = new Date();
  const expiresAt = new Date(Date.now() + PASSWORD_RESET_TTL_MS);

  await client.query(
    `UPDATE app.users
     SET password_reset_token_hash = $1,
         password_reset_sent_at = $2,
         password_reset_expires_at = $3,
         updated_at = NOW()
     WHERE id = $4`,
    [hashOneTimeToken(token), sentAt, expiresAt, userId]
  );

  return token;
}

// POST /api/padel/auth/register
router.post('/register', validate(registerSchema), async (req, res) => {
  const client = await pool.connect();

  try {
    const {
      nombre,
      email,
      password,
      main_level,
      sub_level,
      gender,
      birth_date,
      phone,
      court_preferences,
      dominant_hands,
      availability_preferences,
      match_preferences,
    } = req.body;

    await client.query('BEGIN');

    const existing = await client.query(
      `SELECT id
       FROM app.users
       WHERE email = $1
         AND deleted_at IS NULL`,
      [email]
    );
    if (existing.rows.length > 0) {
      await client.query('ROLLBACK');
      return res
        .status(400)
        .json({ error: 'Ya existe un usuario con este email' });
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    const userResult = await client.query(
      `INSERT INTO app.users (nombre, email, password_hash)
       VALUES ($1, $2, $3)
       RETURNING id, nombre, email, created_at`,
      [nombre, email, hashedPassword]
    );
    const user = userResult.rows[0];

    await client.query(
      `INSERT INTO app.padel_player_profiles (
         user_id,
         display_name,
         main_level,
         sub_level,
         gender,
         birth_date,
         phone,
         court_preferences,
         dominant_hands,
         availability_preferences,
         match_preferences
       )
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)`,
      [
        user.id,
        nombre,
        main_level || 'bajo',
        sub_level || 'bajo',
        gender,
        birth_date,
        phone?.trim() ? phone.trim() : null,
        court_preferences || [],
        dominant_hands || [],
        availability_preferences || [],
        match_preferences || [],
      ]
    );

    const verificationToken = await storeEmailVerificationToken(client, user.id);
    const delivery = await sendVerificationEmail({
      email: user.email,
      nombre: user.nombre,
      token: verificationToken,
    });

    if (isProduction() && !delivery.delivered) {
      await client.query('ROLLBACK');
      return res.status(503).json({
        error:
          'No se ha podido enviar el correo de verificación. Inténtalo de nuevo más tarde.',
      });
    }

    await client.query('COMMIT');
    return res.status(201).json(buildVerificationResponse(delivery));
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Error en registro:', error);
    return res.status(500).json({
      error: 'Error interno del servidor',
      details:
        process.env.NODE_ENV === 'development' ? error.message : undefined,
    });
  } finally {
    client.release();
  }
});

// POST /api/padel/auth/login
router.post('/login', validate(loginSchema), async (req, res) => {
  try {
    const { email, password } = req.body;

    const result = await pool.query(
      `SELECT
         u.id,
         u.nombre,
         u.email,
         u.password_hash,
         u.email_verified_at,
         pp.avatar_url
       FROM app.users u
       LEFT JOIN app.padel_player_profiles pp ON pp.user_id = u.id
       WHERE u.email = $1
         AND u.deleted_at IS NULL`,
      [email]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Credenciales incorrectas' });
    }

    const user = result.rows[0];
    const isValid = await bcrypt.compare(password, user.password_hash);
    if (!isValid) {
      return res.status(401).json({ error: 'Credenciales incorrectas' });
    }

    if (!user.email_verified_at) {
      return res.status(403).json({
        error: 'Debes verificar tu correo antes de iniciar sesión',
      });
    }

    const token = buildJwt(user);

    return res.json({
      message: 'Login exitoso',
      user: {
        id: user.id,
        nombre: user.nombre,
        email: user.email,
        avatar_url: user.avatar_url,
      },
      token,
    });
  } catch (error) {
    console.error('Error en login:', error);
    return res.status(500).json({
      error: 'Error interno del servidor',
      details:
        process.env.NODE_ENV === 'development' ? error.message : undefined,
    });
  }
});

// POST /api/padel/auth/resend-verification
router.post(
  '/resend-verification',
  validate(emailActionSchema),
  async (req, res) => {
    const client = await pool.connect();

    try {
      const { email } = req.body;
      await client.query('BEGIN');

      const result = await client.query(
        `SELECT id, nombre, email, email_verified_at
         FROM app.users
         WHERE email = $1
           AND deleted_at IS NULL
         FOR UPDATE`,
        [email]
      );

      if (result.rows.length === 0) {
        await client.query('ROLLBACK');
        return res.json({
          message:
            'Si existe una cuenta pendiente de verificación, te hemos enviado un nuevo correo.',
        });
      }

      const user = result.rows[0];
      if (user.email_verified_at) {
        await client.query('ROLLBACK');
        return res.json({ message: 'Tu correo ya está verificado' });
      }

      const verificationToken = await storeEmailVerificationToken(client, user.id);
      const delivery = await sendVerificationEmail({
        email: user.email,
        nombre: user.nombre,
        token: verificationToken,
      });

      if (isProduction() && !delivery.delivered) {
        await client.query('ROLLBACK');
        return res.status(503).json({
          error:
            'No se ha podido reenviar el correo de verificación. Inténtalo de nuevo más tarde.',
        });
      }

      await client.query('COMMIT');
      return res.json({
        message:
          'Te hemos enviado un nuevo correo para verificar tu cuenta.',
        ...(delivery.delivered || isProduction()
          ? {}
          : { debug_verification_url: delivery.debugUrl }),
      });
    } catch (error) {
      await client.query('ROLLBACK');
      console.error('Error reenviando verificación:', error);
      return res.status(500).json({ error: 'Error interno del servidor' });
    } finally {
      client.release();
    }
  }
);

// GET /api/padel/auth/verify-email?token=...
router.get('/verify-email', async (req, res) => {
  try {
    const token = req.query?.token?.toString().trim();
    if (!token) {
      return res
        .status(400)
        .type('html')
        .send(
          renderAuthPage({
            title: 'Token inválido',
            heading: 'Falta el enlace de verificación',
            message:
              'Vuelve a abrir el correo que te enviamos y pulsa de nuevo el enlace.',
            tone: 'error',
          })
        );
    }

    const result = await pool.query(
      `UPDATE app.users
       SET email_verified_at = COALESCE(email_verified_at, NOW()),
           email_verification_token_hash = NULL,
           email_verification_sent_at = NULL,
           email_verification_expires_at = NULL,
           updated_at = NOW()
       WHERE email_verification_token_hash = $1
         AND deleted_at IS NULL
         AND (email_verification_expires_at IS NULL OR email_verification_expires_at >= NOW())
       RETURNING id`,
      [hashOneTimeToken(token)]
    );

    if (result.rows.length === 0) {
      return res
        .status(400)
        .type('html')
        .send(
          renderAuthPage({
            title: 'Enlace inválido',
            heading: 'Este enlace ya no es válido',
            message:
              'Puede haber caducado o ya haberse utilizado. Solicita un nuevo correo de verificación desde la app.',
            tone: 'error',
          })
        );
    }

    return res
      .status(200)
      .type('html')
      .send(
        renderAuthPage({
          title: 'Correo verificado',
          heading: 'Correo verificado correctamente',
          message:
            'Ya puedes volver a Indalo Padel e iniciar sesión con tu correo y contraseña.',
        })
      );
  } catch (error) {
    console.error('Error verificando correo:', error);
    return res
      .status(500)
      .type('html')
      .send(
        renderAuthPage({
          title: 'Error',
          heading: 'No se ha podido verificar el correo',
          message: 'Inténtalo de nuevo más tarde.',
          tone: 'error',
        })
      );
  }
});

// POST /api/padel/auth/password-reset/request
router.post(
  '/password-reset/request',
  validate(emailActionSchema),
  async (req, res) => {
    const client = await pool.connect();

    try {
      const { email } = req.body;
      await client.query('BEGIN');

      const result = await client.query(
        `SELECT id, nombre, email, email_verified_at
         FROM app.users
         WHERE email = $1
           AND deleted_at IS NULL
         FOR UPDATE`,
        [email]
      );

      if (result.rows.length === 0 || !result.rows[0].email_verified_at) {
        await client.query('ROLLBACK');
        return res.json(buildPasswordResetResponse({ delivered: true }));
      }

      const user = result.rows[0];
      const resetToken = await storePasswordResetToken(client, user.id);
      const delivery = await sendPasswordResetEmail({
        email: user.email,
        nombre: user.nombre,
        token: resetToken,
      });

      if (isProduction() && !delivery.delivered) {
        await client.query('ROLLBACK');
        return res.status(503).json({
          error:
            'No se ha podido enviar el correo para restablecer la contraseña. Inténtalo de nuevo más tarde.',
        });
      }

      await client.query('COMMIT');
      return res.json(buildPasswordResetResponse(delivery));
    } catch (error) {
      await client.query('ROLLBACK');
      console.error('Error solicitando reset de contraseña:', error);
      return res.status(500).json({ error: 'Error interno del servidor' });
    } finally {
      client.release();
    }
  }
);

// GET /api/padel/auth/reset-password?token=...
router.get('/reset-password', async (req, res) => {
  try {
    const token = req.query?.token?.toString().trim();
    if (!token) {
      return res
        .status(400)
        .type('html')
        .send(
          renderAuthPage({
            title: 'Token inválido',
            heading: 'Falta el enlace de recuperación',
            message:
              'Vuelve a abrir el correo de recuperación y pulsa de nuevo el enlace.',
            tone: 'error',
          })
        );
    }

    const result = await pool.query(
      `SELECT id
       FROM app.users
       WHERE password_reset_token_hash = $1
         AND deleted_at IS NULL
         AND (password_reset_expires_at IS NULL OR password_reset_expires_at >= NOW())`,
      [hashOneTimeToken(token)]
    );

    if (result.rows.length === 0) {
      return res
        .status(400)
        .type('html')
        .send(
          renderAuthPage({
            title: 'Enlace inválido',
            heading: 'Este enlace ya no es válido',
            message:
              'Solicita un nuevo correo para restablecer la contraseña desde la app.',
            tone: 'error',
          })
        );
    }

    return res
      .status(200)
      .type('html')
      .send(
        renderAuthPage({
          title: 'Restablece tu contraseña',
          heading: 'Crea una nueva contraseña',
          message:
            'Introduce una contraseña nueva para tu cuenta de Indalo Padel.',
          extra: `
            <form method="post" action="/api/padel/auth/reset-password">
              <input type="hidden" name="token" value="${token}" />
              <label for="password">Nueva contraseña</label>
              <input id="password" name="password" type="password" minlength="6" required />
              <button type="submit">Guardar contraseña</button>
              <div class="hint">La contraseña debe tener al menos 6 caracteres.</div>
            </form>
          `,
        })
      );
  } catch (error) {
    console.error('Error cargando pantalla de reset:', error);
    return res
      .status(500)
      .type('html')
      .send(
        renderAuthPage({
          title: 'Error',
          heading: 'No se ha podido abrir el cambio de contraseña',
          message: 'Inténtalo de nuevo más tarde.',
          tone: 'error',
        })
      );
  }
});

// POST /api/padel/auth/reset-password
router.post('/reset-password', async (req, res) => {
  const parsed = resetPasswordSchema.safeParse(req.body);
  if (!parsed.success) {
    const message =
      parsed.error.issues[0]?.message || 'Datos de entrada inválidos';
    return res
      .status(400)
      .type('html')
      .send(
        renderAuthPage({
          title: 'Datos inválidos',
          heading: 'No se ha podido actualizar la contraseña',
          message: message,
          tone: 'error',
        })
      );
  }

  try {
    const { token, password } = parsed.data;
    const passwordHash = await bcrypt.hash(password, 10);

    const result = await pool.query(
      `UPDATE app.users
       SET password_hash = $1,
           password_reset_token_hash = NULL,
           password_reset_sent_at = NULL,
           password_reset_expires_at = NULL,
           updated_at = NOW()
       WHERE password_reset_token_hash = $2
         AND deleted_at IS NULL
         AND (password_reset_expires_at IS NULL OR password_reset_expires_at >= NOW())
       RETURNING id`,
      [passwordHash, hashOneTimeToken(token)]
    );

    if (result.rows.length === 0) {
      return res
        .status(400)
        .type('html')
        .send(
          renderAuthPage({
            title: 'Enlace inválido',
            heading: 'Este enlace ya no es válido',
            message:
              'Solicita un nuevo correo para restablecer la contraseña desde la app.',
            tone: 'error',
          })
        );
    }

    return res
      .status(200)
      .type('html')
      .send(
        renderAuthPage({
          title: 'Contraseña actualizada',
          heading: 'Contraseña actualizada',
          message:
            'Ya puedes volver a Indalo Padel e iniciar sesión con tu nueva contraseña.',
        })
      );
  } catch (error) {
    console.error('Error actualizando contraseña:', error);
    return res
      .status(500)
      .type('html')
      .send(
        renderAuthPage({
          title: 'Error',
          heading: 'No se ha podido actualizar la contraseña',
          message: 'Inténtalo de nuevo más tarde.',
          tone: 'error',
        })
      );
  }
});

// GET /api/padel/auth/verify
router.get('/verify', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT
         u.id,
         u.nombre,
         u.email,
         pp.avatar_url
       FROM app.users u
       LEFT JOIN app.padel_player_profiles pp ON pp.user_id = u.id
       WHERE u.id = $1
         AND u.deleted_at IS NULL`,
      [req.user.userId]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Usuario no encontrado' });
    }

    return res.json({ user: result.rows[0] });
  } catch (error) {
    console.error('Error verificando token:', error);
    return res.status(401).json({ error: 'Token inválido' });
  }
});

export default router;
