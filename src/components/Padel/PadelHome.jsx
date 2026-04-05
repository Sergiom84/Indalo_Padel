import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  MapPin,
  Calendar,
  Users,
  ChevronRight,
  Trophy,
  Building2,
  Clock,
} from 'lucide-react';
import { useAuth } from '../../contexts/AuthContext';
import apiClient from '../../lib/apiClient';
import { Card, CardContent } from '../ui/card';
import Badge from '../ui/badge';
import Button from '../ui/button';

export default function PadelHome() {
  const { user } = useAuth();
  const navigate = useNavigate();
  const [venues, setVenues] = useState([]);
  const [bookings, setBookings] = useState([]);
  const [matches, setMatches] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchData = async () => {
      try {
        const [venuesRes, bookingsRes, matchesRes] = await Promise.allSettled([
          apiClient.get('/padel/venues'),
          apiClient.get('/padel/bookings/my'),
          apiClient.get('/padel/matches'),
        ]);
        if (venuesRes.status === 'fulfilled') setVenues(venuesRes.value || []);
        if (bookingsRes.status === 'fulfilled') setBookings(bookingsRes.value || { upcoming: [], past: [] });
        if (matchesRes.status === 'fulfilled') setMatches(matchesRes.value || []);
      } catch {
        // silently handle
      } finally {
        setLoading(false);
      }
    };
    fetchData();
  }, []);

  const openMatches = Array.isArray(matches)
    ? matches.filter((m) => m.status === 'buscando' || m.status === 'abierto')
    : [];
  const upcomingBookings = Array.isArray(bookings?.upcoming) ? bookings.upcoming.slice(0, 3) : [];
  const venueList = Array.isArray(venues) ? venues : [];

  return (
    <div className="min-h-screen bg-padel-dark">
      <div className="max-w-4xl mx-auto px-4 py-6 sm:py-8 space-y-6">
        {/* Welcome */}
        <div>
          <h1 className="text-2xl sm:text-3xl font-bold text-white">
            Hola, {user?.nombre || user?.name || 'Jugador'} 👋
          </h1>
          <p className="text-slate-400 mt-1">Bienvenido a Indalo Padel</p>
        </div>

        {/* Quick Stats */}
        <div className="grid grid-cols-3 gap-3">
          <Card
            className="bg-padel-surface border-padel-surface cursor-pointer hover:border-padel-primary/50 transition-colors"
            onClick={() => navigate('/venues')}
          >
            <CardContent className="p-4 text-center">
              <Building2 className="w-6 h-6 text-padel-primary mx-auto mb-1" />
              <p className="text-xl font-bold text-white">{venueList.length}</p>
              <p className="text-xs text-slate-400">Clubes</p>
            </CardContent>
          </Card>
          <Card
            className="bg-padel-surface border-padel-surface cursor-pointer hover:border-padel-primary/50 transition-colors"
            onClick={() => navigate('/my-bookings')}
          >
            <CardContent className="p-4 text-center">
              <Calendar className="w-6 h-6 text-padel-primary mx-auto mb-1" />
              <p className="text-xl font-bold text-white">{upcomingBookings.length}</p>
              <p className="text-xs text-slate-400">Reservas</p>
            </CardContent>
          </Card>
          <Card
            className="bg-padel-surface border-padel-surface cursor-pointer hover:border-padel-primary/50 transition-colors"
            onClick={() => navigate('/matches')}
          >
            <CardContent className="p-4 text-center">
              <Trophy className="w-6 h-6 text-padel-primary mx-auto mb-1" />
              <p className="text-xl font-bold text-white">{openMatches.length}</p>
              <p className="text-xs text-slate-400">Partidos</p>
            </CardContent>
          </Card>
        </div>

        {/* Venues */}
        <section>
          <div className="flex items-center justify-between mb-3">
            <h2 className="text-lg font-semibold text-white">Clubes</h2>
            <Button
              variant="ghost"
              size="sm"
              className="text-padel-primary hover:text-padel-primary/80"
              onClick={() => navigate('/venues')}
            >
              Ver todos <ChevronRight className="w-4 h-4 ml-1" />
            </Button>
          </div>
          {loading ? (
            <div className="text-slate-400 text-sm">Cargando clubes...</div>
          ) : venueList.length === 0 ? (
            <Card className="bg-padel-surface border-padel-surface">
              <CardContent className="p-6 text-center text-slate-400">
                No hay clubes disponibles
              </CardContent>
            </Card>
          ) : (
            <div className="grid gap-3 sm:grid-cols-2">
              {venueList.slice(0, 4).map((venue) => (
                <Card
                  key={venue.id}
                  className="bg-padel-surface border-padel-surface hover:border-padel-primary/50 transition-colors cursor-pointer"
                  onClick={() => navigate(`/venues/${venue.id}`)}
                >
                  <CardContent className="p-4">
                    <h3 className="font-semibold text-white">{venue.nombre || venue.name}</h3>
                    <div className="flex items-center gap-1 mt-1 text-sm text-slate-400">
                      <MapPin className="w-3.5 h-3.5" />
                      <span>{venue.ubicacion || venue.location || 'Sin ubicación'}</span>
                    </div>
                    <div className="flex items-center gap-1 mt-1 text-sm text-slate-400">
                      <Building2 className="w-3.5 h-3.5" />
                      <span>{venue.court_count ?? venue.pistas?.length ?? '—'} pistas</span>
                    </div>
                  </CardContent>
                </Card>
              ))}
            </div>
          )}
        </section>

        {/* Upcoming Bookings */}
        <section>
          <div className="flex items-center justify-between mb-3">
            <h2 className="text-lg font-semibold text-white">Próximas reservas</h2>
            <Button
              variant="ghost"
              size="sm"
              className="text-padel-primary hover:text-padel-primary/80"
              onClick={() => navigate('/my-bookings')}
            >
              Ver todas <ChevronRight className="w-4 h-4 ml-1" />
            </Button>
          </div>
          {loading ? (
            <div className="text-slate-400 text-sm">Cargando reservas...</div>
          ) : upcomingBookings.length === 0 ? (
            <Card className="bg-padel-surface border-padel-surface">
              <CardContent className="p-6 text-center text-slate-400">
                No tienes reservas próximas
              </CardContent>
            </Card>
          ) : (
            <div className="space-y-3">
              {upcomingBookings.map((booking) => (
                <Card
                  key={booking.id}
                  className="bg-padel-surface border-padel-surface hover:border-padel-primary/50 transition-colors cursor-pointer"
                  onClick={() => navigate('/my-bookings')}
                >
                  <CardContent className="p-4 flex items-center justify-between">
                    <div>
                      <h3 className="font-semibold text-white">
                        {booking.venue_name || booking.pista_name || 'Reserva'}
                      </h3>
                      <div className="flex items-center gap-1 mt-1 text-sm text-slate-400">
                        <Clock className="w-3.5 h-3.5" />
                        <span>
                          {booking.fecha || booking.date}{' '}
                          {booking.hora_inicio || booking.start_time}
                        </span>
                      </div>
                    </div>
                    <Badge className="bg-padel-primary/20 text-padel-primary border-0">
                      {booking.status || 'Confirmada'}
                    </Badge>
                  </CardContent>
                </Card>
              ))}
            </div>
          )}
        </section>

        {/* Open Matches */}
        <section>
          <div className="flex items-center justify-between mb-3">
            <h2 className="text-lg font-semibold text-white">Partidos abiertos</h2>
            <Button
              variant="ghost"
              size="sm"
              className="text-padel-primary hover:text-padel-primary/80"
              onClick={() => navigate('/matches')}
            >
              Ver todos <ChevronRight className="w-4 h-4 ml-1" />
            </Button>
          </div>
          {loading ? (
            <div className="text-slate-400 text-sm">Cargando partidos...</div>
          ) : openMatches.length === 0 ? (
            <Card className="bg-padel-surface border-padel-surface">
              <CardContent className="p-6 text-center text-slate-400">
                No hay partidos abiertos
              </CardContent>
            </Card>
          ) : (
            <div className="space-y-3">
              {openMatches.slice(0, 3).map((match) => (
                <Card
                  key={match.id}
                  className="bg-padel-surface border-padel-surface hover:border-padel-primary/50 transition-colors cursor-pointer"
                  onClick={() => navigate(`/matches/${match.id}`)}
                >
                  <CardContent className="p-4">
                    <div className="flex items-center justify-between">
                      <div>
                        <h3 className="font-semibold text-white">
                          {match.venue_name || match.titulo || 'Partido'}
                        </h3>
                        <div className="flex items-center gap-1 mt-1 text-sm text-slate-400">
                          <Calendar className="w-3.5 h-3.5" />
                          <span>
                            {match.fecha || match.date}{' '}
                            {match.hora || match.time}
                          </span>
                        </div>
                      </div>
                      <div className="flex items-center gap-2">
                        <div className="flex items-center gap-1 text-sm text-slate-400">
                          <Users className="w-4 h-4" />
                          <span>
                            {match.player_count ?? match.jugadores?.length ?? 0}/4
                          </span>
                        </div>
                        <Badge className="bg-green-500/20 text-green-400 border-0">
                          Abierto
                        </Badge>
                      </div>
                    </div>
                  </CardContent>
                </Card>
              ))}
            </div>
          )}
        </section>
      </div>
    </div>
  );
}
