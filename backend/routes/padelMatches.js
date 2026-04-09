import express from 'express';
import { pool } from '../db.js';
import { authenticateToken } from '../middleware/auth.js';
import { validate } from '../middleware/validate.js';
import { createMatchSchema, matchQuerySchema } from '../validators/matchValidators.js';

const router = express.Router();

// GET /api/padel/matches - Partidos abiertos
router.get('/', validate(matchQuerySchema, 'query'), async (req, res) => {
  try {
    const { level, date, venue_id } = req.query;

    let query = `
      SELECT m.*,
        m.current_players as player_count,
        v.name as venue_name, v.location as venue_location,
        u.nombre as creator_name,
        (SELECT json_agg(json_build_object(
          'user_id', mp.user_id,
          'team', mp.team,
          'nombre', pu.nombre,
          'display_name', pp.display_name,
          'numeric_level', pp.numeric_level
        ))
        FROM app.padel_match_players mp
        JOIN app.users pu ON mp.user_id = pu.id
        LEFT JOIN app.padel_player_profiles pp ON mp.user_id = pp.user_id
        WHERE mp.match_id = m.id) as players
      FROM app.padel_matches m
      LEFT JOIN app.padel_venues v ON m.venue_id = v.id
      JOIN app.users u ON m.created_by = u.id
      WHERE m.status IN ('buscando', 'completo')
    `;

    const params = [];
    let paramIdx = 1;

    if (level) {
      query += ` AND m.min_level <= $${paramIdx} AND m.max_level >= $${paramIdx}`;
      params.push(parseInt(level));
      paramIdx++;
    }

    if (date) {
      query += ` AND m.match_date = $${paramIdx}`;
      params.push(date);
      paramIdx++;
    }

    if (venue_id) {
      query += ` AND m.venue_id = $${paramIdx}`;
      params.push(parseInt(venue_id));
      paramIdx++;
    }

    query += ' ORDER BY m.match_date ASC, m.start_time ASC';

    const result = await pool.query(query, params);
    res.json({ matches: result.rows });
  } catch (error) {
    console.error('Error listando partidos:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// POST /api/padel/matches - Crear partido
router.post('/', authenticateToken, validate(createMatchSchema), async (req, res) => {
  try {
    const { booking_id, match_type, min_level, max_level, match_date, start_time, venue_id, description } = req.body;
    const userId = req.user.userId;

    const matchResult = await pool.query(
      `INSERT INTO app.padel_matches (booking_id, created_by, match_type, min_level, max_level, match_date, start_time, venue_id, description)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
       RETURNING *`,
      [booking_id, userId, match_type || 'abierto', min_level || 1, max_level || 9, match_date, start_time, venue_id, description]
    );

    const match = matchResult.rows[0];

    // Add creator as first player
    await pool.query(
      `INSERT INTO app.padel_match_players (match_id, user_id, team, status)
       VALUES ($1, $2, 1, 'confirmado')`,
      [match.id, userId]
    );

    res.status(201).json({ match });
  } catch (error) {
    console.error('Error creando partido:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// GET /api/padel/matches/:id - Detalle de partido
router.get('/:id', async (req, res) => {
  try {
    const matchResult = await pool.query(
      `SELECT m.*,
        m.current_players as player_count,
        v.name as venue_name, v.location as venue_location,
        u.nombre as creator_name
       FROM app.padel_matches m
       LEFT JOIN app.padel_venues v ON m.venue_id = v.id
       JOIN app.users u ON m.created_by = u.id
       WHERE m.id = $1`,
      [req.params.id]
    );

    if (matchResult.rows.length === 0) {
      return res.status(404).json({ error: 'Partido no encontrado' });
    }

    const playersResult = await pool.query(
      `SELECT mp.*, u.nombre, pp.display_name, pp.main_level, pp.sub_level, pp.numeric_level, pp.preferred_side
       FROM app.padel_match_players mp
       JOIN app.users u ON mp.user_id = u.id
       LEFT JOIN app.padel_player_profiles pp ON mp.user_id = pp.user_id
       WHERE mp.match_id = $1
       ORDER BY mp.team, mp.joined_at`,
      [req.params.id]
    );

    res.json({
      match: matchResult.rows[0],
      players: playersResult.rows
    });
  } catch (error) {
    console.error('Error obteniendo partido:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// POST /api/padel/matches/:id/join - Unirse a partido
router.post('/:id/join', authenticateToken, async (req, res) => {
  try {
    const matchId = req.params.id;
    const userId = req.user.userId;
    const { team } = req.body;

    const match = await pool.query(
      'SELECT * FROM app.padel_matches WHERE id = $1',
      [matchId]
    );

    if (match.rows.length === 0) {
      return res.status(404).json({ error: 'Partido no encontrado' });
    }

    if (match.rows[0].status !== 'buscando') {
      return res.status(400).json({ error: 'El partido ya no acepta jugadores' });
    }

    if (match.rows[0].current_players >= match.rows[0].max_players) {
      return res.status(400).json({ error: 'El partido está completo' });
    }

    // Check player level
    const profile = await pool.query(
      'SELECT numeric_level FROM app.padel_player_profiles WHERE user_id = $1',
      [userId]
    );

    if (profile.rows.length > 0) {
      const level = profile.rows[0].numeric_level;
      if (level < match.rows[0].min_level || level > match.rows[0].max_level) {
        return res.status(400).json({ error: 'Tu nivel no es compatible con este partido' });
      }
    }

    await pool.query(
      `INSERT INTO app.padel_match_players (match_id, user_id, team, status)
       VALUES ($1, $2, $3, 'confirmado')`,
      [matchId, userId, team || null]
    );

    const newCount = match.rows[0].current_players + 1;
    const newStatus = newCount >= match.rows[0].max_players ? 'completo' : 'buscando';

    await pool.query(
      'UPDATE app.padel_matches SET current_players = $1, status = $2, updated_at = NOW() WHERE id = $3',
      [newCount, newStatus, matchId]
    );

    res.json({ message: 'Te has unido al partido', current_players: newCount, status: newStatus });
  } catch (error) {
    console.error('Error uniéndose al partido:', error);
    if (error.code === '23505') {
      return res.status(409).json({ error: 'Ya estás en este partido' });
    }
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// POST /api/padel/matches/:id/leave - Salir de partido
router.post('/:id/leave', authenticateToken, async (req, res) => {
  try {
    const matchId = req.params.id;
    const userId = req.user.userId;

    const match = await pool.query('SELECT * FROM app.padel_matches WHERE id = $1', [matchId]);
    if (match.rows.length === 0) {
      return res.status(404).json({ error: 'Partido no encontrado' });
    }

    if (match.rows[0].created_by === userId) {
      return res.status(400).json({ error: 'El creador no puede abandonar el partido' });
    }

    const deleted = await pool.query(
      'DELETE FROM app.padel_match_players WHERE match_id = $1 AND user_id = $2 RETURNING *',
      [matchId, userId]
    );

    if (deleted.rows.length === 0) {
      return res.status(404).json({ error: 'No estás en este partido' });
    }

    const newCount = Math.max(0, match.rows[0].current_players - 1);
    await pool.query(
      `UPDATE app.padel_matches SET current_players = $1, status = 'buscando', updated_at = NOW() WHERE id = $2`,
      [newCount, matchId]
    );

    res.json({ message: 'Has abandonado el partido' });
  } catch (error) {
    console.error('Error saliendo del partido:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// PUT /api/padel/matches/:id/status - Cambiar estado
router.put('/:id/status', authenticateToken, async (req, res) => {
  try {
    const { status } = req.body;

    const result = await pool.query(
      `UPDATE app.padel_matches SET status = $1, updated_at = NOW()
       WHERE id = $2 AND created_by = $3
       RETURNING *`,
      [status, req.params.id, req.user.userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Partido no encontrado o no tienes permisos' });
    }

    res.json({ match: result.rows[0] });
  } catch (error) {
    console.error('Error actualizando estado:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

export default router;
