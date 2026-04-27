import { z } from 'zod';

const courtPreferenceValues = ['drive', 'reves', 'ambos'];
const dominantHandValues = ['diestro', 'zurdo', 'ambidiestro'];
const genderValues = ['masculino', 'femenino', 'otro', 'prefiero_no_decirlo'];
const availabilityPreferenceValues = [
  'laborables',
  'fin_de_semana',
  'cualquiera',
  'mananas',
  'mediodias',
  'tardes_noches',
  'flexible',
];
const matchPreferenceValues = ['amistoso', 'competitivo', 'americana'];
const birthDateSchema = z.string().regex(/^\d{4}-\d{2}-\d{2}$/);
const maxAvatarDataUrlLength = 750000;
const maxAvatarUrlLength = 2048;

const stringArraySchema = (values) =>
  z.array(z.enum(values)).optional();

const avatarUrlSchema = z.string().trim().max(maxAvatarDataUrlLength).refine(
  (value) => {
    if (!value) {
      return true;
    }

    if (value.startsWith('data:')) {
      return /^data:image\/(?:jpeg|jpg|png|webp);base64,[A-Za-z0-9+/=\s]+$/i.test(
        value,
      );
    }

    if (value.length > maxAvatarUrlLength) {
      return false;
    }

    try {
      const parsed = new URL(value);
      return parsed.protocol === 'https:' || parsed.protocol === 'http:';
    } catch {
      return false;
    }
  },
  { message: 'Avatar invalido' },
);

export const updateProfileSchema = z.object({
  display_name: z.string().trim().min(1).max(50).optional(),
  main_level: z.enum(['bajo', 'medio', 'alto']).optional(),
  sub_level: z.enum(['bajo', 'medio', 'alto']).optional(),
  preferred_venue_id: z.number().int().positive().nullable().optional(),
  bio: z.string().max(1000).optional(),
  avatar_url: avatarUrlSchema.optional(),
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

export const deleteProfileSchema = z.object({
  reason: z.enum([
    'no_uso_la_app',
    'no_me_gusta',
    'no_es_lo_que_buscaba',
    'otros',
  ]),
  other_reason: z.string().trim().max(500).optional(),
});

export const playerSearchQuerySchema = z.object({
  name: z.string().trim().max(100).optional(),
  level: z.coerce.number().int().min(1).max(9).optional(),
  main_level: z.enum(['bajo', 'medio', 'alto']).optional(),
  sub_level: z.enum(['bajo', 'medio', 'alto']).optional(),
  gender: z.enum(genderValues).optional(),
  available: z.enum(['true', 'false']).optional(),
});
