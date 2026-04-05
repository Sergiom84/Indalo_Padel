import express from 'express';
import { pool } from '../db.js';
import { authenticateToken } from '../middleware/auth.js';

const router = express.Router();

// GET /api/padel/venues - Listar sedes activas
router.get('/', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT v.*,
        (SELECT COUNT(*) FROM app.padel_courts c WHERE c.venue_id = v.id AND c.is_active = true) as court_count
      FROM app.padel_venues v
      WHERE v.is_active = true
      ORDER BY v.name
    `);
    res.json({ venues: result.rows });
  } catch (error) {
    console.error('Error listando sedes:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// GET /api/padel/venues/:id - Detalle de sede con pistas
router.get('/:id', async (req, res) => {
  try {
    const venueResult = await pool.query(
      'SELECT * FROM app.padel_venues WHERE id = $1 AND is_active = true',
      [req.params.id]
    );

    if (venueResult.rows.length === 0) {
      return res.status(404).json({ error: 'Sede no encontrada' });
    }

    const courtsResult = await pool.query(
      'SELECT * FROM app.padel_courts WHERE venue_id = $1 AND is_active = true ORDER BY name',
      [req.params.id]
    );

    res.json({
      venue: venueResult.rows[0],
      courts: courtsResult.rows
    });
  } catch (error) {
    console.error('Error obteniendo sede:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// GET /api/padel/venues/:id/availability?date=YYYY-MM-DD
router.get('/:id/availability', async (req, res) => {
  try {
    const { date } = req.query;
    if (!date) {
      return res.status(400).json({ error: 'Parámetro date requerido (YYYY-MM-DD)' });
    }

    const venueResult = await pool.query(
      'SELECT opening_time, closing_time FROM app.padel_venues WHERE id = $1',
      [req.params.id]
    );

    if (venueResult.rows.length === 0) {
      return res.status(404).json({ error: 'Sede no encontrada' });
    }

    const venue = venueResult.rows[0];

    const courtsResult = await pool.query(
      'SELECT id, name, court_type, price_per_hour, peak_price_per_hour FROM app.padel_courts WHERE venue_id = $1 AND is_active = true ORDER BY name',
      [req.params.id]
    );

    const bookingsResult = await pool.query(
      `SELECT court_id, start_time, end_time, status
       FROM app.padel_bookings
       WHERE court_id = ANY(SELECT id FROM app.padel_courts WHERE venue_id = $1)
         AND booking_date = $2
         AND status != 'cancelada'`,
      [req.params.id, date]
    );

    // Build availability grid
    const openHour = parseInt(venue.opening_time.split(':')[0]);
    const closeHour = parseInt(venue.closing_time.split(':')[0]);
    const slots = [];

    for (let hour = openHour; hour < closeHour; hour++) {
      const timeSlot = `${String(hour).padStart(2, '0')}:00`;
      const courtSlots = courtsResult.rows.map(court => {
        const isBooked = bookingsResult.rows.some(
          b => b.court_id === court.id && b.start_time.substring(0, 5) === timeSlot
        );
        const isPeak = hour >= 18 && hour < 22;
        return {
          court_id: court.id,
          court_name: court.name,
          available: !isBooked,
          price: isPeak ? court.peak_price_per_hour : court.price_per_hour
        };
      });
      slots.push({ time: timeSlot, courts: courtSlots });
    }

    res.json({
      date,
      venue_id: parseInt(req.params.id),
      opening_time: venue.opening_time,
      closing_time: venue.closing_time,
      courts: courtsResult.rows,
      slots
    });
  } catch (error) {
    console.error('Error obteniendo disponibilidad:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// POST /api/padel/venues - Crear sede (admin)
router.post('/', authenticateToken, async (req, res) => {
  try {
    const { name, location, address, phone, email, image_url, opening_time, closing_time } = req.body;

    if (!name || !location) {
      return res.status(400).json({ error: 'Nombre y ubicación son requeridos' });
    }

    const result = await pool.query(
      `INSERT INTO app.padel_venues (name, location, address, phone, email, image_url, opening_time, closing_time)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING *`,
      [name, location, address, phone, email, image_url, opening_time || '08:00', closing_time || '22:00']
    );

    res.status(201).json({ venue: result.rows[0] });
  } catch (error) {
    console.error('Error creando sede:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// PUT /api/padel/venues/:id - Editar sede (admin)
router.put('/:id', authenticateToken, async (req, res) => {
  try {
    const { name, location, address, phone, email, image_url, opening_time, closing_time, is_active } = req.body;

    const result = await pool.query(
      `UPDATE app.padel_venues
       SET name = COALESCE($1, name),
           location = COALESCE($2, location),
           address = COALESCE($3, address),
           phone = COALESCE($4, phone),
           email = COALESCE($5, email),
           image_url = COALESCE($6, image_url),
           opening_time = COALESCE($7, opening_time),
           closing_time = COALESCE($8, closing_time),
           is_active = COALESCE($9, is_active),
           updated_at = NOW()
       WHERE id = $10
       RETURNING *`,
      [name, location, address, phone, email, image_url, opening_time, closing_time, is_active, req.params.id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Sede no encontrada' });
    }

    res.json({ venue: result.rows[0] });
  } catch (error) {
    console.error('Error actualizando sede:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

export default router;
