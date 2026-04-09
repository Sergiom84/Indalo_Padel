import { z } from 'zod';

const dateRegex = /^\d{4}-\d{2}-\d{2}$/;
const timeRegex = /^\d{2}:\d{2}(:\d{2})?$/;

export const createBookingSchema = z.object({
  court_id: z
    .number({ required_error: 'El ID de pista es requerido' })
    .int('El ID de pista debe ser un entero')
    .positive('El ID de pista debe ser positivo'),
  booking_date: z
    .string({ required_error: 'La fecha es requerida' })
    .regex(dateRegex, 'Formato de fecha inválido (YYYY-MM-DD)'),
  start_time: z
    .string({ required_error: 'La hora de inicio es requerida' })
    .regex(timeRegex, 'Formato de hora inválido (HH:mm o HH:mm:ss)'),
  duration_minutes: z
    .number()
    .int()
    .min(30, 'Duración mínima: 30 minutos')
    .max(240, 'Duración máxima: 240 minutos')
    .optional()
    .default(90),
  notes: z.string().max(500, 'Las notas no pueden superar 500 caracteres').optional(),
  player_user_ids: z
    .array(z.number().int().positive())
    .max(3, 'Máximo 3 jugadores invitados')
    .optional()
    .default([]),
  player_ids: z
    .array(z.number().int().positive())
    .max(3, 'Máximo 3 jugadores invitados')
    .optional(),
});

export const availabilityQuerySchema = z.object({
  date: z
    .string({ required_error: 'Parámetro date requerido (YYYY-MM-DD)' })
    .regex(dateRegex, 'Formato de fecha inválido (YYYY-MM-DD)'),
  duration_minutes: z.coerce
    .number()
    .int()
    .min(30)
    .max(240)
    .optional(),
  slot_step_minutes: z.coerce
    .number()
    .int()
    .min(15)
    .max(120)
    .optional(),
});
