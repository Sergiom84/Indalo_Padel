import express from 'express';
import { pool } from '../db.js';
import { authenticateToken } from '../middleware/auth.js';

const router = express.Router();

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
router.put('/profile', authenticateToken, async (req, res) => {
  try {
    const { display_name, main_level, sub_level, preferred_side, preferred_venue_id, bio, avatar_url, is_available } = req.body;

    const result = await pool.query(
      `UPDATE app.padel_player_profiles
       SET display_name = COALESCE($1, display_name),
           main_level = COALESCE($2, main_level),
           sub_level = COALESCE($3, sub_level),
           preferred_side = COALESCE($4, preferred_side),
           preferred_venue_id = COALESCE($5, preferred_venue_id),
           bio = COALESCE($6, bio),
           avatar_url = COALESCE($7, avatar_url),
           is_available = COALESCE($8, is_available),
           updated_at = NOW()
       WHERE user_id = $9
       RETURNING *`,
      [display_name, main_level, sub_level, preferred_side, preferred_venue_id, bio, avatar_url, is_available, req.user.userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Perfil no encontrado' });
    }

    res.json({ profile: result.rows[0] });
  } catch (error) {
    console.error('Error actualizando perfil:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// GET /api/padel/players/search - Buscar jugadores
router.get('/search', async (req, res) => {
  try {
    const { name, level, available } = req.query;

    let query = `
      SELECT pp.*, u.nombre, u.email,
        COALESCE((SELECT AVG(rating) FROM app.padel_player_ratings WHERE rated_id = pp.user_id), 0) as avg_rating
      FROM app.padel_player_profiles pp
      JOIN app.users u ON pp.user_id = u.id
      WHERE 1=1
    `;

    const params = [];
    let paramIdx = 1;

    if (name) {
      query += ` AND (pp.display_name ILIKE $${paramIdx} OR u.nombre ILIKE $${paramIdx})`;
      params.push(`%${name}%`);
      paramIdx++;
    }

    if (level) {
      query += ` AND pp.numeric_level = $${paramIdx}`;
      params.push(parseInt(level));
      paramIdx++;
    }

    if (available === 'true') {
      query += ' AND pp.is_available = true';
    }

    query += ' ORDER BY pp.numeric_level DESC, u.nombre ASC LIMIT 50';

    const result = await pool.query(query, params);
    res.json({ players: result.rows });
  } catch (error) {
    console.error('Error buscando jugadores:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// GET /api/padel/players/favorites - Lista de favoritos
router.get('/favorites', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT pp.*, u.nombre, u.email,
        COALESCE((SELECT AVG(rating) FROM app.padel_player_ratings WHERE rated_id = pp.user_id), 0) as avg_rating,
        f.created_at as favorited_at
       FROM app.padel_favorites f
       JOIN app.users u ON f.favorite_id = u.id
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
router.get('/:id', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT pp.*, u.nombre,
        COALESCE((SELECT AVG(rating) FROM app.padel_player_ratings WHERE rated_id = pp.user_id), 0) as avg_rating,
        (SELECT COUNT(*) FROM app.padel_player_ratings WHERE rated_id = pp.user_id) as total_ratings
       FROM app.padel_player_profiles pp
       JOIN app.users u ON pp.user_id = u.id
       WHERE pp.user_id = $1`,
      [req.params.id]
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
      player: result.rows[0],
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
