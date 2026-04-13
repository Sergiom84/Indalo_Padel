import { z } from 'zod';

const courtPreferenceValues = ['drive', 'reves', 'ambos'];
const dominantHandValues = ['diestro', 'zurdo', 'ambidiestro'];
const genderValues = ['masculino', 'femenino', 'otro', 'prefiero_no_decirlo'];
const availabilityPreferenceValues = [
  'mananas',
  'mediodias',
  'tardes_noches',
  'flexible',
];
const matchPreferenceValues = ['amistoso', 'competitivo', 'americana'];
const birthDateSchema = z.string().regex(/^\d{4}-\d{2}-\d{2}$/);
const deletionReasonValues = [
  'no_uso_la_app',
  'no_me_gusta',
  'no_es_lo_que_buscaba',
  'otros',
];

const stringArraySchema = (values) =>
  z.array(z.enum(values)).optional();

export const updateProfileSchema = z.object({
  display_name: z.string().trim().min(1).max(50).optional(),
  main_level: z.enum(['bajo', 'medio', 'alto']).optional(),
  sub_level: z.enum(['bajo', 'medio', 'alto']).optional(),
  preferred_venue_id: z.number().int().positive().nullable().optional(),
  bio: z.string().max(1000).optional(),
  avatar_url: z.string().max(2000000).optional(),
  new_password: z.string().min(6).max(100).optional(),
  is_available: z.boolean().optional(),
  gender: z.enum(genderValues).nullable().optional(),
  birth_date: z.union([birthDateSchema, z.null()]).optional(),
  phone: z.string().trim().max(20).nullable().optional(),
  court_preferences: stringArraySchema(courtPreferenceValues),
  dominant_hands: stringArraySchema(dominantHandValues),
  availability_preferences: stringArraySchema(availabilityPreferenceValues),
  match_preferences: stringArraySchema(matchPreferenceValues),
});

export const playerSearchQuerySchema = z.object({
  name: z.string().trim().max(80).optional(),
  level: z
    .union([z.string(), z.number()])
    .transform((value) => Number(value))
    .pipe(z.number().int().min(1).max(9))
    .optional(),
  main_level: z.enum(['bajo', 'medio', 'alto']).optional(),
  sub_level: z.enum(['bajo', 'medio', 'alto']).optional(),
  gender: z.enum(genderValues).optional(),
  available: z.enum(['true', 'false']).optional(),
});

export const deleteProfileSchema = z.object({
  reason: z.enum(deletionReasonValues, {
    required_error: 'Debes indicar un motivo',
  }),
  other_reason: z.string().trim().max(255).optional(),
});
