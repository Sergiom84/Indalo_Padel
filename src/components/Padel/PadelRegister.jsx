import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { UserPlus, Mail, Lock, User } from 'lucide-react';
import { useAuth } from '../../contexts/AuthContext';
import Button from '../ui/button';
import Input, { Select } from '../ui/input';
import { Card, CardContent } from '../ui/card';

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

  const inputClasses =
    'bg-padel-dark border-slate-700 text-white placeholder:text-slate-500 focus:border-padel-primary focus:ring-padel-primary';
  const selectClasses =
    'w-full bg-padel-dark border border-slate-700 text-white rounded-md px-3 py-2 focus:border-padel-primary focus:ring-padel-primary focus:outline-none';

  return (
    <div className="min-h-screen bg-padel-dark flex items-center justify-center px-4 py-8">
      <Card className="w-full max-w-md bg-padel-surface border-padel-surface">
        <CardContent className="p-6 sm:p-8">
          <div className="text-center mb-8">
            <div className="inline-flex items-center justify-center w-16 h-16 rounded-full bg-padel-primary/20 mb-4">
              <UserPlus className="w-8 h-8 text-padel-primary" />
            </div>
            <h1 className="text-2xl font-bold text-white">Crear cuenta</h1>
            <p className="text-slate-400 mt-1">Únete a Indalo Padel</p>
          </div>

          {error && (
            <div className="mb-4 p-3 rounded-lg bg-red-500/10 border border-red-500/30 text-red-400 text-sm">
              {error}
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-slate-300 mb-1.5">
                Nombre
              </label>
              <div className="relative">
                <User className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
                <Input
                  type="text"
                  name="nombre"
                  placeholder="Tu nombre"
                  value={formData.nombre}
                  onChange={handleChange}
                  required
                  className={`pl-10 ${inputClasses}`}
                />
              </div>
            </div>

            <div>
              <label className="block text-sm font-medium text-slate-300 mb-1.5">
                Email
              </label>
              <div className="relative">
                <Mail className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
                <Input
                  type="email"
                  name="email"
                  placeholder="tu@email.com"
                  value={formData.email}
                  onChange={handleChange}
                  required
                  className={`pl-10 ${inputClasses}`}
                />
              </div>
            </div>

            <div>
              <label className="block text-sm font-medium text-slate-300 mb-1.5">
                Contraseña
              </label>
              <div className="relative">
                <Lock className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
                <Input
                  type="password"
                  name="password"
                  placeholder="••••••••"
                  value={formData.password}
                  onChange={handleChange}
                  required
                  className={`pl-10 ${inputClasses}`}
                />
              </div>
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-slate-300 mb-1.5">
                  Nivel principal
                </label>
                <Select
                  name="main_level"
                  value={formData.main_level}
                  onChange={handleChange}
                  className={selectClasses}
                >
                  <option value="bajo">Bajo</option>
                  <option value="medio">Medio</option>
                  <option value="alto">Alto</option>
                </Select>
              </div>

              <div>
                <label className="block text-sm font-medium text-slate-300 mb-1.5">
                  Sub-nivel
                </label>
                <Select
                  name="sub_level"
                  value={formData.sub_level}
                  onChange={handleChange}
                  className={selectClasses}
                >
                  <option value="bajo">Bajo</option>
                  <option value="medio">Medio</option>
                  <option value="alto">Alto</option>
                </Select>
              </div>
            </div>

            <div>
              <label className="block text-sm font-medium text-slate-300 mb-1.5">
                Lado preferido
              </label>
              <Select
                name="preferred_side"
                value={formData.preferred_side}
                onChange={handleChange}
                className={selectClasses}
              >
                <option value="drive">Drive</option>
                <option value="reves">Revés</option>
                <option value="ambos">Ambos</option>
              </Select>
            </div>

            <Button
              type="submit"
              disabled={loading}
              className="w-full bg-padel-primary hover:bg-padel-primary/90 text-white font-medium py-2.5"
            >
              {loading ? 'Creando cuenta...' : 'Crear cuenta'}
            </Button>
          </form>

          <p className="mt-6 text-center text-sm text-slate-400">
            ¿Ya tienes cuenta?{' '}
            <Link to="/login" className="text-padel-primary hover:underline font-medium">
              Inicia sesión
            </Link>
          </p>
        </CardContent>
      </Card>
    </div>
  );
}
