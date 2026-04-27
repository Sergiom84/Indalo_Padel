import express from 'express';

import { authenticateToken } from '../middleware/auth.js';
import { validate } from '../middleware/validate.js';
import {
  createPadelGroupConversation,
  createPadelSocialEvent,
  deletePadelChatMessages,
  getOrCreatePadelDirectConversation,
  getOrCreatePadelEventConversation,
  getOrCreatePadelSocialEventConversation,
  getPadelChatConversation,
  getPadelChatUnreadCount,
  listPadelSocialEvents,
  listPadelChatConversations,
  listPadelChatMessages,
  markPadelChatConversationRead,
  sendPadelChatMessage,
} from '../services/padelChatService.js';
import {
  conversationParamsSchema,
  createGroupConversationSchema,
  createSocialEventSchema,
  deleteChatMessagesSchema,
  directConversationParamsSchema,
  eventConversationParamsSchema,
  listConversationMessagesQuerySchema,
  markConversationReadSchema,
  sendChatMessageSchema,
  socialEventParamsSchema,
} from '../validators/chatValidators.js';

const router = express.Router();

router.get('/conversations', authenticateToken, async (req, res) => {
  try {
    const result = await listPadelChatConversations(req.user.userId);
    res.status(result.status).json(result.body);
  } catch (error) {
    console.error('Error listando conversaciones de chat:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

router.get('/unread-count', authenticateToken, async (req, res) => {
  try {
    const result = await getPadelChatUnreadCount(req.user.userId);
    res.status(result.status).json(result.body);
  } catch (error) {
    console.error('Error obteniendo contador de chat:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

router.get('/social-events', authenticateToken, async (req, res) => {
  try {
    const result = await listPadelSocialEvents(req.user.userId);
    res.status(result.status).json(result.body);
  } catch (error) {
    console.error('Error listando eventos sociales:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

router.post(
  '/direct/:userId',
  authenticateToken,
  validate(directConversationParamsSchema, 'params'),
  async (req, res) => {
    try {
      const result = await getOrCreatePadelDirectConversation({
        userId: req.user.userId,
        otherUserId: req.params.userId,
      });
      res.status(result.status).json(result.body);
    } catch (error) {
      console.error('Error abriendo chat directo:', error);
      res.status(500).json({ error: 'Error interno del servidor' });
    }
  },
);

router.post(
  '/groups',
  authenticateToken,
  validate(createGroupConversationSchema),
  async (req, res) => {
    try {
      const result = await createPadelGroupConversation({
        userId: req.user.userId,
        title: req.body.title,
        participantUserIds: req.body.participant_user_ids,
      });
      res.status(result.status).json(result.body);
    } catch (error) {
      console.error('Error creando grupo de chat:', error);
      res.status(500).json({ error: 'Error interno del servidor' });
    }
  },
);

router.post(
  '/social-events',
  authenticateToken,
  validate(createSocialEventSchema),
  async (req, res) => {
    try {
      const result = await createPadelSocialEvent({
        userId: req.user.userId,
        title: req.body.title,
        description: req.body.description,
        venueName: req.body.venue_name,
        location: req.body.location,
        scheduledDate: req.body.scheduled_date,
        scheduledTime: req.body.scheduled_time,
        durationMinutes: req.body.duration_minutes,
      });
      res.status(result.status).json(result.body);
    } catch (error) {
      console.error('Error creando evento social:', error);
      res.status(500).json({ error: 'Error interno del servidor' });
    }
  },
);

router.post(
  '/social-events/:eventId/join',
  authenticateToken,
  validate(socialEventParamsSchema, 'params'),
  async (req, res) => {
    try {
      const result = await getOrCreatePadelSocialEventConversation({
        userId: req.user.userId,
        eventId: req.params.eventId,
      });
      res.status(result.status).json(result.body);
    } catch (error) {
      console.error('Error abriendo chat de evento social:', error);
      res.status(500).json({ error: 'Error interno del servidor' });
    }
  },
);

router.post(
  '/events/:planId',
  authenticateToken,
  validate(eventConversationParamsSchema, 'params'),
  async (req, res) => {
    try {
      const result = await getOrCreatePadelEventConversation({
        userId: req.user.userId,
        planId: req.params.planId,
      });
      res.status(result.status).json(result.body);
    } catch (error) {
      console.error('Error abriendo chat de evento:', error);
      res.status(500).json({ error: 'Error interno del servidor' });
    }
  },
);

router.get(
  '/conversations/:id',
  authenticateToken,
  validate(conversationParamsSchema, 'params'),
  async (req, res) => {
    try {
      const result = await getPadelChatConversation({
        userId: req.user.userId,
        conversationId: req.params.id,
      });
      res.status(result.status).json(result.body);
    } catch (error) {
      console.error('Error obteniendo conversación de chat:', error);
      res.status(500).json({ error: 'Error interno del servidor' });
    }
  },
);

router.get(
  '/conversations/:id/messages',
  authenticateToken,
  validate(conversationParamsSchema, 'params'),
  validate(listConversationMessagesQuerySchema, 'query'),
  async (req, res) => {
    try {
      const result = await listPadelChatMessages({
        userId: req.user.userId,
        conversationId: req.params.id,
        beforeMessageId: req.query.before_message_id ?? null,
        limit: req.query.limit ?? undefined,
      });
      res.status(result.status).json(result.body);
    } catch (error) {
      console.error('Error obteniendo mensajes de chat:', error);
      res.status(500).json({ error: 'Error interno del servidor' });
    }
  },
);

router.post(
  '/conversations/:id/messages',
  authenticateToken,
  validate(conversationParamsSchema, 'params'),
  validate(sendChatMessageSchema),
  async (req, res) => {
    try {
      const result = await sendPadelChatMessage({
        userId: req.user.userId,
        conversationId: req.params.id,
        body: req.body.body,
      });
      res.status(result.status).json(result.body);
    } catch (error) {
      console.error('Error enviando mensaje de chat:', error);
      res.status(500).json({ error: 'Error interno del servidor' });
    }
  },
);

router.delete(
  '/conversations/:id/messages',
  authenticateToken,
  validate(conversationParamsSchema, 'params'),
  validate(deleteChatMessagesSchema),
  async (req, res) => {
    try {
      const result = await deletePadelChatMessages({
        userId: req.user.userId,
        conversationId: req.params.id,
        messageIds: req.body.message_ids,
      });
      res.status(result.status).json(result.body);
    } catch (error) {
      console.error('Error eliminando mensajes de chat:', error);
      res.status(500).json({ error: 'Error interno del servidor' });
    }
  },
);

router.post(
  '/conversations/:id/read',
  authenticateToken,
  validate(conversationParamsSchema, 'params'),
  validate(markConversationReadSchema),
  async (req, res) => {
    try {
      const result = await markPadelChatConversationRead({
        userId: req.user.userId,
        conversationId: req.params.id,
        messageId: req.body.message_id ?? null,
      });
      res.status(result.status).json(result.body);
    } catch (error) {
      console.error('Error actualizando lectura de chat:', error);
      res.status(500).json({ error: 'Error interno del servidor' });
    }
  },
);

export default router;
