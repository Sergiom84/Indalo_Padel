import express from 'express';
import { authenticateToken } from '../middleware/auth.js';
import { upsertFcmToken, deleteFcmToken } from '../services/pushNotificationService.js';

const router = express.Router();

// POST /api/padel/notifications/fcm-token  — registra o renueva el token del dispositivo
router.post('/fcm-token', authenticateToken, async (req, res) => {
  try {
    const { token, platform } = req.body;
    if (!token || typeof token !== 'string') {
      return res.status(400).json({ error: 'token requerido' });
    }
    await upsertFcmToken({
      userId: req.user.userId,
      token,
      platform: platform || 'android',
    });
    res.json({ ok: true });
  } catch (error) {
    console.error('Error registrando FCM token:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// DELETE /api/padel/notifications/fcm-token  — elimina el token al cerrar sesión
router.delete('/fcm-token', authenticateToken, async (req, res) => {
  try {
    const { token } = req.body;
    if (!token) return res.status(400).json({ error: 'token requerido' });
    await deleteFcmToken({ userId: req.user.userId, token });
    res.json({ ok: true });
  } catch (error) {
    console.error('Error eliminando FCM token:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

export default router;
