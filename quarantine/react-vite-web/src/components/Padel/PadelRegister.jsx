import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { User, Mail, Lock, ArrowRight, ChevronDown } from 'lucide-react';
import { useAuth } from '../../contexts/AuthContext';

export default function PadelRegister() {
  const [formData, setFormData] = useState({
    nombre: '',
    email: '',
    password: '',
    main_level: 'bajo',
    sub_level: 'medio',
    preferred_side: 'ambos',
  });
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const { register } = useAuth();
  const navigate = useNavigate();

  const handleChange = (e) => {
    setFormData((prev) => ({ ...prev, [e.target.name]: e.target.value }));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      await register(formData);
      navigate('/');
    } catch (err) {
      setError(err.data?.error || err.message || 'Error al registrarse');
    } finally {
      setLoading(false);
    }
  };

  const inputBase = "w-full py-3.5 bg-padel-surface border border-padel-border rounded-xl text-white placeholder-padel-muted focus:outline-none focus:border-padel-primary focus:ring-1 focus:ring-padel-primary/40 transition-all text-sm";
  const selectBase = "w-full px-4 py-3.5 bg-padel-surface border border-padel-border rounded-xl text-white focus:outline-none focus:border-padel-primary focus:ring-1 focus:ring-padel-primary/40 transition-all text-sm appearance-none";

  return (
    <div className="min-h-screen bg-padel-dark flex flex-col items-center justify-center px-4 py-8">
      {/* Glow */}
      <div className="absolute top-0 left-1/2 -translate-x-1/2 w-96 h-96 bg-padel-primary/5 rounded-full blur-3xl pointer-events-none" />

      <div className="w-full max-w-sm relative">
        {/* Header */}
        <div className="text-center mb-8">
          <h1 className="text-3xl font-black text-white font-display tracking-tight">
            Únete a Indalo<span className="text-padel-primary">.</span>
          </h1>
          <p className="text-padel-muted mt-1 text-sm">Crea tu perfil de jugador</p>
        </div>

        {/* Error */}
        {error && (
          <div className="mb-5 p-3.5 rounded-xl bg-red-500/10 border border-red-500/20 text-red-400 text-sm flex items-center gap-2">
            <span className="w-1.5 h-1.5 rounded-full bg-red-400 shrink-0" />
            {error}
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-3">
          {/* Nombre */}
          <div className="relative">
            <User className="absolute left-4 top-1/2 -translate-y-1/2 w-4 h-4 text-padel-muted z-10" />
            <input
              type="text" name="nombre" placeholder="Nombre" required
              value={formData.nombre} onChange={handleChange}
              className={`${inputBase} pl-11 pr-4`}
            />
          </div>

          {/* Email */}
          <div className="relative">
            <Mail className="absolute left-4 top-1/2 -translate-y-1/2 w-4 h-4 text-padel-muted z-10" />
            <input
              type="email" name="email" placeholder="tu@email.com" required
              value={formData.email} onChange={handleChange}
              className={`${inputBase} pl-11 pr-4`}
            />
          </div>

          {/* Password */}
          <div className="relative">
            <Lock className="absolute left-4 top-1/2 -translate-y-1/2 w-4 h-4 text-padel-muted z-10" />
            <input
              type="password" name="password" placeholder="Contraseña" required
              value={formData.password} onChange={handleChange}
              className={`${inputBase} pl-11 pr-4`}
            />
          </div>

          {/* Level grid */}
          <div className="grid grid-cols-2 gap-3 pt-1">
            <div>
              <label className="block text-[10px] font-bold uppercase tracking-wider text-padel-muted mb-1.5">Nivel</label>
              <div className="relative">
                <select name="main_level" value={formData.main_level} onChange={handleChange} className={selectBase}>
                  <option value="bajo">Bajo</option>
                  <option value="medio">Medio</option>
                  <option value="alto">Alto</option>
                </select>
                <ChevronDown className="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-padel-muted pointer-events-none" />
              </div>
            </div>
            <div>
              <label className="block text-[10px] font-bold uppercase tracking-wider text-padel-muted mb-1.5">Sub-nivel</label>
              <div className="relative">
                <select name="sub_level" value={formData.sub_level} onChange={handleChange} className={selectBase}>
                  <option value="bajo">Bajo</option>
                  <option value="medio">Medio</option>
                  <option value="alto">Alto</option>
                </select>
                <ChevronDown className="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-padel-muted pointer-events-none" />
              </div>
            </div>
          </div>

          {/* Side */}
          <div>
            <label className="block text-[10px] font-bold uppercase tracking-wider text-padel-muted mb-1.5">Lado preferido</label>
            <div className="relative">
              <select name="preferred_side" value={formData.preferred_side} onChange={handleChange} className={selectBase}>
                <option value="drive">Drive</option>
                <option value="reves">Revés</option>
                <option value="ambos">Ambos</option>
              </select>
              <ChevronDown className="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-padel-muted pointer-events-none" />
            </div>
          </div>

          <button
            type="submit" disabled={loading}
            className="w-full flex items-center justify-center gap-2 bg-padel-primary text-padel-dark font-black py-3.5 rounded-xl hover:bg-padel-primaryDark active:scale-95 transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed mt-2 text-sm glow-primary-sm"
          >
            {loading ? (
              <div className="w-4 h-4 border-2 border-padel-dark border-t-transparent rounded-full animate-spin" />
            ) : (
              <>Crear mi cuenta <ArrowRight className="w-4 h-4" strokeWidth={2.5} /></>
            )}
          </button>
        </form>

        <p className="mt-5 text-center text-sm text-padel-muted">
          ¿Ya tienes cuenta?{' '}
          <Link to="/login" className="text-padel-primary font-bold hover:text-padel-primaryDark transition-colors">
            Inicia sesión
          </Link>
        </p>
      </div>
    </div>
  );
}
