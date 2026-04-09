import express from 'express';
import { pool } from '../db.js';
import { authenticateToken } from '../middleware/auth.js';
import { requireRole } from '../middleware/requireRole.js';
import { validate } from '../middleware/validate.js';
import { createVenueSchema, updateVenueSchema } from '../validators/venueValidators.js';
import { availabilityQuerySchema } from '../validators/bookingValidators.js';
import { getVenueAvailability } from '../services/padelBookingService.js';

const router = express.Router();

// GET /api/padel/venues - Listar sedes activas
router.get('/', async (req, res) => {
  try {
    const result = await pool.query(`
      WITH venues_with_courts AS (
        SELECT
          v.*,
          (
            SELECT COUNT(*)::int
            FROM app.padel_courts c
            WHERE c.venue_id = v.id AND c.is_active = true
          ) AS court_count
        FROM app.padel_venues v
        WHERE v.is_active = true
      )
      SELECT *
      FROM (
        SELECT DISTINCT ON (LOWER(BTRIM(name)), LOWER(BTRIM(location)))
          *
        FROM venues_with_courts
        ORDER BY
          LOWER(BTRIM(name)),
          LOWER(BTRIM(location)),
          court_count DESC,
          id ASC
      ) deduped
      ORDER BY name, id
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

    const scheduleResult = await pool.query(
      `SELECT
          day_of_week,
          start_time,
          end_time,
          valid_from,
          valid_until,
          label
       FROM app.padel_venue_schedule_windows
       WHERE venue_id = $1
         AND is_active = true
       ORDER BY day_of_week ASC NULLS LAST, start_time ASC`,
      [req.params.id]
    );

    res.json({
      venue: venueResult.rows[0],
      courts: courtsResult.rows,
      schedule_windows: scheduleResult.rows,
    });
  } catch (error) {
    console.error('Error obteniendo sede:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// GET /api/padel/venues/:id/availability?date=YYYY-MM-DD
router.get('/:id/availability', validate(availabilityQuerySchema, 'query'), async (req, res) => {
  try {
    const { date, duration_minutes, slot_step_minutes } = req.query;

    const result = await getVenueAvailability({
      venueId: req.params.id,
      date,
      durationMinutes: duration_minutes,
      slotStepMinutes: slot_step_minutes,
    });

    return res.status(result.status).json(result.body);
  } catch (error) {
    console.error('Error obteniendo disponibilidad:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// POST /api/padel/venues - Crear sede (solo admin)
router.post('/', authenticateToken, requireRole('admin'), validate(createVenueSchema), async (req, res) => {
  try {
    const { name, location, address, phone, email, image_url, opening_time, closing_time } = req.body;

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

// PUT /api/padel/venues/:id - Editar sede (solo admin)
router.put('/:id', authenticateToken, requireRole('admin'), validate(updateVenueSchema), async (req, res) => {
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
