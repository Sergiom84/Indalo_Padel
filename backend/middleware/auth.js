import {
  authenticateAccessToken,
  AuthTokenError,
} from '../services/tokenAuthService.js';

const authenticateToken = async (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  try {
    req.user = await authenticateAccessToken(token);
    return next();
  } catch (error) {
    if (error instanceof AuthTokenError) {
      return res.status(error.status).json({
        error: error.message,
        code: error.code,
      });
    }

    console.error('Error autenticando token:', error);
    return res.status(503).json({
      error: 'No se pudo validar la sesión',
      code: 'AUTH_UNAVAILABLE',
    });
  }
};

export default authenticateToken;
export { authenticateToken };
