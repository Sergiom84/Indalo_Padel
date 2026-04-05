import { useNavigate } from 'react-router-dom';
import { MapPin, Clock } from 'lucide-react';
import { Card, CardContent, CardHeader } from '../../ui/card';

export default function VenueCard({ venue }) {
  const navigate = useNavigate();

  const handleClick = () => {
    navigate(`/venues/${venue.id}`);
  };

  return (
    <Card
      className="hover:border-padel-primary/50 transition-colors cursor-pointer h-full"
      onClick={handleClick}
    >
      <CardHeader>
        <h3 className="text-lg font-semibold text-white">{venue.name}</h3>
      </CardHeader>
      <CardContent className="space-y-3">
        <div className="flex items-center gap-2 text-gray-300">
          <MapPin className="h-4 w-4 text-padel-accent" />
          <span className="text-sm">{venue.location}</span>
        </div>

        <div className="flex items-center gap-2 text-gray-300">
          <span className="text-sm font-medium text-padel-accent">
            {venue.court_count} {venue.court_count === 1 ? 'pista' : 'pistas'}
          </span>
        </div>

        {(venue.opening_time || venue.closing_time) && (
          <div className="flex items-center gap-2 text-gray-300">
            <Clock className="h-4 w-4 text-padel-accent" />
            <span className="text-sm">
              {venue.opening_time?.slice(0, 5)} - {venue.closing_time?.slice(0, 5)}
            </span>
          </div>
        )}
      </CardContent>
    </Card>
  );
}
