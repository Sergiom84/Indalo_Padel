import { z } from 'zod';

const positiveInt = z.coerce.number().int().positive();

export const directConversationParamsSchema = z.object({
  userId: positiveInt,
});

export const eventConversationParamsSchema = z.object({
  planId: positiveInt,
});

export const conversationParamsSchema = z.object({
  id: positiveInt,
});

export const createGroupConversationSchema = z.object({
  title: z.string().trim().min(1).max(120),
  participant_user_ids: z
    .array(z.number().int().positive())
    .min(1, 'Selecciona al menos un participante')
    .max(31, 'El grupo admite como máximo 31 invitados'),
});

export const listConversationMessagesQuerySchema = z.object({
  before_message_id: positiveInt.optional(),
  limit: z.coerce.number().int().min(1).max(100).optional(),
});

export const sendChatMessageSchema = z.object({
  body: z.string().trim().min(1).max(4000),
});

export const markConversationReadSchema = z.object({
  message_id: z.number().int().positive().nullable().optional(),
});
