import React, { useState } from 'react';
import { useParams, useNavigate, useLocation } from 'react-router-dom';
import { Calendar, Clock, MapPin } from 'lucide-react';
import { format, parseISO } from 'date-fns';
import { es } from 'date-fns/locale';
import Button from '../../ui/button';
import { Card, CardContent, CardHeader, CardFooter } from '../../ui/card';
import { Textarea } from '../../ui/input';
import { usePadelBooking } from '../hooks/usePadelBooking';

export default function BookingForm() {
  const { courtId } = useParams();
  const navigate = useNavigate();
  const location = useLocation();
  const { date, start_time, venue_name, court_name, price } = location.state || {};

  const { createBooking } = usePadelBooking();

  const [notes, setNotes] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const formattedDate = date
    ? format(parseISO(date), "EEEE d 'de' MMMM, yyyy", { locale: es })
    : '';

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError(null);

    try {
      const booking = await createBooking({
        court_id: courtId,
        booking_date: date,
        start_time,
        notes,
      });

      navigate(`/booking/${booking.id}/confirmation`, {
        state: {
          ...booking,
          venue_name,
          court_name,
          price,
        },
      });
    } catch (err) {
      setError(err.message || 'Error al crear la reserva');
    } finally {
      setLoading(false);
    }
  };

  if (!location.state) {
    return (
      <div className="min-h-screen bg-padel-dark flex items-center justify-center p-4">
        <Card className="w-full max-w-md bg-padel-surface border-slate-700">
          <CardContent className="p-6 text-center">
            <p className="text-slate-300">No se encontraron datos de reserva.</p>
            <Button
              className="mt-4"
              onClick={() => navigate('/')}
            >
              Volver al inicio
            </Button>
          </CardContent>
        </Card>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-padel-dark py-8 px-4">
      <div className="max-w-lg mx-auto">
        <h1 className="text-2xl font-bold text-white mb-6">Confirmar reserva</h1>

        <Card className="bg-padel-surface border-slate-700 mb-6">
          <CardHeader>
            <h2 className="text-lg font-semibold text-white">Resumen de la reserva</h2>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="flex items-center gap-3 text-slate-300">
              <MapPin className="h-5 w-5 text-padel-accent shrink-0" />
              <div>
                <p className="text-white font-medium">{venue_name}</p>
                <p className="text-sm">{court_name}</p>
              </div>
            </div>

            <div className="flex items-center gap-3 text-slate-300">
              <Calendar className="h-5 w-5 text-padel-accent shrink-0" />
              <p className="capitalize">{formattedDate}</p>
            </div>

            <div className="flex items-center gap-3 text-slate-300">
              <Clock className="h-5 w-5 text-padel-accent shrink-0" />
              <p>{start_time}h</p>
            </div>

            <div className="flex items-center justify-between pt-3 border-t border-slate-700">
              <span className="text-slate-400">Precio</span>
              <span className="text-xl font-bold text-padel-accent">{price}€</span>
            </div>
          </CardContent>
        </Card>

        <form onSubmit={handleSubmit}>
          <Card className="bg-padel-surface border-slate-700 mb-6">
            <CardContent className="p-6">
              <label className="block text-sm font-medium text-slate-300 mb-2">
                Notas (opcional)
              </label>
              <Textarea
                value={notes}
                onChange={(e) => setNotes(e.target.value)}
                placeholder="Añade cualquier nota o comentario..."
                rows={3}
                className="bg-padel-dark border-slate-600 text-white placeholder-slate-500"
              />
            </CardContent>
          </Card>

          {error && (
            <div className="bg-red-900/30 border border-red-700 rounded-lg p-3 mb-4">
              <p className="text-red-400 text-sm">{error}</p>
            </div>
          )}

          <Button
            type="submit"
            disabled={loading}
            className="w-full bg-padel-primary hover:bg-teal-700 text-white font-semibold py-3"
          >
            {loading ? 'Reservando...' : 'Confirmar reserva'}
          </Button>
        </form>
      </div>
    </div>
  );
}
