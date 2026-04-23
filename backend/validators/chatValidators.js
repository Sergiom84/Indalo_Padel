import { z } from 'zod';

const positiveInt = z.coerce.number().int().positive();

export const directConversationParamsSchema = z.object({
  userId: positiveInt,
});

export const eventConversationParamsSchema = z.object({
  planId: positiveInt,
});

export const socialEventParamsSchema = z.object({
  eventId: positiveInt,
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

export const createSocialEventSchema = z.object({
  title: z.string().trim().min(1).max(120),
  description: z.string().trim().max(1000).optional().nullable(),
  venue_name: z.string().trim().max(120).optional().nullable(),
  location: z.string().trim().max(160).optional().nullable(),
  scheduled_date: z.string().trim().regex(/^\d{4}-\d{2}-\d{2}$/),
  scheduled_time: z.string().trim().regex(/^\d{2}:\d{2}(:\d{2})?$/),
  duration_minutes: z.coerce.number().int().min(30).max(480).optional(),
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
