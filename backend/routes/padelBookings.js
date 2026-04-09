import express from 'express';
import { pool } from '../db.js';
import { authenticateToken } from '../middleware/auth.js';
import { validate } from '../middleware/validate.js';
import { createBookingSchema } from '../validators/bookingValidators.js';
import {
  cancelBooking,
  createBooking,
  getBookingById,
  getCalendarData,
  listBookingsForUser,
  respondToBooking,
  updateBooking,
} from '../services/padelBookingService.js';
import { runCalendarSyncCycle } from '../services/padelCalendarSync.js';

const router = express.Router();

router.post('/', authenticateToken, validate(createBookingSchema), async (req, res) => {
  try {
    const result = await createBooking({
      userId: req.user.userId,
      courtId: req.body.court_id,
      bookingDate: req.body.booking_date,
      startTime: req.body.start_time,
      durationMinutes: req.body.duration_minutes,
      notes: req.body.notes,
      playerUserIds: req.body.player_user_ids || req.body.player_ids || [],
    });
    return res.status(result.status).json(result.body);
  } catch (error) {
    console.error('Error creando reserva:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

router.get('/my-calendar', authenticateToken, async (req, res) => {
  try {
    await runCalendarSyncCycle().catch((error) => {
      console.error('Error sincronizando calendario antes de responder /my-calendar:', error.message);
    });
    const result = await getCalendarData(req.user.userId);
    return res.json(result);
  } catch (error) {
    console.error('Error obteniendo calendario:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

router.get('/my', authenticateToken, async (req, res) => {
  try {
    const result = await listBookingsForUser(req.user.userId);
    return res.json(result);
  } catch (error) {
    console.error('Error obteniendo reservas:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

router.get('/:id', authenticateToken, async (req, res) => {
  try {
    const booking = await getBookingById(req.params.id, req.user.userId);
    if (!booking) {
      return res.status(404).json({ error: 'Reserva no encontrada' });
    }

    return res.json({ booking });
  } catch (error) {
    console.error('Error obteniendo reserva:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

router.put('/:id', authenticateToken, async (req, res) => {
  try {
    const result = await updateBooking({
      bookingId: req.params.id,
      userId: req.user.userId,
      payload: req.body,
    });
    return res.status(result.status).json(result.body);
  } catch (error) {
    console.error('Error actualizando reserva:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

router.put('/:id/cancel', authenticateToken, async (req, res) => {
  try {
    const result = await cancelBooking({
      bookingId: req.params.id,
      userId: req.user.userId,
    });
    return res.status(result.status).json(result.body);
  } catch (error) {
    console.error('Error cancelando reserva:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

router.put('/:id/respond', authenticateToken, async (req, res) => {
  try {
    const result = await respondToBooking({
      bookingId: req.params.id,
      userId: req.user.userId,
      status: req.body.status ?? req.body.response,
    });
    return res.status(result.status).json(result.body);
  } catch (error) {
    console.error('Error respondiendo a la reserva:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

router.put('/:id/confirm', authenticateToken, async (req, res) => {
  try {
    const client = await pool.connect();
    try {
      const updateResult = await client.query(
        `UPDATE app.padel_bookings
         SET status = 'confirmada',
             calendar_sync_status = 'pendiente',
             updated_at = NOW()
         WHERE id = $1
           AND booked_by = $2
           AND status = 'pendiente'
         RETURNING *`,
        [req.params.id, req.user.userId]
      );
      if (updateResult.rowCount === 0) {
        return res.status(404).json({ error: 'Reserva no encontrada o no se puede confirmar' });
      }
      const booking = await getBookingById(req.params.id, req.user.userId);
      if (!booking) {
        return res.status(404).json({ error: 'Reserva no encontrada o no se puede confirmar' });
      }

      return res.json({ booking });
    } finally {
      client.release();
    }
  } catch (error) {
    console.error('Error confirmando reserva:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

export default router;
