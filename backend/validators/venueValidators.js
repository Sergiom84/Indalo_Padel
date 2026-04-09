import { z } from 'zod';

const timeRegex = /^\d{2}:\d{2}(:\d{2})?$/;

export const createVenueSchema = z.object({
  name: z
    .string({ required_error: 'El nombre es requerido' })
    .min(2, 'El nombre debe tener al menos 2 caracteres')
    .max(100)
    .trim(),
  location: z
    .string({ required_error: 'La ubicación es requerida' })
    .min(2, 'La ubicación debe tener al menos 2 caracteres')
    .max(100)
    .trim(),
  address: z.string().max(200).optional(),
  phone: z.string().max(20).optional(),
  email: z.string().email('Formato de email inválido').optional(),
  image_url: z.string().url('URL de imagen inválida').optional(),
  opening_time: z.string().regex(timeRegex, 'Formato de hora inválido').optional().default('08:00'),
  closing_time: z.string().regex(timeRegex, 'Formato de hora inválido').optional().default('22:00'),
});

export const updateVenueSchema = z.object({
  name: z.string().min(2).max(100).trim().optional(),
  location: z.string().min(2).max(100).trim().optional(),
  address: z.string().max(200).optional(),
  phone: z.string().max(20).optional(),
  email: z.string().email('Formato de email inválido').optional(),
  image_url: z.string().url('URL de imagen inválida').optional(),
  opening_time: z.string().regex(timeRegex).optional(),
  closing_time: z.string().regex(timeRegex).optional(),
  is_active: z.boolean().optional(),
});
