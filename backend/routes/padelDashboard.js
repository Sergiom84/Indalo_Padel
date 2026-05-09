import express from 'express';

import { pool } from '../db.js';
import { authenticateToken } from '../middleware/auth.js';
import { listMyCalendar } from '../services/padelBookingService.js';
import {
  APP_TIME_ZONE,
  normalizeDateValue,
  nowInAppZone,
} from '../services/calendarUtils.js';
import { getCommunityDashboard } from '../services/padelCommunityService.js';

const router = express.Router();

const INACTIVE_BOOKING_INVITE_STATUSES = new Set(['rechazada', 'cancelada']);
const CANCELLED_STATUSES = new Set(['cancelada', 'cancelled', 'expired']);

function countUnique(items, isIncluded) {
  const seen = new Set();
  let count = 0;

  for (const item of items) {
    if (!item || !isIncluded(item)) {
      continue;
    }

    const key = item.id == null
      ? `${item.booking_date || item.scheduled_date || ''}-${item.start_time || item.scheduled_time || ''}`
      : String(item.id);
    if (seen.has(key)) {
      continue;
    }

    seen.add(key);
    count += 1;
  }

  return count;
}

function isBookingOnDate(booking, targetDate) {
  const bookingDate = normalizeDateValue(
    booking.booking_date || booking.date || booking.fecha,
    APP_TIME_ZONE,
  );
  const bookingStatus = String(booking.status || '').toLowerCase();
  const inviteStatus = String(booking.my_invite_status || '').toLowerCase();

  return bookingDate === targetDate
    && !CANCELLED_STATUSES.has(bookingStatus)
    && !INACTIVE_BOOKING_INVITE_STATUSES.has(inviteStatus);
}

function isConfirmedCommunityPlanOnDate(plan, targetDate) {
  const scheduledDate = normalizeDateValue(plan.scheduled_date, APP_TIME_ZONE);
  const inviteState = String(plan.invite_state || '').toLowerCase();
  const reservationState = String(plan.reservation_state || '').toLowerCase();

  return scheduledDate === targetDate
    && reservationState === 'confirmed'
    && !CANCELLED_STATUSES.has(inviteState);
}

function countTodayBookings(bookings, community) {
  const today = nowInAppZone(APP_TIME_ZONE).toISODate();
  const agendaBookings = [
    ...bookings.upcoming,
    ...bookings.past,
  ];
  const communityPlans = [
    ...(
      Array.isArray(community?.active_plans) ? community.active_plans : []
    ),
    ...(
      Array.isArray(community?.history_plans) ? community.history_plans : []
    ),
  ];

  return countUnique(agendaBookings, (booking) =>
    isBookingOnDate(booking, today)) +
    countUnique(communityPlans, (plan) =>
      isConfirmedCommunityPlanOnDate(plan, today));
}

router.get('/', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.userId;
    const now = nowInAppZone(APP_TIME_ZONE);
    const today = now.toISODate();
    const currentTime = now.toFormat('HH:mm:ss');

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
           AND (
             m.match_date > $2::date
             OR (m.match_date = $2::date AND m.start_time >= $3::time)
           )
         ORDER BY m.match_date ASC, m.start_time ASC
         LIMIT 12`,
        [userId, today, currentTime],
      ),
      pool.query(
        `SELECT COUNT(DISTINCT m.id)::int AS total
         FROM app.padel_matches m
         LEFT JOIN app.padel_match_players mp
           ON mp.match_id = m.id
          AND mp.user_id = $1
          AND mp.status <> 'abandonado'
         WHERE (m.created_by = $1 OR mp.user_id = $1)
           AND m.status IN ('buscando', 'completo', 'en_juego')
           AND (
             m.match_date > $2::date
             OR (m.match_date = $2::date AND m.start_time >= $3::time)
           )`,
        [userId, today, currentTime],
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
    const confirmedCommunityBookingsCount = Array.isArray(community?.active_plans)
      ? community.active_plans.filter(
        (plan) =>
          plan?.reservation_state === 'confirmed' &&
          plan?.is_upcoming === true &&
          plan?.is_finished !== true,
      ).length
      : 0;

    res.json({
      venues: venuesResult.rows,
      bookings,
      matches: matchesResult.rows,
      community,
      metrics: {
        venues: venuesResult.rows.length,
        upcoming_bookings:
          bookings.upcoming.length + confirmedCommunityBookingsCount,
        today_bookings: countTodayBookings(bookings, community),
        upcoming_matches: Number(matchCountResult.rows[0]?.total) || 0,
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
