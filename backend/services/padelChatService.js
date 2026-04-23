import { pool } from '../db.js';
import {
  APP_TIME_ZONE,
  combineDateAndTime,
  normalizeDateValue,
  nowInAppZone,
} from './calendarUtils.js';
import { sendPushToUsers } from './pushNotificationService.js';
import {
  emitPadelChatConversationCreated,
  emitPadelChatMessageCreated,
  emitPadelChatReadUpdated,
} from './padelChatSocket.js';

const DEFAULT_MESSAGE_LIMIT = 50;
const DEFAULT_SOCIAL_EVENT_DURATION_MINUTES = 90;

function asInt(value) {
  const parsed = Number.parseInt(value, 10);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : null;
}

function sanitizeOptionalText(value) {
  if (typeof value !== 'string') {
    return null;
  }

  const trimmed = value.trim();
  return trimmed.length ? trimmed : null;
}

function normalizeTimeValue(value) {
  const raw = String(value || '').trim();
  if (!raw) {
    return null;
  }

  return raw.length === 5 ? `${raw}:00` : raw;
}

function normalizeTimeOnlyValue(value) {
  if (!value) {
    return null;
  }

  return String(value).slice(0, 8);
}

function normalizeUserIds(values) {
  return [...new Set((values || []).map(asInt).filter(Boolean))];
}

function normalizeDirectPair(leftUserId, rightUserId) {
  return leftUserId < rightUserId
    ? {
        lowUserId: leftUserId,
        highUserId: rightUserId,
      }
    : {
        lowUserId: rightUserId,
        highUserId: leftUserId,
      };
}

function displayNameFromRow(row, fallbackUserId = null) {
  return (
    row?.display_name ||
    row?.nombre ||
    (fallbackUserId ? `Jugador ${fallbackUserId}` : 'Jugador')
  );
}

function buildUserSummary(row, userIdField = 'user_id') {
  const userId = Number(row[userIdField]);

  return {
    user_id: userId,
    display_name: displayNameFromRow(row, userId),
    nombre: row.nombre || null,
    avatar_url: row.avatar_url || null,
  };
}

function buildParticipantDto(row, currentUserId) {
  const summary = buildUserSummary(row);

  return {
    ...summary,
    role: row.role,
    joined_at: row.joined_at,
    last_read_message_id: row.last_read_message_id
      ? Number(row.last_read_message_id)
      : null,
    last_read_at: row.last_read_at || null,
    is_self: Number(row.user_id) === Number(currentUserId),
  };
}

function buildMessageDto(row, currentUserId) {
  const sender = {
    user_id: Number(row.sender_user_id),
    display_name: displayNameFromRow(
      {
        display_name: row.sender_display_name,
        nombre: row.sender_nombre,
      },
      row.sender_user_id,
    ),
    nombre: row.sender_nombre || null,
    avatar_url: row.sender_avatar_url || null,
  };

  return {
    id: Number(row.id),
    conversation_id: Number(row.conversation_id),
    body: row.body,
    created_at: row.created_at,
    sender,
    is_own: Number(row.sender_user_id) === Number(currentUserId),
  };
}

function buildEventMetadata(row) {
  if (row.social_event_id) {
    return {
      source_type: 'social_event',
      social_event_id: Number(row.social_event_id),
      plan_id: null,
      title: row.social_event_title || 'Evento social',
      description: row.social_event_description || null,
      scheduled_date: normalizeDateValue(row.social_event_scheduled_date),
      scheduled_time: normalizeTimeOnlyValue(row.social_event_scheduled_time),
      duration_minutes: row.social_event_duration_minutes
        ? Number(row.social_event_duration_minutes)
        : null,
      invite_state: null,
      reservation_state: row.social_event_status || null,
      closed_at: null,
      venue: row.social_event_venue_name || row.social_event_location
        ? {
            id: 0,
            name: row.social_event_venue_name || 'Evento local',
            location: row.social_event_location || null,
          }
        : null,
      organizer: row.social_event_creator_user_id
        ? {
            user_id: Number(row.social_event_creator_user_id),
            display_name: displayNameFromRow(
              {
                display_name: row.social_event_creator_display_name,
                nombre: row.social_event_creator_nombre,
              },
              row.social_event_creator_user_id,
            ),
            nombre: row.social_event_creator_nombre || null,
            avatar_url: row.social_event_creator_avatar_url || null,
          }
        : null,
    };
  }

  if (!row.event_id) {
    return null;
  }

  return {
    source_type: 'community_plan',
    plan_id: Number(row.event_id),
    social_event_id: null,
    title: null,
    description: null,
    scheduled_date: row.event_scheduled_date,
    scheduled_time: row.event_scheduled_time,
    duration_minutes: row.event_duration_minutes
      ? Number(row.event_duration_minutes)
      : null,
    invite_state: row.event_invite_state || null,
    reservation_state: row.event_reservation_state || null,
    closed_at: row.event_closed_at || null,
    venue: row.event_venue_id
      ? {
          id: Number(row.event_venue_id),
          name: row.event_venue_name,
          location: row.event_venue_location || null,
        }
      : null,
    organizer: row.event_organizer_user_id
      ? {
          user_id: Number(row.event_organizer_user_id),
          display_name: displayNameFromRow(
            {
              display_name: row.event_organizer_display_name,
              nombre: row.event_organizer_nombre,
            },
            row.event_organizer_user_id,
          ),
          nombre: row.event_organizer_nombre || null,
          avatar_url: row.event_organizer_avatar_url || null,
        }
      : null,
  };
}

function buildEventTitle(event) {
  if (!event) {
    return 'Evento';
  }

  if (event.source_type === 'social_event') {
    return event.title || 'Evento social';
  }

  const timeValue =
    typeof event.scheduled_time === 'string'
      ? event.scheduled_time.slice(0, 5)
      : null;

  return [
    event.venue?.name || 'Convocatoria',
    event.scheduled_date || null,
    timeValue,
  ]
    .filter(Boolean)
    .join(' · ');
}

function buildConversationDto(row, participants, unreadCount, currentUserId) {
  const directPeer =
    row.kind === 'direct'
      ? participants.find(
          (participant) => Number(participant.user_id) !== Number(currentUserId),
        ) || null
      : null;
  const event = buildEventMetadata(row);

  let title = row.title || null;
  if (row.kind === 'direct') {
    title = directPeer?.display_name || directPeer?.nombre || 'Chat directo';
  } else if (row.kind === 'event' || row.kind === 'social_event') {
    title = buildEventTitle(event);
  }

  return {
    id: Number(row.id),
    kind: row.kind,
    title,
    created_by: row.created_by ? Number(row.created_by) : null,
    created_at: row.created_at,
    updated_at: row.updated_at,
    unread_count: Number(unreadCount || 0),
    last_read_message_id: row.last_read_message_id
      ? Number(row.last_read_message_id)
      : null,
    last_read_at: row.last_read_at || null,
    member_count: participants.length,
    participants,
    direct_peer: directPeer,
    event,
    last_message: row.last_message_row_id
      ? {
          id: Number(row.last_message_row_id),
          body: row.last_message_body,
          created_at: row.last_message_created_at,
          sender: {
            user_id: Number(row.last_message_sender_user_id),
            display_name: displayNameFromRow(
              {
                display_name: row.last_message_sender_display_name,
                nombre: row.last_message_sender_nombre,
              },
              row.last_message_sender_user_id,
            ),
            nombre: row.last_message_sender_nombre || null,
            avatar_url: row.last_message_sender_avatar_url || null,
          },
          is_own:
            Number(row.last_message_sender_user_id) === Number(currentUserId),
        }
      : null,
  };
}

function buildPushPreview(body) {
  const normalized = String(body || '').replace(/\s+/g, ' ').trim();
  if (normalized.length <= 120) {
    return normalized;
  }

  return `${normalized.slice(0, 117)}...`;
}

async function loadAcceptedConnectionIds(client, userId) {
  const result = await client.query(
    `
      SELECT CASE
        WHEN user_a_id = $1 THEN user_b_id
        ELSE user_a_id
      END AS user_id
      FROM app.padel_player_connections
      WHERE status = 'accepted'
        AND (user_a_id = $1 OR user_b_id = $1)
    `,
    [userId],
  );

  return new Set(result.rows.map((row) => Number(row.user_id)));
}

async function loadActiveUsersMap(client, userIds) {
  if (!userIds.length) {
    return new Map();
  }

  const result = await client.query(
    `
      SELECT
        u.id AS user_id,
        u.nombre,
        pp.display_name,
        pp.avatar_url
      FROM app.users u
      LEFT JOIN app.padel_player_profiles pp ON pp.user_id = u.id
      WHERE u.id = ANY($1::int[])
        AND u.deleted_at IS NULL
    `,
    [userIds],
  );

  return new Map(
    result.rows.map((row) => [Number(row.user_id), row]),
  );
}

async function loadEventPlanAccess(client, planId, userId) {
  const result = await client.query(
    `
      SELECT cp.id, cp.created_by
      FROM app.padel_community_plans cp
      WHERE cp.id = $1
        AND (
          cp.created_by = $2
          OR EXISTS (
            SELECT 1
            FROM app.padel_community_plan_players cpp
            WHERE cpp.plan_id = cp.id
              AND cpp.user_id = $2
          )
        )
      LIMIT 1
    `,
    [planId, userId],
  );

  return result.rows[0] || null;
}

async function syncEventConversationParticipants(
  client,
  conversationId,
  planId,
  organizerUserId = null,
) {
  let resolvedOrganizerId = organizerUserId ? Number(organizerUserId) : null;

  if (!resolvedOrganizerId) {
    const organizerResult = await client.query(
      `SELECT created_by
       FROM app.padel_community_plans
       WHERE id = $1
       LIMIT 1`,
      [planId],
    );

    if (organizerResult.rows.length === 0) {
      return [];
    }

    resolvedOrganizerId = Number(organizerResult.rows[0].created_by);
  }

  const memberResult = await client.query(
    `
      SELECT cpp.user_id, cpp.role
      FROM app.padel_community_plan_players cpp
      JOIN app.users u
        ON u.id = cpp.user_id
       AND u.deleted_at IS NULL
      WHERE cpp.plan_id = $1
    `,
    [planId],
  );

  const participantRoles = new Map();

  for (const row of memberResult.rows) {
    const memberUserId = Number(row.user_id);
    participantRoles.set(
      memberUserId,
      row.role === 'organizer' ? 'owner' : 'member',
    );
  }

  const organizerMap = await loadActiveUsersMap(client, [resolvedOrganizerId]);
  if (organizerMap.has(resolvedOrganizerId)) {
    participantRoles.set(resolvedOrganizerId, 'owner');
  }

  const participantIds = [...participantRoles.keys()];
  const participantRoleValues = participantIds.map((userId) =>
    participantRoles.get(userId),
  );

  if (participantIds.length > 0) {
    await client.query(
      `
        INSERT INTO app.padel_chat_participants (conversation_id, user_id, role)
        SELECT $1, payload.user_id, payload.role
        FROM UNNEST($2::int[], $3::text[]) AS payload(user_id, role)
        ON CONFLICT (conversation_id, user_id)
        DO UPDATE
          SET role = EXCLUDED.role,
              updated_at = NOW()
      `,
      [conversationId, participantIds, participantRoleValues],
    );
  }

  await client.query(
    `
      DELETE FROM app.padel_chat_participants
      WHERE conversation_id = $1
        AND NOT (user_id = ANY($2::int[]))
    `,
    [conversationId, participantIds],
  );

  return participantIds;
}

async function ensureEventConversation(client, planId) {
  const planResult = await client.query(
    `
      SELECT id, created_by
      FROM app.padel_community_plans
      WHERE id = $1
      LIMIT 1
    `,
    [planId],
  );

  if (planResult.rows.length === 0) {
    return null;
  }

  const plan = planResult.rows[0];

  const insertResult = await client.query(
    `
      INSERT INTO app.padel_chat_conversations (kind, created_by, event_plan_id)
      VALUES ('event', $1, $2)
      ON CONFLICT DO NOTHING
      RETURNING id
    `,
    [plan.created_by, planId],
  );

  let conversationId = insertResult.rows[0]?.id
    ? Number(insertResult.rows[0].id)
    : null;

  if (!conversationId) {
    const existingResult = await client.query(
      `
        SELECT id
        FROM app.padel_chat_conversations
        WHERE kind = 'event'
          AND event_plan_id = $1
        LIMIT 1
      `,
      [planId],
    );

    if (existingResult.rows.length === 0) {
      return null;
    }

    conversationId = Number(existingResult.rows[0].id);
  }

  const participantIds = await syncEventConversationParticipants(
    client,
    conversationId,
    planId,
    Number(plan.created_by),
  );

  return {
    conversationId,
    created: insertResult.rows.length > 0,
    participantIds,
  };
}

async function syncEventConversationsForUser(client, userId) {
  await client.query(
    `
      DELETE FROM app.padel_chat_participants participant
      USING app.padel_chat_conversations conversation
      WHERE participant.conversation_id = conversation.id
        AND conversation.kind = 'event'
        AND participant.user_id = $1
        AND NOT EXISTS (
          SELECT 1
          FROM app.padel_community_plans cp
          WHERE cp.id = conversation.event_plan_id
            AND (
              cp.created_by = $1
              OR EXISTS (
                SELECT 1
                FROM app.padel_community_plan_players cpp
                WHERE cpp.plan_id = cp.id
                  AND cpp.user_id = $1
              )
            )
        )
    `,
    [userId],
  );

  const planResult = await client.query(
    `
      SELECT id AS plan_id
      FROM app.padel_community_plans
      WHERE created_by = $1

      UNION

      SELECT cpp.plan_id
      FROM app.padel_community_plan_players cpp
      JOIN app.padel_community_plans cp ON cp.id = cpp.plan_id
      WHERE cpp.user_id = $1
    `,
    [userId],
  );

  for (const row of planResult.rows) {
    await ensureEventConversation(client, Number(row.plan_id));
  }
}

async function loadConversationRows(client, userId, conversationId = null) {
  const result = await client.query(
    `
      SELECT
        c.id,
        c.kind,
        c.title,
        c.created_by,
        c.direct_user_low_id,
        c.direct_user_high_id,
        c.event_plan_id,
        c.social_event_id,
        c.last_message_id,
        c.last_message_at,
        c.created_at,
        c.updated_at,
        me.role AS my_role,
        me.last_read_message_id,
        me.last_read_at,
        me.joined_at AS my_joined_at,
        lm.id AS last_message_row_id,
        lm.body AS last_message_body,
        lm.sender_user_id AS last_message_sender_user_id,
        lm.created_at AS last_message_created_at,
        lm_user.nombre AS last_message_sender_nombre,
        lm_profile.display_name AS last_message_sender_display_name,
        lm_profile.avatar_url AS last_message_sender_avatar_url,
        cp.id AS event_id,
        cp.scheduled_date AS event_scheduled_date,
        cp.scheduled_time AS event_scheduled_time,
        cp.duration_minutes AS event_duration_minutes,
        cp.invite_state AS event_invite_state,
        cp.reservation_state AS event_reservation_state,
        cp.closed_at AS event_closed_at,
        venue.id AS event_venue_id,
        venue.name AS event_venue_name,
        venue.location AS event_venue_location,
        organizer.id AS event_organizer_user_id,
        organizer.nombre AS event_organizer_nombre,
        organizer_profile.display_name AS event_organizer_display_name,
        organizer_profile.avatar_url AS event_organizer_avatar_url,
        se.id AS social_event_id,
        se.title AS social_event_title,
        se.description AS social_event_description,
        se.venue_name AS social_event_venue_name,
        se.location AS social_event_location,
        se.scheduled_date AS social_event_scheduled_date,
        se.scheduled_time AS social_event_scheduled_time,
        se.duration_minutes AS social_event_duration_minutes,
        se.status AS social_event_status,
        se_creator.id AS social_event_creator_user_id,
        se_creator.nombre AS social_event_creator_nombre,
        se_creator_profile.display_name AS social_event_creator_display_name,
        se_creator_profile.avatar_url AS social_event_creator_avatar_url
      FROM app.padel_chat_conversations c
      JOIN app.padel_chat_participants me
        ON me.conversation_id = c.id
       AND me.user_id = $1
      LEFT JOIN app.padel_chat_messages lm
        ON lm.id = c.last_message_id
      LEFT JOIN app.users lm_user
        ON lm_user.id = lm.sender_user_id
      LEFT JOIN app.padel_player_profiles lm_profile
        ON lm_profile.user_id = lm_user.id
      LEFT JOIN app.padel_community_plans cp
        ON cp.id = c.event_plan_id
      LEFT JOIN app.padel_venues venue
        ON venue.id = cp.venue_id
      LEFT JOIN app.users organizer
        ON organizer.id = cp.created_by
      LEFT JOIN app.padel_player_profiles organizer_profile
        ON organizer_profile.user_id = organizer.id
      LEFT JOIN app.padel_social_events se
        ON se.id = c.social_event_id
      LEFT JOIN app.users se_creator
        ON se_creator.id = se.created_by
      LEFT JOIN app.padel_player_profiles se_creator_profile
        ON se_creator_profile.user_id = se_creator.id
      WHERE ($2::int IS NULL OR c.id = $2)
      ORDER BY COALESCE(c.last_message_at, c.created_at) DESC, c.id DESC
    `,
    [userId, conversationId],
  );

  return result.rows;
}

async function loadConversationParticipants(client, conversationIds, currentUserId) {
  if (!conversationIds.length) {
    return new Map();
  }

  const result = await client.query(
    `
      SELECT
        participant.conversation_id,
        participant.user_id,
        participant.role,
        participant.joined_at,
        participant.last_read_message_id,
        participant.last_read_at,
        u.nombre,
        pp.display_name,
        pp.avatar_url
      FROM app.padel_chat_participants participant
      JOIN app.users u
        ON u.id = participant.user_id
       AND u.deleted_at IS NULL
      LEFT JOIN app.padel_player_profiles pp
        ON pp.user_id = u.id
      WHERE participant.conversation_id = ANY($1::int[])
      ORDER BY
        CASE WHEN participant.role = 'owner' THEN 0 ELSE 1 END,
        participant.joined_at ASC,
        COALESCE(pp.display_name, u.nombre) ASC
    `,
    [conversationIds],
  );

  const conversationMap = new Map();

  for (const row of result.rows) {
    const conversationId = Number(row.conversation_id);

    if (!conversationMap.has(conversationId)) {
      conversationMap.set(conversationId, []);
    }

    conversationMap.get(conversationId).push(
      buildParticipantDto(row, currentUserId),
    );
  }

  return conversationMap;
}

async function loadUnreadCounts(client, userId, conversationIds) {
  if (!conversationIds.length) {
    return new Map();
  }

  const result = await client.query(
    `
      SELECT
        participant.conversation_id,
        COUNT(message.id)::int AS unread_count
      FROM app.padel_chat_participants participant
      JOIN app.padel_chat_messages message
        ON message.conversation_id = participant.conversation_id
      WHERE participant.user_id = $1
        AND participant.conversation_id = ANY($2::int[])
        AND message.sender_user_id <> $1
        AND (
          participant.last_read_message_id IS NULL
          OR message.id > participant.last_read_message_id
        )
      GROUP BY participant.conversation_id
    `,
    [userId, conversationIds],
  );

  return new Map(
    result.rows.map((row) => [
      Number(row.conversation_id),
      Number(row.unread_count || 0),
    ]),
  );
}

async function loadConversationDtoById(client, conversationId, userId) {
  const rows = await loadConversationRows(client, userId, conversationId);
  if (!rows.length) {
    return null;
  }

  const participantsMap = await loadConversationParticipants(
    client,
    [conversationId],
    userId,
  );
  const unreadCounts = await loadUnreadCounts(client, userId, [conversationId]);

  return buildConversationDto(
    rows[0],
    participantsMap.get(conversationId) || [],
    unreadCounts.get(conversationId) || 0,
    userId,
  );
}

async function ensureConversationReadyForUser(client, conversationId, userId) {
  const conversationResult = await client.query(
    `
      SELECT id, kind, event_plan_id, social_event_id
      FROM app.padel_chat_conversations
      WHERE id = $1
      LIMIT 1
    `,
    [conversationId],
  );

  if (conversationResult.rows.length === 0) {
    return null;
  }

  const conversation = conversationResult.rows[0];

  if (conversation.kind === 'event' && conversation.event_plan_id) {
    const access = await loadEventPlanAccess(
      client,
      Number(conversation.event_plan_id),
      userId,
    );

    if (!access) {
      return null;
    }

    await syncEventConversationParticipants(
      client,
      conversationId,
      Number(conversation.event_plan_id),
      Number(access.created_by),
    );
  }

  if (conversation.kind === 'social_event' && conversation.social_event_id) {
    const eventResult = await client.query(
      `
        SELECT id, created_by, status
        FROM app.padel_social_events
        WHERE id = $1
        LIMIT 1
      `,
      [conversation.social_event_id],
    );

    if (
      eventResult.rows.length === 0 ||
      eventResult.rows[0].status === 'cancelled'
    ) {
      return null;
    }

    const role =
      Number(eventResult.rows[0].created_by) === Number(userId)
        ? 'owner'
        : 'member';

    await client.query(
      `
        INSERT INTO app.padel_chat_participants (conversation_id, user_id, role)
        VALUES ($1, $2, $3)
        ON CONFLICT (conversation_id, user_id) DO NOTHING
      `,
      [conversationId, userId, role],
    );
  }

  const membershipResult = await client.query(
    `
      SELECT 1
      FROM app.padel_chat_participants
      WHERE conversation_id = $1
        AND user_id = $2
      LIMIT 1
    `,
    [conversationId, userId],
  );

  if (membershipResult.rows.length === 0) {
    return null;
  }

  return {
    kind: conversation.kind,
    event_plan_id: conversation.event_plan_id
      ? Number(conversation.event_plan_id)
      : null,
    social_event_id: conversation.social_event_id
      ? Number(conversation.social_event_id)
      : null,
  };
}

async function loadConversationParticipantIds(client, conversationId) {
  const result = await client.query(
    `
      SELECT user_id
      FROM app.padel_chat_participants
      WHERE conversation_id = $1
    `,
    [conversationId],
  );

  return result.rows.map((row) => Number(row.user_id));
}

async function loadSenderProfile(client, userId) {
  const result = await client.query(
    `
      SELECT
        u.id AS sender_user_id,
        u.nombre AS sender_nombre,
        pp.display_name AS sender_display_name,
        pp.avatar_url AS sender_avatar_url
      FROM app.users u
      LEFT JOIN app.padel_player_profiles pp ON pp.user_id = u.id
      WHERE u.id = $1
      LIMIT 1
    `,
    [userId],
  );

  return result.rows[0] || null;
}

export async function listPadelChatConversations(userId) {
  const client = await pool.connect();

  try {
    await syncEventConversationsForUser(client, userId);

    const rows = await loadConversationRows(client, userId);
    const conversationIds = rows.map((row) => Number(row.id));
    const [participantsMap, unreadCounts] = await Promise.all([
      loadConversationParticipants(client, conversationIds, userId),
      loadUnreadCounts(client, userId, conversationIds),
    ]);

    const conversations = rows.map((row) =>
      buildConversationDto(
        row,
        participantsMap.get(Number(row.id)) || [],
        unreadCounts.get(Number(row.id)) || 0,
        userId,
      ),
    );

    return {
      status: 200,
      body: {
        conversations,
      },
    };
  } finally {
    client.release();
  }
}

export async function getPadelChatConversation({
  userId,
  conversationId,
}) {
  const client = await pool.connect();

  try {
    const access = await ensureConversationReadyForUser(
      client,
      conversationId,
      userId,
    );

    if (!access) {
      return {
        status: 404,
        body: {
          error: 'Conversación no encontrada',
        },
      };
    }

    const conversation = await loadConversationDtoById(
      client,
      conversationId,
      userId,
    );

    if (!conversation) {
      return {
        status: 404,
        body: {
          error: 'Conversación no encontrada',
        },
      };
    }

    return {
      status: 200,
      body: {
        conversation,
      },
    };
  } finally {
    client.release();
  }
}

export async function getOrCreatePadelDirectConversation({
  userId,
  otherUserId,
}) {
  if (Number(userId) === Number(otherUserId)) {
    return {
      status: 400,
      body: {
        error: 'No puedes abrir un chat contigo mismo',
      },
    };
  }

  const client = await pool.connect();
  let transactionOpen = false;

  try {
    await client.query('BEGIN');
    transactionOpen = true;

    const activeUsers = await loadActiveUsersMap(client, [otherUserId]);
    if (!activeUsers.has(Number(otherUserId))) {
      await client.query('ROLLBACK');
      transactionOpen = false;
      return {
        status: 404,
        body: {
          error: 'Jugador no encontrado',
        },
      };
    }

    const { lowUserId, highUserId } = normalizeDirectPair(userId, otherUserId);
    const connectionResult = await client.query(
      `
        SELECT id
        FROM app.padel_player_connections
        WHERE user_a_id = $1
          AND user_b_id = $2
          AND status = 'accepted'
        LIMIT 1
      `,
      [lowUserId, highUserId],
    );

    if (connectionResult.rows.length === 0) {
      await client.query('ROLLBACK');
      transactionOpen = false;
      return {
        status: 403,
        body: {
          error: 'Solo puedes abrir chats directos con jugadores de tu red',
        },
      };
    }

    const insertResult = await client.query(
      `
        INSERT INTO app.padel_chat_conversations (
          kind,
          created_by,
          direct_user_low_id,
          direct_user_high_id
        )
        VALUES ('direct', $1, $2, $3)
        ON CONFLICT DO NOTHING
        RETURNING id
      `,
      [userId, lowUserId, highUserId],
    );

    let conversationId = insertResult.rows[0]?.id
      ? Number(insertResult.rows[0].id)
      : null;

    if (!conversationId) {
      const existingResult = await client.query(
        `
          SELECT id
          FROM app.padel_chat_conversations
          WHERE kind = 'direct'
            AND direct_user_low_id = $1
            AND direct_user_high_id = $2
          LIMIT 1
        `,
        [lowUserId, highUserId],
      );

      if (existingResult.rows.length === 0) {
        throw new Error('No se pudo localizar la conversación directa creada');
      }

      conversationId = Number(existingResult.rows[0].id);
    }

    await client.query(
      `
        INSERT INTO app.padel_chat_participants (conversation_id, user_id, role)
        SELECT $1, payload.user_id, payload.role
        FROM UNNEST($2::int[], $3::text[]) AS payload(user_id, role)
        ON CONFLICT (conversation_id, user_id) DO NOTHING
      `,
      [conversationId, [userId, otherUserId], ['owner', 'member']],
    );

    const conversation = await loadConversationDtoById(
      client,
      conversationId,
      userId,
    );

    await client.query('COMMIT');
    transactionOpen = false;

    if (insertResult.rows.length > 0) {
      emitPadelChatConversationCreated({
        userIds: [userId, otherUserId],
        conversationId,
        kind: 'direct',
      });
    }

    return {
      status: insertResult.rows.length > 0 ? 201 : 200,
      body: {
        conversation,
      },
    };
  } catch (error) {
    if (transactionOpen) {
      await client.query('ROLLBACK');
    }
    throw error;
  } finally {
    client.release();
  }
}

export async function createPadelGroupConversation({
  userId,
  title,
  participantUserIds,
}) {
  const normalizedParticipantIds = normalizeUserIds(participantUserIds).filter(
    (participantId) => Number(participantId) !== Number(userId),
  );

  if (!normalizedParticipantIds.length) {
    return {
      status: 400,
      body: {
        error: 'Selecciona al menos un participante',
      },
    };
  }

  const client = await pool.connect();
  let transactionOpen = false;

  try {
    await client.query('BEGIN');
    transactionOpen = true;

    const activeUsers = await loadActiveUsersMap(client, normalizedParticipantIds);
    const missingUserIds = normalizedParticipantIds.filter(
      (participantId) => !activeUsers.has(Number(participantId)),
    );

    if (missingUserIds.length > 0) {
      await client.query('ROLLBACK');
      transactionOpen = false;
      return {
        status: 404,
        body: {
          error: 'Hay jugadores que no existen o ya no están activos',
          missing_user_ids: missingUserIds,
        },
      };
    }

    const acceptedConnections = await loadAcceptedConnectionIds(client, userId);
    const forbiddenUserIds = normalizedParticipantIds.filter(
      (participantId) => !acceptedConnections.has(Number(participantId)),
    );

    if (forbiddenUserIds.length > 0) {
      await client.query('ROLLBACK');
      transactionOpen = false;
      return {
        status: 403,
        body: {
          error:
            'Solo puedes crear grupos con jugadores que formen parte de tu red',
          invalid_user_ids: forbiddenUserIds,
        },
      };
    }

    const insertResult = await client.query(
      `
        INSERT INTO app.padel_chat_conversations (kind, created_by, title)
        VALUES ('group', $1, $2)
        RETURNING id
      `,
      [userId, title.trim()],
    );

    const conversationId = Number(insertResult.rows[0].id);
    const allParticipantIds = [userId, ...normalizedParticipantIds];
    const participantRoles = allParticipantIds.map((participantId) =>
      Number(participantId) === Number(userId) ? 'owner' : 'member',
    );

    await client.query(
      `
        INSERT INTO app.padel_chat_participants (conversation_id, user_id, role)
        SELECT $1, payload.user_id, payload.role
        FROM UNNEST($2::int[], $3::text[]) AS payload(user_id, role)
      `,
      [conversationId, allParticipantIds, participantRoles],
    );

    const conversation = await loadConversationDtoById(
      client,
      conversationId,
      userId,
    );

    await client.query('COMMIT');
    transactionOpen = false;

    emitPadelChatConversationCreated({
      userIds: allParticipantIds,
      conversationId,
      kind: 'group',
    });

    return {
      status: 201,
      body: {
        conversation,
      },
    };
  } catch (error) {
    if (transactionOpen) {
      await client.query('ROLLBACK');
    }
    throw error;
  } finally {
    client.release();
  }
}

export async function getOrCreatePadelEventConversation({
  userId,
  planId,
}) {
  const client = await pool.connect();
  let transactionOpen = false;

  try {
    await client.query('BEGIN');
    transactionOpen = true;

    const access = await loadEventPlanAccess(client, planId, userId);
    if (!access) {
      await client.query('ROLLBACK');
      transactionOpen = false;
      return {
        status: 404,
        body: {
          error: 'Evento no encontrado',
        },
      };
    }

    const ensuredConversation = await ensureEventConversation(client, planId);
    if (!ensuredConversation) {
      await client.query('ROLLBACK');
      transactionOpen = false;
      return {
        status: 404,
        body: {
          error: 'Evento no encontrado',
        },
      };
    }

    const conversation = await loadConversationDtoById(
      client,
      ensuredConversation.conversationId,
      userId,
    );

    await client.query('COMMIT');
    transactionOpen = false;

    return {
      status: ensuredConversation.created ? 201 : 200,
      body: {
        conversation,
      },
    };
  } catch (error) {
    if (transactionOpen) {
      await client.query('ROLLBACK');
    }
    throw error;
  } finally {
    client.release();
  }
}

function buildSocialEventDto(row) {
  return {
    id: Number(row.id),
    title: row.title,
    description: row.description || null,
    venue_name: row.venue_name || null,
    location: row.location || null,
    scheduled_date: normalizeDateValue(row.scheduled_date),
    scheduled_time: normalizeTimeOnlyValue(row.scheduled_time),
    duration_minutes: Number(
      row.duration_minutes || DEFAULT_SOCIAL_EVENT_DURATION_MINUTES,
    ),
    status: row.status,
    created_by: row.created_by ? Number(row.created_by) : null,
    creator: row.creator_user_id
      ? {
          user_id: Number(row.creator_user_id),
          display_name: displayNameFromRow(
            {
              display_name: row.creator_display_name,
              nombre: row.creator_nombre,
            },
            row.creator_user_id,
          ),
          nombre: row.creator_nombre || null,
          avatar_url: row.creator_avatar_url || null,
        }
      : null,
    conversation_id: row.conversation_id ? Number(row.conversation_id) : null,
    participant_count: Number(row.participant_count || 0),
    is_joined: Boolean(row.is_joined),
    created_at: row.created_at,
    updated_at: row.updated_at,
  };
}

async function ensureSocialEventConversation(client, eventId, userId) {
  const eventResult = await client.query(
    `
      SELECT id, created_by, status
      FROM app.padel_social_events
      WHERE id = $1
      LIMIT 1
    `,
    [eventId],
  );

  if (
    eventResult.rows.length === 0 ||
    eventResult.rows[0].status === 'cancelled'
  ) {
    return null;
  }

  const event = eventResult.rows[0];
  const insertResult = await client.query(
    `
      INSERT INTO app.padel_chat_conversations (
        kind,
        created_by,
        social_event_id
      )
      VALUES ('social_event', $1, $2)
      ON CONFLICT DO NOTHING
      RETURNING id
    `,
    [event.created_by || userId, eventId],
  );

  let conversationId = insertResult.rows[0]?.id
    ? Number(insertResult.rows[0].id)
    : null;

  if (!conversationId) {
    const existingResult = await client.query(
      `
        SELECT id
        FROM app.padel_chat_conversations
        WHERE kind = 'social_event'
          AND social_event_id = $1
        LIMIT 1
      `,
      [eventId],
    );

    if (existingResult.rows.length === 0) {
      return null;
    }

    conversationId = Number(existingResult.rows[0].id);
  }

  const role = Number(event.created_by) === Number(userId) ? 'owner' : 'member';
  const participantResult = await client.query(
    `
      INSERT INTO app.padel_chat_participants (conversation_id, user_id, role)
      VALUES ($1, $2, $3)
      ON CONFLICT (conversation_id, user_id) DO NOTHING
      RETURNING user_id
    `,
    [conversationId, userId, role],
  );

  return {
    conversationId,
    created: insertResult.rows.length > 0,
    joined: participantResult.rows.length > 0,
  };
}

export async function listPadelSocialEvents(userId) {
  const client = await pool.connect();

  try {
    const result = await client.query(
      `
        SELECT
          se.*,
          creator.id AS creator_user_id,
          creator.nombre AS creator_nombre,
          creator_profile.display_name AS creator_display_name,
          creator_profile.avatar_url AS creator_avatar_url,
          conversation.id AS conversation_id,
          COUNT(participant.id)::int AS participant_count,
          BOOL_OR(participant.user_id = $1)::boolean AS is_joined
        FROM app.padel_social_events se
        LEFT JOIN app.users creator
          ON creator.id = se.created_by
        LEFT JOIN app.padel_player_profiles creator_profile
          ON creator_profile.user_id = creator.id
        LEFT JOIN app.padel_chat_conversations conversation
          ON conversation.kind = 'social_event'
         AND conversation.social_event_id = se.id
        LEFT JOIN app.padel_chat_participants participant
          ON participant.conversation_id = conversation.id
        WHERE se.status = 'active'
          AND (se.scheduled_date + se.scheduled_time) >= (NOW() AT TIME ZONE $2)
        GROUP BY
          se.id,
          creator.id,
          creator.nombre,
          creator_profile.display_name,
          creator_profile.avatar_url,
          conversation.id
        ORDER BY se.scheduled_date ASC, se.scheduled_time ASC, se.id ASC
        LIMIT 100
      `,
      [userId, APP_TIME_ZONE],
    );

    return {
      status: 200,
      body: {
        events: result.rows.map(buildSocialEventDto),
      },
    };
  } finally {
    client.release();
  }
}

export async function createPadelSocialEvent({
  userId,
  title,
  description = null,
  venueName = null,
  location = null,
  scheduledDate,
  scheduledTime,
  durationMinutes = DEFAULT_SOCIAL_EVENT_DURATION_MINUTES,
}) {
  const client = await pool.connect();
  let transactionOpen = false;

  try {
    const normalizedDate = normalizeDateValue(scheduledDate);
    const normalizedTime = normalizeTimeValue(scheduledTime);
    const startsAt = combineDateAndTime(normalizedDate, normalizedTime);

    if (!startsAt.isValid || startsAt < nowInAppZone().minus({ minutes: 1 })) {
      return {
        status: 400,
        body: {
          error: 'El evento debe programarse en una fecha futura',
        },
      };
    }

    await client.query('BEGIN');
    transactionOpen = true;

    const eventResult = await client.query(
      `
        INSERT INTO app.padel_social_events (
          created_by,
          title,
          description,
          venue_name,
          location,
          scheduled_date,
          scheduled_time,
          duration_minutes
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        RETURNING *
      `,
      [
        userId,
        title.trim(),
        sanitizeOptionalText(description),
        sanitizeOptionalText(venueName),
        sanitizeOptionalText(location),
        normalizedDate,
        normalizedTime,
        Number.parseInt(durationMinutes, 10) ||
          DEFAULT_SOCIAL_EVENT_DURATION_MINUTES,
      ],
    );

    const eventId = Number(eventResult.rows[0].id);
    const conversationInfo = await ensureSocialEventConversation(
      client,
      eventId,
      userId,
    );

    const conversation = conversationInfo
      ? await loadConversationDtoById(
          client,
          conversationInfo.conversationId,
          userId,
        )
      : null;

    await client.query('COMMIT');
    transactionOpen = false;

    if (conversationInfo) {
      emitPadelChatConversationCreated({
        userIds: [userId],
        conversationId: conversationInfo.conversationId,
        kind: 'social_event',
      });
    }

    return {
      status: 201,
      body: {
        event: buildSocialEventDto({
          ...eventResult.rows[0],
          creator_user_id: userId,
          conversation_id: conversation?.id || null,
          participant_count: 1,
          is_joined: true,
        }),
        conversation,
      },
    };
  } catch (error) {
    if (transactionOpen) {
      await client.query('ROLLBACK');
    }
    throw error;
  } finally {
    client.release();
  }
}

export async function getOrCreatePadelSocialEventConversation({
  userId,
  eventId,
}) {
  const client = await pool.connect();
  let transactionOpen = false;

  try {
    await client.query('BEGIN');
    transactionOpen = true;

    const conversationInfo = await ensureSocialEventConversation(
      client,
      asInt(eventId),
      userId,
    );

    if (!conversationInfo) {
      await client.query('ROLLBACK');
      transactionOpen = false;
      return {
        status: 404,
        body: {
          error: 'Evento no encontrado o cancelado',
        },
      };
    }

    const conversation = await loadConversationDtoById(
      client,
      conversationInfo.conversationId,
      userId,
    );

    await client.query('COMMIT');
    transactionOpen = false;

    if (conversationInfo.created || conversationInfo.joined) {
      emitPadelChatConversationCreated({
        userIds: [userId],
        conversationId: conversationInfo.conversationId,
        kind: 'social_event',
      });
    }

    return {
      status: conversationInfo.created ? 201 : 200,
      body: {
        conversation,
      },
    };
  } catch (error) {
    if (transactionOpen) {
      await client.query('ROLLBACK');
    }
    throw error;
  } finally {
    client.release();
  }
}

export async function listPadelChatMessages({
  userId,
  conversationId,
  beforeMessageId = null,
  limit = DEFAULT_MESSAGE_LIMIT,
}) {
  const client = await pool.connect();

  try {
    const access = await ensureConversationReadyForUser(
      client,
      conversationId,
      userId,
    );

    if (!access) {
      return {
        status: 404,
        body: {
          error: 'Conversación no encontrada',
        },
      };
    }

    const conversation = await loadConversationDtoById(
      client,
      conversationId,
      userId,
    );

    const params = [conversationId];
    let beforeClause = '';

    if (beforeMessageId) {
      params.push(beforeMessageId);
      beforeClause = `AND message.id < $${params.length}`;
    }

    params.push(limit + 1);

    const result = await client.query(
      `
        SELECT
          message.id,
          message.conversation_id,
          message.body,
          message.created_at,
          message.sender_user_id,
          sender.nombre AS sender_nombre,
          sender_profile.display_name AS sender_display_name,
          sender_profile.avatar_url AS sender_avatar_url
        FROM app.padel_chat_messages message
        JOIN app.users sender ON sender.id = message.sender_user_id
        LEFT JOIN app.padel_player_profiles sender_profile
          ON sender_profile.user_id = sender.id
        WHERE message.conversation_id = $1
          ${beforeClause}
        ORDER BY message.id DESC
        LIMIT $${params.length}
      `,
      params,
    );

    const hasMore = result.rows.length > limit;
    const rows = hasMore ? result.rows.slice(0, limit) : result.rows;
    const messages = rows.reverse().map((row) => buildMessageDto(row, userId));
    const oldestMessage = messages[0] || null;

    return {
      status: 200,
      body: {
        conversation,
        messages,
        has_more: hasMore,
        next_before_message_id: hasMore && oldestMessage
          ? Number(oldestMessage.id)
          : null,
      },
    };
  } finally {
    client.release();
  }
}

export async function sendPadelChatMessage({
  userId,
  conversationId,
  body,
}) {
  const client = await pool.connect();
  let transactionOpen = false;

  try {
    await client.query('BEGIN');
    transactionOpen = true;

    const access = await ensureConversationReadyForUser(
      client,
      conversationId,
      userId,
    );

    if (!access) {
      await client.query('ROLLBACK');
      transactionOpen = false;
      return {
        status: 404,
        body: {
          error: 'Conversación no encontrada',
        },
      };
    }

    const insertResult = await client.query(
      `
        INSERT INTO app.padel_chat_messages (conversation_id, sender_user_id, body)
        VALUES ($1, $2, $3)
        RETURNING id, conversation_id, body, created_at, sender_user_id
      `,
      [conversationId, userId, body],
    );

    const senderProfile = await loadSenderProfile(client, userId);
    const participantIds = await loadConversationParticipantIds(
      client,
      conversationId,
    );
    const conversation = await loadConversationDtoById(
      client,
      conversationId,
      userId,
    );

    const message = buildMessageDto(
      {
        ...insertResult.rows[0],
        ...senderProfile,
      },
      userId,
    );

    await client.query('COMMIT');
    transactionOpen = false;

    const recipientIds = participantIds.filter(
      (participantId) => Number(participantId) !== Number(userId),
    );

    emitPadelChatMessageCreated({
      userIds: participantIds,
      conversationId,
      kind: conversation?.kind || access.kind,
      message,
    });

    sendPushToUsers({
      userIds: recipientIds,
      title: message.sender.display_name,
      body: buildPushPreview(body),
      data: {
        type: 'chat_message',
        conversation_id: conversationId,
        conversation_kind: conversation?.kind || access.kind,
      },
    }).catch((error) => {
      console.error('Error enviando push de chat:', error);
    });

    return {
      status: 201,
      body: {
        conversation,
        message,
      },
    };
  } catch (error) {
    if (transactionOpen) {
      await client.query('ROLLBACK');
    }
    throw error;
  } finally {
    client.release();
  }
}

export async function markPadelChatConversationRead({
  userId,
  conversationId,
  messageId = null,
}) {
  const client = await pool.connect();
  let transactionOpen = false;

  try {
    await client.query('BEGIN');
    transactionOpen = true;

    const access = await ensureConversationReadyForUser(
      client,
      conversationId,
      userId,
    );

    if (!access) {
      await client.query('ROLLBACK');
      transactionOpen = false;
      return {
        status: 404,
        body: {
          error: 'Conversación no encontrada',
        },
      };
    }

    const participantResult = await client.query(
      `
        SELECT last_read_message_id, last_read_at
        FROM app.padel_chat_participants
        WHERE conversation_id = $1
          AND user_id = $2
        FOR UPDATE
      `,
      [conversationId, userId],
    );

    if (participantResult.rows.length === 0) {
      await client.query('ROLLBACK');
      transactionOpen = false;
      return {
        status: 404,
        body: {
          error: 'Conversación no encontrada',
        },
      };
    }

    const currentState = participantResult.rows[0];
    let targetMessageId = currentState.last_read_message_id
      ? Number(currentState.last_read_message_id)
      : null;
    let targetReadAt = currentState.last_read_at || null;

    if (messageId) {
      const messageResult = await client.query(
        `
          SELECT id, created_at
          FROM app.padel_chat_messages
          WHERE id = $1
            AND conversation_id = $2
          LIMIT 1
        `,
        [messageId, conversationId],
      );

      if (messageResult.rows.length === 0) {
        await client.query('ROLLBACK');
        transactionOpen = false;
        return {
          status: 404,
          body: {
            error: 'Mensaje no encontrado en la conversación',
          },
        };
      }

      const targetMessage = messageResult.rows[0];
      if (!targetMessageId || Number(targetMessage.id) > Number(targetMessageId)) {
        targetMessageId = Number(targetMessage.id);
        targetReadAt = targetMessage.created_at;
      }
    } else if (!targetMessageId) {
      const lastMessageResult = await client.query(
        `
          SELECT id, created_at
          FROM app.padel_chat_messages
          WHERE conversation_id = $1
          ORDER BY id DESC
          LIMIT 1
        `,
        [conversationId],
      );

      if (lastMessageResult.rows.length > 0) {
        targetMessageId = Number(lastMessageResult.rows[0].id);
        targetReadAt = lastMessageResult.rows[0].created_at;
      } else {
        targetReadAt = new Date().toISOString();
      }
    }

    if (!targetReadAt) {
      targetReadAt = new Date().toISOString();
    }

    await client.query(
      `
        UPDATE app.padel_chat_participants
        SET last_read_message_id = $3,
            last_read_at = $4,
            updated_at = NOW()
        WHERE conversation_id = $1
          AND user_id = $2
      `,
      [conversationId, userId, targetMessageId, targetReadAt],
    );

    const participantIds = await loadConversationParticipantIds(
      client,
      conversationId,
    );

    await client.query('COMMIT');
    transactionOpen = false;

    emitPadelChatReadUpdated({
      userIds: participantIds,
      conversationId,
      userId,
      messageId: targetMessageId,
      readAt: targetReadAt,
    });

    return {
      status: 200,
      body: {
        conversation_id: Number(conversationId),
        message_id: targetMessageId,
        read_at: targetReadAt,
      },
    };
  } catch (error) {
    if (transactionOpen) {
      await client.query('ROLLBACK');
    }
    throw error;
  } finally {
    client.release();
  }
}
