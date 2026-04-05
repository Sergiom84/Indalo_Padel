import { Link, useLocation } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import { Home, Calendar, Users, Trophy, Heart, LogOut, Menu, X } from 'lucide-react';
import { useState } from 'react';

export default function Navigation() {
  const { user, logout } = useAuth();
  const location = useLocation();
  const [mobileOpen, setMobileOpen] = useState(false);

  if (!user) return null;

  const navItems = [
    { to: '/', icon: Home, label: 'Inicio' },
    { to: '/my-bookings', icon: Calendar, label: 'Reservas' },
    { to: '/matches', icon: Trophy, label: 'Partidos' },
    { to: '/players', icon: Users, label: 'Jugadores' },
    { to: '/players/favorites', icon: Heart, label: 'Favoritos' },
  ];

  const isActive = (path) => location.pathname === path;

  return (
    <>
      {/* Desktop top nav */}
      <nav className="hidden md:flex items-center justify-between bg-padel-surface border-b border-padel-20 px-6 py-3">
        <Link to="/" className="flex items-center gap-2">
          <div className="w-8 h-8 bg-padel-primary rounded-lg flex items-center justify-center">
            <Trophy className="w-5 h-5 text-white" />
          </div>
          <span className="font-display font-bold text-lg text-white">Indalo Padel</span>
        </Link>

        <div className="flex items-center gap-1">
          {navItems.map(item => (
            <Link
              key={item.to}
              to={item.to}
              className={`flex items-center gap-2 px-3 py-2 rounded-lg text-sm transition-colors ${
                isActive(item.to)
                  ? 'bg-padel-primary/20 text-padel-accent'
                  : 'text-slate-400 hover:text-white hover:bg-white/5'
              }`}
            >
              <item.icon className="w-4 h-4" />
              {item.label}
            </Link>
          ))}
        </div>

        <div className="flex items-center gap-3">
          <span className="text-sm text-slate-400">{user.nombre}</span>
          <button
            onClick={logout}
            className="p-2 text-slate-400 hover:text-red-400 transition-colors"
            title="Cerrar sesión"
          >
            <LogOut className="w-4 h-4" />
          </button>
        </div>
      </nav>

      {/* Mobile bottom nav */}
      <nav className="md:hidden fixed bottom-0 left-0 right-0 z-50 bg-padel-surface border-t border-padel-20 px-2 py-1 safe-area-pb">
        <div className="flex justify-around">
          {navItems.map(item => (
            <Link
              key={item.to}
              to={item.to}
              className={`flex flex-col items-center py-2 px-3 text-xs transition-colors ${
                isActive(item.to) ? 'text-padel-accent' : 'text-slate-500'
              }`}
            >
              <item.icon className="w-5 h-5 mb-0.5" />
              {item.label}
            </Link>
          ))}
          <button
            onClick={logout}
            className="flex flex-col items-center py-2 px-3 text-xs text-slate-500"
          >
            <LogOut className="w-5 h-5 mb-0.5" />
            Salir
          </button>
        </div>
      </nav>
    </>
  );
}
