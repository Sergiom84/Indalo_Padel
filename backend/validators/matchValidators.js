import { z } from 'zod';

const dateRegex = /^\d{4}-\d{2}-\d{2}$/;
const timeRegex = /^\d{2}:\d{2}(:\d{2})?$/;

export const createMatchSchema = z.object({
  booking_id: z.number().int().positive().optional().nullable(),
  match_type: z.enum(['abierto', 'privado']).optional().default('abierto'),
  min_level: z
    .number()
    .int()
    .min(1, 'Nivel mínimo: 1')
    .max(9, 'Nivel máximo: 9')
    .optional()
    .default(1),
  max_level: z
    .number()
    .int()
    .min(1, 'Nivel mínimo: 1')
    .max(9, 'Nivel máximo: 9')
    .optional()
    .default(9),
  match_date: z
    .string({ required_error: 'La fecha del partido es requerida' })
    .regex(dateRegex, 'Formato de fecha inválido (YYYY-MM-DD)'),
  start_time: z
    .string({ required_error: 'La hora de inicio es requerida' })
    .regex(timeRegex, 'Formato de hora inválido (HH:mm o HH:mm:ss)'),
  venue_id: z
    .number({ required_error: 'El ID de sede es requerido' })
    .int()
    .positive(),
  description: z.string().max(500, 'La descripción no puede superar 500 caracteres').optional(),
}).refine((data) => data.min_level <= data.max_level, {
  message: 'El nivel mínimo no puede ser mayor que el máximo',
  path: ['min_level'],
});

export const matchQuerySchema = z.object({
  level: z.coerce.number().int().min(0).max(9).optional(),
  date: z.string().regex(dateRegex).optional(),
  venue_id: z.coerce.number().int().positive().optional(),
  limit: z.coerce.number().int().min(1).max(100).optional(),
});
