import { z } from 'zod';

const dateRegex = /^\d{4}-\d{2}-\d{2}$/;
const timeRegex = /^\d{2}:\d{2}(:\d{2})?$/;

const participantIdsSchema = z
  .array(z.number().int().positive('Jugador inválido'))
  .min(1, 'Selecciona al menos un compañero')
  .max(3, 'Puedes invitar como máximo a tres compañeros');

const optionalUpdatedAtSchema = z
  .string()
  .trim()
  .min(1, 'updated_at inválido')
  .optional();

export const createCommunityPlanSchema = z.object({
  scheduled_date: z
    .string({ required_error: 'La fecha es obligatoria' })
    .regex(dateRegex, 'Formato de fecha inválido (YYYY-MM-DD)'),
  scheduled_time: z
    .string({ required_error: 'La hora es obligatoria' })
    .regex(timeRegex, 'Formato de hora inválido (HH:mm o HH:mm:ss)'),
  participant_user_ids: participantIdsSchema,
  force_send: z.boolean().optional(),
});

export const updateCommunityPlanSchema = createCommunityPlanSchema.extend({
  updated_at: optionalUpdatedAtSchema,
});

export const respondCommunityPlanSchema = z.object({
  action: z.enum(['accepted', 'declined', 'doubt']),
  updated_at: optionalUpdatedAtSchema,
});

export const proposeCommunityTimeSchema = z.object({
  scheduled_date: z
    .string({ required_error: 'La fecha es obligatoria' })
    .regex(dateRegex, 'Formato de fecha inválido (YYYY-MM-DD)'),
  scheduled_time: z
    .string({ required_error: 'La hora es obligatoria' })
    .regex(timeRegex, 'Formato de hora inválido (HH:mm o HH:mm:ss)'),
  updated_at: optionalUpdatedAtSchema,
});

export const updateCommunityReservationSchema = z.object({
  status: z.enum(['confirmed', 'retry']),
  handled_by_user_id: z.number().int().positive().optional().nullable(),
  updated_at: optionalUpdatedAtSchema,
});

const setScoreSchema = z.object({
  a: z.number().int().min(0).max(7),
  b: z.number().int().min(0).max(7),
});

export const submitMatchResultSchema = z.object({
  partner_user_id: z.number().int().positive().optional().nullable(),
  winner_team: z.number().int().refine((v) => v === 1 || v === 2, {
    message: 'winner_team debe ser 1 o 2',
  }),
  sets: z
    .array(setScoreSchema)
    .min(1, 'Indica al menos un set')
    .max(3, 'Máximo 3 sets'),
});

export const previewCommunityConflictsSchema = z.object({
  plan_id: z.number().int().positive().optional().nullable(),
  scheduled_date: z
    .string({ required_error: 'La fecha es obligatoria' })
    .regex(dateRegex, 'Formato de fecha inválido (YYYY-MM-DD)'),
  scheduled_time: z
    .string({ required_error: 'La hora es obligatoria' })
    .regex(timeRegex, 'Formato de hora inválido (HH:mm o HH:mm:ss)'),
  participant_user_ids: participantIdsSchema,
});
