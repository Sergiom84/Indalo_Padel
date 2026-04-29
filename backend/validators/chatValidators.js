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

export const sendChatMessageSchema = z
  .object({
    message_type: z.enum(['text', 'image', 'voice']).optional().default('text'),
    body: z.string().trim().max(4000).optional().default(''),
    attachment_data_url: z.string().trim().max(10_000_000).optional(),
    attachment_duration_seconds: z.coerce
      .number()
      .int()
      .min(1)
      .max(60)
      .optional()
      .nullable(),
  })
  .superRefine((value, ctx) => {
    if (value.message_type === 'text' && !value.body.trim()) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['body'],
        message: 'Escribe un mensaje',
      });
    }

    if (value.message_type !== 'text' && !value.attachment_data_url) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['attachment_data_url'],
        message: 'Adjunta un archivo',
      });
    }

    if (
      value.message_type === 'voice' &&
      !value.attachment_duration_seconds
    ) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['attachment_duration_seconds'],
        message: 'La nota de voz no tiene duracion',
      });
    }
  });

export const deleteChatMessagesSchema = z.object({
  message_ids: z
    .array(positiveInt)
    .min(1, 'Selecciona al menos un mensaje')
    .max(50, 'Puedes eliminar hasta 50 mensajes a la vez'),
});

export const markConversationReadSchema = z.object({
  message_id: z.number().int().positive().nullable().optional(),
});
