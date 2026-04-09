import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Trophy, ArrowLeft, Save } from 'lucide-react';

import Button from '../../ui/button';
import { Card, CardContent, CardHeader, CardFooter } from '../../ui/card';
import Input, { Select, Textarea } from '../../ui/input';
import { usePadelMatches } from '../hooks/usePadelMatches';
import apiClient from '../../../lib/apiClient';

const levelOptions = Array.from({ length: 9 }, (_, i) => i + 1);

export default function MatchCreate() {
  const navigate = useNavigate();
  const { createMatch } = usePadelMatches();

  const [venues, setVenues] = useState([]);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState(null);

  const [form, setForm] = useState({
    match_date: '',
    start_time: '',
    venue_id: '',
    match_type: 'abierto',
    min_level: '1',
    max_level: '9',
    description: '',
  });

  useEffect(() => {
    async function fetchVenues() {
      try {
        const res = await apiClient.get('/padel/venues');
        setVenues(res.data ?? res);
      } catch (err) {
        console.error('Error cargando sedes:', err);
      }
    }
    fetchVenues();
  }, []);

  function handleChange(e) {
    const { name, value } = e.target;
    setForm((prev) => ({ ...prev, [name]: value }));
  }

  async function handleSubmit(e) {
    e.preventDefault();
    setError(null);

    if (!form.match_date || !form.start_time || !form.venue_id) {
      setError('Por favor completa los campos obligatorios: fecha, hora y sede.');
      return;
    }

    if (Number(form.min_level) > Number(form.max_level)) {
      setError('El nivel minimo no puede ser mayor que el maximo.');
      return;
    }

    setSubmitting(true);
    try {
      const payload = {
        ...form,
        venue_id: Number(form.venue_id),
        min_level: Number(form.min_level),
        max_level: Number(form.max_level),
      };
      const result = await createMatch(payload);
      const matchId = result?.id ?? result?.match?.id;
      navigate(matchId ? `/matches/${matchId}` : '/matches');
    } catch (err) {
      setError(err?.data?.error || err.message || 'Error al crear el partido.');
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div className="max-w-2xl mx-auto space-y-6">
      {/* Header */}
      <div className="flex items-center gap-3">
        <Button variant="ghost" size="sm" onClick={() => navigate(-1)}>
          <ArrowLeft className="h-4 w-4" />
        </Button>
        <h1 className="text-2xl font-bold text-white flex items-center gap-2">
          <Trophy className="h-7 w-7 text-padel-accent" />
          Crear partido
        </h1>
      </div>

      <form onSubmit={handleSubmit}>
        <Card>
          <CardHeader>
            <h2 className="text-lg font-semibold text-white">Detalles del partido</h2>
          </CardHeader>

          <CardContent className="space-y-5">
            {error && (
              <div className="bg-red-500/10 border border-red-500/30 text-red-400 rounded-lg px-4 py-3 text-sm">
                {error}
              </div>
            )}

            {/* Date & Time */}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <Input
                label="Fecha *"
                type="date"
                name="match_date"
                value={form.match_date}
                onChange={handleChange}
                required
              />
              <Input
                label="Hora de inicio *"
                type="time"
                name="start_time"
                value={form.start_time}
                onChange={handleChange}
                required
              />
            </div>

            {/* Venue */}
            <Select
              label="Sede *"
              name="venue_id"
              value={form.venue_id}
              onChange={handleChange}
              required
            >
              <option value="">Selecciona una sede</option>
              {venues.map((v) => (
                <option key={v.id} value={v.id}>
                  {v.name}
                </option>
              ))}
            </Select>

            {/* Match type */}
            <Select
              label="Tipo de partido"
              name="match_type"
              value={form.match_type}
              onChange={handleChange}
            >
              <option value="abierto">Abierto</option>
              <option value="privado">Privado</option>
            </Select>

            {/* Level range */}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <Select
                label="Nivel minimo"
                name="min_level"
                value={form.min_level}
                onChange={handleChange}
              >
                {levelOptions.map((n) => (
                  <option key={n} value={n}>
                    Nivel {n}
                  </option>
                ))}
              </Select>
              <Select
                label="Nivel maximo"
                name="max_level"
                value={form.max_level}
                onChange={handleChange}
              >
                {levelOptions.map((n) => (
                  <option key={n} value={n}>
                    Nivel {n}
                  </option>
                ))}
              </Select>
            </div>

            {/* Description */}
            <Textarea
              label="Descripcion"
              name="description"
              value={form.description}
              onChange={handleChange}
              placeholder="Informacion adicional sobre el partido..."
              rows={3}
            />
          </CardContent>

          <CardFooter className="flex justify-end gap-3">
            <Button
              variant="ghost"
              type="button"
              onClick={() => navigate(-1)}
            >
              Cancelar
            </Button>
            <Button type="submit" disabled={submitting}>
              <Save className="h-4 w-4 mr-1" />
              {submitting ? 'Creando...' : 'Crear partido'}
            </Button>
          </CardFooter>
        </Card>
      </form>
    </div>
  );
}
