import { pool } from '../db.js';

/**
 * Middleware que verifica que el usuario autenticado tiene el rol requerido.
 * Debe usarse DESPUÉS de authenticateToken.
 *
 * @param  {...string} roles - Roles permitidos (ej: 'admin', 'user')
 */
const requireRole = (...roles) => {
  return async (req, res, next) => {
    try {
      const userId = req.user?.id;
      if (!userId) {
        return res.status(401).json({ error: 'Usuario no autenticado' });
      }

      const result = await pool.query(
        'SELECT role FROM app.users WHERE id = $1',
        [userId]
      );

      if (result.rows.length === 0) {
        return res.status(404).json({ error: 'Usuario no encontrado' });
      }

      const userRole = result.rows[0].role;
      if (!roles.includes(userRole)) {
        return res.status(403).json({ error: 'No tienes permisos para realizar esta acción' });
      }

      req.user.role = userRole;
      next();
    } catch (error) {
      console.error('Error verificando rol:', error);
      res.status(500).json({ error: 'Error interno del servidor' });
    }
  };
};

export default requireRole;
export { requireRole };
