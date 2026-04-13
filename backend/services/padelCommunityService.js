import { DateTime } from 'luxon';
import { pool } from '../db.js';
import {
  APP_TIME_ZONE,
  DEFAULT_DURATION_MINUTES,
  combineDateAndTime,
  calculateEndTime,
  normalizeDateValue,
  toGoogleDateTime,
} from './calendarUtils.js';
import {
  createCalendarEvent,
  isGoogleCalendarConfigured,
  updateCalendarEvent,
} from './googleCalendar.js';

const MAX_ACTIVE_PLANS = 3;
const COMMUNITY_RECOVERY_BUFFER_MINUTES = 45;
const TERMINAL_INVITE_STATES = new Set(['cancelled', 'expired']);
const TERMINAL_RESERVATION_STATES = new Set(['confirmed', 'cancelled', 'expired']);
const SERIOUS_RESPONSE_STATES = new Set(['accepted']);
const PENDING_RESPONSE_STATES = new Set(['pending', 'doubt']);

function isPlanTerminal(plan) {
  if (!plan) {
    return false;
  }

  return TERMINAL_INVITE_STATES.has(plan.invite_state)
    || TERMINAL_RESERVATION_STATES.has(plan.reservation_state);
}

function isPlanActive(plan) {
  return !isPlanTerminal(plan);
}

function normalizeTimestamp(value) {
  if (!value) {
    return null;
  }

  const date = value instanceof Date ? value : new Date(value);
  const time = date.getTime();
  return Number.isFinite(time) ? time : null;
}

function ensureFreshPlan(plan, expectedUpdatedAt) {
  if (!expectedUpdatedAt) {
    return null;
  }

  const current = normalizeTimestamp(plan?.updated_at);
  const expected = normalizeTimestamp(expectedUpdatedAt);
  if (current === null || expected === null) {
    return null;
  }

  if (current !== expected) {
    return {
      status: 409,
      body: {
        error: 'La convocatoria ha cambiado en otra sesión. Recarga antes de continuar.',
        code: 'stale_plan',
        current_updated_at: plan.updated_at,
      },
    };
  }

  return null;
}

function buildClosedPayload(plan, reason = null) {
  const state = plan?.reservation_state || plan?.invite_state;
  return {
    status: 400,
    body: {
      error: 'La convocatoria ya está cerrada y solo se puede consultar.',
      code: 'plan_closed',
      plan_state: state,
      closed_reason: reason || plan?.closed_reason || null,
    },
  };
}

function asInt(value) {
  const parsed = Number.parseInt(value, 10);
  return Number.isInteger(parsed) ? parsed : null;
}

function normalizeParticipantIds(values, currentUserId) {
  return [...new Set((values || [])
    .map((value) => asInt(value))
    .filter((value) => value !== null && value !== currentUserId))];
}

function displayNameFromRow(row, {
  displayNameKey = 'display_name',
  fallbackNameKey = 'nombre',
  fallback = 'Jugador',
} = {}) {
  return row?.[displayNameKey] || row?.[fallbackNameKey] || fallback;
}

function mapCommunityPlayerRow(row) {
  return {
    user_id: Number(row.user_id),
    display_name: displayNameFromRow(row),
    nombre: row.nombre,
    email: row.email || null,
    numeric_level: Number.parseInt(row.numeric_level, 10) || 0,
    is_available: row.is_available ?? true,
    avatar_url: row.avatar_url || null,
    avg_rating: Number(row.avg_rating || 0),
  };
}

function mapParticipantRow(row, currentUserId) {
  return {
    user_id: Number(row.user_id),
    display_name: displayNameFromRow(row),
    nombre: row.nombre,
    email: row.email || null,
    numeric_level: Number.parseInt(row.numeric_level, 10) || 0,
    is_available: row.is_available ?? true,
    avatar_url: row.avatar_url || null,
    role: row.role,
    response_state: row.response_state,
    responded_at: row.responded_at,
    is_current_user: Number(row.user_id) === Number(currentUserId),
    is_organizer: row.role === 'organizer',
  };
}

function mapVenueRow(row) {
  if (!row) {
    return null;
  }

  return {
    id: row.id ? Number(row.id) : (row.venue_id ? Number(row.venue_id) : null),
    name: row.name || row.venue_name || 'Centro deportivo',
    location: row.location || row.venue_location || null,
    address: row.address || row.venue_address || null,
    phone: row.phone || row.venue_phone || null,
  };
}

function mapNotificationRow(row) {
  return {
    id: Number(row.id),
    plan_id: Number(row.plan_id),
    type: row.type,
    title: row.title,
    message: row.message,
    metadata: row.metadata || {},
    is_read: row.is_read,
    created_at: row.created_at,
    action_type: row.action_type || null,
  };
}

function buildPlanDto(row, participants, currentUserId) {
  const myParticipant = participants.find(
    (participant) => Number(participant.user_id) === Number(currentUserId),
  );

  return {
    id: Number(row.id),
    created_by: Number(row.created_by),
    creator_name:
      row.creator_display_name || row.creator_name || 'Organizador',
    scheduled_date: normalizeDateValue(row.scheduled_date, APP_TIME_ZONE),
    scheduled_time: row.scheduled_time,
    duration_minutes:
      Number.parseInt(row.duration_minutes, 10) || DEFAULT_DURATION_MINUTES,
    invite_state: row.invite_state,
    reservation_state: row.reservation_state,
    reservation_handled_by: row.reservation_handled_by
      ? Number(row.reservation_handled_by)
      : null,
    reservation_handled_by_name:
      row.reservation_handled_display_name ||
      row.reservation_handled_by_name ||
      null,
    reservation_contact_phone: row.reservation_contact_phone || null,
    google_event_id: row.google_event_id || null,
    last_declined_by: row.last_declined_by ? Number(row.last_declined_by) : null,
    last_declined_by_name:
      row.last_declined_display_name || row.last_declined_by_name || null,
    last_reschedule_by: row.last_reschedule_by
      ? Number(row.last_reschedule_by)
      : null,
    last_reschedule_by_name:
      row.last_reschedule_display_name || row.last_reschedule_by_name || null,
    last_reschedule_date: row.last_reschedule_date
      ? normalizeDateValue(row.last_reschedule_date, APP_TIME_ZONE)
      : null,
    last_reschedule_time: row.last_reschedule_time || null,
    reservation_confirmed_at: row.reservation_confirmed_at || null,
    calendar_sync_status: row.calendar_sync_status || 'pending',
    last_synced_at: row.last_synced_at || null,
    closed_at: row.closed_at || null,
    closed_by: row.closed_by ? Number(row.closed_by) : null,
    closed_by_name:
      row.closed_by_display_name || row.closed_by_name || null,
    closed_reason: row.closed_reason || null,
    created_at: row.created_at,
    updated_at: row.updated_at,
    venue: mapVenueRow(row),
    participants,
    is_organizer: Number(row.created_by) === Number(currentUserId),
    my_response_state: myParticipant?.response_state || null,
  };
}

async function loadDefaultVenue(client) {
  const result = await client.query(
    `SELECT id, name, location, address, phone
     FROM app.padel_venues
     WHERE is_active = true
     ORDER BY
       CASE WHEN COALESCE(is_bookable, true) THEN 0 ELSE 1 END,
       CASE WHEN phone IS NOT NULL AND BTRIM(phone) <> '' THEN 0 ELSE 1 END,
       id ASC
     LIMIT 1`,
  );

  return result.rows[0] || null;
}

async function loadAcceptedCompanions(client, userId) {
  const result = await client.query(
    `
      WITH ratings AS (
        SELECT rated_id, AVG(rating) AS avg_rating
        FROM app.padel_player_ratings
        GROUP BY rated_id
      )
      SELECT
        u.id as user_id,
        u.nombre,
        u.email,
        pp.display_name,
        pp.numeric_level,
        pp.is_available,
        pp.avatar_url,
        COALESCE(r.avg_rating, 0) as avg_rating
      FROM app.padel_player_connections pc
      JOIN app.users u
        ON u.id = CASE
          WHEN pc.user_a_id = $1 THEN pc.user_b_id
          ELSE pc.user_a_id
        END
      LEFT JOIN app.padel_player_profiles pp ON pp.user_id = u.id
      LEFT JOIN ratings r ON r.rated_id = u.id
      WHERE pc.status = 'accepted'
        AND (pc.user_a_id = $1 OR pc.user_b_id = $1)
      ORDER BY u.nombre ASC
    `,
    [userId],
  );

  return result.rows.map(mapCommunityPlayerRow);
}

async function ensureParticipantPool(client, userId, participantUserIds) {
  const participantIds = normalizeParticipantIds(participantUserIds, userId);
  const companions = await loadAcceptedCompanions(client, userId);
  const companionMap = new Map(
    companions.map((player) => [Number(player.user_id), player]),
  );

  const selectedPlayers = participantIds
    .map((id) => companionMap.get(Number(id)) || null)
    .filter(Boolean);

  if (selectedPlayers.length !== participantIds.length) {
    return {
      ok: false,
      participantIds,
      players: [],
    };
  }

  return {
    ok: true,
    participantIds,
    players: selectedPlayers,
  };
}

async function loadPlanRowsForUser(client, userId) {
  const result = await client.query(
    `
      SELECT
        cp.*,
        v.name as venue_name,
        v.location as venue_location,
        v.address as venue_address,
        v.phone as venue_phone,
        creator.nombre as creator_name,
        creator_profile.display_name as creator_display_name,
        handled.nombre as reservation_handled_by_name,
        handled_profile.display_name as reservation_handled_display_name,
        declined.nombre as last_declined_by_name,
        declined_profile.display_name as last_declined_display_name,
        reschedule.nombre as last_reschedule_by_name,
        reschedule_profile.display_name as last_reschedule_display_name,
        closed_user.nombre as closed_by_name,
        closed_profile.display_name as closed_by_display_name
      FROM app.padel_community_plans cp
      JOIN app.padel_community_plan_players membership
        ON membership.plan_id = cp.id
       AND membership.user_id = $1
      LEFT JOIN app.padel_venues v ON v.id = cp.venue_id
      LEFT JOIN app.users creator ON creator.id = cp.created_by
      LEFT JOIN app.padel_player_profiles creator_profile
        ON creator_profile.user_id = creator.id
      LEFT JOIN app.users handled ON handled.id = cp.reservation_handled_by
      LEFT JOIN app.padel_player_profiles handled_profile
        ON handled_profile.user_id = handled.id
      LEFT JOIN app.users declined ON declined.id = cp.last_declined_by
      LEFT JOIN app.padel_player_profiles declined_profile
        ON declined_profile.user_id = declined.id
      LEFT JOIN app.users reschedule ON reschedule.id = cp.last_reschedule_by
      LEFT JOIN app.padel_player_profiles reschedule_profile
        ON reschedule_profile.user_id = reschedule.id
      LEFT JOIN app.users closed_user ON closed_user.id = cp.closed_by
      LEFT JOIN app.padel_player_profiles closed_profile
        ON closed_profile.user_id = closed_user.id
      ORDER BY
        CASE
          WHEN cp.reservation_state IN ('confirmed', 'cancelled', 'expired')
            OR cp.invite_state IN ('cancelled', 'expired')
          THEN 1
          ELSE 0
        END,
        cp.updated_at DESC,
        cp.id DESC
    `,
    [userId],
  );

  return result.rows;
}

async function loadParticipantsForPlans(client, planIds, currentUserId) {
  if (!planIds.length) {
    return new Map();
  }

  const result = await client.query(
    `
      SELECT
        cpp.plan_id,
        cpp.user_id,
        cpp.role,
        cpp.response_state,
        cpp.responded_at,
        u.nombre,
        u.email,
        pp.display_name,
        pp.numeric_level,
        pp.is_available,
        pp.avatar_url
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

  const participantMap = new Map();
  for (const row of result.rows) {
    const planId = Number(row.plan_id);
    if (!participantMap.has(planId)) {
      participantMap.set(planId, []);
    }
    participantMap.get(planId).push(mapParticipantRow(row, currentUserId));
  }

  return participantMap;
}

async function loadUnreadNotifications(client, userId) {
  await client.query(
    `DELETE FROM app.padel_community_notifications
     WHERE user_id = $1 AND created_at < NOW() - INTERVAL '30 days'`,
    [userId],
  );

  const result = await client.query(
    `
      SELECT id, plan_id, type, title, message, metadata, is_read, created_at
      FROM app.padel_community_notifications
      WHERE user_id = $1
        AND is_read = false
      ORDER BY created_at ASC
      LIMIT 20
    `,
    [userId],
  );

  return result.rows.map(mapNotificationRow);
}

async function loadPlanForMember(client, planId, userId) {
  const result = await client.query(
    `
      SELECT cp.*
      FROM app.padel_community_plans cp
      JOIN app.padel_community_plan_players membership
        ON membership.plan_id = cp.id
       AND membership.user_id = $2
      WHERE cp.id = $1
      LIMIT 1
    `,
    [planId, userId],
  );

  return result.rows[0] || null;
}

async function loadPlanForOrganizer(client, planId, userId) {
  const result = await client.query(
    `
      SELECT *
      FROM app.padel_community_plans
      WHERE id = $1
        AND created_by = $2
      LIMIT 1
    `,
    [planId, userId],
  );

  return result.rows[0] || null;
}

async function loadPlanBundle(client, planId, userId) {
  const planRows = await loadPlanRowsForUser(client, userId);
  const row = planRows.find((plan) => Number(plan.id) === Number(planId));
  if (!row) {
    return null;
  }

  const participantsMap = await loadParticipantsForPlans(
    client,
    [Number(planId)],
    userId,
  );

  return buildPlanDto(
    row,
    participantsMap.get(Number(planId)) || [],
    userId,
  );
}

async function createNotifications(client, {
  planId,
  userIds,
  excludeUserIds = [],
  type,
  title,
  message,
  metadata = {},
}) {
  const excluded = new Set(excludeUserIds.map((value) => Number(value)));
  const recipients = [...new Set(userIds.map((value) => Number(value)))]
    .filter((value) => !excluded.has(value));

  for (const recipientId of recipients) {
    await client.query(
      `
        INSERT INTO app.padel_community_notifications (
          plan_id,
          user_id,
          type,
          title,
          message,
          metadata
        )
        VALUES ($1, $2, $3, $4, $5, $6::jsonb)
      `,
      [planId, recipientId, type, title, message, JSON.stringify(metadata)],
    );
  }
}

async function updateInviteState(client, planId, nextState, extraUpdates = {}) {
  await client.query(
    `
      UPDATE app.padel_community_plans
      SET invite_state = $2,
          last_declined_by = $3,
          last_reschedule_by = $4,
          last_reschedule_date = $5,
          last_reschedule_time = $6,
          closed_at = COALESCE($7, closed_at),
          closed_by = COALESCE($8, closed_by),
          closed_reason = COALESCE($9, closed_reason),
          updated_at = NOW()
      WHERE id = $1
    `,
    [
      planId,
      nextState,
      extraUpdates.last_declined_by ?? null,
      extraUpdates.last_reschedule_by ?? null,
      extraUpdates.last_reschedule_date ?? null,
      extraUpdates.last_reschedule_time ?? null,
      extraUpdates.closed_at ?? null,
      extraUpdates.closed_by ?? null,
      extraUpdates.closed_reason ?? null,
    ],
  );
}

async function recomputeInviteState(client, planId) {
  const summaryResult = await client.query(
    `
      SELECT
        cp.invite_state,
        cp.reservation_state,
        COUNT(*) AS total_players,
        COUNT(*) FILTER (WHERE cpp.response_state = 'accepted') AS accepted_players,
        COUNT(*) FILTER (WHERE cpp.response_state = 'declined') AS declined_players,
        COUNT(*) FILTER (WHERE cpp.response_state = 'doubt') AS doubt_players,
        COUNT(*) FILTER (WHERE cpp.response_state = 'pending') AS pending_players
      FROM app.padel_community_plans cp
      JOIN app.padel_community_plan_players cpp ON cpp.plan_id = cp.id
      WHERE cp.id = $1
      GROUP BY cp.id
    `,
    [planId],
  );

  if (summaryResult.rows.length === 0) {
    return null;
  }

  const summary = summaryResult.rows[0];
  if (TERMINAL_RESERVATION_STATES.has(summary.reservation_state)
      || TERMINAL_INVITE_STATES.has(summary.invite_state)) {
    return summary.invite_state;
  }

  const totalPlayers = Number(summary.total_players || 0);
  const acceptedPlayers = Number(summary.accepted_players || 0);
  const declinedPlayers = Number(summary.declined_players || 0);
  const doubtPlayers = Number(summary.doubt_players || 0);
  const pendingPlayers = Number(summary.pending_players || 0);

  let nextState = 'pending';
  if (declinedPlayers > 0) {
    nextState = 'replacement_required';
  } else if (acceptedPlayers === totalPlayers && totalPlayers > 0) {
    nextState = 'ready';
  } else if (summary.invite_state === 'reschedule_pending') {
    nextState = 'reschedule_pending';
  } else if (doubtPlayers > 0 || pendingPlayers > 0) {
    nextState = 'pending';
  }

  await client.query(
    `
      UPDATE app.padel_community_plans
      SET invite_state = $2,
          updated_at = NOW()
      WHERE id = $1
    `,
    [planId, nextState],
  );

  return nextState;
}

function buildCommunityTimeRange(scheduledDate, scheduledTime, durationMinutes = DEFAULT_DURATION_MINUTES) {
  const start = combineDateAndTime(scheduledDate, scheduledTime, APP_TIME_ZONE);
  const end = start.plus({ minutes: durationMinutes || DEFAULT_DURATION_MINUTES });
  const hardStart = start.minus({ minutes: COMMUNITY_RECOVERY_BUFFER_MINUTES });
  const hardEnd = end.plus({ minutes: COMMUNITY_RECOVERY_BUFFER_MINUTES });

  return { start, end, hardStart, hardEnd };
}

function overlapsRange(leftStart, leftEnd, rightStart, rightEnd) {
  return leftStart.toMillis() < rightEnd.toMillis()
    && leftEnd.toMillis() > rightStart.toMillis();
}

function buildCommunityConflictMessage(conflict) {
  const time = conflict.scheduled_time?.slice(0, 5) || '';
  const date = normalizeDateValue(conflict.scheduled_date, APP_TIME_ZONE) || '';

  if (conflict.severity === 'hard') {
    if (conflict.source === 'booking') {
      return `${conflict.display_name} ya tiene una reserva confirmada el ${date} a las ${time}.`;
    }

    return `${conflict.display_name} ya está comprometido con otro partido el ${date} a las ${time}.`;
  }

  return `${conflict.display_name} ya tiene otra invitación pendiente el ${date} a las ${time}.`;
}

async function loadConflictEntriesForUser(client, {
  userId,
  planId = null,
  scheduledDate,
  scheduledTime,
}) {
  const range = buildCommunityTimeRange(scheduledDate, scheduledTime);
  const dateFloor = range.start.minus({ days: 1 }).toISODate();
  const dateCeiling = range.end.plus({ days: 1 }).toISODate();

  const planConflictsResult = await client.query(
    `
      SELECT
        cp.id,
        cp.scheduled_date,
        cp.scheduled_time,
        cp.duration_minutes,
        cp.invite_state,
        cp.reservation_state,
        cpp.response_state,
        u.nombre,
        pp.display_name
      FROM app.padel_community_plan_players cpp
      JOIN app.padel_community_plans cp ON cp.id = cpp.plan_id
      JOIN app.users u ON u.id = cpp.user_id
      LEFT JOIN app.padel_player_profiles pp ON pp.user_id = u.id
      WHERE cpp.user_id = $1
        AND ($2::int IS NULL OR cp.id <> $2)
        AND cp.scheduled_date BETWEEN $3::date AND $4::date
        AND cp.invite_state NOT IN ('cancelled', 'expired')
        AND cp.reservation_state NOT IN ('cancelled', 'expired')
    `,
    [userId, planId, dateFloor, dateCeiling],
  );

  const bookingConflictsResult = await client.query(
    `
      SELECT DISTINCT
        b.id,
        b.booking_date AS scheduled_date,
        b.start_time AS scheduled_time,
        b.duration_minutes,
        u.nombre,
        pp.display_name
      FROM app.padel_bookings b
      JOIN app.users u ON u.id = $1
      LEFT JOIN app.padel_player_profiles pp ON pp.user_id = u.id
      LEFT JOIN app.padel_booking_players bp
        ON bp.booking_id = b.id
       AND bp.user_id = $1
      WHERE (b.booked_by = $1 OR bp.user_id = $1)
        AND b.status = 'confirmada'
        AND b.booking_date BETWEEN $2::date AND $3::date
        AND (
          b.booked_by = $1
          OR bp.invite_status = 'aceptada'
        )
    `,
    [userId, dateFloor, dateCeiling],
  );

  const conflicts = [];

  for (const row of planConflictsResult.rows) {
    const otherRange = buildCommunityTimeRange(
      row.scheduled_date,
      row.scheduled_time,
      Number.parseInt(row.duration_minutes, 10) || DEFAULT_DURATION_MINUTES,
    );
    const serious = row.reservation_state === 'confirmed'
      || row.invite_state === 'ready'
      || SERIOUS_RESPONSE_STATES.has(row.response_state);

    if (serious && overlapsRange(range.hardStart, range.hardEnd, otherRange.start, otherRange.end)) {
      conflicts.push({
        id: Number(row.id),
        source: 'community',
        severity: 'hard',
        scheduled_date: normalizeDateValue(row.scheduled_date, APP_TIME_ZONE),
        scheduled_time: row.scheduled_time,
        display_name: displayNameFromRow(row),
        message: buildCommunityConflictMessage({
          ...row,
          severity: 'hard',
          source: 'community',
          display_name: displayNameFromRow(row),
        }),
      });
      continue;
    }

    if (
      PENDING_RESPONSE_STATES.has(row.response_state)
      || row.invite_state === 'reschedule_pending'
      || row.invite_state === 'replacement_required'
    ) {
      if (overlapsRange(range.start, range.end, otherRange.start, otherRange.end)) {
        conflicts.push({
          id: Number(row.id),
          source: 'community',
          severity: 'soft',
          scheduled_date: normalizeDateValue(row.scheduled_date, APP_TIME_ZONE),
          scheduled_time: row.scheduled_time,
          display_name: displayNameFromRow(row),
          message: buildCommunityConflictMessage({
            ...row,
            severity: 'soft',
            source: 'community',
            display_name: displayNameFromRow(row),
          }),
        });
      }
    }
  }

  for (const row of bookingConflictsResult.rows) {
    const bookingRange = buildCommunityTimeRange(
      row.scheduled_date,
      row.scheduled_time,
      Number.parseInt(row.duration_minutes, 10) || DEFAULT_DURATION_MINUTES,
    );

    if (overlapsRange(range.hardStart, range.hardEnd, bookingRange.start, bookingRange.end)) {
      conflicts.push({
        id: Number(row.id),
        source: 'booking',
        severity: 'hard',
        scheduled_date: normalizeDateValue(row.scheduled_date, APP_TIME_ZONE),
        scheduled_time: row.scheduled_time,
        display_name: displayNameFromRow(row),
        message: buildCommunityConflictMessage({
          ...row,
          severity: 'hard',
          source: 'booking',
          display_name: displayNameFromRow(row),
        }),
      });
    }
  }

  return conflicts.sort((left, right) => {
    if (left.severity !== right.severity) {
      return left.severity === 'hard' ? -1 : 1;
    }

    return `${left.scheduled_date} ${left.scheduled_time}`
      .localeCompare(`${right.scheduled_date} ${right.scheduled_time}`);
  });
}

async function previewCommunityConflictsInternal(client, {
  planId = null,
  userId,
  scheduledDate,
  scheduledTime,
  participantUserIds,
}) {
  const participantPool = await ensureParticipantPool(
    client,
    userId,
    participantUserIds,
  );

  if (!participantPool.ok) {
    return {
      status: 400,
      body: {
        error: 'Solo puedes convocar a jugadores que formen parte de tu red.',
      },
    };
  }

  const conflicts = [];
  for (const player of participantPool.players) {
    const items = await loadConflictEntriesForUser(client, {
      userId: player.user_id,
      planId,
      scheduledDate,
      scheduledTime,
    });

    if (items.length === 0) {
      continue;
    }

    conflicts.push({
      user_id: player.user_id,
      display_name: player.display_name,
      level: items.some((item) => item.severity === 'hard') ? 'hard' : 'soft',
      items,
    });
  }

  return {
    status: 200,
    body: {
      conflicts,
      has_conflicts: conflicts.length > 0,
      has_hard_conflicts: conflicts.some((conflict) => conflict.level === 'hard'),
    },
  };
}

function buildCommunityReservationEventPayload({ plan, venue, participants }) {
  const startDateTime = toGoogleDateTime(
    plan.scheduled_date,
    plan.scheduled_time,
    APP_TIME_ZONE,
  );
  const endDateTime = calculateEndTime(
    plan.scheduled_date,
    plan.scheduled_time,
    plan.duration_minutes || DEFAULT_DURATION_MINUTES,
    APP_TIME_ZONE,
  ).toISO({ suppressMilliseconds: true });

  const attendees = participants
    .filter((participant) => participant.email)
    .map((participant) => ({
      email: participant.email,
      displayName: participant.display_name || participant.nombre,
      responseStatus: 'accepted',
      optional: false,
    }));

  const playersList = participants
    .map((participant) => participant.display_name || participant.nombre)
    .join(', ');

  return {
    summary: `Partido confirmado · ${venue?.name || 'Centro deportivo'}`,
    location:
      [venue?.address, venue?.location].filter(Boolean).join(' - ') ||
      venue?.name ||
      'Centro deportivo',
    description: [
      'Indalo Padel',
      `Comunidad · Convocatoria ${plan.id}`,
      `Organiza: ${plan.creator_name}`,
      `Jugadores: ${playersList}`,
      '',
      'Reserva confirmada por el centro deportivo.',
    ].join('\n'),
    start: {
      dateTime: startDateTime,
      timeZone: APP_TIME_ZONE,
    },
    end: {
      dateTime: endDateTime,
      timeZone: APP_TIME_ZONE,
    },
    attendees,
    guestsCanModify: false,
    guestsCanInviteOthers: false,
    guestsCanSeeOtherGuests: true,
    reminders: { useDefault: true },
    extendedProperties: {
      private: {
        app: 'indalo_padel',
        community_plan_id: String(plan.id),
      },
    },
  };
}

async function syncCommunityCalendarEvent(client, plan, userId) {
  if (!isGoogleCalendarConfigured()) {
    await client.query(
      `UPDATE app.padel_community_plans
       SET calendar_sync_status = 'pending',
           last_synced_at = NOW(),
           updated_at = NOW()
       WHERE id = $1`,
      [plan.id],
    );
    return { google_event_id: plan.google_event_id || null, sync_error: null };
  }

  try {
    const bundle = await loadPlanBundle(client, plan.id, userId);
    if (!bundle) {
      return { google_event_id: plan.google_event_id || null, sync_error: null };
    }

    const payload = buildCommunityReservationEventPayload({
      plan: bundle,
      venue: bundle.venue,
      participants: bundle.participants,
    });

    if (plan.google_event_id) {
      await updateCalendarEvent(plan.google_event_id, payload);
      await client.query(
        `UPDATE app.padel_community_plans
         SET calendar_sync_status = 'synced',
             last_synced_at = NOW(),
             updated_at = NOW()
         WHERE id = $1`,
        [plan.id],
      );
      return { google_event_id: plan.google_event_id, sync_error: null };
    }

    const createdEvent = await createCalendarEvent(payload);
    const googleEventId = createdEvent?.id || null;

    if (googleEventId) {
      await client.query(
        `
          UPDATE app.padel_community_plans
          SET google_event_id = $2,
              calendar_sync_status = 'synced',
              last_synced_at = NOW(),
              updated_at = NOW()
          WHERE id = $1
        `,
        [plan.id, googleEventId],
      );
    } else {
      await client.query(
        `UPDATE app.padel_community_plans
         SET calendar_sync_status = 'synced',
             last_synced_at = NOW(),
             updated_at = NOW()
         WHERE id = $1`,
        [plan.id],
      );
    }

    return { google_event_id: googleEventId, sync_error: null };
  } catch (error) {
    console.error(
      'Error sincronizando convocatoria con Google Calendar:',
      error.message,
    );
    await client.query(
      `UPDATE app.padel_community_plans
       SET calendar_sync_status = 'error',
           last_synced_at = NOW(),
           updated_at = NOW()
       WHERE id = $1`,
      [plan.id],
    );
    return {
      google_event_id: plan.google_event_id || null,
      sync_error: error.message,
    };
  }
}

export async function getCommunityDashboard(userId) {
  await runCommunityLifecycleMaintenance();
  const client = await pool.connect();
  try {
    const venue = await loadDefaultVenue(client);
    const companions = await loadAcceptedCompanions(client, userId);
    const planRows = await loadPlanRowsForUser(client, userId);
    const notifications = await loadUnreadNotifications(client, userId);

    const participantMap = await loadParticipantsForPlans(
      client,
      planRows.map((row) => Number(row.id)),
      userId,
    );

    const allPlans = planRows.map((row) =>
      buildPlanDto(row, participantMap.get(Number(row.id)) || [], userId),
    );

    const activePlans = allPlans.filter((plan) => isPlanActive({
      invite_state: plan.invite_state,
      reservation_state: plan.reservation_state,
    }));
    const historyPlans = allPlans.filter((plan) => !activePlans.includes(plan));
    const activePlan = activePlans[0] || null;

    return {
      venue: mapVenueRow(venue),
      companions,
      plans: activePlans,
      active_plans: activePlans,
      history_plans: historyPlans,
      active_plan: activePlan,
      notifications,
    };
  } finally {
    client.release();
  }
}

export async function previewCommunityPlanConflicts({
  planId = null,
  userId,
  scheduledDate,
  scheduledTime,
  participantUserIds,
}) {
  const client = await pool.connect();
  try {
    return await previewCommunityConflictsInternal(client, {
      planId,
      userId,
      scheduledDate,
      scheduledTime,
      participantUserIds,
    });
  } finally {
    client.release();
  }
}

export async function createCommunityPlan({
  userId,
  scheduledDate,
  scheduledTime,
  participantUserIds,
  forceSend = false,
}) {
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    const activeCountResult = await client.query(
      `SELECT COUNT(*) AS cnt
       FROM app.padel_community_plans
       WHERE created_by = $1
         AND invite_state NOT IN ('cancelled', 'expired')
         AND reservation_state NOT IN ('confirmed', 'cancelled', 'expired')`,
      [userId],
    );
    if (Number(activeCountResult.rows[0].cnt) >= MAX_ACTIVE_PLANS) {
      await client.query('ROLLBACK');
      return {
        status: 400,
        body: {
          error: `Ya tienes ${MAX_ACTIVE_PLANS} convocatorias activas. Completa o cancela alguna antes de crear otra.`,
        },
      };
    }

    const defaultVenue = await loadDefaultVenue(client);
    const participantPool = await ensureParticipantPool(
      client,
      userId,
      participantUserIds,
    );

    if (!participantPool.ok) {
      await client.query('ROLLBACK');
      return {
        status: 400,
        body: {
          error:
            'Solo puedes convocar a jugadores que formen parte de tu red.',
        },
      };
    }

    const conflictPreview = await previewCommunityConflictsInternal(client, {
      userId,
      scheduledDate,
      scheduledTime,
      participantUserIds,
    });
    if (conflictPreview.status !== 200) {
      await client.query('ROLLBACK');
      return conflictPreview;
    }

    if (conflictPreview.body.has_conflicts && !forceSend) {
      await client.query('ROLLBACK');
      return {
        status: 409,
        body: {
          error: 'Hay conflictos detectados para alguno de los jugadores. Confirma si quieres enviar igualmente la invitación.',
          code: 'conflicts_detected',
          ...conflictPreview.body,
        },
      };
    }

    const planResult = await client.query(
      `
        INSERT INTO app.padel_community_plans (
          created_by,
          venue_id,
          scheduled_date,
          scheduled_time,
          duration_minutes,
          invite_state,
          reservation_state,
          reservation_contact_phone
        )
        VALUES ($1, $2, $3, $4, $5, 'pending', 'pending', $6)
        RETURNING *
      `,
      [
        userId,
        defaultVenue?.id || null,
        scheduledDate,
        scheduledTime,
        DEFAULT_DURATION_MINUTES,
        defaultVenue?.phone || null,
      ],
    );

    const plan = planResult.rows[0];

    await client.query(
      `
        INSERT INTO app.padel_community_plan_players (
          plan_id,
          user_id,
          role,
          response_state,
          responded_at
        )
        VALUES ($1, $2, 'organizer', 'accepted', NOW())
      `,
      [plan.id, userId],
    );

    for (const participantId of participantPool.participantIds) {
      await client.query(
        `
          INSERT INTO app.padel_community_plan_players (
            plan_id,
            user_id,
            role,
            response_state
          )
          VALUES ($1, $2, 'player', 'pending')
        `,
        [plan.id, participantId],
      );
    }

    await client.query('COMMIT');

    let planDto = null;
    try {
      planDto = await loadPlanBundle(client, plan.id, userId);
    } catch (bundleError) {
      console.error('Error cargando plan tras commit:', bundleError.message);
    }

    return {
      status: 201,
      body: { plan: planDto },
    };
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    throw error;
  } finally {
    client.release();
  }
}

export async function updateCommunityPlan({
  planId,
  userId,
  scheduledDate,
  scheduledTime,
  participantUserIds,
  expectedUpdatedAt = null,
  forceSend = false,
}) {
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    const plan = await loadPlanForOrganizer(client, planId, userId);
    if (!plan) {
      await client.query('ROLLBACK');
      return {
        status: 404,
        body: {
          error: 'Convocatoria no encontrada o no tienes permisos.',
        },
      };
    }

    const staleError = ensureFreshPlan(plan, expectedUpdatedAt);
    if (staleError) {
      await client.query('ROLLBACK');
      return staleError;
    }

    if (isPlanTerminal(plan)) {
      await client.query('ROLLBACK');
      return buildClosedPayload(plan);
    }

    const participantPool = await ensureParticipantPool(
      client,
      userId,
      participantUserIds,
    );
    if (!participantPool.ok) {
      await client.query('ROLLBACK');
      return {
        status: 400,
        body: {
          error:
            'Solo puedes convocar a jugadores que formen parte de tu red.',
        },
      };
    }

    const conflictPreview = await previewCommunityConflictsInternal(client, {
      planId,
      userId,
      scheduledDate,
      scheduledTime,
      participantUserIds,
    });
    if (conflictPreview.status !== 200) {
      await client.query('ROLLBACK');
      return conflictPreview;
    }

    if (conflictPreview.body.has_conflicts && !forceSend) {
      await client.query('ROLLBACK');
      return {
        status: 409,
        body: {
          error: 'Hay conflictos detectados para alguno de los jugadores. Confirma si quieres enviar igualmente la invitación.',
          code: 'conflicts_detected',
          ...conflictPreview.body,
        },
      };
    }

    const keepIds = [userId, ...participantPool.participantIds];
    await client.query(
      `
        DELETE FROM app.padel_community_plan_players
        WHERE plan_id = $1
          AND NOT (user_id = ANY($2::int[]))
      `,
      [planId, keepIds],
    );

    await client.query(
      `
        UPDATE app.padel_community_plans
        SET scheduled_date = $2,
            scheduled_time = $3,
            invite_state = 'pending',
            reservation_state = CASE
              WHEN reservation_state IN ('confirmed', 'cancelled', 'expired')
                THEN reservation_state
              ELSE 'pending'
            END,
            last_declined_by = NULL,
            last_reschedule_by = NULL,
            last_reschedule_date = NULL,
            last_reschedule_time = NULL,
            closed_at = NULL,
            closed_by = NULL,
            closed_reason = NULL,
            updated_at = NOW()
        WHERE id = $1
      `,
      [planId, scheduledDate, scheduledTime],
    );

    await client.query(
      `
        INSERT INTO app.padel_community_plan_players (
          plan_id,
          user_id,
          role,
          response_state,
          responded_at
        )
        VALUES ($1, $2, 'organizer', 'accepted', NOW())
        ON CONFLICT (plan_id, user_id) DO UPDATE
        SET role = EXCLUDED.role,
            response_state = EXCLUDED.response_state,
            responded_at = EXCLUDED.responded_at,
            updated_at = NOW()
      `,
      [planId, userId],
    );

    for (const participantId of participantPool.participantIds) {
      await client.query(
        `
          INSERT INTO app.padel_community_plan_players (
            plan_id,
            user_id,
            role,
            response_state,
            responded_at
          )
          VALUES ($1, $2, 'player', 'pending', NULL)
          ON CONFLICT (plan_id, user_id) DO UPDATE
          SET role = EXCLUDED.role,
              response_state = EXCLUDED.response_state,
              responded_at = EXCLUDED.responded_at,
              updated_at = NOW()
        `,
        [planId, participantId],
      );
    }

    await client.query('COMMIT');

    let planDto = null;
    try {
      planDto = await loadPlanBundle(client, planId, userId);
    } catch (bundleError) {
      console.error('Error cargando plan tras commit:', bundleError.message);
    }

    return {
      status: 200,
      body: { plan: planDto },
    };
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    throw error;
  } finally {
    client.release();
  }
}

export async function respondToCommunityPlan({
  planId,
  userId,
  action,
  expectedUpdatedAt = null,
}) {
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    const plan = await loadPlanForMember(client, planId, userId);
    if (!plan) {
      await client.query('ROLLBACK');
      return {
        status: 404,
        body: { error: 'Convocatoria no encontrada.' },
      };
    }

    const staleError = ensureFreshPlan(plan, expectedUpdatedAt);
    if (staleError) {
      await client.query('ROLLBACK');
      return staleError;
    }

    if (isPlanTerminal(plan)) {
      await client.query('ROLLBACK');
      return buildClosedPayload(plan);
    }

    if (Number(plan.created_by) === Number(userId) && action !== 'accepted') {
      await client.query('ROLLBACK');
      return {
        status: 400,
        body: {
          error: 'El organizador no puede salir ni quedarse en duda en su propia convocatoria.',
        },
      };
    }

    if (action === 'accepted') {
      const hardConflicts = await loadConflictEntriesForUser(client, {
        userId,
        planId,
        scheduledDate: plan.scheduled_date,
        scheduledTime: plan.scheduled_time,
      });
      const blockingConflicts = hardConflicts.filter(
        (conflict) => conflict.severity === 'hard',
      );
      if (blockingConflicts.length > 0) {
        await client.query('ROLLBACK');
        return {
          status: 409,
          body: {
            error: blockingConflicts[0].message,
            code: 'hard_conflict',
            conflicts: blockingConflicts,
          },
        };
      }
    }

    const nextResponseState = action === 'accepted'
      ? 'accepted'
      : action === 'doubt'
        ? 'doubt'
        : 'declined';
    await client.query(
      `
        UPDATE app.padel_community_plan_players
        SET response_state = $3,
            responded_at = NOW(),
            updated_at = NOW()
        WHERE plan_id = $1
          AND user_id = $2
      `,
      [planId, userId, nextResponseState],
    );

    if (nextResponseState === 'declined') {
      const participantResult = await client.query(
        `
          SELECT u.id as user_id, u.nombre, pp.display_name
          FROM app.padel_community_plan_players cpp
          JOIN app.users u ON u.id = cpp.user_id
          LEFT JOIN app.padel_player_profiles pp ON pp.user_id = u.id
          WHERE cpp.plan_id = $1
        `,
        [planId],
      );

      const declinedPlayer = participantResult.rows.find(
        (row) => Number(row.user_id) === Number(userId),
      );
      const declinedName = displayNameFromRow(declinedPlayer);
      const participantIds = participantResult.rows.map((row) =>
        Number(row.user_id),
      );

      await updateInviteState(client, planId, 'replacement_required', {
        last_declined_by: userId,
        last_reschedule_by: null,
        last_reschedule_date: null,
        last_reschedule_time: null,
      });

      await createNotifications(client, {
        planId,
        userIds: participantIds,
        excludeUserIds: [userId],
        type: 'member_declined',
        title: 'Selecciona otro jugador',
        message: `${declinedName} no ha podido participar esta vez. El organizador debe sustituirlo o cancelar la convocatoria.`,
        metadata: {
          declined_by_user_id: userId,
          declined_by_name: declinedName,
          action_type: 'review_plan',
        },
      });
    } else if (nextResponseState === 'doubt') {
      const participantResult = await client.query(
        `
          SELECT u.id as user_id, u.nombre, pp.display_name
          FROM app.padel_community_plan_players cpp
          JOIN app.users u ON u.id = cpp.user_id
          LEFT JOIN app.padel_player_profiles pp ON pp.user_id = u.id
          WHERE cpp.plan_id = $1
        `,
        [planId],
      );
      const doubtfulPlayer = participantResult.rows.find(
        (row) => Number(row.user_id) === Number(userId),
      );
      const doubtfulName = displayNameFromRow(doubtfulPlayer);
      const participantIds = participantResult.rows.map((row) =>
        Number(row.user_id),
      );

      await recomputeInviteState(client, planId);
      await createNotifications(client, {
        planId,
        userIds: participantIds,
        excludeUserIds: [userId],
        type: 'conflict_warning',
        title: 'Jugador en duda',
        message: `${doubtfulName} sigue en duda. La convocatoria no puede avanzar todavía.`,
        metadata: {
          doubtful_user_id: userId,
          doubtful_name: doubtfulName,
          action_type: 'review_plan',
        },
      });
    } else {
      await recomputeInviteState(client, planId);
    }

    await client.query('COMMIT');

    let planDto = null;
    try {
      planDto = await loadPlanBundle(client, planId, userId);
    } catch (bundleError) {
      console.error('Error cargando plan tras commit:', bundleError.message);
    }

    return {
      status: 200,
      body: { plan: planDto },
    };
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    throw error;
  } finally {
    client.release();
  }
}

export async function proposeCommunityPlanTime({
  planId,
  userId,
  scheduledDate,
  scheduledTime,
  expectedUpdatedAt = null,
}) {
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    const plan = await loadPlanForMember(client, planId, userId);
    if (!plan) {
      await client.query('ROLLBACK');
      return {
        status: 404,
        body: { error: 'Convocatoria no encontrada.' },
      };
    }

    const staleError = ensureFreshPlan(plan, expectedUpdatedAt);
    if (staleError) {
      await client.query('ROLLBACK');
      return staleError;
    }

    if (isPlanTerminal(plan)) {
      await client.query('ROLLBACK');
      return buildClosedPayload(plan);
    }

    await client.query(
      `
        UPDATE app.padel_community_plans
        SET scheduled_date = $2,
            scheduled_time = $3,
            invite_state = 'reschedule_pending',
            reservation_state = CASE
              WHEN reservation_state IN ('confirmed', 'cancelled', 'expired')
                THEN reservation_state
              ELSE 'pending'
            END,
            last_declined_by = NULL,
            last_reschedule_by = $4,
            last_reschedule_date = $2,
            last_reschedule_time = $3,
            closed_at = NULL,
            closed_by = NULL,
            closed_reason = NULL,
            updated_at = NOW()
        WHERE id = $1
      `,
      [planId, scheduledDate, scheduledTime, userId],
    );

    await client.query(
      `
        UPDATE app.padel_community_plan_players
        SET response_state = CASE
              WHEN user_id = $2 THEN 'accepted'
              ELSE 'pending'
            END,
            responded_at = CASE
              WHEN user_id = $2 THEN NOW()
              ELSE NULL
            END,
            updated_at = NOW()
        WHERE plan_id = $1
      `,
      [planId, userId],
    );

    const participantResult = await client.query(
      `
        SELECT u.id as user_id, u.nombre, pp.display_name
        FROM app.padel_community_plan_players cpp
        JOIN app.users u ON u.id = cpp.user_id
        LEFT JOIN app.padel_player_profiles pp ON pp.user_id = u.id
        WHERE cpp.plan_id = $1
      `,
      [planId],
    );

    const proposer = participantResult.rows.find(
      (row) => Number(row.user_id) === Number(userId),
    );
    const proposerName = displayNameFromRow(proposer);
    const participantIds = participantResult.rows.map((row) =>
      Number(row.user_id),
    );

    await createNotifications(client, {
      planId,
      userIds: participantIds,
      excludeUserIds: [userId],
      type: 'reschedule_proposed',
      title: 'Nuevo horario propuesto',
      message: `${proposerName} propone jugar el ${scheduledDate} a las ${scheduledTime.slice(0, 5)}.`,
      metadata: {
        proposed_by_user_id: userId,
        proposed_by_name: proposerName,
        scheduled_date: scheduledDate,
        scheduled_time: scheduledTime,
      },
    });

    await client.query('COMMIT');

    let planDto = null;
    try {
      planDto = await loadPlanBundle(client, planId, userId);
    } catch (bundleError) {
      console.error('Error cargando plan tras commit:', bundleError.message);
    }

    return {
      status: 200,
      body: { plan: planDto },
    };
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    throw error;
  } finally {
    client.release();
  }
}

export async function updateCommunityReservationStatus({
  planId,
  userId,
  status,
  handledByUserId,
  expectedUpdatedAt = null,
}) {
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    const plan = await loadPlanForMember(client, planId, userId);
    if (!plan) {
      await client.query('ROLLBACK');
      return {
        status: 404,
        body: { error: 'Convocatoria no encontrada.' },
      };
    }

    const staleError = ensureFreshPlan(plan, expectedUpdatedAt);
    if (staleError) {
      await client.query('ROLLBACK');
      return staleError;
    }

    if (isPlanTerminal(plan)) {
      await client.query('ROLLBACK');
      return buildClosedPayload(plan);
    }

    const handlerId = handledByUserId || userId;

    const participantResult = await client.query(
      `
        SELECT
          cpp.user_id,
          cpp.role,
          cpp.response_state,
          u.nombre,
          u.email,
          pp.display_name,
          pp.numeric_level,
          pp.is_available,
          pp.avatar_url
        FROM app.padel_community_plan_players cpp
        JOIN app.users u ON u.id = cpp.user_id
        LEFT JOIN app.padel_player_profiles pp ON pp.user_id = cpp.user_id
        WHERE cpp.plan_id = $1
      `,
      [planId],
    );

    const participantIds = participantResult.rows.map((row) =>
      Number(row.user_id),
    );
    if (!participantIds.includes(Number(handlerId))) {
      await client.query('ROLLBACK');
      return {
        status: 400,
        body: {
          error: 'La persona que gestiona la reserva debe formar parte de la convocatoria.',
        },
      };
    }

    const confirmed = status === 'confirmed';
    const hasBlockingParticipants = participantResult.rows.some((row) => (
      row.role !== 'organizer'
      && ['pending', 'declined', 'doubt'].includes(row.response_state)
    ));
    if (
      plan.invite_state === 'replacement_required'
      || plan.invite_state === 'reschedule_pending'
      || hasBlockingParticipants
    ) {
      await client.query('ROLLBACK');
      return {
        status: 400,
        body: {
          error: 'La convocatoria no está lista para reservar. Falta resolver respuestas pendientes, dudas o sustituciones.',
        },
      };
    }

    await client.query(
      `
        UPDATE app.padel_community_plans
        SET reservation_state = $2,
            reservation_handled_by = $3,
            reservation_confirmed_at = CASE
              WHEN $2 = 'confirmed' THEN NOW()
              ELSE reservation_confirmed_at
            END,
            calendar_sync_status = CASE
              WHEN $2 = 'confirmed' THEN 'pending'
              ELSE calendar_sync_status
            END,
            updated_at = NOW()
        WHERE id = $1
      `,
      [planId, confirmed ? 'confirmed' : 'retry', handlerId],
    );

    const handler = participantResult.rows.find(
      (row) => Number(row.user_id) === Number(handlerId),
    );
    const handlerName = displayNameFromRow(handler);

    const notificationType = confirmed
      ? 'reservation_confirmed'
      : 'reservation_retry';
    const notificationTitle = confirmed
      ? 'Reserva confirmada'
      : 'Seguimos intentando reservar';
    const notificationMessage = confirmed
      ? `${handlerName} ha confirmado la reserva con el centro deportivo.`
      : `${handlerName} no ha conseguido la reserva todavía. Habrá un segundo intento.`;

    await createNotifications(client, {
      planId,
      userIds: participantIds,
      excludeUserIds: [userId],
      type: notificationType,
      title: notificationTitle,
      message: notificationMessage,
      metadata: {
        handled_by_user_id: handlerId,
        handled_by_name: handlerName,
        reservation_state: confirmed ? 'confirmed' : 'retry',
      },
    });

    await client.query('COMMIT');

    let calendarInfo = { google_event_id: plan.google_event_id || null, sync_error: null };
    if (confirmed) {
      calendarInfo = await syncCommunityCalendarEvent(
        client,
        { ...plan, google_event_id: plan.google_event_id },
        userId,
      );
    }

    let planDto = null;
    try {
      planDto = await loadPlanBundle(client, planId, userId);
    } catch (bundleError) {
      console.error('Error cargando plan tras commit:', bundleError.message);
    }

    return {
      status: 200,
      body: {
        plan: planDto,
        google_event_id: calendarInfo.google_event_id,
        calendar_sync_error: calendarInfo.sync_error,
      },
    };
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    throw error;
  } finally {
    client.release();
  }
}

export async function cancelCommunityPlan({
  planId,
  userId,
  expectedUpdatedAt = null,
}) {
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    const plan = await loadPlanForOrganizer(client, planId, userId);
    if (!plan) {
      await client.query('ROLLBACK');
      return {
        status: 404,
        body: { error: 'Convocatoria no encontrada o no tienes permisos.' },
      };
    }

    const staleError = ensureFreshPlan(plan, expectedUpdatedAt);
    if (staleError) {
      await client.query('ROLLBACK');
      return staleError;
    }

    if (isPlanTerminal(plan)) {
      await client.query('ROLLBACK');
      return buildClosedPayload(plan);
    }

    const participantResult = await client.query(
      `SELECT user_id
       FROM app.padel_community_plan_players
       WHERE plan_id = $1`,
      [planId],
    );
    const participantIds = participantResult.rows.map((row) => Number(row.user_id));

    await client.query(
      `UPDATE app.padel_community_plans
       SET invite_state = 'cancelled',
           reservation_state = 'cancelled',
           closed_at = NOW(),
           closed_by = $2,
           closed_reason = 'organizer_cancelled',
           updated_at = NOW()
       WHERE id = $1`,
      [planId, userId],
    );

    await createNotifications(client, {
      planId,
      userIds: participantIds,
      excludeUserIds: [userId],
      type: 'plan_cancelled',
      title: 'Convocatoria cancelada',
      message: 'El organizador ha cancelado la convocatoria. Se conserva en el historial para que nadie pierda el hilo.',
      metadata: {
        closed_reason: 'organizer_cancelled',
        action_type: 'review_plan',
      },
    });

    await client.query('COMMIT');

    return {
      status: 200,
      body: { cancelled: true, plan_id: planId },
    };
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    throw error;
  } finally {
    client.release();
  }
}

async function notifyPlanClosure(client, {
  planId,
  type,
  title,
  message,
  metadata = {},
}) {
  const participantResult = await client.query(
    `SELECT user_id
     FROM app.padel_community_plan_players
     WHERE plan_id = $1`,
    [planId],
  );

  await createNotifications(client, {
    planId,
    userIds: participantResult.rows.map((row) => Number(row.user_id)),
    type,
    title,
    message,
    metadata,
  });
}

async function expirePastCommunityPlans(client) {
  const planResult = await client.query(
    `
      SELECT id, scheduled_date, scheduled_time
      FROM app.padel_community_plans
      WHERE invite_state NOT IN ('cancelled', 'expired')
        AND reservation_state NOT IN ('confirmed', 'cancelled', 'expired')
    `,
  );

  let expiredCount = 0;
  const now = buildCommunityTimeRange(
    normalizeDateValue(new Date(), APP_TIME_ZONE),
    DateTime.now().setZone(APP_TIME_ZONE).toFormat('HH:mm:ss'),
    0,
  ).start;

  for (const row of planResult.rows) {
    const range = buildCommunityTimeRange(
      row.scheduled_date,
      row.scheduled_time,
    );
    if (range.end.toMillis() >= now.toMillis()) {
      continue;
    }

    await client.query(
      `UPDATE app.padel_community_plans
       SET invite_state = 'expired',
           reservation_state = 'expired',
           closed_at = COALESCE(closed_at, NOW()),
           closed_reason = 'past_datetime',
           updated_at = NOW()
       WHERE id = $1`,
      [row.id],
    );

    await notifyPlanClosure(client, {
      planId: Number(row.id),
      type: 'plan_expired',
      title: 'Convocatoria expirada',
      message: 'La fecha del partido ya ha pasado y la convocatoria se ha cerrado automáticamente.',
      metadata: {
        closed_reason: 'past_datetime',
        action_type: 'review_plan',
      },
    });
    expiredCount += 1;
  }

  return expiredCount;
}

async function cancelTimedOutRetryPlans(client) {
  const planResult = await client.query(
    `
      SELECT id
      FROM app.padel_community_plans
      WHERE reservation_state = 'retry'
        AND invite_state NOT IN ('cancelled', 'expired')
        AND updated_at < NOW() - INTERVAL '24 hours'
    `,
  );

  let cancelledCount = 0;
  for (const row of planResult.rows) {
    await client.query(
      `UPDATE app.padel_community_plans
       SET invite_state = 'cancelled',
           reservation_state = 'cancelled',
           closed_at = COALESCE(closed_at, NOW()),
           closed_reason = 'retry_timeout',
           updated_at = NOW()
       WHERE id = $1`,
      [row.id],
    );

    await notifyPlanClosure(client, {
      planId: Number(row.id),
      type: 'retry_timeout',
      title: 'Convocatoria cerrada por tiempo',
      message: 'La reserva seguía en segundo intento tras 24 horas y la convocatoria se ha cancelado automáticamente.',
      metadata: {
        closed_reason: 'retry_timeout',
        action_type: 'review_plan',
      },
    });
    cancelledCount += 1;
  }

  return cancelledCount;
}

async function retryPendingCommunityCalendarSyncs() {
  const client = await pool.connect();
  try {
    const result = await client.query(
      `
        SELECT id, created_by, google_event_id
        FROM app.padel_community_plans
        WHERE reservation_state = 'confirmed'
          AND calendar_sync_status IN ('pending', 'error')
      `,
    );

    let syncedCount = 0;
    for (const row of result.rows) {
      const syncInfo = await syncCommunityCalendarEvent(client, row, row.created_by);
      if (!syncInfo.sync_error) {
        syncedCount += 1;
      }
    }

    return syncedCount;
  } finally {
    client.release();
  }
}

export async function runCommunityLifecycleMaintenance() {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const expired = await expirePastCommunityPlans(client);
    const retryCancelled = await cancelTimedOutRetryPlans(client);
    await client.query('COMMIT');

    const synced = await retryPendingCommunityCalendarSyncs();
    return {
      expired,
      retry_cancelled: retryCancelled,
      synced,
    };
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    throw error;
  } finally {
    client.release();
  }
}

export async function markCommunityNotificationRead({
  notificationId,
  userId,
}) {
  const result = await pool.query(
    `
      UPDATE app.padel_community_notifications
      SET is_read = true
      WHERE id = $1
        AND user_id = $2
      RETURNING id
    `,
    [notificationId, userId],
  );

  if (result.rows.length === 0) {
    return {
      status: 404,
      body: { error: 'Aviso no encontrado.' },
    };
  }

  return {
    status: 200,
    body: { notification_id: Number(result.rows[0].id) },
  };
}
