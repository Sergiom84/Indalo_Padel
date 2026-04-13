import React, { useState, useEffect } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import {
  Trophy, ArrowLeft, Users, Clock, MapPin, Calendar,
  LogIn, LogOut, Shield, CheckCircle, Play, XCircle, Info,
} from 'lucide-react';
import { format, parseISO } from 'date-fns';
import { es } from 'date-fns/locale';

import Button from '../../ui/button';
import { Card, CardContent, CardHeader, CardFooter } from '../../ui/card';
import Badge, { LevelBadge } from '../../ui/badge';
import { usePadelMatches } from '../hooks/usePadelMatches';
import { useAuth } from '../../../contexts/AuthContext';

const statusConfig = {
  buscando: { label: 'Buscando jugadores', variant: 'warning', icon: Users },
  completo: { label: 'Completo', variant: 'success', icon: CheckCircle },
  en_juego: { label: 'En juego', variant: 'info', icon: Play },
  finalizado: { label: 'Finalizado', variant: 'default', icon: Trophy },
  cancelado: { label: 'Cancelado', variant: 'danger', icon: XCircle },
};

const statusTransitions = [
  { value: 'completo', label: 'Marcar completo', icon: CheckCircle },
  { value: 'en_juego', label: 'Iniciar partido', icon: Play },
  { value: 'finalizado', label: 'Finalizar', icon: Trophy },
  { value: 'cancelado', label: 'Cancelar', icon: XCircle },
];

function PlayerSlot({ player }) {
  if (!player) {
    return (
      <div className="flex items-center gap-3 p-3 rounded-lg border border-dashed border-slate-600 bg-padel-dark/30">
        <div className="h-10 w-10 rounded-full bg-slate-700 flex items-center justify-center">
          <Users className="h-5 w-5 text-slate-500" />
        </div>
        <span className="text-slate-500 italic">Puesto libre</span>
      </div>
    );
  }

  return (
    <div className="flex items-center gap-3 p-3 rounded-lg bg-padel-dark/50 border border-slate-700">
      <div className="h-10 w-10 rounded-full bg-padel-primary/20 flex items-center justify-center text-padel-accent font-bold">
        {player.name?.charAt(0)?.toUpperCase() || '?'}
      </div>
      <div className="flex-1 min-w-0">
        <p className="text-white font-medium truncate">{player.name}</p>
        {player.preferred_side && (
          <p className="text-sm text-slate-400">{player.preferred_side}</p>
        )}
      </div>
      <LevelBadge level={player.level} />
    </div>
  );
}

function TeamSection({ title, players, maxPerTeam = 2 }) {
  const slots = Array.from({ length: maxPerTeam }, (_, i) => players[i] || null);

  return (
    <div className="space-y-3">
      <h3 className="text-sm font-semibold text-slate-400 uppercase tracking-wider">{title}</h3>
      <div className="space-y-2">
        {slots.map((player, idx) => (
          <PlayerSlot key={player?.id ?? `empty-${idx}`} player={player} />
        ))}
      </div>
    </div>
  );
}

export default function MatchDetail() {
  const { id } = useParams();
  const navigate = useNavigate();
  const { user } = useAuth();
  const { getMatch, joinMatch, leaveMatch, updateMatchStatus } = usePadelMatches();

  const [match, setMatch] = useState(null);
  const [players, setPlayers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [actionLoading, setActionLoading] = useState(false);
  const [error, setError] = useState(null);

  async function fetchMatch() {
    try {
      const data = await getMatch(id);
      setMatch(data.match);
      setPlayers(data.players || []);
    } catch (err) {
      console.error('Error cargando partido:', err);
      setError('No se pudo cargar el partido.');
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    fetchMatch();
  }, [id]);

  const isCreator = user?.id && match?.creator_id === user.id;
  const isInMatch = players.some((p) => p.user_id === user?.id);
  const canJoin = !isInMatch && match?.status === 'buscando';

  const team1 = players.filter((p) => p.team === 1);
  const team2 = players.filter((p) => p.team === 2);

  async function handleJoin(team) {
    setActionLoading(true);
    setError(null);
    try {
      await joinMatch(id, team);
      await fetchMatch();
    } catch (err) {
      setError(err?.data?.error || err.message || 'Error al unirse al partido.');
    } finally {
      setActionLoading(false);
    }
  }

  async function handleLeave() {
    setActionLoading(true);
    setError(null);
    try {
      await leaveMatch(id);
      await fetchMatch();
    } catch (err) {
      setError(err?.data?.error || err.message || 'Error al salir del partido.');
    } finally {
      setActionLoading(false);
    }
  }

  async function handleStatusChange(newStatus) {
    setActionLoading(true);
    setError(null);
    try {
      await updateMatchStatus(id, newStatus);
      await fetchMatch();
    } catch (err) {
      setError(err?.data?.error || err.message || 'Error al cambiar el estado.');
    } finally {
      setActionLoading(false);
    }
  }

  if (loading) {
    return (
      <div className="text-center py-12 text-slate-400">Cargando partido...</div>
    );
  }

  if (!match) {
    return (
      <div className="text-center py-12 space-y-4">
        <Trophy className="h-12 w-12 mx-auto text-slate-500" />
        <p className="text-slate-400">{error || 'Partido no encontrado'}</p>
        <Link to="/matches">
          <Button variant="ghost" size="sm">Volver a partidos</Button>
        </Link>
      </div>
    );
  }

  const status = statusConfig[match.status] || statusConfig.buscando;
  const StatusIcon = status.icon;
  const matchDate = parseISO(match.match_date);

  return (
    <div className="max-w-3xl mx-auto space-y-6">
      {/* Header */}
      <div className="flex items-center gap-3">
        <Button variant="ghost" size="sm" onClick={() => navigate('/matches')}>
          <ArrowLeft className="h-4 w-4" />
        </Button>
        <h1 className="text-2xl font-bold text-white flex items-center gap-2">
          <Trophy className="h-7 w-7 text-padel-accent" />
          Detalle del partido
        </h1>
      </div>

      {error && (
        <div className="bg-red-500/10 border border-red-500/30 text-red-400 rounded-lg px-4 py-3 text-sm">
          {error}
        </div>
      )}

      {/* Match info */}
      <Card>
        <CardHeader className="flex flex-row items-center justify-between">
          <div className="flex items-center gap-2">
            <StatusIcon className="h-5 w-5 text-padel-accent" />
            <span className="text-lg font-semibold text-white">Informacion del partido</span>
          </div>
          <Badge variant={status.variant}>{status.label}</Badge>
        </CardHeader>

        <CardContent className="space-y-4">
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div className="flex items-center gap-3 text-slate-300">
              <Calendar className="h-5 w-5 text-slate-400" />
              <span>{format(matchDate, "EEEE d 'de' MMMM yyyy", { locale: es })}</span>
            </div>

            <div className="flex items-center gap-3 text-slate-300">
              <Clock className="h-5 w-5 text-slate-400" />
              <span>{match.start_time?.slice(0, 5)}</span>
            </div>

            <div className="flex items-center gap-3 text-slate-300">
              <MapPin className="h-5 w-5 text-slate-400" />
              <span>{match.venue_name || 'Sin sede'}</span>
            </div>

            <div className="flex items-center gap-3 text-slate-300">
              <Shield className="h-5 w-5 text-slate-400" />
              <span className="capitalize">{match.match_type || 'Abierto'}</span>
            </div>
          </div>

          <div className="flex items-center gap-2">
            <span className="text-sm text-slate-400">Nivel:</span>
            <LevelBadge level={match.min_level} />
            <span className="text-slate-500">-</span>
            <LevelBadge level={match.max_level} />
          </div>

          {match.description && (
            <div className="flex gap-2 text-slate-300 pt-2 border-t border-slate-700">
              <Info className="h-5 w-5 text-slate-400 shrink-0 mt-0.5" />
              <p>{match.description}</p>
            </div>
          )}
        </CardContent>
      </Card>

      {/* Players */}
      <Card>
        <CardHeader>
          <h2 className="text-lg font-semibold text-white flex items-center gap-2">
            <Users className="h-5 w-5 text-padel-accent" />
            Jugadores ({players.length} / {match.max_players ?? 4})
          </h2>
        </CardHeader>

        <CardContent>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-6">
            <TeamSection title="Equipo 1" players={team1} />
            <TeamSection title="Equipo 2" players={team2} />
          </div>
        </CardContent>

        <CardFooter className="flex flex-wrap gap-3">
          {/* Join buttons */}
          {canJoin && (
            <>
              <Button
                size="sm"
                disabled={actionLoading || team1.length >= 2}
                onClick={() => handleJoin(1)}
              >
                <LogIn className="h-4 w-4 mr-1" />
                Unirse al equipo 1
              </Button>
              <Button
                size="sm"
                disabled={actionLoading || team2.length >= 2}
                onClick={() => handleJoin(2)}
              >
                <LogIn className="h-4 w-4 mr-1" />
                Unirse al equipo 2
              </Button>
            </>
          )}

          {/* Leave button */}
          {isInMatch && !isCreator && (
            <Button
              variant="ghost"
              size="sm"
              disabled={actionLoading}
              onClick={handleLeave}
            >
              <LogOut className="h-4 w-4 mr-1" />
              Salir del partido
            </Button>
          )}
        </CardFooter>
      </Card>

      {/* Creator actions */}
      {isCreator && (
        <Card>
          <CardHeader>
            <h2 className="text-lg font-semibold text-white flex items-center gap-2">
              <Shield className="h-5 w-5 text-padel-accent" />
              Acciones del organizador
            </h2>
          </CardHeader>
          <CardContent className="flex flex-wrap gap-3">
            {statusTransitions
              .filter((t) => t.value !== match.status)
              .map((transition) => {
                const TransIcon = transition.icon;
                return (
                  <Button
                    key={transition.value}
                    variant="ghost"
                    size="sm"
                    disabled={actionLoading}
                    onClick={() => handleStatusChange(transition.value)}
                  >
                    <TransIcon className="h-4 w-4 mr-1" />
                    {transition.label}
                  </Button>
                );
              })}
          </CardContent>
        </Card>
      )}
    </div>
  );
}
