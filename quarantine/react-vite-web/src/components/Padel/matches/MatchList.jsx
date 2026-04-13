import React, { useState, useEffect, useMemo } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { Trophy, Users, Plus, Filter, Calendar, MapPin, Clock } from 'lucide-react';
import { format, parseISO } from 'date-fns';
import { es } from 'date-fns/locale';

import Button from '../../ui/button';
import { Card, CardContent, CardHeader, CardFooter } from '../../ui/card';
import Badge, { LevelBadge } from '../../ui/badge';
import Input, { Select } from '../../ui/input';
import { usePadelMatches } from '../hooks/usePadelMatches';
import apiClient from '../../../lib/apiClient';

const statusConfig = {
  buscando: { label: 'Buscando', variant: 'warning' },
  completo: { label: 'Completo', variant: 'success' },
  en_juego: { label: 'En juego', variant: 'info' },
  finalizado: { label: 'Finalizado', variant: 'default' },
  cancelado: { label: 'Cancelado', variant: 'danger' },
};

function MatchCard({ match }) {
  const navigate = useNavigate();
  const status = statusConfig[match.status] || statusConfig.buscando;
  const matchDate = parseISO(match.match_date);

  return (
    <Card
      className="cursor-pointer hover:border-padel-accent/50 transition-colors"
      onClick={() => navigate(`/matches/${match.id}`)}
    >
      <CardHeader className="flex flex-row items-center justify-between">
        <div className="flex items-center gap-2">
          <Trophy className="h-5 w-5 text-padel-accent" />
          <span className="font-semibold text-white">
            {format(matchDate, "EEE d MMM", { locale: es })}
          </span>
        </div>
        <Badge variant={status.variant}>{status.label}</Badge>
      </CardHeader>

      <CardContent className="space-y-3">
        <div className="flex items-center gap-2 text-slate-300">
          <Clock className="h-4 w-4 text-slate-400" />
          <span>{match.start_time?.slice(0, 5)}</span>
        </div>

        <div className="flex items-center gap-2 text-slate-300">
          <MapPin className="h-4 w-4 text-slate-400" />
          <span>{match.venue_name || 'Sin sede'}</span>
        </div>

        <div className="flex items-center gap-2 text-slate-300">
          <Users className="h-4 w-4 text-slate-400" />
          <span>{match.player_count ?? 0} / {match.max_players ?? 4}</span>
        </div>

        <div className="flex items-center gap-2">
          <LevelBadge level={match.min_level} />
          <span className="text-slate-400">-</span>
          <LevelBadge level={match.max_level} />
        </div>

        {match.creator_name && (
          <p className="text-sm text-slate-400">
            Creado por <span className="text-padel-accent">{match.creator_name}</span>
          </p>
        )}
      </CardContent>
    </Card>
  );
}

export default function MatchList() {
  const { getMatches } = usePadelMatches();
  const [matches, setMatches] = useState([]);
  const [venues, setVenues] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showFilters, setShowFilters] = useState(false);

  const [filterVenue, setFilterVenue] = useState('');
  const [filterDate, setFilterDate] = useState('');

  useEffect(() => {
    async function fetchData() {
      try {
        const [matchesData, venuesRes] = await Promise.all([
          getMatches(),
          apiClient.get('/padel/venues'),
        ]);
        setMatches(matchesData);
        setVenues(venuesRes.data ?? venuesRes);
      } catch (err) {
        console.error('Error cargando partidos:', err);
      } finally {
        setLoading(false);
      }
    }
    fetchData();
  }, []);

  const filteredMatches = useMemo(() => {
    return matches.filter((m) => {
      if (filterVenue && String(m.venue_id) !== filterVenue) return false;
      if (filterDate && m.match_date?.slice(0, 10) !== filterDate) return false;
      return true;
    });
  }, [matches, filterVenue, filterDate]);

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-white flex items-center gap-2">
          <Trophy className="h-7 w-7 text-padel-accent" />
          Partidos
        </h1>
        <div className="flex gap-2">
          <Button
            variant="ghost"
            size="sm"
            onClick={() => setShowFilters((v) => !v)}
          >
            <Filter className="h-4 w-4 mr-1" />
            Filtros
          </Button>
          <Link to="/matches/create">
            <Button size="sm">
              <Plus className="h-4 w-4 mr-1" />
              Nuevo partido
            </Button>
          </Link>
        </div>
      </div>

      {/* Filters */}
      {showFilters && (
        <Card>
          <CardContent className="flex flex-wrap gap-4 py-4">
            <div className="w-48">
              <Select
                label="Sede"
                value={filterVenue}
                onChange={(e) => setFilterVenue(e.target.value)}
              >
                <option value="">Todas las sedes</option>
                {venues.map((v) => (
                  <option key={v.id} value={v.id}>
                    {v.name}
                  </option>
                ))}
              </Select>
            </div>
            <div className="w-48">
              <Input
                label="Fecha"
                type="date"
                value={filterDate}
                onChange={(e) => setFilterDate(e.target.value)}
              />
            </div>
            <div className="flex items-end">
              <Button
                variant="ghost"
                size="sm"
                onClick={() => {
                  setFilterVenue('');
                  setFilterDate('');
                }}
              >
                Limpiar
              </Button>
            </div>
          </CardContent>
        </Card>
      )}

      {/* Match grid */}
      {loading ? (
        <div className="text-center py-12 text-slate-400">Cargando partidos...</div>
      ) : filteredMatches.length === 0 ? (
        <div className="text-center py-12 text-slate-400">
          <Trophy className="h-12 w-12 mx-auto mb-3 opacity-40" />
          <p>No se encontraron partidos</p>
          <Link to="/matches/create" className="text-padel-accent hover:underline text-sm mt-2 inline-block">
            Crea el primero
          </Link>
        </div>
      ) : (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {filteredMatches.map((match) => (
            <MatchCard key={match.id} match={match} />
          ))}
        </div>
      )}
    </div>
  );
}
