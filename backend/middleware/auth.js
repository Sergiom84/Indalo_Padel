import jwt from 'jsonwebtoken';
import { pool } from '../db.js';

const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Token de acceso requerido' });
  }

  jwt.verify(token, process.env.JWT_SECRET, async (err, decoded) => {
    if (err) {
      return res.status(403).json({ error: 'Token inválido' });
    }

    const userId = decoded?.userId ?? decoded?.id;
    if (!userId) {
      return res.status(403).json({ error: 'Token inválido' });
    }

    try {
      const result = await pool.query(
        `SELECT id
         FROM app.users
         WHERE id = $1
           AND deleted_at IS NULL`,
        [userId]
      );

      if (result.rows.length === 0) {
        return res.status(401).json({ error: 'Usuario no disponible' });
      }

      req.user = {
        ...decoded,
        id: userId,
        userId,
      };

      next();
    } catch (error) {
      console.error('Error validando sesión:', error);
      return res.status(500).json({ error: 'No se pudo validar la sesión' });
    }
  });
};

export default authenticateToken;
export { authenticateToken };
