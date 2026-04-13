import React from 'react';
import { useLocation, Link } from 'react-router-dom';
import { CheckCircle, Calendar, Clock, MapPin } from 'lucide-react';
import { format, parseISO } from 'date-fns';
import { es } from 'date-fns/locale';
import Button from '../../ui/button';
import { Card, CardContent } from '../../ui/card';
import Badge from '../../ui/badge';

export default function BookingConfirmation() {
  const location = useLocation();
  const booking = location.state || {};

  const { venue_name, court_name, date, start_time, price, status } = booking;

  const formattedDate = date
    ? format(parseISO(date), "EEEE d 'de' MMMM, yyyy", { locale: es })
    : '';

  if (!location.state) {
    return (
      <div className="min-h-screen bg-padel-dark flex items-center justify-center p-4">
        <Card className="w-full max-w-md bg-padel-surface border-slate-700">
          <CardContent className="p-6 text-center">
            <p className="text-slate-300">No se encontraron datos de confirmación.</p>
            <Link to="/">
              <Button className="mt-4">Volver al inicio</Button>
            </Link>
          </CardContent>
        </Card>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-padel-dark py-8 px-4">
      <div className="max-w-lg mx-auto">
        <Card className="bg-padel-surface border-slate-700">
          <CardContent className="p-8">
            <div className="flex flex-col items-center text-center mb-8">
              <CheckCircle className="h-16 w-16 text-green-500 mb-4" />
              <h1 className="text-2xl font-bold text-white mb-2">
                ¡Reserva confirmada!
              </h1>
              <p className="text-slate-400">
                Tu pista ha sido reservada correctamente.
              </p>
            </div>

            <div className="space-y-4 mb-8">
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

              <div className="flex items-center justify-between">
                <span className="text-slate-400">Estado</span>
                <Badge variant="success">{status || 'Confirmada'}</Badge>
              </div>
            </div>

            <div className="flex flex-col gap-3">
              <Link to="/my-bookings">
                <Button className="w-full bg-padel-primary hover:bg-teal-700 text-white font-semibold">
                  Ver mis reservas
                </Button>
              </Link>
              <Link to="/">
                <Button
                  variant="outline"
                  className="w-full border-slate-600 text-slate-300 hover:bg-slate-700"
                >
                  Volver al inicio
                </Button>
              </Link>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
