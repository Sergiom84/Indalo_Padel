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
  Zap,
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
      <div className="max-w-4xl mx-auto px-4 pb-24 md:pb-8 space-y-8">

        {/* Hero header */}
        <div className="pt-6 sm:pt-8">
          <p className="text-label mb-1">Bienvenido de vuelta</p>
          <h1 className="text-3xl sm:text-4xl font-black text-white font-display tracking-tight">
            {user?.nombre || user?.name || 'Jugador'}{' '}
            <span className="text-padel-primary">👋</span>
          </h1>
        </div>

        {/* Quick actions */}
        <div className="grid grid-cols-2 gap-3">
          <button
            onClick={() => navigate('/venues')}
            className="flex items-center gap-3 bg-padel-primary rounded-2xl p-4 text-left active:scale-95 transition-transform"
          >
            <div className="w-10 h-10 bg-padel-dark/20 rounded-xl flex items-center justify-center shrink-0">
              <Calendar className="w-5 h-5 text-padel-dark" strokeWidth={2.5} />
            </div>
            <div>
              <p className="font-black text-padel-dark text-sm leading-tight">Reservar</p>
              <p className="text-padel-dark/60 text-xs font-medium">pista ahora</p>
            </div>
          </button>
          <button
            onClick={() => navigate('/matches')}
            className="flex items-center gap-3 bg-padel-surface border border-padel-border rounded-2xl p-4 text-left hover:border-padel-primary/40 active:scale-95 transition-all"
          >
            <div className="w-10 h-10 bg-padel-primary/15 rounded-xl flex items-center justify-center shrink-0">
              <Users className="w-5 h-5 text-padel-primary" strokeWidth={2.5} />
            </div>
            <div>
              <p className="font-black text-white text-sm leading-tight">Unirse</p>
              <p className="text-padel-muted text-xs font-medium">a un partido</p>
            </div>
          </button>
        </div>

        {/* Stats row */}
        <div className="grid grid-cols-3 gap-3">
          {[
            { icon: Building2, value: venueList.length, label: 'Clubes', route: '/venues' },
            { icon: Calendar, value: upcomingBookings.length, label: 'Reservas', route: '/my-bookings' },
            { icon: Trophy, value: openMatches.length, label: 'Partidos', route: '/matches' },
          ].map(({ icon: Icon, value, label, route }) => (
            <button
              key={label}
              onClick={() => navigate(route)}
              className="bg-padel-surface border border-padel-border rounded-2xl p-4 text-center hover:border-padel-primary/40 active:scale-95 transition-all duration-200"
            >
              <Icon className="w-5 h-5 text-padel-primary mx-auto mb-2" strokeWidth={2} />
              <p className="text-2xl font-black text-white">{loading ? '—' : value}</p>
              <p className="text-[11px] font-semibold text-padel-muted mt-0.5">{label}</p>
            </button>
          ))}
        </div>

        {/* Venues */}
        <section>
          <div className="section-header">
            <h2 className="section-title">Clubes</h2>
            <button className="section-link" onClick={() => navigate('/venues')}>
              Ver todos <ChevronRight className="w-4 h-4" />
            </button>
          </div>
          {loading ? (
            <div className="grid gap-3 sm:grid-cols-2">
              {[1, 2].map(i => (
                <div key={i} className="bg-padel-surface border border-padel-border rounded-2xl h-24 animate-pulse" />
              ))}
            </div>
          ) : venueList.length === 0 ? (
            <Card>
              <CardContent className="py-8 text-center text-padel-muted">
                No hay clubes disponibles
              </CardContent>
            </Card>
          ) : (
            <div className="grid gap-3 sm:grid-cols-2">
              {venueList.slice(0, 4).map((venue) => (
                <div
                  key={venue.id}
                  className="bg-padel-surface border border-padel-border rounded-2xl p-4 hover:border-padel-primary/40 hover:bg-padel-surface2 transition-all duration-200 cursor-pointer"
                  onClick={() => navigate(`/venues/${venue.id}`)}
                >
                  <div className="flex items-start justify-between">
                    <div className="flex-1 min-w-0">
                      <h3 className="font-bold text-white truncate">{venue.nombre || venue.name}</h3>
                      <div className="flex items-center gap-1.5 mt-1.5 text-sm text-padel-muted">
                        <MapPin className="w-3.5 h-3.5 shrink-0" />
                        <span className="truncate">{venue.ubicacion || venue.location || 'Sin ubicación'}</span>
                      </div>
                    </div>
                    <Badge variant="default" className="ml-2 shrink-0">
                      {venue.court_count ?? venue.pistas?.length ?? '—'} pistas
                    </Badge>
                  </div>
                </div>
              ))}
            </div>
          )}
        </section>

        {/* Upcoming Bookings */}
        <section>
          <div className="section-header">
            <h2 className="section-title">Próximas reservas</h2>
            <button className="section-link" onClick={() => navigate('/my-bookings')}>
              Ver todas <ChevronRight className="w-4 h-4" />
            </button>
          </div>
          {loading ? (
            <div className="space-y-3">
              {[1, 2].map(i => (
                <div key={i} className="bg-padel-surface border border-padel-border rounded-2xl h-20 animate-pulse" />
              ))}
            </div>
          ) : upcomingBookings.length === 0 ? (
            <Card>
              <CardContent className="py-8 text-center">
                <Calendar className="w-8 h-8 text-padel-border mx-auto mb-2" />
                <p className="text-padel-muted text-sm">No tienes reservas próximas</p>
                <Button
                  size="sm"
                  className="mt-3"
                  onClick={() => navigate('/venues')}
                >
                  Reservar ahora
                </Button>
              </CardContent>
            </Card>
          ) : (
            <div className="space-y-3">
              {upcomingBookings.map((booking) => (
                <div
                  key={booking.id}
                  className="bg-padel-surface border border-padel-border rounded-2xl p-4 flex items-center justify-between hover:border-padel-primary/40 hover:bg-padel-surface2 transition-all duration-200 cursor-pointer"
                  onClick={() => navigate('/my-bookings')}
                >
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 bg-padel-primary/15 rounded-xl flex items-center justify-center shrink-0">
                      <Calendar className="w-5 h-5 text-padel-primary" />
                    </div>
                    <div>
                      <h3 className="font-bold text-white text-sm">
                        {booking.venue_name || booking.pista_name || 'Reserva'}
                      </h3>
                      <div className="flex items-center gap-1.5 mt-0.5 text-xs text-padel-muted">
                        <Clock className="w-3 h-3" />
                        <span>
                          {booking.fecha || booking.date}{' '}
                          {booking.hora_inicio || booking.start_time}
                        </span>
                      </div>
                    </div>
                  </div>
                  <Badge variant="success">{booking.status || 'Confirmada'}</Badge>
                </div>
              ))}
            </div>
          )}
        </section>

        {/* Open Matches */}
        <section>
          <div className="section-header">
            <h2 className="section-title">Partidos abiertos</h2>
            <button className="section-link" onClick={() => navigate('/matches')}>
              Ver todos <ChevronRight className="w-4 h-4" />
            </button>
          </div>
          {loading ? (
            <div className="space-y-3">
              {[1, 2].map(i => (
                <div key={i} className="bg-padel-surface border border-padel-border rounded-2xl h-20 animate-pulse" />
              ))}
            </div>
          ) : openMatches.length === 0 ? (
            <Card>
              <CardContent className="py-8 text-center">
                <Trophy className="w-8 h-8 text-padel-border mx-auto mb-2" />
                <p className="text-padel-muted text-sm">No hay partidos abiertos</p>
                <Button
                  size="sm"
                  variant="outline"
                  className="mt-3"
                  onClick={() => navigate('/matches')}
                >
                  Crear partido
                </Button>
              </CardContent>
            </Card>
          ) : (
            <div className="space-y-3">
              {openMatches.slice(0, 3).map((match) => (
                <div
                  key={match.id}
                  className="bg-padel-surface border border-padel-border rounded-2xl p-4 hover:border-padel-primary/40 hover:bg-padel-surface2 transition-all duration-200 cursor-pointer"
                  onClick={() => navigate(`/matches/${match.id}`)}
                >
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-3">
                      <div className="w-10 h-10 bg-padel-primary/15 rounded-xl flex items-center justify-center shrink-0">
                        <Zap className="w-5 h-5 text-padel-primary" strokeWidth={2.5} />
                      </div>
                      <div>
                        <h3 className="font-bold text-white text-sm">
                          {match.venue_name || match.titulo || 'Partido'}
                        </h3>
                        <div className="flex items-center gap-1.5 mt-0.5 text-xs text-padel-muted">
                          <Calendar className="w-3 h-3" />
                          <span>{match.fecha || match.date} {match.hora || match.time}</span>
                        </div>
                      </div>
                    </div>
                    <div className="flex flex-col items-end gap-1.5">
                      <Badge variant="success">Abierto</Badge>
                      <div className="flex items-center gap-1 text-xs text-padel-muted">
                        <Users className="w-3 h-3" />
                        <span className="font-semibold">
                          {match.player_count ?? match.jugadores?.length ?? 0}/4
                        </span>
                      </div>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </section>

      </div>
    </div>
  );
}
