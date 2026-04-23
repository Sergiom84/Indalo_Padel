/**
 * Script para generar/regenerar el GOOGLE_REFRESH_TOKEN de Google Calendar.
 *
 * Uso:
 *   node backend/scripts/get-google-token.js
 *
 * El script levanta un servidor local en el puerto 3030, abre la URL de Google
 * en el navegador, y captura el código automáticamente al redirigir.
 *
 * Requiere en .env (o variables de entorno):
 *   GOOGLE_CLIENT_ID
 *   GOOGLE_CLIENT_SECRET
 *
 * IMPORTANTE: En Google Cloud Console debes tener añadida esta URI autorizada:
 *   http://localhost:3030/oauth2callback
 *   (Credentials → tu OAuth client → Authorized redirect URIs)
 */

import http from 'http';
import { exec } from 'child_process';
import '../loadEnv.js';

const CLIENT_ID = process.env.GOOGLE_CLIENT_ID;
const CLIENT_SECRET = process.env.GOOGLE_CLIENT_SECRET;
const PORT = 3030;
const REDIRECT_URI = `http://localhost:${PORT}/oauth2callback`;

if (!CLIENT_ID || !CLIENT_SECRET) {
  console.error('❌ Faltan GOOGLE_CLIENT_ID y/o GOOGLE_CLIENT_SECRET en el .env');
  process.exit(1);
}

const params = new URLSearchParams({
  client_id: CLIENT_ID,
  redirect_uri: REDIRECT_URI,
  response_type: 'code',
  scope: 'https://www.googleapis.com/auth/calendar',
  access_type: 'offline',
  prompt: 'consent',
});

const authUrl = `https://accounts.google.com/o/oauth2/v2/auth?${params}`;

async function exchangeCode(code) {
  const body = new URLSearchParams({
    code,
    client_id: CLIENT_ID,
    client_secret: CLIENT_SECRET,
    redirect_uri: REDIRECT_URI,
    grant_type: 'authorization_code',
  });

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body,
  });

  const data = await response.json();

  if (!response.ok) {
    throw new Error(data.error_description || data.error || 'Error al intercambiar el código');
  }

  return data;
}

const server = http.createServer(async (req, res) => {
  if (!req.url.startsWith('/oauth2callback')) {
    res.writeHead(404);
    res.end();
    return;
  }

  const url = new URL(req.url, `http://localhost:${PORT}`);
  const code = url.searchParams.get('code');
  const error = url.searchParams.get('error');

  if (error) {
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(`<h2>❌ Error: ${error}</h2><p>Puedes cerrar esta ventana.</p>`);
    server.close();
    console.error(`\n❌ Google devolvió error: ${error}\n`);
    process.exit(1);
  }

  if (!code) {
    res.writeHead(400, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end('<h2>No se recibió código. Cierra esta ventana e inténtalo de nuevo.</h2>');
    server.close();
    process.exit(1);
  }

  try {
    const tokens = await exchangeCode(code);

    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(`
      <h2>✅ ¡Autorización completada!</h2>
      <p>Puedes cerrar esta ventana y volver a la terminal.</p>
    `);

    server.close();

    console.log('\n✅ ¡Tokens obtenidos!\n');

    if (tokens.refresh_token) {
      console.log('Añade esta línea a tu .env y actualiza la variable en Render:\n');
      console.log(`GOOGLE_REFRESH_TOKEN=${tokens.refresh_token}\n`);
      console.log('→ Render: Dashboard → tu servicio → Environment → GOOGLE_REFRESH_TOKEN → Save Changes\n');
    } else {
      console.warn('⚠️  Google no devolvió refresh_token.');
      console.warn('   Esto ocurre si ya existe un token activo para esta app.');
      console.warn('   Revoca el acceso en https://myaccount.google.com/permissions');
      console.warn('   y vuelve a ejecutar este script.\n');
    }
  } catch (err) {
    res.writeHead(500, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(`<h2>❌ Error: ${err.message}</h2><p>Puedes cerrar esta ventana.</p>`);
    server.close();
    console.error('\n❌', err.message, '\n');
    process.exit(1);
  }
});

server.listen(PORT, () => {
  console.log(`\n🚀 Servidor de autorización escuchando en http://localhost:${PORT}`);
  console.log('\n⚠️  ANTES de continuar, asegúrate de que en Google Cloud Console tienes añadida:');
  console.log(`   Authorized redirect URI → ${REDIRECT_URI}`);
  console.log('   (Credentials → tu OAuth 2.0 Client → Authorized redirect URIs → Add URI)\n');
  console.log('Abriendo el navegador para autorizar...\n');

  // Abrir el navegador automáticamente en Windows
  exec(`start "" "${authUrl}"`);

  console.log('Si el navegador no se abrió, copia esta URL manualmente:\n');
  console.log(authUrl);
  console.log('\nEsperando autorización...\n');
});
