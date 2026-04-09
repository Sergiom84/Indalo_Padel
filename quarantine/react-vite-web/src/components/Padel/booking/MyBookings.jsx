import React, { useState, useEffect, useCallback } from 'react';
import { Calendar, Clock, MapPin } from 'lucide-react';
import { format, parseISO } from 'date-fns';
import { es } from 'date-fns/locale';
import Button from '../../ui/button';
import { Card, CardContent } from '../../ui/card';
import Badge from '../../ui/badge';
import { Tabs } from '../../ui/tabs';
import { usePadelBooking } from '../hooks/usePadelBooking';

const STATUS_VARIANTS = {
  pendiente: 'warning',
  confirmada: 'success',
  cancelada: 'danger',
  completada: 'neutral',
};

const tabs = [
  { value: 'upcoming', label: 'Próximas' },
  { value: 'past', label: 'Historial' },
];

function BookingCard({ booking, isUpcoming, onConfirm, onCancel }) {
  const { venue_name, court_name, date, start_time, status, price } = booking;
  const [actionLoading, setActionLoading] = useState(null);

  const formattedDate = date
    ? format(parseISO(date), "EEE d MMM yyyy", { locale: es })
    : '';

  const handleAction = async (action, fn) => {
    setActionLoading(action);
    try {
      await fn(booking.id);
    } finally {
      setActionLoading(null);
    }
  };

  return (
    <Card className="bg-padel-surface border-slate-700">
      <CardContent className="p-5">
        <div className="flex items-start justify-between mb-3">
          <div className="flex items-center gap-2">
            <MapPin className="h-4 w-4 text-padel-accent shrink-0" />
            <div>
              <p className="text-white font-medium text-sm">{venue_name}</p>
              <p className="text-slate-400 text-xs">{court_name}</p>
            </div>
          </div>
          <Badge variant={STATUS_VARIANTS[status] || 'neutral'}>
            {status}
          </Badge>
        </div>

        <div className="flex items-center gap-4 text-sm text-slate-300 mb-3">
          <div className="flex items-center gap-1.5">
            <Calendar className="h-4 w-4 text-padel-accent" />
            <span className="capitalize">{formattedDate}</span>
          </div>
          <div className="flex items-center gap-1.5">
            <Clock className="h-4 w-4 text-padel-accent" />
            <span>{start_time}h</span>
          </div>
        </div>

        <div className="flex items-center justify-between">
          <span className="text-padel-accent font-bold">{price}€</span>

          {isUpcoming && status !== 'cancelada' && (
            <div className="flex gap-2">
              {status === 'pendiente' && (
                <Button
                  size="sm"
                  className="bg-padel-primary hover:bg-teal-700 text-white text-xs"
                  disabled={actionLoading === 'confirm'}
                  onClick={() => handleAction('confirm', onConfirm)}
                >
                  {actionLoading === 'confirm' ? 'Confirmando...' : 'Confirmar'}
                </Button>
              )}
              <Button
                size="sm"
                variant="outline"
                className="border-red-600 text-red-400 hover:bg-red-900/30 text-xs"
                disabled={actionLoading === 'cancel'}
                onClick={() => handleAction('cancel', onCancel)}
              >
                {actionLoading === 'cancel' ? 'Cancelando...' : 'Cancelar'}
              </Button>
            </div>
          )}
        </div>
      </CardContent>
    </Card>
  );
}

export default function MyBookings() {
  const { getMyBookings, confirmBooking, cancelBooking } = usePadelBooking();

  const [activeTab, setActiveTab] = useState('upcoming');
  const [bookings, setBookings] = useState({ upcoming: [], past: [] });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const fetchBookings = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await getMyBookings();
      setBookings(data);
    } catch (err) {
      setError(err.message || 'Error al cargar las reservas');
    } finally {
      setLoading(false);
    }
  }, [getMyBookings]);

  useEffect(() => {
    fetchBookings();
  }, [fetchBookings]);

  const handleConfirm = async (bookingId) => {
    await confirmBooking(bookingId);
    await fetchBookings();
  };

  const handleCancel = async (bookingId) => {
    await cancelBooking(bookingId);
    await fetchBookings();
  };

  const currentBookings = bookings[activeTab] || [];

  return (
    <div className="min-h-screen bg-padel-dark py-8 px-4">
      <div className="max-w-lg mx-auto">
        <h1 className="text-2xl font-bold text-white mb-6">Mis reservas</h1>

        <Tabs
          tabs={tabs}
          activeTab={activeTab}
          onChange={setActiveTab}
          className="mb-6"
        />

        {loading && (
          <div className="flex justify-center py-12">
            <div className="animate-spin rounded-full h-8 w-8 border-2 border-padel-accent border-t-transparent" />
          </div>
        )}

        {error && (
          <div className="bg-red-900/30 border border-red-700 rounded-lg p-4 mb-4">
            <p className="text-red-400 text-sm">{error}</p>
          </div>
        )}

        {!loading && !error && currentBookings.length === 0 && (
          <Card className="bg-padel-surface border-slate-700">
            <CardContent className="p-8 text-center">
              <Calendar className="h-12 w-12 text-slate-600 mx-auto mb-3" />
              <p className="text-slate-400">
                {activeTab === 'upcoming'
                  ? 'No tienes reservas próximas.'
                  : 'No tienes reservas anteriores.'}
              </p>
            </CardContent>
          </Card>
        )}

        {!loading && !error && (
          <div className="space-y-4">
            {currentBookings.map((booking) => (
              <BookingCard
                key={booking.id}
                booking={booking}
                isUpcoming={activeTab === 'upcoming'}
                onConfirm={handleConfirm}
                onCancel={handleCancel}
              />
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
