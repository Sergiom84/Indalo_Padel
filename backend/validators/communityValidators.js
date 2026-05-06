import { z } from 'zod';

const dateRegex = /^\d{4}-\d{2}-\d{2}$/;
const timeRegex = /^\d{2}:\d{2}(:\d{2})?$/;
const communityModalityValues = ['amistoso', 'competitivo', 'americana'];

const participantIdsSchema = z
  .array(z.number().int().positive('Jugador inválido'))
  .min(1, 'Selecciona al menos un compañero')
  .max(7, 'Puedes invitar como máximo a siete compañeros');

const optionalUpdatedAtSchema = z
  .string()
  .trim()
  .min(1, 'updated_at inválido')
  .optional();

const optionalClubIdSchema = z.number().int().positive().optional().nullable();
const optionalTrimmedText = (maxLength) =>
  z
    .string()
    .trim()
    .max(maxLength)
    .optional()
    .nullable();

const communityPlanBaseSchema = z.object({
  scheduled_date: z
    .string({ required_error: 'La fecha es obligatoria' })
    .regex(dateRegex, 'Formato de fecha inválido (YYYY-MM-DD)'),
  scheduled_time: z
    .string({ required_error: 'La hora es obligatoria' })
    .regex(timeRegex, 'Formato de hora inválido (HH:mm o HH:mm:ss)'),
  participant_user_ids: participantIdsSchema,
  modality: z.enum(communityModalityValues).optional().default('amistoso'),
  capacity: z.number().int().positive().optional().nullable(),
  club_id: optionalClubIdSchema,
  venue_id: optionalClubIdSchema,
  post_padel_plan: optionalTrimmedText(160),
  notes: optionalTrimmedText(500),
  force_send: z.boolean().optional(),
}).superRefine((value, ctx) => {
  const modality = value.modality ?? 'amistoso';
  const participantCount = value.participant_user_ids.length;
  const expectedCapacity = modality === 'americana' ? 8 : 4;

  if (modality === 'americana' && participantCount !== 7) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ['participant_user_ids'],
      message: 'La modalidad americana requiere invitar a 7 jugadores para completar 8 plazas.',
    });
  }

  if (modality !== 'americana' && participantCount > 3) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ['participant_user_ids'],
      message: 'Las convocatorias amistosas o competitivas admiten hasta 4 jugadores en total.',
    });
  }

  if (value.capacity != null && value.capacity !== expectedCapacity) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ['capacity'],
      message: modality === 'americana'
        ? 'La modalidad americana usa 8 plazas.'
        : 'Las convocatorias amistosas o competitivas usan 4 plazas.',
    });
  }

  if (
    value.club_id != null &&
    value.venue_id != null &&
    value.club_id !== value.venue_id
  ) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ['club_id'],
      message: 'club_id y venue_id deben referirse al mismo club.',
    });
  }
});

export const createCommunityPlanSchema = communityPlanBaseSchema;

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

const setScoreSchema = z
  .object({
    a: z.number().int().min(0).max(99),
    b: z.number().int().min(0).max(99),
    tie_break_a: z.number().int().min(0).max(99).optional().nullable(),
    tie_break_b: z.number().int().min(0).max(99).optional().nullable(),
  })
  .refine(
    (set) => (set.tie_break_a == null) === (set.tie_break_b == null),
    'Indica ambos valores del tie-break',
  );

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
  modality: z.enum(communityModalityValues).optional(),
  capacity: z.number().int().positive().optional().nullable(),
});
