import express from 'express';
import bcrypt from 'bcryptjs';
import { pool } from '../db.js';
import { authenticateToken } from '../middleware/auth.js';
import { validate } from '../middleware/validate.js';
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
        `SELECT id
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
             deleted_reason = $1,
             deleted_reason_other = CASE
               WHEN $1 = 'otros' THEN NULLIF($2, '')
               ELSE NULL
             END,
             deleted_email = email,
             email = $3,
             password_hash = $4,
             updated_at = NOW()
         WHERE id = $5`,
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
          pp.avatar_url,
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

    res.json({
      player: buildPlayerRow(result.rows[0]),
      ratings: ratings.rows
    });
  } catch (error) {
    console.error('Error obteniendo jugador:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// POST /api/padel/players/:id/rate - Valorar jugador
router.post('/:id/rate', authenticateToken, async (req, res) => {
  try {
    const { rating, comment, match_id } = req.body;
    const raterId = req.user.userId;
    const ratedId = parseInt(req.params.id);

    if (raterId === ratedId) {
      return res.status(400).json({ error: 'No puedes valorarte a ti mismo' });
    }

    if (!rating || rating < 1 || rating > 5) {
      return res.status(400).json({ error: 'La valoración debe ser entre 1 y 5' });
    }

    const ratedExists = await pool.query(
      'SELECT id FROM app.users WHERE id = $1 AND deleted_at IS NULL',
      [ratedId]
    );
    if (ratedExists.rows.length === 0) {
      return res.status(404).json({ error: 'Jugador no encontrado' });
    }

    const result = await pool.query(
      `INSERT INTO app.padel_player_ratings (rater_id, rated_id, match_id, rating, comment)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (rater_id, rated_id, match_id)
       DO UPDATE SET rating = $4, comment = $5
       RETURNING *`,
      [raterId, ratedId, match_id || null, rating, comment]
    );

    res.json({ rating: result.rows[0] });
  } catch (error) {
    console.error('Error valorando jugador:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
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
