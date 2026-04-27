import express from 'express';
import bcrypt from 'bcryptjs';
import { pool } from '../db.js';
import { authenticateToken } from '../middleware/auth.js';
import { validate } from '../middleware/validate.js';
import {
  DEFAULT_DURATION_MINUTES,
  calculateEndTime,
  normalizeDateValue,
  nowInAppZone,
} from '../services/calendarUtils.js';
import {
  deleteProfileSchema,
  playerSearchQuerySchema,
  updateProfileSchema,
} from '../validators/playerValidators.js';

const router = express.Router();

const basePlayerColumns = `
  pp.user_id,
  pp.display_name,
  pp.main_level,
  pp.sub_level,
  pp.numeric_level,
  pp.court_preferences,
  pp.dominant_hands,
  pp.availability_preferences,
  pp.match_preferences,
  pp.bio,
  pp.avatar_url,
  pp.matches_played,
  pp.matches_won,
  pp.is_available,
  pp.gender,
  pp.birth_date,
  pp.phone,
  u.nombre,
  COALESCE(r.avg_rating, 0) as avg_rating
`;

function normalizeConnectionPair(leftUserId, rightUserId) {
  return leftUserId < rightUserId
    ? { userAId: leftUserId, userBId: rightUserId }
    : { userAId: rightUserId, userBId: leftUserId };
}

function connectionSelectSql(currentUserParamIndex) {
  return `
    pc.id as connection_id,
    CASE
      WHEN pc.id IS NULL THEN NULL
      WHEN pc.status = 'accepted' THEN 'accepted'
      WHEN pc.status = 'pending' AND pc.requested_by = $${currentUserParamIndex} THEN 'outgoing_pending'
      WHEN pc.status = 'pending' THEN 'incoming_pending'
      WHEN pc.status = 'rejected' AND pc.requested_by = $${currentUserParamIndex} THEN 'rejected'
      ELSE NULL
    END as connection_status,
    COALESCE(pc.requested_by = $${currentUserParamIndex}, false) as connection_requested_by_me,
    pc.requested_at as connection_requested_at,
    pc.responded_at as connection_responded_at
  `;
}

function connectionJoinSql(profileUserIdExpression, currentUserParamIndex) {
  return `
    LEFT JOIN app.padel_player_connections pc
      ON pc.user_a_id = LEAST(${profileUserIdExpression}, $${currentUserParamIndex})
     AND pc.user_b_id = GREATEST(${profileUserIdExpression}, $${currentUserParamIndex})
  `;
}

function buildPlayerRow(row) {
  return {
    ...row,
    avg_rating: Number(row.avg_rating ?? 0),
  };
}

function buildDeletedEmail(userId) {
  return `deleted+${userId}+${Date.now()}@deleted.indalo.local`;
}

function parseOptionalInt(value) {
  const parsed = Number.parseInt(value, 10);
  return Number.isInteger(parsed) ? parsed : null;
}

function hasCommunityPlanFinished(plan, referenceNow = nowInAppZone()) {
  const endMoment = calculateEndTime(
    normalizeDateValue(plan.scheduled_date),
    plan.scheduled_time,
    Number.parseInt(plan.duration_minutes, 10) || DEFAULT_DURATION_MINUTES,
  );

  return endMoment.plus({ minutes: 1 }).toMillis() <= referenceNow.toMillis();
}

function hasLegacyMatchFinished(match, referenceNow = nowInAppZone()) {
  if (match.status === 'finalizado') {
    return true;
  }

  if (!match.match_date || !match.start_time) {
    return false;
  }

  const endMoment = calculateEndTime(
    normalizeDateValue(match.match_date),
    match.start_time,
    DEFAULT_DURATION_MINUTES,
  );

  return endMoment.toMillis() <= referenceNow.toMillis();
}

async function resolveCommunityPlanForRating(client, {
  raterId,
  ratedId,
  planId = null,
  requireUnrated = false,
}) {
  const result = await client.query(
    `
      SELECT
        cp.id,
        cp.scheduled_date,
        cp.scheduled_time,
        cp.duration_minutes,
        cp.invite_state,
        cp.reservation_state,
        mr.status AS result_status,
        EXISTS (
          SELECT 1
          FROM app.padel_match_result_submissions submissions
          WHERE submissions.plan_id = cp.id
            AND submissions.user_id = $1
        ) AS rater_submitted_result,
        EXISTS (
          SELECT 1
          FROM app.padel_player_ratings pr
          WHERE pr.rater_id = $1
            AND pr.rated_id = $2
            AND pr.community_plan_id = cp.id
        ) AS already_rated
      FROM app.padel_community_plans cp
      JOIN app.padel_community_plan_players rater_membership
        ON rater_membership.plan_id = cp.id
       AND rater_membership.user_id = $1
       AND rater_membership.response_state = 'accepted'
      JOIN app.padel_community_plan_players rated_membership
        ON rated_membership.plan_id = cp.id
       AND rated_membership.user_id = $2
       AND rated_membership.response_state = 'accepted'
      LEFT JOIN app.padel_match_results mr ON mr.plan_id = cp.id
      WHERE cp.reservation_state = 'confirmed'
        AND cp.invite_state NOT IN ('cancelled', 'expired')
        AND ($3::int IS NULL OR cp.id = $3)
      ORDER BY
        cp.scheduled_date DESC,
        cp.scheduled_time DESC,
        cp.id DESC
    `,
    [raterId, ratedId, planId],
  );

  if (!result.rows.length) {
    return { plan: null, error: 'no_shared_plan' };
  }

  const finishedPlans = result.rows.filter((row) => hasCommunityPlanFinished(row));
  if (!finishedPlans.length) {
    return { plan: null, error: 'plan_not_finished' };
  }

  const resolvedPlans = finishedPlans.filter(
    (row) => row.result_status === 'consensuado' || row.rater_submitted_result,
  );
  if (!resolvedPlans.length) {
    return { plan: null, error: 'result_missing' };
  }

  const candidatePlans = requireUnrated
    ? resolvedPlans.filter((row) => !row.already_rated)
    : resolvedPlans;

  if (!candidatePlans.length) {
    return { plan: null, error: 'already_rated' };
  }

  return { plan: candidatePlans[0], error: null };
}

async function loadLegacyMatchForRating(client, { raterId, ratedId, matchId }) {
  const result = await client.query(
    `
      SELECT m.id, m.status, m.match_date, m.start_time
      FROM app.padel_matches m
      JOIN app.padel_match_players rater_player
        ON rater_player.match_id = m.id
       AND rater_player.user_id = $1
      JOIN app.padel_match_players rated_player
        ON rated_player.match_id = m.id
       AND rated_player.user_id = $2
      WHERE m.id = $3
      LIMIT 1
    `,
    [raterId, ratedId, matchId],
  );

  return result.rows[0] || null;
}

async function loadRatingContextsForPlayer(client, { raterId, ratedId }) {
  const communityResult = await client.query(
    `
      SELECT
        cp.id,
        cp.scheduled_date,
        cp.scheduled_time,
        cp.duration_minutes,
        cp.invite_state,
        cp.reservation_state,
        v.name AS venue_name,
        mr.status AS result_status,
        EXISTS (
          SELECT 1
          FROM app.padel_match_result_submissions submissions
          WHERE submissions.plan_id = cp.id
            AND submissions.user_id = $1
        ) AS rater_submitted_result,
        pr.rating AS existing_rating,
        pr.comment AS existing_comment
      FROM app.padel_community_plans cp
      JOIN app.padel_community_plan_players rater_membership
        ON rater_membership.plan_id = cp.id
       AND rater_membership.user_id = $1
       AND rater_membership.response_state = 'accepted'
      JOIN app.padel_community_plan_players rated_membership
        ON rated_membership.plan_id = cp.id
       AND rated_membership.user_id = $2
       AND rated_membership.response_state = 'accepted'
      LEFT JOIN app.padel_venues v ON v.id = cp.venue_id
      LEFT JOIN app.padel_match_results mr ON mr.plan_id = cp.id
      LEFT JOIN app.padel_player_ratings pr
        ON pr.rater_id = $1
       AND pr.rated_id = $2
       AND pr.community_plan_id = cp.id
      WHERE cp.reservation_state = 'confirmed'
        AND cp.invite_state NOT IN ('cancelled', 'expired')
      ORDER BY cp.scheduled_date DESC, cp.scheduled_time DESC, cp.id DESC
      LIMIT 20
    `,
    [raterId, ratedId],
  );

  const communityContexts = communityResult.rows
    .filter((row) => hasCommunityPlanFinished(row))
    .filter((row) => row.result_status === 'consensuado' || row.rater_submitted_result)
    .map((row) => ({
      context_type: 'community_plan',
      plan_id: Number(row.id),
      match_id: null,
      scheduled_date: normalizeDateValue(row.scheduled_date),
      scheduled_time: row.scheduled_time || null,
      venue_name: row.venue_name || null,
      existing_rating: row.existing_rating ? Number(row.existing_rating) : null,
      existing_comment: row.existing_comment || null,
    }));

  const legacyResult = await client.query(
    `
      SELECT
        m.id,
        m.status,
        m.match_date,
        m.start_time,
        v.name AS venue_name,
        pr.rating AS existing_rating,
        pr.comment AS existing_comment
      FROM app.padel_matches m
      JOIN app.padel_match_players rater_player
        ON rater_player.match_id = m.id
       AND rater_player.user_id = $1
      JOIN app.padel_match_players rated_player
        ON rated_player.match_id = m.id
       AND rated_player.user_id = $2
      LEFT JOIN app.padel_venues v ON v.id = m.venue_id
      LEFT JOIN app.padel_player_ratings pr
        ON pr.rater_id = $1
       AND pr.rated_id = $2
       AND pr.match_id = m.id
      ORDER BY m.match_date DESC, m.start_time DESC, m.id DESC
      LIMIT 20
    `,
    [raterId, ratedId],
  );

  const legacyContexts = legacyResult.rows
    .filter((row) => hasLegacyMatchFinished(row))
    .map((row) => ({
      context_type: 'match',
      plan_id: null,
      match_id: Number(row.id),
      scheduled_date: normalizeDateValue(row.match_date),
      scheduled_time: row.start_time || null,
      venue_name: row.venue_name || null,
      existing_rating: row.existing_rating ? Number(row.existing_rating) : null,
      existing_comment: row.existing_comment || null,
    }));

  return [...communityContexts, ...legacyContexts]
    .sort((left, right) => {
      const leftKey = `${left.scheduled_date || ''}T${left.scheduled_time || ''}`;
      const rightKey = `${right.scheduled_date || ''}T${right.scheduled_time || ''}`;
      return rightKey.localeCompare(leftKey);
    });
}

// GET /api/padel/players/profile - Mi perfil
router.get('/profile', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT pp.*, u.nombre, u.email
       FROM app.padel_player_profiles pp
       JOIN app.users u ON pp.user_id = u.id
       WHERE pp.user_id = $1`,
      [req.user.userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Perfil no encontrado' });
    }

    // Get average rating
    const ratingResult = await pool.query(
      'SELECT COALESCE(AVG(rating), 0) as avg_rating, COUNT(*) as total_ratings FROM app.padel_player_ratings WHERE rated_id = $1',
      [req.user.userId]
    );

    res.json({
      profile: {
        ...result.rows[0],
        avg_rating: parseFloat(ratingResult.rows[0].avg_rating).toFixed(1),
        total_ratings: parseInt(ratingResult.rows[0].total_ratings)
      }
    });
  } catch (error) {
    console.error('Error obteniendo perfil:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// PUT /api/padel/players/profile - Actualizar perfil
router.put('/profile', authenticateToken, validate(updateProfileSchema), async (req, res) => {
  const client = await pool.connect();

  try {
    const {
      display_name,
      main_level,
      sub_level,
      preferred_venue_id,
      bio,
      avatar_url,
      is_available,
      gender,
      birth_date,
      phone,
      court_preferences,
      dominant_hands,
      availability_preferences,
      match_preferences,
      new_password,
    } = req.body;

    await client.query('BEGIN');

    if (new_password) {
      const passwordHash = await bcrypt.hash(new_password, 10);
      const userResult = await client.query(
        `UPDATE app.users
         SET password_hash = $1,
             updated_at = NOW()
         WHERE id = $2
         RETURNING id`,
        [passwordHash, req.user.userId]
      );

      if (userResult.rows.length === 0) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'Usuario no encontrado' });
      }
    }

    const result = await client.query(
      `UPDATE app.padel_player_profiles
       SET display_name = COALESCE($1, display_name),
           main_level = COALESCE($2, main_level),
           sub_level = COALESCE($3, sub_level),
           preferred_venue_id = COALESCE($4, preferred_venue_id),
           bio = COALESCE($5, bio),
           avatar_url = COALESCE($6, avatar_url),
           is_available = COALESCE($7, is_available),
           court_preferences = COALESCE($8, court_preferences),
           dominant_hands = COALESCE($9, dominant_hands),
           availability_preferences = COALESCE($10, availability_preferences),
           match_preferences = COALESCE($11, match_preferences),
           gender = COALESCE($12, gender),
           birth_date = COALESCE($13::date, birth_date),
           phone = CASE
             WHEN $14::text IS NULL THEN phone
             ELSE NULLIF($14, '')
           END,
           updated_at = NOW()
       WHERE user_id = $15
       RETURNING *`,
      [
        display_name,
        main_level,
        sub_level,
        preferred_venue_id,
        bio,
        avatar_url,
        is_available,
        court_preferences,
        dominant_hands,
        availability_preferences,
        match_preferences,
        gender,
        birth_date,
        phone?.trim() ?? null,
        req.user.userId,
      ]
    );

    if (result.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Perfil no encontrado' });
    }

    await client.query('COMMIT');
    res.json({ profile: result.rows[0] });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Error actualizando perfil:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  } finally {
    client.release();
  }
});

// DELETE /api/padel/players/profile - Baja lógica del perfil
router.delete(
  '/profile',
  authenticateToken,
  validate(deleteProfileSchema),
  async (req, res) => {
    const client = await pool.connect();

    try {
      const { reason, other_reason } = req.body;
      const userId = req.user.userId;
      const deletedPasswordHash = await bcrypt.hash(
        `deleted::${userId}::${Date.now()}`,
        10
      );

      await client.query('BEGIN');

      const userResult = await client.query(
        `SELECT id, email
         FROM app.users
         WHERE id = $1
           AND deleted_at IS NULL
         FOR UPDATE`,
        [userId]
      );

      if (userResult.rows.length === 0) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'Perfil no encontrado' });
      }

      await client.query(
        'DELETE FROM app.padel_favorites WHERE user_id = $1 OR favorite_id = $1',
        [userId]
      );
      await client.query(
        'DELETE FROM app.padel_fcm_tokens WHERE user_id = $1',
        [userId]
      );
      await client.query(
        'DELETE FROM app.padel_player_connections WHERE user_a_id = $1 OR user_b_id = $1',
        [userId]
      );
      await client.query(
        `UPDATE app.padel_player_profiles
         SET is_available = false,
             updated_at = NOW()
         WHERE user_id = $1`,
        [userId]
      );
      await client.query(
        `UPDATE app.users
         SET deleted_at = NOW(),
             deleted_reason = $1::VARCHAR(32),
             deleted_reason_other = CASE
               WHEN $1::VARCHAR(32) = 'otros' THEN NULLIF($2::TEXT, '')
               ELSE NULL
             END,
             deleted_email = email,
             email = $3::VARCHAR(100),
             password_hash = $4::VARCHAR(255),
             email_verification_token_hash = NULL,
             email_verification_sent_at = NULL,
             email_verification_expires_at = NULL,
             password_reset_token_hash = NULL,
             password_reset_sent_at = NULL,
             password_reset_expires_at = NULL,
             updated_at = NOW()
         WHERE id = $5::INTEGER`,
        [
          reason,
          other_reason?.trim() ?? null,
          buildDeletedEmail(userId),
          deletedPasswordHash,
          userId,
        ]
      );

      await client.query('COMMIT');
      return res.json({ message: 'Perfil eliminado correctamente' });
    } catch (error) {
      await client.query('ROLLBACK');
      console.error('Error eliminando perfil:', error);
      return res.status(500).json({ error: 'No se pudo eliminar el perfil' });
    } finally {
      client.release();
    }
  }
);

// GET /api/padel/players/network - Mi red, solicitudes recibidas y enviadas
router.get('/network', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.userId;

    const result = await pool.query(
      `
        WITH ratings AS (
          SELECT rated_id, AVG(rating) AS avg_rating
          FROM app.padel_player_ratings
          GROUP BY rated_id
        )
        SELECT
          pc.id as connection_id,
          pc.status,
          pc.requested_by,
          pc.responded_by,
          pc.requested_at,
          pc.responded_at,
          CASE
            WHEN pc.user_a_id = $1 THEN pc.user_b_id
            ELSE pc.user_a_id
          END as user_id,
          pp.display_name,
          pp.main_level,
          pp.sub_level,
          pp.numeric_level,
          pp.court_preferences,
          pp.dominant_hands,
          pp.availability_preferences,
          pp.match_preferences,
          pp.bio,
          pp.matches_played,
          pp.matches_won,
          pp.is_available,
          pp.gender,
          pp.birth_date,
          pp.phone,
          u.nombre,
          COALESCE(r.avg_rating, 0) as avg_rating,
          CASE
            WHEN pc.status = 'accepted' THEN 'accepted'
            WHEN pc.status = 'pending' AND pc.requested_by = $1 THEN 'outgoing_pending'
            WHEN pc.status = 'pending' THEN 'incoming_pending'
            WHEN pc.status = 'rejected' AND pc.requested_by = $1 THEN 'rejected'
            ELSE NULL
          END as connection_status,
          COALESCE(pc.requested_by = $1, false) as connection_requested_by_me,
          pc.requested_at as connection_requested_at,
          pc.responded_at as connection_responded_at
        FROM app.padel_player_connections pc
        JOIN app.users u
          ON u.id = CASE
            WHEN pc.user_a_id = $1 THEN pc.user_b_id
            ELSE pc.user_a_id
          END
         AND u.deleted_at IS NULL
        LEFT JOIN app.padel_player_profiles pp ON pp.user_id = u.id
        LEFT JOIN ratings r ON r.rated_id = u.id
        WHERE pc.user_a_id = $1 OR pc.user_b_id = $1
        ORDER BY COALESCE(pc.responded_at, pc.requested_at) DESC, u.nombre ASC
      `,
      [userId]
    );

    const companions = [];
    const incomingRequests = [];
    const outgoingRequests = [];

    for (const row of result.rows) {
      const player = buildPlayerRow(row);

      if (row.status === 'accepted') {
        companions.push(player);
        if (row.requested_by === userId) {
          outgoingRequests.push(player);
        }
        continue;
      }

      if (row.status === 'pending') {
        if (row.requested_by === userId) {
          outgoingRequests.push(player);
        } else {
          incomingRequests.push(player);
        }
        continue;
      }

      if (row.status === 'rejected' && row.requested_by === userId) {
        outgoingRequests.push(player);
      }
    }

    res.json({
      companions,
      incoming_requests: incomingRequests,
      outgoing_requests: outgoingRequests,
    });
  } catch (error) {
    console.error('Error obteniendo red de jugadores:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// POST /api/padel/players/:id/network/request - Solicitar jugar
router.post('/:id/network/request', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.userId;
    const targetId = parseInt(req.params.id, 10);

    if (!Number.isInteger(targetId)) {
      return res.status(400).json({ error: 'Jugador inválido' });
    }

    if (userId === targetId) {
      return res.status(400).json({ error: 'No puedes enviarte una solicitud a ti mismo' });
    }

    const userExists = await pool.query(
      'SELECT id FROM app.users WHERE id = $1 AND deleted_at IS NULL',
      [targetId]
    );
    if (userExists.rows.length === 0) {
      return res.status(404).json({ error: 'Jugador no encontrado' });
    }

    const { userAId, userBId } = normalizeConnectionPair(userId, targetId);
    const existingResult = await pool.query(
      `
        SELECT id, status, requested_by
        FROM app.padel_player_connections
        WHERE user_a_id = $1 AND user_b_id = $2
      `,
      [userAId, userBId]
    );

    if (existingResult.rows.length === 0) {
      const inserted = await pool.query(
        `
          INSERT INTO app.padel_player_connections (
            user_a_id,
            user_b_id,
            requested_by,
            status
          )
          VALUES ($1, $2, $3, 'pending')
          RETURNING id
        `,
        [userAId, userBId, userId]
      );

      return res.json({
        request_id: inserted.rows[0].id,
        status: 'outgoing_pending',
        message: 'Solicitud enviada',
      });
    }

    const existing = existingResult.rows[0];

    if (existing.status === 'accepted') {
      return res.json({
        request_id: existing.id,
        status: 'accepted',
        message: 'Ese jugador ya forma parte de tu red',
      });
    }

    if (existing.status === 'pending') {
      if (existing.requested_by === userId) {
        return res.json({
          request_id: existing.id,
          status: 'outgoing_pending',
          message: 'Ya has enviado una solicitud a este jugador',
        });
      }

      return res.json({
        request_id: existing.id,
        status: 'incoming_pending',
        message: 'Ese jugador ya te ha enviado una solicitud. Respóndela en Mi red.',
      });
    }

    const reopened = await pool.query(
      `
        UPDATE app.padel_player_connections
        SET requested_by = $3,
            responded_by = NULL,
            status = 'pending',
            requested_at = NOW(),
            responded_at = NULL,
            updated_at = NOW()
        WHERE user_a_id = $1 AND user_b_id = $2
        RETURNING id
      `,
      [userAId, userBId, userId]
    );

    res.json({
      request_id: reopened.rows[0].id,
      status: 'outgoing_pending',
      message: 'Solicitud enviada de nuevo',
    });
  } catch (error) {
    console.error('Error enviando solicitud de red:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// POST /api/padel/players/:id/network/respond - Aceptar o rechazar solicitud
router.post('/:id/network/respond', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.userId;
    const targetId = parseInt(req.params.id, 10);
    const action = req.body?.action;

    if (!Number.isInteger(targetId)) {
      return res.status(400).json({ error: 'Jugador inválido' });
    }

    if (!['accepted', 'rejected'].includes(action)) {
      return res.status(400).json({ error: 'Acción inválida' });
    }

    const { userAId, userBId } = normalizeConnectionPair(userId, targetId);
    const result = await pool.query(
      `
        UPDATE app.padel_player_connections
        SET status = $3,
            responded_by = $4,
            responded_at = NOW(),
            updated_at = NOW()
        WHERE user_a_id = $1
          AND user_b_id = $2
          AND status = 'pending'
          AND requested_by = $5
        RETURNING id, status
      `,
      [userAId, userBId, action, userId, targetId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        error: 'No se encontró una solicitud pendiente de ese jugador',
      });
    }

    res.json({
      request_id: result.rows[0].id,
      status: action,
      message:
        action === 'accepted'
          ? 'Has aceptado la solicitud'
          : 'Has rechazado la solicitud',
    });
  } catch (error) {
    console.error('Error respondiendo solicitud de red:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// GET /api/padel/players/search - Buscar jugadores
router.get(
  '/search',
  authenticateToken,
  validate(playerSearchQuerySchema, 'query'),
  async (req, res) => {
  try {
    const { name, level, main_level, sub_level, gender, available } =
      req.query;
    const userId = req.user.userId;

    let query = `
      WITH ratings AS (
        SELECT rated_id, AVG(rating) AS avg_rating
        FROM app.padel_player_ratings
        GROUP BY rated_id
      )
      SELECT
        ${basePlayerColumns},
        ${connectionSelectSql(1)}
      FROM app.padel_player_profiles pp
      JOIN app.users u ON pp.user_id = u.id AND u.deleted_at IS NULL
      LEFT JOIN ratings r ON r.rated_id = pp.user_id
      ${connectionJoinSql('pp.user_id', 1)}
      WHERE pp.user_id <> $1
    `;

    const params = [userId];
    let paramIdx = 2;

    if (name) {
      query += ` AND (pp.display_name ILIKE $${paramIdx} OR u.nombre ILIKE $${paramIdx})`;
      params.push(`%${name}%`);
      paramIdx++;
    }

    if (level) {
      query += ` AND pp.numeric_level = $${paramIdx}`;
      params.push(level);
      paramIdx++;
    }

    if (main_level) {
      query += ` AND pp.main_level = $${paramIdx}`;
      params.push(main_level);
      paramIdx++;
    }

    if (sub_level) {
      query += ` AND pp.sub_level = $${paramIdx}`;
      params.push(sub_level);
      paramIdx++;
    }

    if (gender) {
      query += ` AND pp.gender = $${paramIdx}`;
      params.push(gender);
      paramIdx++;
    }

    if (available === 'true') {
      query += ' AND pp.is_available = true';
    }

    query += ' ORDER BY pp.numeric_level DESC, u.nombre ASC LIMIT 50';

    const result = await pool.query(query, params);
    res.json({ players: result.rows.map(buildPlayerRow) });
  } catch (error) {
    console.error('Error buscando jugadores:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// GET /api/padel/players/favorites - Lista de favoritos
router.get('/favorites', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT
        pp.user_id,
        pp.display_name,
        pp.main_level,
        pp.sub_level,
        pp.numeric_level,
        pp.court_preferences,
        pp.dominant_hands,
        pp.availability_preferences,
        pp.match_preferences,
        pp.bio,
        pp.avatar_url,
        pp.matches_played,
        pp.matches_won,
        pp.is_available,
        u.nombre,
        COALESCE((SELECT AVG(rating) FROM app.padel_player_ratings WHERE rated_id = pp.user_id), 0) as avg_rating,
        f.created_at as favorited_at
       FROM app.padel_favorites f
       JOIN app.users u ON f.favorite_id = u.id AND u.deleted_at IS NULL
       LEFT JOIN app.padel_player_profiles pp ON f.favorite_id = pp.user_id
       WHERE f.user_id = $1
       ORDER BY f.created_at DESC`,
      [req.user.userId]
    );

    res.json({ favorites: result.rows });
  } catch (error) {
    console.error('Error obteniendo favoritos:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// GET /api/padel/players/:id - Perfil público
router.get('/:id', authenticateToken, async (req, res) => {
  try {
    const currentUserId = req.user.userId;
    const result = await pool.query(
      `
        SELECT
          ${basePlayerColumns},
          (SELECT COUNT(*) FROM app.padel_player_ratings WHERE rated_id = pp.user_id) as total_ratings,
          ${connectionSelectSql(2)}
        FROM app.padel_player_profiles pp
        JOIN app.users u ON pp.user_id = u.id AND u.deleted_at IS NULL
        LEFT JOIN (
          SELECT rated_id, AVG(rating) AS avg_rating
          FROM app.padel_player_ratings
          GROUP BY rated_id
        ) r ON r.rated_id = pp.user_id
        ${connectionJoinSql('pp.user_id', 2)}
        WHERE pp.user_id = $1
      `,
      [req.params.id, currentUserId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Jugador no encontrado' });
    }

    // Recent ratings
    const ratings = await pool.query(
      `SELECT r.*, u.nombre as rater_name
       FROM app.padel_player_ratings r
       JOIN app.users u ON r.rater_id = u.id
       WHERE r.rated_id = $1
       ORDER BY r.created_at DESC
       LIMIT 10`,
      [req.params.id]
    );

    const ratingContexts = Number(currentUserId) === Number(req.params.id)
      ? []
      : await loadRatingContextsForPlayer(pool, {
        raterId: currentUserId,
        ratedId: parseInt(req.params.id, 10),
      });

    res.json({
      player: buildPlayerRow(result.rows[0]),
      ratings: ratings.rows,
      rating_contexts: ratingContexts,
    });
  } catch (error) {
    console.error('Error obteniendo jugador:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// POST /api/padel/players/:id/rate - Valorar jugador
router.post('/:id/rate', authenticateToken, async (req, res) => {
  const client = await pool.connect();
  try {
    const {
      rating,
      comment,
      match_id,
      plan_id,
      community_plan_id,
    } = req.body;
    const raterId = req.user.userId;
    const ratedId = parseInt(req.params.id, 10);
    const matchId = parseOptionalInt(match_id);
    const planId = parseOptionalInt(plan_id ?? community_plan_id);

    if (raterId === ratedId) {
      return res.status(400).json({ error: 'No puedes valorarte a ti mismo' });
    }

    if (planId !== null && matchId !== null) {
      return res.status(400).json({
        error: 'Indica solo un contexto de valoración: plan_id o match_id.',
      });
    }

    if (!rating || rating < 1 || rating > 5) {
      return res.status(400).json({ error: 'La valoración debe ser entre 1 y 5' });
    }

    const ratedExists = await client.query(
      'SELECT id FROM app.users WHERE id = $1 AND deleted_at IS NULL',
      [ratedId]
    );
    if (ratedExists.rows.length === 0) {
      return res.status(404).json({ error: 'Jugador no encontrado' });
    }

    const trimmedComment =
      typeof comment === 'string' && comment.trim().length > 0
        ? comment.trim()
        : null;

    if (planId !== null || matchId === null) {
      const { plan, error } = await resolveCommunityPlanForRating(client, {
        raterId,
        ratedId,
        planId,
        requireUnrated: planId === null && matchId === null,
      });

      if (plan) {
        const existingRating = await client.query(
          `
            SELECT id
            FROM app.padel_player_ratings
            WHERE rater_id = $1
              AND rated_id = $2
              AND community_plan_id = $3
            LIMIT 1
          `,
          [raterId, ratedId, plan.id],
        );

        const ratingResult = existingRating.rows.length > 0
          ? await client.query(
            `
              UPDATE app.padel_player_ratings
              SET rating = $2,
                  comment = $3
              WHERE id = $1
              RETURNING *
            `,
            [existingRating.rows[0].id, rating, trimmedComment],
          )
          : await client.query(
            `
              INSERT INTO app.padel_player_ratings (
                rater_id,
                rated_id,
                community_plan_id,
                rating,
                comment
              )
              VALUES ($1, $2, $3, $4, $5)
              RETURNING *
            `,
            [raterId, ratedId, plan.id, rating, trimmedComment],
          );

        return res.json({ rating: ratingResult.rows[0] });
      }

      if (planId !== null || matchId === null) {
        switch (error) {
          case 'plan_not_finished':
            return res.status(400).json({
              error: 'Solo puedes valorar este plan cuando haya terminado.',
            });
          case 'result_not_resolved':
          case 'result_missing':
            return res.status(400).json({
              error: 'Antes de valorar debes haber enviado el resultado del partido o esperar a que quede consensuado.',
            });
          case 'already_rated':
            return res.status(409).json({
              error: 'Ya has valorado a este jugador en tus planes cerrados. Indica plan_id para editar una valoración concreta.',
            });
          case 'no_shared_plan':
          default:
            if (planId !== null) {
              return res.status(403).json({
                error: 'Solo puedes valorar a jugadores de un plan confirmado en el que ambos hayáis jugado.',
              });
            }
            return res.status(400).json({
              error: 'Solo puedes valorar a jugadores con los que hayas jugado un plan confirmado y con resultado cerrado.',
            });
        }
      }
    }

    if (matchId === null) {
      return res.status(400).json({
        error: 'Debes indicar plan_id o match_id para registrar la valoración.',
      });
    }

    const match = await loadLegacyMatchForRating(client, {
      raterId,
      ratedId,
      matchId,
    });

    if (!match) {
      return res.status(403).json({
        error: 'Solo puedes valorar jugadores que hayan compartido partido contigo.',
      });
    }

    if (!hasLegacyMatchFinished(match)) {
      return res.status(400).json({
        error: 'Solo puedes valorar este partido cuando haya terminado.',
      });
    }

    const result = await client.query(
      `INSERT INTO app.padel_player_ratings (rater_id, rated_id, match_id, rating, comment)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (rater_id, rated_id, match_id)
       DO UPDATE SET rating = $4, comment = $5
       RETURNING *`,
      [raterId, ratedId, matchId, rating, trimmedComment]
    );

    res.json({ rating: result.rows[0] });
  } catch (error) {
    console.error('Error valorando jugador:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  } finally {
    client.release();
  }
});

// POST /api/padel/players/:id/favorite - Toggle favorito
router.post('/:id/favorite', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.userId;
    const favoriteId = parseInt(req.params.id);

    if (userId === favoriteId) {
      return res.status(400).json({ error: 'No puedes añadirte como favorito' });
    }

    const favoriteExists = await pool.query(
      'SELECT id FROM app.users WHERE id = $1 AND deleted_at IS NULL',
      [favoriteId]
    );
    if (favoriteExists.rows.length === 0) {
      return res.status(404).json({ error: 'Jugador no encontrado' });
    }

    // Check if already favorited
    const existing = await pool.query(
      'SELECT id FROM app.padel_favorites WHERE user_id = $1 AND favorite_id = $2',
      [userId, favoriteId]
    );

    if (existing.rows.length > 0) {
      await pool.query('DELETE FROM app.padel_favorites WHERE user_id = $1 AND favorite_id = $2', [userId, favoriteId]);
      res.json({ favorited: false, message: 'Eliminado de favoritos' });
    } else {
      await pool.query(
        'INSERT INTO app.padel_favorites (user_id, favorite_id) VALUES ($1, $2)',
        [userId, favoriteId]
      );
      res.json({ favorited: true, message: 'Añadido a favoritos' });
    }
  } catch (error) {
    console.error('Error toggle favorito:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

export default router;
