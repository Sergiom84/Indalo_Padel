import jwt from 'jsonwebtoken';

import { pool } from '../db.js';
import {
  getSupabaseUser,
  resolveAppUserFromSupabaseUser,
  SupabaseAuthError,
} from './supabaseAuthService.js';

export class AuthTokenError extends Error {
  constructor(message, status = 401, code = 'INVALID_TOKEN') {
    super(message);
    this.name = 'AuthTokenError';
    this.status = status;
    this.code = code;
  }
}

async function resolveLegacyUser(decoded) {
  const userId = Number(decoded?.userId ?? decoded?.id);
  if (!Number.isInteger(userId) || userId <= 0) {
    throw new AuthTokenError('Token inválido', 401, 'INVALID_TOKEN');
  }

  const result = await pool.query(
    `SELECT id, email, nombre
     FROM app.users
     WHERE id = $1
       AND deleted_at IS NULL
     LIMIT 1`,
    [userId],
  );

  if (result.rows.length === 0) {
    throw new AuthTokenError('Usuario no encontrado', 401, 'USER_NOT_FOUND');
  }

  const user = result.rows[0];
  return {
    ...decoded,
    id: user.id,
    userId: user.id,
    email: user.email,
    nombre: user.nombre,
    authProvider: 'legacy',
  };
}

async function resolveSupabaseToken(token) {
  try {
    const supabaseUser = await getSupabaseUser(token);
    const appUser = await resolveAppUserFromSupabaseUser(supabaseUser);

    if (!appUser) {
      throw new AuthTokenError('Usuario no encontrado', 401, 'USER_NOT_FOUND');
    }

    return {
      id: appUser.id,
      userId: appUser.id,
      email: appUser.email,
      nombre: appUser.nombre,
      authUserId: appUser.auth_user_id,
      authProvider: 'supabase',
    };
  } catch (error) {
    if (error instanceof AuthTokenError) {
      throw error;
    }

    if (error instanceof SupabaseAuthError && error.status === 401) {
      throw new AuthTokenError('Token inválido', 401, 'INVALID_TOKEN');
    }

    throw error;
  }
}

export async function authenticateAccessToken(token) {
  if (!token) {
    throw new AuthTokenError(
      'Token de acceso requerido',
      401,
      'TOKEN_REQUIRED',
    );
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    return resolveLegacyUser(decoded);
  } catch (legacyError) {
    try {
      return await resolveSupabaseToken(token);
    } catch (supabaseError) {
      if (supabaseError instanceof AuthTokenError) {
        throw supabaseError;
      }

      if (legacyError.name === 'TokenExpiredError') {
        throw new AuthTokenError('Token expirado', 401, 'TOKEN_EXPIRED');
      }

      if (supabaseError instanceof SupabaseAuthError && supabaseError.status >= 500) {
        throw supabaseError;
      }

      throw new AuthTokenError('Token inválido', 401, 'INVALID_TOKEN');
    }
  }
}
