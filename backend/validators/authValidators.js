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
const birthDateSchema = z
  .string({ required_error: 'La fecha de nacimiento es requerida' })
  .regex(/^\d{4}-\d{2}-\d{2}$/, 'Formato de fecha inválido');

export const registerSchema = z.object({
  nombre: z
    .string({ required_error: 'El nombre es requerido' })
    .min(2, 'El nombre debe tener al menos 2 caracteres')
    .max(50, 'El nombre no puede superar 50 caracteres')
    .trim(),
  email: z
    .string({ required_error: 'El email es requerido' })
    .email('Formato de email inválido')
    .max(100, 'El email no puede superar 100 caracteres')
    .toLowerCase()
    .trim(),
  password: z
    .string({ required_error: 'La contraseña es requerida' })
    .min(6, 'La contraseña debe tener al menos 6 caracteres')
    .max(100, 'La contraseña no puede superar 100 caracteres'),
  main_level: z.enum(['bajo', 'medio', 'alto']).optional().default('bajo'),
  sub_level: z.enum(['bajo', 'medio', 'alto']).optional().default('bajo'),
  gender: z.enum(genderValues, {
    required_error: 'El género es requerido',
  }),
  birth_date: birthDateSchema,
  phone: z.string().trim().max(20).optional(),
  court_preferences: z
    .array(z.enum(courtPreferenceValues))
    .optional()
    .default([]),
  dominant_hands: z
    .array(z.enum(dominantHandValues))
    .optional()
    .default([]),
  availability_preferences: z
    .array(z.enum(availabilityPreferenceValues))
    .optional()
    .default([]),
  match_preferences: z
    .array(z.enum(matchPreferenceValues))
    .optional()
    .default([]),
});

export const loginSchema = z.object({
  email: z
    .string({ required_error: 'El email es requerido' })
    .email('Formato de email inválido')
    .toLowerCase()
    .trim(),
  password: z
    .string({ required_error: 'La contraseña es requerida' })
    .min(1, 'La contraseña es requerida'),
});

export const emailActionSchema = z.object({
  email: z
    .string({ required_error: 'El email es requerido' })
    .email('Formato de email inválido')
    .max(100, 'El email no puede superar 100 caracteres')
    .toLowerCase()
    .trim(),
});

export const resetPasswordSchema = z.object({
  token: z
    .string({ required_error: 'El token es requerido' })
    .min(32, 'Token inválido')
    .max(512, 'Token inválido')
    .trim(),
  password: z
    .string({ required_error: 'La contraseña es requerida' })
    .min(6, 'La contraseña debe tener al menos 6 caracteres')
    .max(100, 'La contraseña no puede superar 100 caracteres'),
});
