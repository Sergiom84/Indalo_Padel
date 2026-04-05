import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Search, Users, Filter, Star } from 'lucide-react';
import Button from '../../ui/button';
import { Card, CardContent } from '../../ui/card';
import Badge, { LevelBadge } from '../../ui/badge';
import Input, { Select } from '../../ui/input';
import { usePadelPlayers } from '../hooks/usePadelPlayers';

function PlayerCard({ player, onClick }) {
  return (
    <Card
      className="cursor-pointer hover:border-teal-500/50 transition-colors"
      onClick={onClick}
    >
      <CardContent className="p-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-full bg-slate-700 flex items-center justify-center">
              <Users className="w-5 h-5 text-slate-400" />
            </div>
            <div>
              <h3 className="text-white font-medium">
                {player.display_name || player.nombre}
              </h3>
              <div className="flex items-center gap-2 mt-1">
                <LevelBadge level={player.level} />
                {player.preferred_side && (
                  <Badge variant="outline">{player.preferred_side}</Badge>
                )}
              </div>
            </div>
          </div>

          <div className="flex flex-col items-end gap-1">
            {player.avg_rating != null && (
              <div className="flex items-center gap-1">
                <Star className="w-4 h-4 fill-yellow-400 text-yellow-400" />
                <span className="text-sm text-white font-medium">
                  {player.avg_rating.toFixed(1)}
                </span>
              </div>
            )}
            <span
              className={`inline-flex items-center gap-1 text-xs ${
                player.is_available ? 'text-teal-400' : 'text-slate-500'
              }`}
            >
              <span
                className={`w-1.5 h-1.5 rounded-full ${
                  player.is_available ? 'bg-teal-400' : 'bg-slate-500'
                }`}
              />
              {player.is_available ? 'Disponible' : 'No disponible'}
            </span>
          </div>
        </div>
      </CardContent>
    </Card>
  );
}

export default function PlayerSearch() {
  const navigate = useNavigate();
  const { searchPlayers } = usePadelPlayers();

  const [name, setName] = useState('');
  const [level, setLevel] = useState('');
  const [available, setAvailable] = useState(false);
  const [players, setPlayers] = useState([]);
  const [loading, setLoading] = useState(false);
  const [showFilters, setShowFilters] = useState(false);

  useEffect(() => {
    const timeout = setTimeout(() => {
      fetchPlayers();
    }, 300);
    return () => clearTimeout(timeout);
  }, [name, level, available]);

  async function fetchPlayers() {
    setLoading(true);
    try {
      const params = {};
      if (name.trim()) params.name = name.trim();
      if (level) params.level = parseInt(level);
      if (available) params.available = true;
      const results = await searchPlayers(params);
      setPlayers(results || []);
    } catch (err) {
      console.error('Error searching players:', err);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="max-w-3xl mx-auto space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-white flex items-center gap-2">
          <Users className="w-6 h-6 text-teal-400" />
          Buscar jugadores
        </h1>
        <Button
          variant="ghost"
          onClick={() => setShowFilters((prev) => !prev)}
          className="flex items-center gap-1"
        >
          <Filter className="w-4 h-4" />
          Filtros
        </Button>
      </div>

      {/* Search Input */}
      <div className="relative">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
        <Input
          value={name}
          onChange={(e) => setName(e.target.value)}
          placeholder="Buscar por nombre..."
          className="pl-10"
        />
      </div>

      {/* Filters */}
      {showFilters && (
        <Card>
          <CardContent className="p-4">
            <div className="flex flex-wrap gap-4 items-end">
              <div className="flex-1 min-w-[150px]">
                <label className="block text-sm text-slate-300 mb-1">
                  Nivel
                </label>
                <Select
                  value={level}
                  onChange={(e) => setLevel(e.target.value)}
                >
                  <option value="">Todos los niveles</option>
                  {[1, 2, 3, 4, 5, 6, 7, 8, 9].map((l) => (
                    <option key={l} value={l}>
                      Nivel {l}
                    </option>
                  ))}
                </Select>
              </div>
              <div className="flex items-center gap-2">
                <input
                  type="checkbox"
                  id="filterAvailable"
                  checked={available}
                  onChange={(e) => setAvailable(e.target.checked)}
                  className="rounded border-slate-600 bg-slate-700 text-teal-500"
                />
                <label
                  htmlFor="filterAvailable"
                  className="text-sm text-slate-300"
                >
                  Solo disponibles
                </label>
              </div>
            </div>
          </CardContent>
        </Card>
      )}

      {/* Results */}
      {loading ? (
        <div className="flex items-center justify-center py-12">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-teal-400" />
        </div>
      ) : players.length === 0 ? (
        <div className="text-center py-16 text-slate-400">
          <Users className="w-12 h-12 mx-auto mb-4 opacity-50" />
          <p>No se encontraron jugadores</p>
        </div>
      ) : (
        <div className="space-y-2">
          {players.map((player) => (
            <PlayerCard
              key={player.user_id || player.id}
              player={player}
              onClick={() => navigate(`/players/${player.user_id || player.id}`)}
            />
          ))}
        </div>
      )}
    </div>
  );
}
