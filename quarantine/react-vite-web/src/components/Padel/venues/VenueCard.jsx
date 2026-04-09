import { useNavigate } from 'react-router-dom';
import { MapPin, Clock, ChevronRight } from 'lucide-react';

export default function VenueCard({ venue }) {
  const navigate = useNavigate();

  return (
    <div
      className="bg-padel-surface border border-padel-border rounded-2xl p-5 hover:border-padel-primary/40 hover:bg-padel-surface2 transition-all duration-200 cursor-pointer group"
      onClick={() => navigate(`/venues/${venue.id}`)}
    >
      <div className="flex items-start justify-between mb-3">
        <h3 className="font-bold text-white text-base leading-tight group-hover:text-padel-primary transition-colors">
          {venue.nombre || venue.name}
        </h3>
        <ChevronRight className="w-4 h-4 text-padel-muted group-hover:text-padel-primary transition-colors shrink-0 mt-0.5" />
      </div>

      <div className="space-y-2">
        <div className="flex items-center gap-2 text-padel-muted">
          <MapPin className="w-3.5 h-3.5 text-padel-primary shrink-0" />
          <span className="text-sm truncate">{venue.ubicacion || venue.location || 'Sin ubicación'}</span>
        </div>

        {(venue.opening_time || venue.closing_time) && (
          <div className="flex items-center gap-2 text-padel-muted">
            <Clock className="w-3.5 h-3.5 text-padel-primary shrink-0" />
            <span className="text-sm">
              {venue.opening_time?.slice(0, 5)} – {venue.closing_time?.slice(0, 5)}
            </span>
          </div>
        )}
      </div>

      <div className="mt-4 pt-3 border-t border-padel-border flex items-center justify-between">
        <span className="text-xs font-semibold text-padel-muted uppercase tracking-wider">Pistas disponibles</span>
        <span className="text-sm font-black text-padel-primary">
          {venue.court_count ?? venue.pistas?.length ?? '—'}
        </span>
      </div>
    </div>
  );
}
