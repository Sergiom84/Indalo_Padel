import express from 'express';

import { pool } from '../db.js';
import { authenticateToken } from '../middleware/auth.js';
import { listBookingsForUser } from '../services/padelBookingService.js';
import { getCommunityDashboard } from '../services/padelCommunityService.js';

const router = express.Router();

router.get('/', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.userId;

    const [venuesResult, matchesResult, bookings, community] = await Promise.all([
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
        `SELECT m.*,
                m.current_players AS player_count,
                v.name AS venue_name,
                v.location AS venue_location,
                u.nombre AS creator_name
         FROM app.padel_matches m
         LEFT JOIN app.padel_venues v ON m.venue_id = v.id
         JOIN app.users u ON m.created_by = u.id
         WHERE m.status IN ('buscando', 'completo')
         ORDER BY m.match_date ASC, m.start_time ASC
         LIMIT 12`,
      ),
      listBookingsForUser(userId),
      getCommunityDashboard(userId),
    ]);

    res.json({
      venues: venuesResult.rows,
      bookings,
      matches: matchesResult.rows,
      community,
      metrics: {
        venues: venuesResult.rows.length,
        upcoming_bookings: Array.isArray(bookings?.upcoming)
          ? bookings.upcoming.length
          : 0,
        open_matches: matchesResult.rows.length,
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
