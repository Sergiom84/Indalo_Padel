import { Link, useLocation } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import { Home, Calendar, Users, Trophy, Heart, LogOut } from 'lucide-react';

export default function Navigation() {
  const { user, logout } = useAuth();
  const location = useLocation();

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
      <nav className="hidden md:flex items-center justify-between bg-padel-surface border-b border-padel-border px-6 py-0 h-16 sticky top-0 z-50 backdrop-blur-sm">
        {/* Logo */}
        <Link to="/" className="flex items-center gap-2.5 shrink-0">
          <div className="w-8 h-8 bg-padel-primary rounded-lg flex items-center justify-center">
            <Trophy className="w-4.5 h-4.5 text-padel-dark" strokeWidth={2.5} />
          </div>
          <span className="font-display font-black text-lg text-white tracking-tight">
            Indalo<span className="text-padel-primary">.</span>
          </span>
        </Link>

        {/* Nav links */}
        <div className="flex items-center gap-1">
          {navItems.map(item => (
            <Link
              key={item.to}
              to={item.to}
              className={`flex items-center gap-2 px-3.5 py-2 rounded-xl text-sm font-medium transition-all duration-200 ${
                isActive(item.to)
                  ? 'bg-padel-primary text-padel-dark font-bold'
                  : 'text-padel-muted hover:text-white hover:bg-padel-surface2'
              }`}
            >
              <item.icon className="w-4 h-4" />
              {item.label}
            </Link>
          ))}
        </div>

        {/* User */}
        <div className="flex items-center gap-3">
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-full bg-padel-primary/20 border border-padel-primary/30 flex items-center justify-center">
              <span className="text-xs font-bold text-padel-primary">
                {(user.nombre || user.name || 'U')[0].toUpperCase()}
              </span>
            </div>
            <span className="text-sm font-medium text-white">{user.nombre || user.name}</span>
          </div>
          <button
            onClick={logout}
            className="p-2 rounded-lg text-padel-muted hover:text-red-400 hover:bg-red-400/10 transition-all duration-200"
            title="Cerrar sesión"
          >
            <LogOut className="w-4 h-4" />
          </button>
        </div>
      </nav>

      {/* Mobile bottom nav */}
      <nav className="md:hidden fixed bottom-0 left-0 right-0 z-50 bg-padel-surface border-t border-padel-border px-2 pb-safe">
        <div className="flex justify-around items-center h-16">
          {navItems.map(item => (
            <Link
              key={item.to}
              to={item.to}
              className={`flex flex-col items-center gap-0.5 py-2 px-3 rounded-xl transition-all duration-200 ${
                isActive(item.to)
                  ? 'text-padel-primary'
                  : 'text-padel-muted'
              }`}
            >
              <item.icon
                className={`w-5 h-5 ${isActive(item.to) ? 'stroke-[2.5px]' : ''}`}
              />
              <span className={`text-[10px] font-semibold ${isActive(item.to) ? 'text-padel-primary' : ''}`}>
                {item.label}
              </span>
            </Link>
          ))}
          <button
            onClick={logout}
            className="flex flex-col items-center gap-0.5 py-2 px-3 text-padel-muted"
          >
            <LogOut className="w-5 h-5" />
            <span className="text-[10px] font-semibold">Salir</span>
          </button>
        </div>
      </nav>
    </>
  );
}
