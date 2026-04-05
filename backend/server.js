import express from 'express';
import cors from 'cors';
import path from 'path';
import { fileURLToPath } from 'url';

import './loadEnv.js';
import { hasDatabaseConnection, pool } from './db.js';
import padelAuthRoutes from './routes/padelAuth.js';
import padelVenuesRoutes from './routes/padelVenues.js';
import padelBookingsRoutes from './routes/padelBookings.js';
import padelMatchesRoutes from './routes/padelMatches.js';
import padelPlayersRoutes from './routes/padelPlayers.js';

const app = express();
const PORT = process.env.PORT || 3010;

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const FRONTEND_DIST = path.join(__dirname, '../dist');

// Verificar search_path al arrancar
(async () => {
  if (!hasDatabaseConnection) {
    console.log('ℹ️ Backend arrancado sin PostgreSQL porque el modo demo está activo');
    return;
  }

  try {
    const { rows } = await pool.query('SHOW search_path;');
    console.log('📂 search_path actual:', rows[0].search_path);
  } catch (err) {
    console.error('❌ Error en inicialización:', err);
  }
})();

// Middleware
app.use(cors({
  origin: [
    'http://localhost:5173',
    'http://localhost:5174',
    'http://localhost:3000',
    /\.onrender\.com$/
  ],
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
app.use('/api/padel/players', padelPlayersRoutes);

// Health check
app.get('/api/health', (req, res) => {
  res.json({
    status: 'ok',
    message: 'Indalo Padel API funcionando correctamente',
    timestamp: new Date().toISOString(),
    version: '1.0'
  });
});

// Serve frontend static files
app.use(express.static(FRONTEND_DIST));

app.get(/^(?!\/api).*/, (req, res) => {
  res.sendFile(path.join(FRONTEND_DIST, 'index.html'));
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
});
