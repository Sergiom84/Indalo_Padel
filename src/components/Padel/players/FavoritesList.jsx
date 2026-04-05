import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Heart, Star, X } from 'lucide-react';
import Button from '../../ui/button';
import { Card, CardContent } from '../../ui/card';
import Badge, { LevelBadge } from '../../ui/badge';
import { usePadelPlayers } from '../hooks/usePadelPlayers';

export default function FavoritesList() {
  const navigate = useNavigate();
  const { getFavorites, toggleFavorite } = usePadelPlayers();

  const [favorites, setFavorites] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchFavorites();
  }, []);

  async function fetchFavorites() {
    setLoading(true);
    try {
      const data = await getFavorites();
      setFavorites(data.favorites || []);
    } catch (err) {
      console.error('Error fetching favorites:', err);
    } finally {
      setLoading(false);
    }
  }

  async function handleRemoveFavorite(e, userId) {
    e.stopPropagation();
    try {
      await toggleFavorite(userId);
      setFavorites((prev) => prev.filter((f) => f.user_id !== userId));
    } catch (err) {
      console.error('Error removing favorite:', err);
    }
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-[400px]">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-teal-400" />
      </div>
    );
  }

  return (
    <div className="max-w-3xl mx-auto space-y-4">
      <h1 className="text-2xl font-bold text-white flex items-center gap-2">
        <Heart className="w-6 h-6 text-red-400" />
        Jugadores favoritos
      </h1>

      {favorites.length === 0 ? (
        <div className="text-center py-16 text-slate-400">
          <Heart className="w-12 h-12 mx-auto mb-4 opacity-50" />
          <p>No tienes jugadores favoritos aún</p>
        </div>
      ) : (
        <div className="space-y-2">
          {favorites.map((fav) => (
            <Card
              key={fav.user_id || fav.id}
              className="cursor-pointer hover:border-teal-500/50 transition-colors"
              onClick={() => navigate(`/players/${fav.user_id || fav.id}`)}
            >
              <CardContent className="p-4">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 rounded-full bg-slate-700 flex items-center justify-center">
                      <Heart className="w-5 h-5 fill-red-500 text-red-500" />
                    </div>
                    <div>
                      <h3 className="text-white font-medium">
                        {fav.display_name || fav.nombre}
                      </h3>
                      <div className="flex items-center gap-2 mt-1">
                        <LevelBadge level={fav.level} />
                        {fav.avg_rating != null && (
                          <div className="flex items-center gap-1">
                            <Star className="w-3.5 h-3.5 fill-yellow-400 text-yellow-400" />
                            <span className="text-xs text-slate-300">
                              {fav.avg_rating.toFixed(1)}
                            </span>
                          </div>
                        )}
                      </div>
                    </div>
                  </div>

                  <div className="flex items-center gap-3">
                    {fav.favorited_at && (
                      <span className="text-xs text-slate-500">
                        {new Date(fav.favorited_at).toLocaleDateString('es-ES', {
                          day: 'numeric',
                          month: 'short',
                          year: 'numeric',
                        })}
                      </span>
                    )}
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={(e) =>
                        handleRemoveFavorite(e, fav.user_id || fav.id)
                      }
                      className="p-1.5 text-slate-400 hover:text-red-400"
                    >
                      <X className="w-4 h-4" />
                    </Button>
                  </div>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
