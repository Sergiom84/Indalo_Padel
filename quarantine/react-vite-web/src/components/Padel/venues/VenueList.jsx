import { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { MapPin, Building2 } from 'lucide-react';
import { Card, CardContent, CardHeader } from '../../ui/card';
import apiClient from '../../../lib/apiClient';

export default function VenueList() {
  const [venues, setVenues] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    const fetchVenues = async () => {
      try {
        setLoading(true);
        const response = await apiClient.get('/padel/venues');
        setVenues(response || []);
      } catch (err) {
        setError('Error al cargar las sedes');
        console.error('Error fetching venues:', err);
      } finally {
        setLoading(false);
      }
    };

    fetchVenues();
  }, []);

  if (loading) {
    return (
      <div className="flex items-center justify-center py-12">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-padel-primary" />
      </div>
    );
  }

  if (error) {
    return (
      <div className="text-center py-12 text-red-400">
        <p>{error}</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-white">Sedes</h1>
      </div>

      {venues.length === 0 ? (
        <p className="text-gray-400 text-center py-8">No hay sedes disponibles</p>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {venues.map((venue) => (
            <Link key={venue.id} to={`/venues/${venue.id}`} className="block">
              <Card className="hover:border-padel-primary/50 transition-colors cursor-pointer h-full">
                <CardHeader>
                  <h3 className="text-lg font-semibold text-white">{venue.name}</h3>
                </CardHeader>
                <CardContent className="space-y-3">
                  <div className="flex items-center gap-2 text-gray-300">
                    <MapPin className="h-4 w-4 text-padel-accent" />
                    <span className="text-sm">{venue.location}</span>
                  </div>
                  <div className="flex items-center gap-2 text-gray-300">
                    <Building2 className="h-4 w-4 text-padel-accent" />
                    <span className="text-sm">
                      {venue.court_count} {venue.court_count === 1 ? 'pista' : 'pistas'}
                    </span>
                  </div>
                </CardContent>
              </Card>
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}
