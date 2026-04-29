import express from 'express';
import { pool } from '../db.js';
import { authenticateToken } from '../middleware/auth.js';
import {
  APP_TIME_ZONE,
  calculateEndTime,
  normalizeDateValue,
  nowInAppZone,
} from '../services/calendarUtils.js';
import { runCommunityLifecycleMaintenance } from '../services/padelCommunityService.js';

const router = express.Router();

const communityModalityLabels = {
  amistoso: 'Amistoso',
  competitivo: 'Competitivo',
  americana: 'Americana',
};

function normalizeTime(value) {
  if (!value) {
    return '';
  }
  return String(value).slice(0, 8);
}

function formatDate(value) {
  const normalized = normalizeDateValue(value, APP_TIME_ZONE);
  if (!normalized) {
    return '';
  }
  const [year, month, day] = normalized.split('-');
  return year && month && day ? `${day}/${month}` : normalized;
}

function formatTime(value) {
  const normalized = normalizeTime(value);
  return normalized.length >= 5 ? normalized.slice(0, 5) : normalized;
}

function displayNameFromRow(row, fallback = 'Jugador') {
  return row.display_name || row.nombre || fallback;
}

function isPlanCancelledOrExpired(plan) {
  return (
    plan.invite_state === 'cancelled' ||
    plan.invite_state === 'expired' ||
    plan.reservation_state === 'cancelled' ||
    plan.reservation_state === 'expired'
  );
}

function isPlanTerminal(plan) {
  return plan.reservation_state === 'confirmed' || isPlanCancelledOrExpired(plan);
}

function isPlanFinished(plan, now = nowInAppZone()) {
  const scheduledDate = normalizeDateValue(plan.scheduled_date, APP_TIME_ZONE);
  const scheduledTime = normalizeTime(plan.scheduled_time);
  if (!scheduledDate || !scheduledTime) {
    return false;
  }

  const durationMinutes =
    Number.parseInt(plan.duration_minutes, 10) || 90;
  const endAt = calculateEndTime(
    scheduledDate,
    scheduledTime,
    durationMinutes,
    APP_TIME_ZONE,
  );

  return endAt.plus({ minutes: 1 }).toMillis() <= now.toMillis();
}

function buildCommunityInvitationBody(plan) {
  const date = formatDate(plan.scheduled_date);
  const time = formatTime(plan.scheduled_time);
  const isRescheduled = plan.invite_state === 'reschedule_pending';
  const details = [];

  if (plan.venue_name) {
    details.push(plan.venue_name);
  }
  details.push(
    `Modalidad: ${communityModalityLabels[plan.modality] || plan.modality || 'Amistoso'}`,
  );
  if (plan.post_padel_plan) {
    details.push(`Post padel: ${plan.post_padel_plan}`);
  }
  if (plan.notes) {
    details.push(`Observaciones: ${plan.notes}`);
  }

  const summary = isRescheduled
    ? `${plan.creator_name} propone jugar el ${date} a las ${time}`
    : `${plan.creator_name} te ha invitado a jugar el ${date} a las ${time}`;

  return details.length ? `${summary}. ${details.join(' - ')}.` : `${summary}.`;
}

function buildCommunityInvitationAlert(plan) {
  const updatedKey = plan.updated_at || plan.scheduled_date || '';
  const isRescheduled = plan.invite_state === 'reschedule_pending';
  return {
    unique_key: `community-plan:${plan.id}:${updatedKey}:${plan.response_state || 'pending'}`,
    title: isRescheduled
      ? 'Nuevo horario en tu convocatoria'
      : 'Te han invitado a un partido',
    body: buildCommunityInvitationBody(plan),
  };
}

function buildPendingPlan(row, participants, userId) {
  const scheduledDate = normalizeDateValue(row.scheduled_date, APP_TIME_ZONE) || '';
  const scheduledTime = normalizeTime(row.scheduled_time);
  return {
    id: Number(row.id),
    created_by: Number(row.created_by),
    creator_name: row.creator_name || 'Organizador',
    scheduled_date: scheduledDate,
    scheduled_time: scheduledTime,
    duration_minutes: Number.parseInt(row.duration_minutes, 10) || 90,
    invite_state: row.invite_state || 'ready',
    reservation_state: row.reservation_state || 'confirmed',
    modality: row.modality || 'amistoso',
    capacity: Number.parseInt(row.capacity, 10) || 4,
    venue_id: row.venue_id ? Number(row.venue_id) : null,
    club_id: row.venue_id ? Number(row.venue_id) : null,
    venue: row.venue_id
      ? {
          id: Number(row.venue_id),
          name: row.venue_name || 'Centro deportivo',
        }
      : null,
    participants,
    is_organizer: Number(row.created_by) === Number(userId),
    my_response_state: row.my_response_state || null,
    is_upcoming: false,
    is_finished: true,
    can_submit_result: true,
    needs_result_notification: true,
    needs_rating: false,
    created_at: row.created_at || null,
    updated_at: row.updated_at || null,
  };
}

async function loadPlayerAlerts(client, userId) {
  const result = await client.query(
    `
      SELECT
        pc.id,
        pc.requested_at,
        COALESCE(NULLIF(pp.display_name, ''), u.nombre, 'Jugador') AS display_name
      FROM app.padel_player_connections pc
      JOIN app.users u
        ON u.id = CASE
          WHEN pc.user_a_id = $1 THEN pc.user_b_id
          ELSE pc.user_a_id
        END
       AND u.deleted_at IS NULL
      LEFT JOIN app.padel_player_profiles pp ON pp.user_id = u.id
      WHERE (pc.user_a_id = $1 OR pc.user_b_id = $1)
        AND pc.status = 'pending'
        AND pc.requested_by <> $1
      ORDER BY pc.requested_at DESC
      LIMIT 20
    `,
    [userId],
  );

  return result.rows.map((row) => ({
    unique_key: `player-request:${row.id}:${row.requested_at || ''}`,
    kind: 'network_request',
    title: 'Nueva invitacion en Jugadores',
    body: `${displayNameFromRow(row)} quiere jugar contigo.`,
  }));
}

async function loadAcceptedPlayerAlerts(client, userId) {
  const result = await client.query(
    `
      SELECT
        pc.id,
        pc.responded_at,
        COALESCE(NULLIF(pp.display_name, ''), u.nombre, 'Jugador') AS display_name
      FROM app.padel_player_connections pc
      JOIN app.users u
        ON u.id = CASE
          WHEN pc.user_a_id = $1 THEN pc.user_b_id
          ELSE pc.user_a_id
        END
       AND u.deleted_at IS NULL
      LEFT JOIN app.padel_player_profiles pp ON pp.user_id = u.id
      WHERE (pc.user_a_id = $1 OR pc.user_b_id = $1)
        AND pc.status = 'accepted'
        AND pc.requested_by = $1
        AND pc.responded_at IS NOT NULL
        AND pc.responded_at >= NOW() - INTERVAL '14 days'
      ORDER BY pc.responded_at DESC
      LIMIT 20
    `,
    [userId],
  );

  return result.rows.map((row) => ({
    unique_key: `player-request-accepted:${row.id}:${row.responded_at || ''}`,
    kind: 'network_accepted',
    title: 'Solicitud aceptada',
    body: `${displayNameFromRow(row)} ha aceptado tu solicitud de amistad.`,
  }));
}

async function loadBookingInvitationAlerts(client, userId) {
  const now = nowInAppZone();
  const today = now.toISODate();
  const currentTime = now.toFormat('HH:mm:ss');

  const result = await client.query(
    `
      SELECT
        bp.id,
        bp.created_at,
        bp.updated_at,
        b.id AS booking_id,
        b.booking_date,
        b.start_time,
        b.end_time,
        c.name AS court_name,
        v.name AS venue_name,
        COALESCE(NULLIF(organizer_profile.display_name, ''), organizer.nombre, 'Organizador') AS organizer_name
      FROM app.padel_booking_players bp
      JOIN app.padel_bookings b ON b.id = bp.booking_id
      JOIN app.padel_courts c ON c.id = b.court_id
      JOIN app.padel_venues v ON v.id = c.venue_id
      JOIN app.users organizer
        ON organizer.id = b.booked_by
       AND organizer.deleted_at IS NULL
      LEFT JOIN app.padel_player_profiles organizer_profile
        ON organizer_profile.user_id = b.booked_by
      WHERE bp.user_id = $1
        AND bp.role = 'guest'
        AND bp.invite_status = 'pendiente'
        AND b.status <> 'cancelada'
        AND (
          b.booking_date > $2::date
          OR (b.booking_date = $2::date AND b.end_time >= $3::time)
        )
      ORDER BY b.booking_date ASC, b.start_time ASC, bp.id ASC
      LIMIT 20
    `,
    [userId, today, currentTime],
  );

  return result.rows.map((row) => {
    const date = formatDate(row.booking_date);
    const time = formatTime(row.start_time);
    const place = [row.venue_name, row.court_name].filter(Boolean).join(' - ');
    const details = [place, date && time ? `${date} a las ${time}` : date || time]
      .filter(Boolean)
      .join(' - ');

    return {
      unique_key: `booking-invitation:${row.id}:${row.updated_at || row.created_at || ''}`,
      kind: 'booking_invitation',
      title: 'Invitacion a reserva',
      body: details
        ? `${row.organizer_name} te ha invitado a una reserva. ${details}.`
        : `${row.organizer_name} te ha invitado a una reserva.`,
    };
  });
}

function buildRatingContext(row) {
  const date = formatDate(row.scheduled_date || row.match_date);
  const time = formatTime(row.scheduled_time || row.start_time);
  const details = [];

  if (row.venue_name) {
    details.push(row.venue_name);
  }
  if (date) {
    details.push(time ? `${date} a las ${time}` : date);
  }

  return details.length ? ` (${details.join(' - ')})` : '';
}

async function loadRatingAlerts(client, userId) {
  const result = await client.query(
    `
      SELECT
        r.id,
        r.rating,
        r.comment,
        r.created_at,
        COALESCE(NULLIF(rater_profile.display_name, ''), rater.nombre, 'Jugador') AS rater_name,
        cp.scheduled_date,
        cp.scheduled_time,
        m.match_date,
        m.start_time,
        COALESCE(plan_venue.name, match_venue.name) AS venue_name
      FROM app.padel_player_ratings r
      JOIN app.users rater
        ON rater.id = r.rater_id
       AND rater.deleted_at IS NULL
      LEFT JOIN app.padel_player_profiles rater_profile
        ON rater_profile.user_id = r.rater_id
      LEFT JOIN app.padel_community_plans cp
        ON cp.id = r.community_plan_id
      LEFT JOIN app.padel_matches m
        ON m.id = r.match_id
      LEFT JOIN app.padel_venues plan_venue
        ON plan_venue.id = cp.venue_id
      LEFT JOIN app.padel_venues match_venue
        ON match_venue.id = m.venue_id
      WHERE r.rated_id = $1
      ORDER BY r.created_at DESC, r.id DESC
      LIMIT 10
    `,
    [userId],
  );

  return result.rows.map((row) => {
    const rating = Number.parseInt(row.rating, 10) || 0;
    const context = buildRatingContext(row);
    const comment = row.comment ? ` Comentario: ${row.comment}` : '';
    return {
      unique_key: `player-rating:${row.id}:${row.created_at || ''}`,
      title: 'Nueva valoración recibida',
      body: `${displayNameFromRow(row, row.rater_name)} te ha valorado con ${rating}/5 estrellas${context}.${comment}`,
    };
  });
}

async function loadCommunityNotificationAlerts(client, userId) {
  const result = await client.query(
    `
      SELECT
        n.id,
        n.plan_id,
        n.title,
        n.message,
        n.metadata,
        n.created_at,
        cp.created_by
      FROM app.padel_community_notifications n
      LEFT JOIN app.padel_community_plans cp ON cp.id = n.plan_id
      WHERE n.user_id = $1
        AND n.is_read = false
      ORDER BY n.created_at ASC
      LIMIT 20
    `,
    [userId],
  );

  const planner = [];
  const invitations = [];
  for (const row of result.rows) {
    const metadata = row.metadata || {};
    const alert = {
      unique_key: `community-notification:${row.id}`,
      title: row.title || 'Aviso de comunidad',
      body: row.message || '',
    };
    const isPlanner =
      Number(row.created_by) === Number(userId) ||
      metadata.action_type === 'review_plan';
    if (isPlanner) {
      planner.push(alert);
    } else {
      invitations.push(alert);
    }
  }

  return { planner, invitations };
}

async function loadCommunityInvitationAlerts(client, userId) {
  const result = await client.query(
    `
      SELECT
        cp.id,
        cp.created_by,
        COALESCE(NULLIF(creator_profile.display_name, ''), creator.nombre, 'Organizador') AS creator_name,
        cp.scheduled_date,
        cp.scheduled_time,
        cp.duration_minutes,
        cp.invite_state,
        cp.reservation_state,
        cp.modality,
        cp.post_padel_plan,
        cp.notes,
        cp.updated_at,
        v.name AS venue_name,
        cpp.response_state
      FROM app.padel_community_plans cp
      JOIN app.padel_community_plan_players cpp
        ON cpp.plan_id = cp.id
       AND cpp.user_id = $1
      JOIN app.users creator ON creator.id = cp.created_by
      LEFT JOIN app.padel_player_profiles creator_profile
        ON creator_profile.user_id = cp.created_by
      LEFT JOIN app.padel_venues v ON v.id = cp.venue_id
      WHERE cpp.role <> 'organizer'
        AND cpp.response_state IN ('pending', 'doubt')
        AND cp.invite_state NOT IN ('cancelled', 'expired')
        AND cp.reservation_state NOT IN ('confirmed', 'cancelled', 'expired')
        AND NOT EXISTS (
          SELECT 1
          FROM app.padel_community_notifications n
          WHERE n.plan_id = cp.id
            AND n.user_id = $1
            AND n.type = 'plan_invitation'
            AND n.is_read = false
        )
      ORDER BY cp.scheduled_date ASC, cp.scheduled_time ASC, cp.id ASC
      LIMIT 20
    `,
    [userId],
  );

  return result.rows
    .filter((plan) => !isPlanTerminal(plan))
    .map(buildCommunityInvitationAlert);
}

async function loadPendingResultPlans(client, userId) {
  const planResult = await client.query(
    `
      SELECT
        cp.id,
        cp.created_by,
        COALESCE(NULLIF(creator_profile.display_name, ''), creator.nombre, 'Organizador') AS creator_name,
        cp.scheduled_date,
        cp.scheduled_time,
        cp.duration_minutes,
        cp.invite_state,
        cp.reservation_state,
        cp.modality,
        cp.capacity,
        cp.venue_id,
        cp.created_at,
        cp.updated_at,
        v.name AS venue_name,
        mine.response_state AS my_response_state,
        COALESCE(accepted.accepted_count, 0) AS accepted_count,
        mr.status AS result_status,
        my_submission.id AS my_submission_id
      FROM app.padel_community_plans cp
      JOIN app.padel_community_plan_players mine
        ON mine.plan_id = cp.id
       AND mine.user_id = $1
       AND mine.response_state = 'accepted'
      JOIN app.users creator ON creator.id = cp.created_by
      LEFT JOIN app.padel_player_profiles creator_profile
        ON creator_profile.user_id = cp.created_by
      LEFT JOIN app.padel_venues v ON v.id = cp.venue_id
      LEFT JOIN app.padel_match_results mr ON mr.plan_id = cp.id
      LEFT JOIN app.padel_match_result_submissions my_submission
        ON my_submission.plan_id = cp.id
       AND my_submission.user_id = $1
      LEFT JOIN (
        SELECT plan_id, COUNT(*) AS accepted_count
        FROM app.padel_community_plan_players
        WHERE response_state = 'accepted'
        GROUP BY plan_id
      ) accepted ON accepted.plan_id = cp.id
      WHERE cp.reservation_state = 'confirmed'
        AND cp.invite_state NOT IN ('cancelled', 'expired')
        AND my_submission.id IS NULL
        AND COALESCE(mr.status, '') <> 'consensuado'
      ORDER BY cp.scheduled_date DESC, cp.scheduled_time DESC, cp.id DESC
      LIMIT 10
    `,
    [userId],
  );

  const now = nowInAppZone();
  const rows = planResult.rows.filter((row) => {
    const acceptedCount = Number.parseInt(row.accepted_count, 10) || 0;
    return (
      (acceptedCount === 2 || acceptedCount === 4) &&
      !isPlanCancelledOrExpired(row) &&
      isPlanFinished(row, now)
    );
  });

  if (!rows.length) {
    return [];
  }

  const planIds = rows.map((row) => Number(row.id));
  const participantResult = await client.query(
    `
      SELECT
        cpp.plan_id,
        cpp.user_id,
        COALESCE(NULLIF(pp.display_name, ''), u.nombre, 'Jugador') AS display_name,
        u.nombre,
        pp.numeric_level,
        pp.main_level,
        pp.sub_level,
        cpp.role,
        cpp.response_state,
        cpp.responded_at
      FROM app.padel_community_plan_players cpp
      JOIN app.users u ON u.id = cpp.user_id
      LEFT JOIN app.padel_player_profiles pp ON pp.user_id = cpp.user_id
      WHERE cpp.plan_id = ANY($1::int[])
      ORDER BY
        cpp.plan_id ASC,
        CASE WHEN cpp.role = 'organizer' THEN 0 ELSE 1 END,
        u.nombre ASC
    `,
    [planIds],
  );

  const participantsByPlan = new Map();
  for (const row of participantResult.rows) {
    const planId = Number(row.plan_id);
    const participant = {
      user_id: Number(row.user_id),
      display_name: displayNameFromRow(row),
      nombre: row.nombre || null,
      numeric_level: Number.parseInt(row.numeric_level, 10) || 0,
      main_level: row.main_level || null,
      sub_level: row.sub_level || null,
      role: row.role || 'player',
      response_state: row.response_state || 'pending',
      responded_at: row.responded_at || null,
      is_current_user: Number(row.user_id) === Number(userId),
      is_organizer: row.role === 'organizer',
    };

    if (!participantsByPlan.has(planId)) {
      participantsByPlan.set(planId, []);
    }
    participantsByPlan.get(planId).push(participant);
  }

  return rows.map((row) =>
    buildPendingPlan(
      row,
      participantsByPlan.get(Number(row.id)) || [],
      userId,
    ),
  );
}

router.get('/', authenticateToken, async (req, res) => {
  const userId = req.user.userId;

  try {
    await runCommunityLifecycleMaintenance();

    const client = await pool.connect();
    try {
      const playerInvitationAlerts = await loadPlayerAlerts(client, userId);
      const acceptedPlayerAlerts = await loadAcceptedPlayerAlerts(client, userId);
      const bookingInvitationAlerts =
        await loadBookingInvitationAlerts(client, userId);
      const ratingAlerts = await loadRatingAlerts(client, userId);
      const notificationAlerts =
        await loadCommunityNotificationAlerts(client, userId);
      const communityInvitationAlerts = [
        ...(await loadCommunityInvitationAlerts(client, userId)),
        ...notificationAlerts.invitations,
      ];
      const pendingResultPlans = await loadPendingResultPlans(client, userId);

      res.json({
        community_planner_alerts: notificationAlerts.planner,
        community_invitation_alerts: communityInvitationAlerts,
        booking_invitation_alerts: bookingInvitationAlerts,
        player_invitation_alerts: [
          ...playerInvitationAlerts,
          ...acceptedPlayerAlerts,
        ],
        rating_alerts: ratingAlerts,
        pending_result_plans: pendingResultPlans,
        updated_at: nowInAppZone().toISO(),
      });
    } finally {
      client.release();
    }
  } catch (error) {
    console.error('Error obteniendo alertas ligeras:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

export default router;
