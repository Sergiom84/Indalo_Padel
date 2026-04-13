-- =============================================
-- Indalo Padel - Seed Data (actualizado)
-- Fuente funcional: Info_pistas.txt (abril 2026)
-- Solo incluye centros, pistas, precios y horarios.
-- =============================================

CREATE TEMP TABLE tmp_seed_venues (
  name VARCHAR(100) NOT NULL,
  location VARCHAR(100) NOT NULL,
  address TEXT,
  opening_time TIME,
  closing_time TIME,
  is_bookable BOOLEAN NOT NULL DEFAULT false
) ON COMMIT DROP;

INSERT INTO tmp_seed_venues (name, location, address, opening_time, closing_time, is_bookable) VALUES
  ('Pistas Municipales de Mojácar', 'Mojácar', 'Paraje La Mata, Mojácar, Almería', '10:30', '22:00', false),
  ('Marina de la Torre', 'Mojácar', 'Paseo del Mediterráneo, Mojácar, Almería', '08:00', '24:00', true),
  ('Centro Deportivo Puerto Rey', 'Vera', 'Urbanización Puerto Rey, Vera, Almería', '09:00', '23:00', false),
  ('P4 Pádel Vera', 'Vera', 'Valle del Este, Vera, Almería', NULL, NULL, false),
  ('Club Vera de Mar', 'Vera', 'Vera Playa, Vera, Almería', NULL, NULL, false),
  ('Tenis Academia y Pádel Indalo', 'Vera', 'Vera, Almería', NULL, NULL, false),
  ('Pistas Municipales de Garrucha', 'Garrucha', 'Garrucha, Almería', '09:00', '21:00', false),
  ('Polideportivo Municipal de Cuevas del Almanzora', 'Cuevas del Almanzora', 'Cuevas del Almanzora, Almería', NULL, NULL, false),
  ('Pádel Al-Mansura', 'Cuevas del Almanzora', 'Cuevas del Almanzora, Almería', NULL, NULL, false),
  ('Pista de Pádel de Los Gallardos', 'Los Gallardos', 'Los Gallardos, Almería', NULL, NULL, false);

-- 1) Desactiva sedes antiguas no incluidas en la nueva fuente.
UPDATE app.padel_venues v
SET is_active = false,
    updated_at = NOW()
WHERE v.is_active = true
  AND NOT EXISTS (
    SELECT 1
    FROM tmp_seed_venues s
    WHERE LOWER(BTRIM(v.name)) = LOWER(BTRIM(s.name))
      AND LOWER(BTRIM(v.location)) = LOWER(BTRIM(s.location))
  );

-- 2) Sincroniza las sedes existentes.
WITH ranked_existing AS (
  SELECT
    v.id,
    LOWER(BTRIM(v.name)) AS normalized_name,
    LOWER(BTRIM(v.location)) AS normalized_location,
    ROW_NUMBER() OVER (
      PARTITION BY LOWER(BTRIM(v.name)), LOWER(BTRIM(v.location))
      ORDER BY v.is_active DESC, v.id ASC
    ) AS rn
  FROM app.padel_venues v
),
target_existing AS (
  SELECT
    r.id,
    s.address,
    s.opening_time,
    s.closing_time,
    s.is_bookable
  FROM tmp_seed_venues s
  JOIN ranked_existing r
    ON r.normalized_name = LOWER(BTRIM(s.name))
   AND r.normalized_location = LOWER(BTRIM(s.location))
  WHERE r.rn = 1
)
UPDATE app.padel_venues v
SET address = t.address,
    opening_time = t.opening_time,
    closing_time = t.closing_time,
    is_bookable = t.is_bookable,
    is_active = true,
    updated_at = NOW()
FROM target_existing t
WHERE v.id = t.id;

-- 3) Inserta las sedes que no existan.
INSERT INTO app.padel_venues (
  name,
  location,
  address,
  opening_time,
  closing_time,
  is_bookable,
  is_active
)
SELECT
  s.name,
  s.location,
  s.address,
  s.opening_time,
  s.closing_time,
  s.is_bookable,
  true
FROM tmp_seed_venues s
WHERE NOT EXISTS (
  SELECT 1
  FROM app.padel_venues v
  WHERE LOWER(BTRIM(v.name)) = LOWER(BTRIM(s.name))
    AND LOWER(BTRIM(v.location)) = LOWER(BTRIM(s.location))
);

CREATE TEMP TABLE tmp_seed_schedule_windows (
  venue_name VARCHAR(100) NOT NULL,
  venue_location VARCHAR(100) NOT NULL,
  day_of_week SMALLINT,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  label VARCHAR(80)
) ON COMMIT DROP;

INSERT INTO tmp_seed_schedule_windows (
  venue_name,
  venue_location,
  day_of_week,
  start_time,
  end_time,
  label
) VALUES
  -- Marina de la Torre: L-D 08:00-24:00
  ('Marina de la Torre', 'Mojácar', 1, '08:00', '24:00', 'General'),
  ('Marina de la Torre', 'Mojácar', 2, '08:00', '24:00', 'General'),
  ('Marina de la Torre', 'Mojácar', 3, '08:00', '24:00', 'General'),
  ('Marina de la Torre', 'Mojácar', 4, '08:00', '24:00', 'General'),
  ('Marina de la Torre', 'Mojácar', 5, '08:00', '24:00', 'General'),
  ('Marina de la Torre', 'Mojácar', 6, '08:00', '24:00', 'General'),
  ('Marina de la Torre', 'Mojácar', 7, '08:00', '24:00', 'General'),

  -- Pistas Municipales de Mojácar:
  -- J-D: 10:30-13:00, L-S: 17:00-22:00
  ('Pistas Municipales de Mojácar', 'Mojácar', 4, '10:30', '13:00', 'Manana municipal'),
  ('Pistas Municipales de Mojácar', 'Mojácar', 5, '10:30', '13:00', 'Manana municipal'),
  ('Pistas Municipales de Mojácar', 'Mojácar', 6, '10:30', '13:00', 'Manana municipal'),
  ('Pistas Municipales de Mojácar', 'Mojácar', 7, '10:30', '13:00', 'Manana municipal'),
  ('Pistas Municipales de Mojácar', 'Mojácar', 1, '17:00', '22:00', 'Tarde municipal'),
  ('Pistas Municipales de Mojácar', 'Mojácar', 2, '17:00', '22:00', 'Tarde municipal'),
  ('Pistas Municipales de Mojácar', 'Mojácar', 3, '17:00', '22:00', 'Tarde municipal'),
  ('Pistas Municipales de Mojácar', 'Mojácar', 4, '17:00', '22:00', 'Tarde municipal'),
  ('Pistas Municipales de Mojácar', 'Mojácar', 5, '17:00', '22:00', 'Tarde municipal'),
  ('Pistas Municipales de Mojácar', 'Mojácar', 6, '17:00', '22:00', 'Tarde municipal'),

  -- Puerto Rey: L-D 09:00-23:00
  ('Centro Deportivo Puerto Rey', 'Vera', 1, '09:00', '23:00', 'General'),
  ('Centro Deportivo Puerto Rey', 'Vera', 2, '09:00', '23:00', 'General'),
  ('Centro Deportivo Puerto Rey', 'Vera', 3, '09:00', '23:00', 'General'),
  ('Centro Deportivo Puerto Rey', 'Vera', 4, '09:00', '23:00', 'General'),
  ('Centro Deportivo Puerto Rey', 'Vera', 5, '09:00', '23:00', 'General'),
  ('Centro Deportivo Puerto Rey', 'Vera', 6, '09:00', '23:00', 'General'),
  ('Centro Deportivo Puerto Rey', 'Vera', 7, '09:00', '23:00', 'General'),

  -- Garrucha: L-V 09:00-14:00 y 17:00-21:00
  ('Pistas Municipales de Garrucha', 'Garrucha', 1, '09:00', '14:00', 'Manana municipal'),
  ('Pistas Municipales de Garrucha', 'Garrucha', 2, '09:00', '14:00', 'Manana municipal'),
  ('Pistas Municipales de Garrucha', 'Garrucha', 3, '09:00', '14:00', 'Manana municipal'),
  ('Pistas Municipales de Garrucha', 'Garrucha', 4, '09:00', '14:00', 'Manana municipal'),
  ('Pistas Municipales de Garrucha', 'Garrucha', 5, '09:00', '14:00', 'Manana municipal'),
  ('Pistas Municipales de Garrucha', 'Garrucha', 1, '17:00', '21:00', 'Tarde municipal'),
  ('Pistas Municipales de Garrucha', 'Garrucha', 2, '17:00', '21:00', 'Tarde municipal'),
  ('Pistas Municipales de Garrucha', 'Garrucha', 3, '17:00', '21:00', 'Tarde municipal'),
  ('Pistas Municipales de Garrucha', 'Garrucha', 4, '17:00', '21:00', 'Tarde municipal'),
  ('Pistas Municipales de Garrucha', 'Garrucha', 5, '17:00', '21:00', 'Tarde municipal');

-- 4) Resetea franjas horarias de las sedes del seed y vuelve a cargarlas.
DELETE FROM app.padel_venue_schedule_windows sw
USING app.padel_venues v
JOIN tmp_seed_venues s
  ON LOWER(BTRIM(v.name)) = LOWER(BTRIM(s.name))
 AND LOWER(BTRIM(v.location)) = LOWER(BTRIM(s.location))
WHERE sw.venue_id = v.id;

INSERT INTO app.padel_venue_schedule_windows (
  venue_id,
  day_of_week,
  start_time,
  end_time,
  label,
  is_active
)
SELECT
  v.id,
  s.day_of_week,
  s.start_time,
  s.end_time,
  s.label,
  true
FROM tmp_seed_schedule_windows s
JOIN app.padel_venues v
  ON LOWER(BTRIM(v.name)) = LOWER(BTRIM(s.venue_name))
 AND LOWER(BTRIM(v.location)) = LOWER(BTRIM(s.venue_location))
WHERE v.is_active = true;

-- 5) Desactiva pistas de sedes inactivas.
UPDATE app.padel_courts c
SET is_active = false
WHERE c.is_active = true
  AND c.venue_id IN (
    SELECT v.id
    FROM app.padel_venues v
    WHERE v.is_active = false
  );

CREATE TEMP TABLE tmp_seed_courts (
  venue_name VARCHAR(100) NOT NULL,
  venue_location VARCHAR(100) NOT NULL,
  court_name VARCHAR(50) NOT NULL,
  court_type VARCHAR(20) NOT NULL,
  surface VARCHAR(20) NOT NULL,
  price_per_hour DECIMAL(6,2),
  peak_price_per_hour DECIMAL(6,2)
) ON COMMIT DROP;

INSERT INTO tmp_seed_courts (
  venue_name,
  venue_location,
  court_name,
  court_type,
  surface,
  price_per_hour,
  peak_price_per_hour
) VALUES
  -- Mojácar
  ('Marina de la Torre', 'Mojácar', 'Pista Césped 1', 'standard', 'cesped', 10.00, 10.00),
  ('Marina de la Torre', 'Mojácar', 'Pista Césped 2', 'standard', 'cesped', 10.00, 10.00),
  ('Marina de la Torre', 'Mojácar', 'Pista Cristal 1', 'cristal', 'cesped', 12.00, 12.00),
  ('Marina de la Torre', 'Mojácar', 'Pista Cristal 2', 'cristal', 'cesped', 12.00, 12.00),

  -- Vera
  ('Centro Deportivo Puerto Rey', 'Vera', 'Pista 1', 'standard', 'cesped', 15.00, 15.00),
  ('Centro Deportivo Puerto Rey', 'Vera', 'Pista 2', 'standard', 'cesped', 15.00, 15.00),
  ('Centro Deportivo Puerto Rey', 'Vera', 'Pista 3', 'standard', 'cesped', 15.00, 15.00),
  ('Centro Deportivo Puerto Rey', 'Vera', 'Pista 4', 'standard', 'cesped', 15.00, 15.00),
  ('Centro Deportivo Puerto Rey', 'Vera', 'Pista 5', 'standard', 'cesped', 15.00, 15.00),
  ('Centro Deportivo Puerto Rey', 'Vera', 'Pista 6', 'standard', 'cesped', 15.00, 15.00),
  ('Centro Deportivo Puerto Rey', 'Vera', 'Pista 7', 'standard', 'cesped', 15.00, 15.00),
  ('Centro Deportivo Puerto Rey', 'Vera', 'Pista 8', 'standard', 'cesped', 15.00, 15.00),
  ('Centro Deportivo Puerto Rey', 'Vera', 'Pista 9', 'standard', 'cesped', 15.00, 15.00),
  ('Centro Deportivo Puerto Rey', 'Vera', 'Pista Cristal 1', 'cristal', 'cesped', 15.00, 15.00),
  ('Centro Deportivo Puerto Rey', 'Vera', 'Pista Cristal 2', 'cristal', 'cesped', 15.00, 15.00),
  ('P4 Pádel Vera', 'Vera', 'Pista 1', 'cristal', 'cesped', 15.00, 15.00),
  ('P4 Pádel Vera', 'Vera', 'Pista 2', 'cristal', 'cesped', 15.00, 15.00),
  ('P4 Pádel Vera', 'Vera', 'Pista 3', 'cristal', 'cesped', 15.00, 15.00),
  ('P4 Pádel Vera', 'Vera', 'Pista 4', 'cristal', 'cesped', 15.00, 15.00),

  -- Garrucha
  ('Pistas Municipales de Garrucha', 'Garrucha', 'Pista Municipal 1', 'standard', 'cesped', NULL, NULL),
  ('Pistas Municipales de Garrucha', 'Garrucha', 'Pista Municipal 2', 'standard', 'cesped', NULL, NULL),

  -- Cuevas del Almanzora y alrededores
  ('Polideportivo Municipal de Cuevas del Almanzora', 'Cuevas del Almanzora', 'Pista Municipal', 'standard', 'cesped', NULL, NULL),
  ('Pádel Al-Mansura', 'Cuevas del Almanzora', 'Pista Indoor 1', 'standard', 'cesped', NULL, NULL),
  ('Pádel Al-Mansura', 'Cuevas del Almanzora', 'Pista Indoor 2', 'standard', 'cesped', NULL, NULL),
  ('Pádel Al-Mansura', 'Cuevas del Almanzora', 'Pista Indoor 3', 'standard', 'cesped', NULL, NULL),
  ('Pádel Al-Mansura', 'Cuevas del Almanzora', 'Pista Indoor 4', 'standard', 'cesped', NULL, NULL),
  ('Pista de Pádel de Los Gallardos', 'Los Gallardos', 'Pista Municipal', 'standard', 'cesped', NULL, NULL);

-- 6) Desactiva pistas antiguas de sedes activas seed para dejar el inventario limpio.
UPDATE app.padel_courts c
SET is_active = false
FROM app.padel_venues v
JOIN tmp_seed_venues s
  ON LOWER(BTRIM(v.name)) = LOWER(BTRIM(s.name))
 AND LOWER(BTRIM(v.location)) = LOWER(BTRIM(s.location))
WHERE c.venue_id = v.id
  AND c.is_active = true;

-- 7) Inserta/actualiza pistas reales y las reactiva.
INSERT INTO app.padel_courts (
  venue_id,
  name,
  court_type,
  surface,
  price_per_hour,
  peak_price_per_hour,
  is_active
)
SELECT
  v.id,
  s.court_name,
  s.court_type,
  s.surface,
  s.price_per_hour,
  s.peak_price_per_hour,
  true
FROM tmp_seed_courts s
JOIN app.padel_venues v
  ON LOWER(BTRIM(v.name)) = LOWER(BTRIM(s.venue_name))
 AND LOWER(BTRIM(v.location)) = LOWER(BTRIM(s.venue_location))
WHERE v.is_active = true
ON CONFLICT (venue_id, name) DO UPDATE
SET court_type = EXCLUDED.court_type,
    surface = EXCLUDED.surface,
    price_per_hour = EXCLUDED.price_per_hour,
    peak_price_per_hour = EXCLUDED.peak_price_per_hour,
    is_active = true;
