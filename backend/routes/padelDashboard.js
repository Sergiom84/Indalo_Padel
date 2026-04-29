import express from 'express';

import { pool } from '../db.js';
import { authenticateToken } from '../middleware/auth.js';
import { listMyCalendar } from '../services/padelBookingService.js';
import { getCommunityDashboard } from '../services/padelCommunityService.js';

const router = express.Router();

router.get('/', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.userId;

    const [
      venuesResult,
      matchesResult,
      matchCountResult,
      calendar,
      community,
    ] = await Promise.all([
      pool.query(
        `SELECT id, name, location, address, phone, opening_time, closing_time,
                COALESCE(is_bookable, true) AS is_bookable
         FROM app.padel_venues
         WHERE is_active = true
         ORDER BY
           CASE WHEN COALESCE(is_bookable, true) THEN 0 ELSE 1 END,
           name ASC
         LIMIT 3`,
      ),
      pool.query(
        `SELECT DISTINCT m.*,
                m.current_players AS player_count,
                v.name AS venue_name,
                v.location AS venue_location,
                u.nombre AS creator_name
         FROM app.padel_matches m
         LEFT JOIN app.padel_venues v ON m.venue_id = v.id
         JOIN app.users u ON m.created_by = u.id
         LEFT JOIN app.padel_match_players mp
           ON mp.match_id = m.id
          AND mp.user_id = $1
          AND mp.status <> 'abandonado'
         WHERE (m.created_by = $1 OR mp.user_id = $1)
           AND m.status IN ('buscando', 'completo', 'en_juego')
         ORDER BY m.match_date ASC, m.start_time ASC
         LIMIT 12`,
        [userId],
      ),
      pool.query(
        `SELECT COUNT(DISTINCT m.id)::int AS total
         FROM app.padel_matches m
         LEFT JOIN app.padel_match_players mp
           ON mp.match_id = m.id
          AND mp.user_id = $1
          AND mp.status <> 'abandonado'
         WHERE (m.created_by = $1 OR mp.user_id = $1)
           AND m.status IN ('buscando', 'completo', 'en_juego')`,
        [userId],
      ),
      listMyCalendar(userId),
      getCommunityDashboard(userId),
    ]);
    const bookings = {
      upcoming: Array.isArray(calendar?.agenda?.upcoming)
        ? calendar.agenda.upcoming
        : [],
      past: Array.isArray(calendar?.agenda?.history)
        ? calendar.agenda.history
        : [],
    };

    res.json({
      venues: venuesResult.rows,
      bookings,
      matches: matchesResult.rows,
      community,
      metrics: {
        venues: venuesResult.rows.length,
        upcoming_bookings: bookings.upcoming.length,
        open_matches: Number(matchCountResult.rows[0]?.total) || 0,
        community_active_plans: Array.isArray(community?.active_plans)
          ? community.active_plans.length
          : 0,
      },
    });
  } catch (error) {
    console.error('Error obteniendo dashboard:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

export default router;
