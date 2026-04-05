import express from 'express';
import { pool } from '../db.js';
import { authenticateToken } from '../middleware/auth.js';

const router = express.Router();

// POST /api/padel/bookings - Crear reserva
router.post('/', authenticateToken, async (req, res) => {
  try {
    const { court_id, booking_date, start_time, end_time, notes } = req.body;
    const userId = req.user.userId;

    if (!court_id || !booking_date || !start_time) {
      return res.status(400).json({ error: 'court_id, booking_date y start_time son requeridos' });
    }

    const endTime = end_time || `${String(parseInt(start_time.split(':')[0]) + 1).padStart(2, '0')}:30`;

    // Check availability
    const existing = await pool.query(
      `SELECT id FROM app.padel_bookings
       WHERE court_id = $1 AND booking_date = $2 AND start_time = $3 AND status != 'cancelada'`,
      [court_id, booking_date, start_time]
    );

    if (existing.rows.length > 0) {
      return res.status(409).json({ error: 'Este horario ya está reservado' });
    }

    // Get price
    const courtResult = await pool.query(
      'SELECT price_per_hour, peak_price_per_hour FROM app.padel_courts WHERE id = $1',
      [court_id]
    );

    if (courtResult.rows.length === 0) {
      return res.status(404).json({ error: 'Pista no encontrada' });
    }

    const court = courtResult.rows[0];
    const hour = parseInt(start_time.split(':')[0]);
    const isPeak = hour >= 18 && hour < 22;
    const price = isPeak ? court.peak_price_per_hour : court.price_per_hour;

    const result = await pool.query(
      `INSERT INTO app.padel_bookings (court_id, booked_by, booking_date, start_time, end_time, total_price, notes)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING *`,
      [court_id, userId, booking_date, start_time, endTime, price, notes]
    );

    res.status(201).json({ booking: result.rows[0] });
  } catch (error) {
    console.error('Error creando reserva:', error);
    if (error.code === '23505') {
      return res.status(409).json({ error: 'Este horario ya está reservado' });
    }
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// GET /api/padel/bookings/my - Mis reservas
router.get('/my', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.userId;

    const result = await pool.query(
      `SELECT b.*,
        c.name as court_name, c.court_type,
        v.name as venue_name, v.location as venue_location
       FROM app.padel_bookings b
       JOIN app.padel_courts c ON b.court_id = c.id
       JOIN app.padel_venues v ON c.venue_id = v.id
       WHERE b.booked_by = $1
       ORDER BY b.booking_date DESC, b.start_time DESC`,
      [userId]
    );

    const now = new Date();
    const upcoming = [];
    const past = [];

    result.rows.forEach(booking => {
      const bookingDate = new Date(`${booking.booking_date}T${booking.start_time}`);
      if (bookingDate >= now && booking.status !== 'cancelada') {
        upcoming.push(booking);
      } else {
        past.push(booking);
      }
    });

    res.json({ upcoming, past });
  } catch (error) {
    console.error('Error obteniendo reservas:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// GET /api/padel/bookings/:id - Detalle de reserva
router.get('/:id', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT b.*,
        c.name as court_name, c.court_type, c.venue_id,
        v.name as venue_name, v.location as venue_location, v.address as venue_address
       FROM app.padel_bookings b
       JOIN app.padel_courts c ON b.court_id = c.id
       JOIN app.padel_venues v ON c.venue_id = v.id
       WHERE b.id = $1`,
      [req.params.id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Reserva no encontrada' });
    }

    res.json({ booking: result.rows[0] });
  } catch (error) {
    console.error('Error obteniendo reserva:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// PUT /api/padel/bookings/:id/confirm
router.put('/:id/confirm', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      `UPDATE app.padel_bookings SET status = 'confirmada', updated_at = NOW()
       WHERE id = $1 AND booked_by = $2 AND status = 'pendiente'
       RETURNING *`,
      [req.params.id, req.user.userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Reserva no encontrada o no se puede confirmar' });
    }

    res.json({ booking: result.rows[0] });
  } catch (error) {
    console.error('Error confirmando reserva:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// PUT /api/padel/bookings/:id/cancel
router.put('/:id/cancel', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      `UPDATE app.padel_bookings SET status = 'cancelada', updated_at = NOW()
       WHERE id = $1 AND booked_by = $2 AND status IN ('pendiente', 'confirmada')
       RETURNING *`,
      [req.params.id, req.user.userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Reserva no encontrada o no se puede cancelar' });
    }

    res.json({ booking: result.rows[0] });
  } catch (error) {
    console.error('Error cancelando reserva:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

export default router;
