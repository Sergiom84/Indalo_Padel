import express from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { pool } from '../db.js';
import { authenticateToken } from '../middleware/auth.js';
import { validate } from '../middleware/validate.js';
import { registerSchema, loginSchema } from '../validators/authValidators.js';

const router = express.Router();

// POST /api/padel/auth/register
router.post('/register', validate(registerSchema), async (req, res) => {
  try {
    const {
      nombre,
      email,
      password,
      main_level,
      sub_level,
      court_preferences,
      dominant_hands,
      availability_preferences,
      match_preferences,
    } = req.body;

    const existing = await pool.query('SELECT id FROM app.users WHERE email = $1', [email]);
    if (existing.rows.length > 0) {
      return res.status(400).json({ error: 'Ya existe un usuario con este email' });
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    const userResult = await pool.query(
      `INSERT INTO app.users (nombre, email, password_hash)
       VALUES ($1, $2, $3)
       RETURNING id, nombre, email, created_at`,
      [nombre, email, hashedPassword]
    );

    const user = userResult.rows[0];

    // Create player profile
    await pool.query(
      `INSERT INTO app.padel_player_profiles (
         user_id,
         display_name,
         main_level,
         sub_level,
         court_preferences,
         dominant_hands,
         availability_preferences,
         match_preferences
       )
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
      [
        user.id,
        nombre,
        main_level || 'bajo',
        sub_level || 'bajo',
        court_preferences || [],
        dominant_hands || [],
        availability_preferences || [],
        match_preferences || [],
      ]
    );

    const token = jwt.sign(
      { userId: user.id, email: user.email },
      process.env.JWT_SECRET,
      { expiresIn: '7d' }
    );

    res.status(201).json({
      message: 'Usuario registrado exitosamente',
      user: { id: user.id, nombre: user.nombre, email: user.email },
      token
    });
  } catch (error) {
    console.error('Error en registro:', error);
    res.status(500).json({
      error: 'Error interno del servidor',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

// POST /api/padel/auth/login
router.post('/login', validate(loginSchema), async (req, res) => {
  try {
    const { email, password } = req.body;

    const result = await pool.query(
      'SELECT id, nombre, email, password_hash FROM app.users WHERE email = $1',
      [email]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Credenciales incorrectas' });
    }

    const user = result.rows[0];
    const isValid = await bcrypt.compare(password, user.password_hash);

    if (!isValid) {
      return res.status(401).json({ error: 'Credenciales incorrectas' });
    }

    const token = jwt.sign(
      { userId: user.id, email: user.email },
      process.env.JWT_SECRET,
      { expiresIn: '7d' }
    );

    res.json({
      message: 'Login exitoso',
      user: { id: user.id, nombre: user.nombre, email: user.email },
      token
    });
  } catch (error) {
    console.error('Error en login:', error);
    res.status(500).json({
      error: 'Error interno del servidor',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

// GET /api/padel/auth/verify
router.get('/verify', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id, nombre, email FROM app.users WHERE id = $1',
      [req.user.userId]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Usuario no encontrado' });
    }

    res.json({ user: result.rows[0] });
  } catch (error) {
    console.error('Error verificando token:', error);
    res.status(401).json({ error: 'Token inválido' });
  }
});

export default router;
