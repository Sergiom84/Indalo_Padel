import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { Mail, Lock, ArrowRight } from 'lucide-react';
import { useAuth } from '../../contexts/AuthContext';
import Button from '../ui/button';
import Input from '../ui/input';

export default function PadelLogin() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const { login } = useAuth();
  const navigate = useNavigate();

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      await login(email, password);
      navigate('/');
    } catch (err) {
      setError(err.data?.error || err.message || 'Error al iniciar sesión');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-padel-dark flex flex-col items-center justify-center px-4 py-8">
      {/* Glow spot */}
      <div className="absolute top-0 left-1/2 -translate-x-1/2 w-96 h-96 bg-padel-primary/5 rounded-full blur-3xl pointer-events-none" />

      <div className="w-full max-w-sm relative">
        {/* Logo */}
        <div className="text-center mb-10">
          <div className="inline-flex items-center justify-center w-14 h-14 rounded-2xl bg-padel-primary mb-5 glow-primary">
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#0A0A0A" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
              <circle cx="12" cy="12" r="10" />
              <path d="M12 6l4 6-4 6-4-6z" />
            </svg>
          </div>
          <h1 className="text-3xl font-black text-white font-display tracking-tight">
            Indalo<span className="text-padel-primary">.</span>
          </h1>
          <p className="text-padel-muted mt-1 text-sm">Tu club de pádel, siempre contigo</p>
        </div>

        {/* Error */}
        {error && (
          <div className="mb-5 p-3.5 rounded-xl bg-red-500/10 border border-red-500/20 text-red-400 text-sm flex items-center gap-2">
            <span className="w-1.5 h-1.5 rounded-full bg-red-400 shrink-0" />
            {error}
          </div>
        )}

        {/* Form */}
        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="relative">
            <Mail className="absolute left-4 top-1/2 -translate-y-1/2 w-4 h-4 text-padel-muted z-10" />
            <input
              type="email"
              placeholder="tu@email.com"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
              className="w-full pl-11 pr-4 py-3.5 bg-padel-surface border border-padel-border rounded-xl text-white placeholder-padel-muted focus:outline-none focus:border-padel-primary focus:ring-1 focus:ring-padel-primary/40 transition-all text-sm"
            />
          </div>

          <div className="relative">
            <Lock className="absolute left-4 top-1/2 -translate-y-1/2 w-4 h-4 text-padel-muted z-10" />
            <input
              type="password"
              placeholder="Contraseña"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              className="w-full pl-11 pr-4 py-3.5 bg-padel-surface border border-padel-border rounded-xl text-white placeholder-padel-muted focus:outline-none focus:border-padel-primary focus:ring-1 focus:ring-padel-primary/40 transition-all text-sm"
            />
          </div>

          <button
            type="submit"
            disabled={loading}
            className="w-full flex items-center justify-center gap-2 bg-padel-primary text-padel-dark font-black py-3.5 rounded-xl hover:bg-padel-primaryDark active:scale-95 transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed mt-2 text-sm glow-primary-sm"
          >
            {loading ? (
              <div className="w-4 h-4 border-2 border-padel-dark border-t-transparent rounded-full animate-spin" />
            ) : (
              <>
                Entrar <ArrowRight className="w-4 h-4" strokeWidth={2.5} />
              </>
            )}
          </button>
        </form>

        <p className="mt-6 text-center text-sm text-padel-muted">
          ¿No tienes cuenta?{' '}
          <Link to="/register" className="text-padel-primary font-bold hover:text-padel-primaryDark transition-colors">
            Regístrate gratis
          </Link>
        </p>
      </div>
    </div>
  );
}
