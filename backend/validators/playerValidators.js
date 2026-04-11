import { z } from 'zod';

const courtPreferenceValues = ['drive', 'reves', 'ambos'];
const dominantHandValues = ['diestro', 'zurdo', 'ambidiestro'];
const availabilityPreferenceValues = [
  'mananas',
  'mediodias',
  'tardes_noches',
  'flexible',
];
const matchPreferenceValues = ['amistoso', 'competitivo', 'americana'];

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
  court_preferences: stringArraySchema(courtPreferenceValues),
  dominant_hands: stringArraySchema(dominantHandValues),
  availability_preferences: stringArraySchema(availabilityPreferenceValues),
  match_preferences: stringArraySchema(matchPreferenceValues),
});
