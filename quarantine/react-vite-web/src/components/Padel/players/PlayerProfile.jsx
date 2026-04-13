import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { User, Star, Heart, Trophy, Target } from 'lucide-react';
import Button from '../../ui/button';
import { Card, CardContent } from '../../ui/card';
import Badge, { LevelBadge } from '../../ui/badge';
import Input, { Select } from '../../ui/input';
import { Dialog, DialogContent } from '../../ui/dialog';
import { usePadelPlayers } from '../hooks/usePadelPlayers';
import { useAuth } from '../../../contexts/AuthContext';

function StarRating({ value, onChange, readonly = false, size = 'md' }) {
  const [hovered, setHovered] = useState(0);
  const sizeClass = size === 'sm' ? 'w-4 h-4' : 'w-5 h-5';

  return (
    <div className="flex gap-0.5">
      {[1, 2, 3, 4, 5].map((star) => (
        <Star
          key={star}
          className={`${sizeClass} cursor-${readonly ? 'default' : 'pointer'} transition-colors ${
            star <= (hovered || value)
              ? 'fill-yellow-400 text-yellow-400'
              : 'text-slate-500'
          }`}
          onMouseEnter={() => !readonly && setHovered(star)}
          onMouseLeave={() => !readonly && setHovered(0)}
          onClick={() => !readonly && onChange?.(star)}
        />
      ))}
    </div>
  );
}

export default function PlayerProfile() {
  const { id } = useParams();
  const navigate = useNavigate();
  const { user } = useAuth();
  const { getPlayer, ratePlayer, toggleFavorite, updateProfile } = usePadelPlayers();

  const [player, setPlayer] = useState(null);
  const [ratings, setRatings] = useState([]);
  const [loading, setLoading] = useState(true);
  const [isFavorited, setIsFavorited] = useState(false);

  // Edit dialog state
  const [editOpen, setEditOpen] = useState(false);
  const [editForm, setEditForm] = useState({
    display_name: '',
    preferred_side: '',
    bio: '',
    is_available: true,
  });

  // Rate dialog state
  const [rateOpen, setRateOpen] = useState(false);
  const [rateValue, setRateValue] = useState(0);
  const [rateComment, setRateComment] = useState('');

  const isOwnProfile = user?.id === player?.user_id;

  useEffect(() => {
    async function fetchPlayer() {
      setLoading(true);
      try {
        const data = await getPlayer(id);
        setPlayer(data.player);
        setRatings(data.ratings || []);
        setIsFavorited(data.player?.is_favorited || false);
        setEditForm({
          display_name: data.player?.display_name || '',
          preferred_side: data.player?.preferred_side || '',
          bio: data.player?.bio || '',
          is_available: data.player?.is_available ?? true,
        });
      } catch (err) {
        console.error('Error fetching player:', err);
      } finally {
        setLoading(false);
      }
    }
    if (id) fetchPlayer();
  }, [id]);

  async function handleUpdateProfile() {
    try {
      await updateProfile(editForm);
      setPlayer((prev) => ({ ...prev, ...editForm }));
      setEditOpen(false);
    } catch (err) {
      console.error('Error updating profile:', err);
    }
  }

  async function handleRate() {
    if (rateValue === 0) return;
    try {
      await ratePlayer(id, { rating: rateValue, comment: rateComment });
      const data = await getPlayer(id);
      setPlayer(data.player);
      setRatings(data.ratings || []);
      setRateOpen(false);
      setRateValue(0);
      setRateComment('');
    } catch (err) {
      console.error('Error rating player:', err);
    }
  }

  async function handleToggleFavorite() {
    try {
      await toggleFavorite(player.user_id);
      setIsFavorited((prev) => !prev);
    } catch (err) {
      console.error('Error toggling favorite:', err);
    }
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-[400px]">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-teal-400" />
      </div>
    );
  }

  if (!player) {
    return (
      <div className="text-center py-16 text-slate-400">
        <User className="w-12 h-12 mx-auto mb-4 opacity-50" />
        <p>Jugador no encontrado</p>
      </div>
    );
  }

  return (
    <div className="max-w-3xl mx-auto space-y-6">
      {/* Player Header */}
      <Card>
        <CardContent className="p-6">
          <div className="flex items-start justify-between">
            <div className="flex items-center gap-4">
              <div className="w-16 h-16 rounded-full bg-slate-700 flex items-center justify-center">
                <User className="w-8 h-8 text-slate-400" />
              </div>
              <div>
                <h1 className="text-2xl font-bold text-white">
                  {player.display_name}
                </h1>
                <div className="flex items-center gap-2 mt-1">
                  <LevelBadge level={player.level} />
                  {player.preferred_side && (
                    <Badge>{player.preferred_side}</Badge>
                  )}
                  <span
                    className={`inline-flex items-center gap-1 text-sm ${
                      player.is_available ? 'text-teal-400' : 'text-slate-500'
                    }`}
                  >
                    <span
                      className={`w-2 h-2 rounded-full ${
                        player.is_available ? 'bg-teal-400' : 'bg-slate-500'
                      }`}
                    />
                    {player.is_available ? 'Disponible' : 'No disponible'}
                  </span>
                </div>
              </div>
            </div>

            <div className="flex gap-2">
              {isOwnProfile ? (
                <Button onClick={() => setEditOpen(true)}>Editar perfil</Button>
              ) : (
                <>
                  <Button onClick={() => setRateOpen(true)}>
                    <Star className="w-4 h-4 mr-1" />
                    Valorar
                  </Button>
                  <Button
                    variant="ghost"
                    onClick={handleToggleFavorite}
                    className="p-2"
                  >
                    <Heart
                      className={`w-5 h-5 transition-colors ${
                        isFavorited
                          ? 'fill-red-500 text-red-500'
                          : 'text-slate-400'
                      }`}
                    />
                  </Button>
                </>
              )}
            </div>
          </div>

          {player.bio && (
            <p className="mt-4 text-slate-300">{player.bio}</p>
          )}

          {/* Stats */}
          <div className="grid grid-cols-3 gap-4 mt-6">
            <div className="bg-slate-700/50 rounded-lg p-4 text-center">
              <Trophy className="w-5 h-5 text-teal-400 mx-auto mb-1" />
              <p className="text-2xl font-bold text-white">
                {player.matches_played || 0}
              </p>
              <p className="text-sm text-slate-400">Partidos jugados</p>
            </div>
            <div className="bg-slate-700/50 rounded-lg p-4 text-center">
              <Target className="w-5 h-5 text-teal-400 mx-auto mb-1" />
              <p className="text-2xl font-bold text-white">
                {player.matches_won || 0}
              </p>
              <p className="text-sm text-slate-400">Partidos ganados</p>
            </div>
            <div className="bg-slate-700/50 rounded-lg p-4 text-center">
              <Star className="w-5 h-5 text-yellow-400 mx-auto mb-1" />
              <div className="flex items-center justify-center gap-1">
                <p className="text-2xl font-bold text-white">
                  {player.avg_rating ? player.avg_rating.toFixed(1) : '-'}
                </p>
              </div>
              <div className="flex justify-center mt-1">
                <StarRating
                  value={Math.round(player.avg_rating || 0)}
                  readonly
                  size="sm"
                />
              </div>
              <p className="text-sm text-slate-400">Valoración media</p>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Recent Ratings */}
      <Card>
        <CardContent className="p-6">
          <h2 className="text-lg font-semibold text-white mb-4">
            Valoraciones recientes
          </h2>
          {ratings.length === 0 ? (
            <p className="text-slate-400 text-center py-8">
              Aún no tiene valoraciones
            </p>
          ) : (
            <div className="space-y-4">
              {ratings.map((rating, idx) => (
                <div
                  key={rating.id || idx}
                  className="border-b border-slate-700 last:border-0 pb-4 last:pb-0"
                >
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <div className="w-8 h-8 rounded-full bg-slate-700 flex items-center justify-center">
                        <User className="w-4 h-4 text-slate-400" />
                      </div>
                      <span className="text-white font-medium">
                        {rating.rater_name || 'Anónimo'}
                      </span>
                    </div>
                    <StarRating value={rating.rating} readonly size="sm" />
                  </div>
                  {rating.comment && (
                    <p className="mt-2 text-slate-300 text-sm ml-10">
                      {rating.comment}
                    </p>
                  )}
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>

      {/* Edit Profile Dialog */}
      <Dialog open={editOpen} onOpenChange={setEditOpen}>
        <DialogContent>
          <h2 className="text-lg font-semibold text-white mb-4">
            Editar perfil
          </h2>
          <div className="space-y-4">
            <div>
              <label className="block text-sm text-slate-300 mb-1">
                Nombre
              </label>
              <Input
                value={editForm.display_name}
                onChange={(e) =>
                  setEditForm((prev) => ({
                    ...prev,
                    display_name: e.target.value,
                  }))
                }
                placeholder="Tu nombre"
              />
            </div>
            <div>
              <label className="block text-sm text-slate-300 mb-1">
                Lado preferido
              </label>
              <Select
                value={editForm.preferred_side}
                onChange={(e) =>
                  setEditForm((prev) => ({
                    ...prev,
                    preferred_side: e.target.value,
                  }))
                }
              >
                <option value="">Sin preferencia</option>
                <option value="derecha">Derecha</option>
                <option value="revés">Revés</option>
                <option value="ambos">Ambos</option>
              </Select>
            </div>
            <div>
              <label className="block text-sm text-slate-300 mb-1">Bio</label>
              <Input
                value={editForm.bio}
                onChange={(e) =>
                  setEditForm((prev) => ({ ...prev, bio: e.target.value }))
                }
                placeholder="Cuéntanos sobre ti..."
              />
            </div>
            <div className="flex items-center gap-2">
              <input
                type="checkbox"
                id="available"
                checked={editForm.is_available}
                onChange={(e) =>
                  setEditForm((prev) => ({
                    ...prev,
                    is_available: e.target.checked,
                  }))
                }
                className="rounded border-slate-600 bg-slate-700 text-teal-500"
              />
              <label htmlFor="available" className="text-sm text-slate-300">
                Disponible para jugar
              </label>
            </div>
            <div className="flex justify-end gap-2 pt-2">
              <Button variant="ghost" onClick={() => setEditOpen(false)}>
                Cancelar
              </Button>
              <Button onClick={handleUpdateProfile}>Guardar</Button>
            </div>
          </div>
        </DialogContent>
      </Dialog>

      {/* Rate Player Dialog */}
      <Dialog open={rateOpen} onOpenChange={setRateOpen}>
        <DialogContent>
          <h2 className="text-lg font-semibold text-white mb-4">
            Valorar jugador
          </h2>
          <div className="space-y-4">
            <div className="flex justify-center">
              <StarRating value={rateValue} onChange={setRateValue} />
            </div>
            <div>
              <label className="block text-sm text-slate-300 mb-1">
                Comentario (opcional)
              </label>
              <Input
                value={rateComment}
                onChange={(e) => setRateComment(e.target.value)}
                placeholder="Escribe un comentario..."
              />
            </div>
            <div className="flex justify-end gap-2 pt-2">
              <Button variant="ghost" onClick={() => setRateOpen(false)}>
                Cancelar
              </Button>
              <Button onClick={handleRate} disabled={rateValue === 0}>
                Enviar valoración
              </Button>
            </div>
          </div>
        </DialogContent>
      </Dialog>
    </div>
  );
}
