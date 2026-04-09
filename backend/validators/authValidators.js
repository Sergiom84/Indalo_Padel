import { z } from 'zod';

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
  preferred_side: z.enum(['drive', 'reves', 'ambos']).optional().default('ambos'),
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
