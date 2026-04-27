import jwt from 'jsonwebtoken';
import { Server } from 'socket.io';

import { pool } from '../db.js';

let ioInstance = null;

function userRoom(userId) {
  return `chat:user:${Number(userId)}`;
}

function conversationRoom(conversationId) {
  return `chat:conversation:${Number(conversationId)}`;
}

function stripBearerToken(value) {
  if (typeof value !== 'string') {
    return null;
  }

  return value.replace(/^Bearer\s+/i, '').trim() || null;
}

function extractSocketToken(socket) {
  return (
    stripBearerToken(socket.handshake?.auth?.token) ||
    stripBearerToken(socket.handshake?.headers?.authorization)
  );
}

function ackSuccess(ack, payload = {}) {
  if (typeof ack === 'function') {
    ack({ ok: true, ...payload });
  }
}

function ackError(ack, error) {
  if (typeof ack === 'function') {
    ack({ ok: false, error });
  }
}

async function authenticateSocket(socket, next) {
  const token = extractSocketToken(socket);

  if (!token) {
    next(new Error('Token de acceso requerido'));
    return;
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const userId = Number(decoded?.userId ?? decoded?.id);

    if (!Number.isInteger(userId) || userId <= 0) {
      next(new Error('Token inválido'));
      return;
    }

    const result = await pool.query(
      `SELECT id
       FROM app.users
       WHERE id = $1
         AND deleted_at IS NULL
       LIMIT 1`,
      [userId],
    );

    if (result.rows.length === 0) {
      next(new Error('Usuario no encontrado'));
      return;
    }

    socket.data.userId = userId;
    next();
  } catch (_error) {
    next(new Error('Token inválido'));
  }
}

export function attachPadelChatSocket(httpServer, { isAllowedOrigin }) {
  if (ioInstance) {
    return ioInstance;
  }

  ioInstance = new Server(httpServer, {
    cors: {
      origin(origin, callback) {
        if (!isAllowedOrigin || isAllowedOrigin(origin)) {
          callback(null, true);
          return;
        }

        callback(new Error(`Origen no permitido por CORS: ${origin}`));
      },
      credentials: true,
    },
  });

  ioInstance.use(authenticateSocket);

  ioInstance.on('connection', (socket) => {
    const userId = Number(socket.data.userId);

    socket.join(userRoom(userId));
    socket.emit('chat:ready', { user_id: userId });

    socket.on('chat:join', async (payload = {}, ack) => {
      const conversationId = Number(payload?.conversation_id);

      if (!Number.isInteger(conversationId) || conversationId <= 0) {
        ackError(ack, 'conversation_id inválido');
        return;
      }

      try {
        const result = await pool.query(
          `SELECT 1
           FROM app.padel_chat_participants
           WHERE conversation_id = $1
             AND user_id = $2
           LIMIT 1`,
          [conversationId, userId],
        );

        if (result.rows.length === 0) {
          ackError(ack, 'No perteneces a esa conversación');
          return;
        }

        socket.join(conversationRoom(conversationId));
        ackSuccess(ack, { conversation_id: conversationId });
      } catch (error) {
        console.error('Error suscribiendo socket a conversación:', error);
        ackError(ack, 'No se pudo completar la suscripción');
      }
    });

    socket.on('chat:leave', (payload = {}, ack) => {
      const conversationId = Number(payload?.conversation_id);

      if (!Number.isInteger(conversationId) || conversationId <= 0) {
        ackError(ack, 'conversation_id inválido');
        return;
      }

      socket.leave(conversationRoom(conversationId));
      ackSuccess(ack, { conversation_id: conversationId });
    });
  });

  return ioInstance;
}

function emitToUsers(userIds, eventName, payload) {
  if (!ioInstance) {
    return;
  }

  const uniqueUserIds = [...new Set((userIds || []).map((value) => Number(value)).filter(Boolean))];

  for (const userId of uniqueUserIds) {
    ioInstance.to(userRoom(userId)).emit(eventName, payload);
  }
}

export function emitPadelChatConversationCreated({
  userIds,
  conversationId,
  kind,
}) {
  emitToUsers(userIds, 'chat:conversation.created', {
    conversation_id: Number(conversationId),
    kind,
  });
}

export function emitPadelChatMessageCreated({
  userIds,
  conversationId,
  kind,
  message,
}) {
  emitToUsers(userIds, 'chat:message.created', {
    conversation_id: Number(conversationId),
    kind,
    message,
  });
}

export function emitPadelChatMessagesDeleted({
  userIds,
  conversationId,
  messageIds,
  conversation,
}) {
  emitToUsers(userIds, 'chat:messages.deleted', {
    conversation_id: Number(conversationId),
    message_ids: messageIds.map((messageId) => Number(messageId)),
    conversation,
  });
}

export function emitPadelChatReadUpdated({
  userIds,
  conversationId,
  userId,
  messageId,
  readAt,
}) {
  emitToUsers(userIds, 'chat:conversation.read', {
    conversation_id: Number(conversationId),
    user_id: Number(userId),
    message_id: messageId ? Number(messageId) : null,
    read_at: readAt || null,
  });
}
