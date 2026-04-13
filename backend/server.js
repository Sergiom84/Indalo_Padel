import express from 'express';
import cors from 'cors';

import './loadEnv.js';
import { hasDatabaseConnection, pool } from './db.js';
import padelAuthRoutes from './routes/padelAuth.js';
import padelVenuesRoutes from './routes/padelVenues.js';
import padelBookingsRoutes from './routes/padelBookings.js';
import padelMatchesRoutes from './routes/padelMatches.js';
import padelCommunityRoutes from './routes/padelCommunity.js';
import padelPlayersRoutes from './routes/padelPlayers.js';
import { startCalendarSyncJob } from './services/padelCalendarSync.js';
import { startCommunityLifecycleJob } from './services/padelCommunityLifecycle.js';

const app = express();
const PORT = process.env.PORT || 3011;

// Red de seguridad global: capturamos errores no manejados para evitar que un
// hipo transitorio (DNS EAI_AGAIN hacia Supabase, ECONNRESET en Google Calendar,
// etc.) tumbe el proceso entero y obligue a Render a reiniciar el contenedor.
// Solo logueamos: las rutas Express ya tienen su propio error handler y los
// recursos en uso (pool de pg) se recuperan por su cuenta.
process.on('unhandledRejection', (reason) => {
  console.error('⚠️ Unhandled promise rejection (no se mata el proceso):', reason);
});
process.on('uncaughtException', (err) => {
  console.error('⚠️ Uncaught exception (no se mata el proceso):', err);
});

// Verificar search_path al arrancar. Si falla por un fallo transitorio de red
// no se considera bloqueante: Render seguira reportando el servicio como vivo
// gracias al healthcheck y la primera query real reintentara la conexion.
(async () => {
  if (!hasDatabaseConnection) {
    console.log('ℹ️ Backend arrancado sin PostgreSQL porque el modo demo está activo');
    return;
  }

  try {
    const { rows } = await pool.query('SHOW search_path;');
    console.log('📂 search_path actual:', rows[0].search_path);
  } catch (err) {
    console.error('❌ Error en inicialización (no bloqueante):', err.message);
  }
})();

const allowedOriginPatterns = [
  /^http:\/\/localhost:\d+$/,
  /^http:\/\/127\.0\.0\.1:\d+$/,
  /\.onrender\.com$/,
];
const explicitOrigins = (process.env.CORS_ORIGINS || '')
  .split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);

function isAllowedOrigin(origin) {
  if (!origin) {
    return true;
  }

  if (explicitOrigins.includes(origin)) {
    return true;
  }

  return allowedOriginPatterns.some((pattern) => pattern.test(origin));
}

// Middleware
app.use(cors({
  origin(origin, callback) {
    if (isAllowedOrigin(origin)) {
      return callback(null, true);
    }

    return callback(new Error(`Origen no permitido por CORS: ${origin}`));
  },
  credentials: true
}));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Logging
app.use((req, res, next) => {
  const timestamp = new Date().toLocaleString('es-ES', { timeZone: 'Europe/Madrid' });
  console.log(`📥 ${req.method} ${req.path} - ${timestamp}`);
  next();
});

// Routes
app.use('/api/padel/auth', padelAuthRoutes);
app.use('/api/padel/venues', padelVenuesRoutes);
app.use('/api/padel/bookings', padelBookingsRoutes);
app.use('/api/padel/matches', padelMatchesRoutes);
app.use('/api/padel/community', padelCommunityRoutes);
app.use('/api/padel/players', padelPlayersRoutes);

// Health check
app.get('/api/health', (req, res) => {
  res.json({
    status: 'ok',
    message: 'Indalo Padel API funcionando correctamente',
    timestamp: new Date().toISOString(),
    version: '1.0',
    mode: hasDatabaseConnection ? 'database' : 'demo'
  });
});

app.get('/', (_req, res) => {
  res.json({
    service: 'Indalo Padel API',
    client: 'Flutter',
    health: `/api/health`,
  });
});

app.get(/^(?!\/api).*/, (req, res) => {
  res.status(404).json({
    error: 'Ruta no encontrada',
    message: 'Este servidor expone solo la API. El frontend activo vive en flutter_app.',
  });
});

// Error handler
app.use((err, req, res, _next) => {
  console.error(err.stack);
  res.status(500).json({
    error: 'Algo salió mal!',
    message: process.env.NODE_ENV === 'development' ? err.message : 'Error interno del servidor'
  });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Indalo Padel API en http://0.0.0.0:${PORT}`);
  console.log(`📊 Health: http://0.0.0.0:${PORT}/api/health`);
  startCalendarSyncJob();
  startCommunityLifecycleJob();
});
