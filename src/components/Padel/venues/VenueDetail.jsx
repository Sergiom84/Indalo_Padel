import { useState, useEffect } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import { MapPin, Clock, ArrowLeft, Building2, CalendarDays } from 'lucide-react';
import { format } from 'date-fns';
import { Card, CardContent, CardHeader } from '../../ui/card';
import Button from '../../ui/button';
import apiClient from '../../../lib/apiClient';

export default function VenueDetail() {
  const { id } = useParams();
  const navigate = useNavigate();

  const [venue, setVenue] = useState(null);
  const [availability, setAvailability] = useState(null);
  const [selectedDate, setSelectedDate] = useState(format(new Date(), 'yyyy-MM-dd'));
  const [loading, setLoading] = useState(true);
  const [availabilityLoading, setAvailabilityLoading] = useState(false);
  const [error, setError] = useState(null);

  // Fetch venue detail
  useEffect(() => {
    const fetchVenue = async () => {
      try {
        setLoading(true);
        const response = await apiClient.get(`/padel/venues/${id}`);
        setVenue(response);
      } catch (err) {
        setError('Error al cargar la sede');
        console.error('Error fetching venue:', err);
      } finally {
        setLoading(false);
      }
    };

    fetchVenue();
  }, [id]);

  // Fetch availability when date changes
  useEffect(() => {
    if (!selectedDate || !id) return;

    const fetchAvailability = async () => {
      try {
        setAvailabilityLoading(true);
        const response = await apiClient.get(
          `/padel/venues/${id}/availability?date=${selectedDate}`
        );
        setAvailability(response);
      } catch (err) {
        console.error('Error fetching availability:', err);
        setAvailability(null);
      } finally {
        setAvailabilityLoading(false);
      }
    };

    fetchAvailability();
  }, [id, selectedDate]);

  const handleSlotClick = (court, slot) => {
    navigate(`/booking/${court.id}`, {
      state: {
        date: selectedDate,
        start_time: slot.start_time,
        venue_name: venue.name,
        court_name: court.name,
        price: slot.price,
      },
    });
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center py-12">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-padel-primary" />
      </div>
    );
  }

  if (error || !venue) {
    return (
      <div className="text-center py-12">
        <p className="text-red-400 mb-4">{error || 'Sede no encontrada'}</p>
        <Link to="/venues">
          <Button>Volver a sedes</Button>
        </Link>
      </div>
    );
  }

  const courts = availability?.courts || [];
  const timeSlots = availability?.time_slots || [];

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center gap-4">
        <button
          onClick={() => navigate('/venues')}
          className="text-gray-400 hover:text-white transition-colors"
        >
          <ArrowLeft className="h-5 w-5" />
        </button>
        <h1 className="text-2xl font-bold text-white">{venue.name}</h1>
      </div>

      {/* Venue Info */}
      <Card>
        <CardContent className="p-6">
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <div className="flex items-center gap-2 text-gray-300">
              <MapPin className="h-4 w-4 text-padel-accent shrink-0" />
              <span className="text-sm">{venue.location}</span>
            </div>
            <div className="flex items-center gap-2 text-gray-300">
              <Building2 className="h-4 w-4 text-padel-accent shrink-0" />
              <span className="text-sm">
                {venue.court_count} {venue.court_count === 1 ? 'pista' : 'pistas'}
              </span>
            </div>
            {(venue.opening_time || venue.closing_time) && (
              <div className="flex items-center gap-2 text-gray-300">
                <Clock className="h-4 w-4 text-padel-accent shrink-0" />
                <span className="text-sm">
                  {venue.opening_time?.slice(0, 5)} - {venue.closing_time?.slice(0, 5)}
                </span>
              </div>
            )}
          </div>
        </CardContent>
      </Card>

      {/* Courts List */}
      {venue.courts && venue.courts.length > 0 && (
        <Card>
          <CardHeader>
            <h2 className="text-lg font-semibold text-white">Pistas</h2>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
              {venue.courts.map((court) => (
                <div
                  key={court.id}
                  className="bg-padel-dark rounded-lg p-3 border border-gray-700"
                >
                  <p className="text-white font-medium">{court.name}</p>
                  {court.surface_type && (
                    <p className="text-sm text-gray-400 mt-1">{court.surface_type}</p>
                  )}
                  {court.is_indoor !== undefined && (
                    <p className="text-sm text-gray-400">
                      {court.is_indoor ? 'Cubierta' : 'Exterior'}
                    </p>
                  )}
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      )}

      {/* Availability Section */}
      <Card>
        <CardHeader>
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            <h2 className="text-lg font-semibold text-white flex items-center gap-2">
              <CalendarDays className="h-5 w-5 text-padel-accent" />
              Disponibilidad
            </h2>
            <input
              type="date"
              value={selectedDate}
              onChange={(e) => setSelectedDate(e.target.value)}
              min={format(new Date(), 'yyyy-MM-dd')}
              className="bg-padel-dark border border-gray-700 rounded-lg px-3 py-2 text-white text-sm focus:outline-none focus:border-padel-primary"
            />
          </div>
        </CardHeader>
        <CardContent>
          {availabilityLoading ? (
            <div className="flex items-center justify-center py-8">
              <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-padel-primary" />
            </div>
          ) : courts.length === 0 || timeSlots.length === 0 ? (
            <p className="text-gray-400 text-center py-8">
              No hay disponibilidad para esta fecha
            </p>
          ) : (
            <>
              {/* Legend */}
              <div className="flex items-center gap-4 mb-4 text-sm">
                <div className="flex items-center gap-2">
                  <div className="w-4 h-4 rounded bg-emerald-600/30 border border-emerald-500" />
                  <span className="text-gray-300">Disponible</span>
                </div>
                <div className="flex items-center gap-2">
                  <div className="w-4 h-4 rounded bg-red-900/30 border border-red-800" />
                  <span className="text-gray-300">Ocupado</span>
                </div>
              </div>

              {/* Availability Grid */}
              <div className="overflow-x-auto -mx-4 px-4 sm:mx-0 sm:px-0">
                <table className="w-full min-w-[500px] border-collapse">
                  <thead>
                    <tr>
                      <th className="text-left text-sm font-medium text-gray-400 p-2 sticky left-0 bg-padel-surface z-10">
                        Hora
                      </th>
                      {courts.map((court) => (
                        <th
                          key={court.id}
                          className="text-center text-sm font-medium text-gray-400 p-2"
                        >
                          {court.name}
                        </th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {timeSlots.map((slot, slotIndex) => (
                      <tr
                        key={slot.start_time}
                        className={slotIndex % 2 === 0 ? 'bg-padel-dark/30' : ''}
                      >
                        <td className="text-sm text-gray-300 p-2 whitespace-nowrap sticky left-0 bg-padel-surface z-10">
                          {slot.start_time?.slice(0, 5)}
                        </td>
                        {courts.map((court) => {
                          const courtSlot = slot.courts?.[court.id] || slot.courts?.[String(court.id)];
                          const isAvailable = courtSlot?.available ?? false;
                          const price = courtSlot?.price;

                          return (
                            <td key={court.id} className="p-1 text-center">
                              {isAvailable ? (
                                <button
                                  onClick={() =>
                                    handleSlotClick(court, {
                                      start_time: slot.start_time,
                                      price: price,
                                    })
                                  }
                                  className="w-full py-2 px-1 rounded bg-emerald-600/20 border border-emerald-500/40 text-emerald-400 text-xs font-medium hover:bg-emerald-600/40 hover:border-emerald-400 transition-colors"
                                >
                                  {price != null ? `${price}€` : 'Libre'}
                                </button>
                              ) : (
                                <div className="w-full py-2 px-1 rounded bg-red-900/20 border border-red-800/40 text-red-400/60 text-xs">
                                  Ocupado
                                </div>
                              )}
                            </td>
                          );
                        })}
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
