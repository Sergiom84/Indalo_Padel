import crypto from 'crypto';

const RESEND_API_URL = 'https://api.resend.com/emails';
const DEFAULT_PUBLIC_API_BASE_URL = 'https://indalo-padel.onrender.com/api';

function normalizeUrl(url) {
  return url.replace(/\/+$/, '');
}

function getPublicApiBaseUrl() {
  const explicitBaseUrl = process.env.PUBLIC_API_BASE_URL?.trim();
  if (explicitBaseUrl) {
    return normalizeUrl(explicitBaseUrl);
  }

  const renderExternalUrl = process.env.RENDER_EXTERNAL_URL?.trim();
  if (renderExternalUrl) {
    return `${normalizeUrl(renderExternalUrl)}/api`;
  }

  if (process.env.NODE_ENV !== 'production') {
    const port = process.env.PORT || '3011';
    return `http://localhost:${port}/api`;
  }

  return DEFAULT_PUBLIC_API_BASE_URL;
}

function escapeHtml(value) {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

function renderEmailBody({ heading, intro, ctaLabel, ctaUrl, secondaryText }) {
  return `
    <div style="font-family:Arial,sans-serif;background:#0c1320;padding:32px;color:#f6f8fb;">
      <div style="max-width:560px;margin:0 auto;background:#162235;border:1px solid #263754;border-radius:20px;padding:32px;">
        <div style="font-size:12px;letter-spacing:1px;text-transform:uppercase;color:#7ed7c1;font-weight:700;">
          Indalo Padel
        </div>
        <h1 style="margin:16px 0 12px;font-size:28px;line-height:1.2;">${escapeHtml(heading)}</h1>
        <p style="margin:0 0 20px;color:#c3d0e0;line-height:1.6;">${escapeHtml(intro)}</p>
        <a
          href="${escapeHtml(ctaUrl)}"
          style="display:inline-block;background:#7ed7c1;color:#07121f;text-decoration:none;padding:14px 20px;border-radius:999px;font-weight:700;"
        >
          ${escapeHtml(ctaLabel)}
        </a>
        <p style="margin:24px 0 0;color:#8fa2ba;line-height:1.6;font-size:14px;">
          ${escapeHtml(secondaryText)}
        </p>
      </div>
    </div>
  `;
}

function renderEmailText({ heading, intro, ctaLabel, ctaUrl, secondaryText }) {
  return [
    'Indalo Padel',
    '',
    heading,
    '',
    intro,
    '',
    `${ctaLabel}: ${ctaUrl}`,
    '',
    secondaryText,
  ].join('\n');
}

function isTransactionalEmailConfigured() {
  return Boolean(process.env.RESEND_API_KEY && process.env.EMAIL_FROM);
}

async function sendWithResend({ to, subject, html, text }) {
  const response = await fetch(RESEND_API_URL, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${process.env.RESEND_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from: process.env.EMAIL_FROM,
      to: [to],
      subject,
      html,
      text,
    }),
  });

  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(
      payload?.message ||
        payload?.error ||
        `No se pudo enviar el correo (${response.status})`
    );
  }
}

function generateOneTimeToken() {
  return crypto.randomBytes(32).toString('hex');
}

function hashOneTimeToken(token) {
  return crypto.createHash('sha256').update(token).digest('hex');
}

function buildVerificationUrl(token) {
  return `${getPublicApiBaseUrl()}/padel/auth/verify-email?token=${encodeURIComponent(token)}`;
}

function buildPasswordResetUrl(token) {
  return `${getPublicApiBaseUrl()}/padel/auth/reset-password?token=${encodeURIComponent(token)}`;
}

async function deliverEmail({ to, subject, heading, intro, ctaLabel, ctaUrl, secondaryText }) {
  const html = renderEmailBody({
    heading,
    intro,
    ctaLabel,
    ctaUrl,
    secondaryText,
  });
  const text = renderEmailText({
    heading,
    intro,
    ctaLabel,
    ctaUrl,
    secondaryText,
  });

  if (!isTransactionalEmailConfigured()) {
    console.warn(
      `⚠️ Correo transaccional no configurado. Destino=${to} enlace=${ctaUrl}`
    );

    return {
      delivered: false,
      debugUrl: ctaUrl,
    };
  }

  await sendWithResend({ to, subject, html, text });
  return {
    delivered: true,
    debugUrl: ctaUrl,
  };
}

async function sendVerificationEmail({ email, nombre, token }) {
  const ctaUrl = buildVerificationUrl(token);
  const safeName = nombre?.trim() || 'jugador';

  return deliverEmail({
    to: email,
    subject: 'Verifica tu correo en Indalo Padel',
    heading: 'Verifica tu correo',
    intro: `Hola ${safeName}, confirma tu cuenta para poder entrar en Indalo Padel.`,
    ctaLabel: 'Verificar correo',
    ctaUrl,
    secondaryText:
      'Si no has creado esta cuenta, puedes ignorar este mensaje.',
  });
}

async function sendPasswordResetEmail({ email, nombre, token }) {
  const ctaUrl = buildPasswordResetUrl(token);
  const safeName = nombre?.trim() || 'jugador';

  return deliverEmail({
    to: email,
    subject: 'Restablece tu contraseña de Indalo Padel',
    heading: 'Restablece tu contraseña',
    intro: `Hola ${safeName}, usa este enlace para crear una nueva contraseña en Indalo Padel.`,
    ctaLabel: 'Cambiar contraseña',
    ctaUrl,
    secondaryText:
      'Si no has solicitado este cambio, puedes ignorar este mensaje.',
  });
}

export {
  buildPasswordResetUrl,
  buildVerificationUrl,
  generateOneTimeToken,
  getPublicApiBaseUrl,
  hashOneTimeToken,
  isTransactionalEmailConfigured,
  sendPasswordResetEmail,
  sendVerificationEmail,
};
