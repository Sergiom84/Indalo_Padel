-- =============================================
-- Indalo Padel - Seed Data
-- Sedes reales de la zona Garrucha/Vera/Mojácar
-- =============================================

-- Sedes
INSERT INTO app.padel_venues (name, location, address, phone, opening_time, closing_time, image_url) VALUES
  ('Centro Deportivo Puerto Rey', 'Vera', 'Urbanización Puerto Rey, Vera, Almería', NULL, '08:00', '23:00', NULL),
  ('Labios Pádel Cuevas', 'Cuevas del Almanzora', 'Cuevas del Almanzora, Almería', NULL, '09:00', '22:00', NULL),
  ('Desert Springs Resort', 'Cuevas del Almanzora', 'Desert Springs Resort, Cuevas del Almanzora, Almería', NULL, '08:00', '21:00', NULL)
ON CONFLICT DO NOTHING;

-- Pistas seed por nombre/ubicación para no depender de IDs fijos.
INSERT INTO app.padel_courts (
  venue_id,
  name,
  court_type,
  surface,
  price_per_hour,
  peak_price_per_hour
)
SELECT
  v.id,
  seed.court_name,
  seed.court_type,
  seed.surface,
  seed.price_per_hour,
  seed.peak_price_per_hour
FROM (
  VALUES
    ('Centro Deportivo Puerto Rey', 'Vera', 'Pista 1', 'standard', 'cesped', 12.00, 16.00),
    ('Centro Deportivo Puerto Rey', 'Vera', 'Pista 2', 'standard', 'cesped', 12.00, 16.00),
    ('Centro Deportivo Puerto Rey', 'Vera', 'Pista 3', 'standard', 'cesped', 12.00, 16.00),
    ('Centro Deportivo Puerto Rey', 'Vera', 'Pista 4', 'standard', 'cesped', 12.00, 16.00),
    ('Centro Deportivo Puerto Rey', 'Vera', 'Pista 5', 'standard', 'cesped', 12.00, 16.00),
    ('Centro Deportivo Puerto Rey', 'Vera', 'Pista 6', 'standard', 'cesped', 12.00, 16.00),
    ('Centro Deportivo Puerto Rey', 'Vera', 'Pista 7', 'standard', 'cesped', 12.00, 16.00),
    ('Centro Deportivo Puerto Rey', 'Vera', 'Pista 8', 'standard', 'cesped', 12.00, 16.00),
    ('Centro Deportivo Puerto Rey', 'Vera', 'Pista 9', 'standard', 'cesped', 12.00, 16.00),
    ('Centro Deportivo Puerto Rey', 'Vera', 'Pista Cristal 1', 'cristal', 'cesped', 16.00, 20.00),
    ('Centro Deportivo Puerto Rey', 'Vera', 'Pista Cristal 2', 'cristal', 'cesped', 16.00, 20.00),
    ('Labios Pádel Cuevas', 'Cuevas del Almanzora', 'Pista 1', 'standard', 'cesped', 10.00, 14.00),
    ('Labios Pádel Cuevas', 'Cuevas del Almanzora', 'Pista 2', 'standard', 'cesped', 10.00, 14.00),
    ('Labios Pádel Cuevas', 'Cuevas del Almanzora', 'Pista 3', 'standard', 'cesped', 10.00, 14.00),
    ('Labios Pádel Cuevas', 'Cuevas del Almanzora', 'Pista 4', 'cristal', 'cesped', 14.00, 18.00),
    ('Desert Springs Resort', 'Cuevas del Almanzora', 'Pista 1', 'standard', 'cesped', 14.00, 18.00),
    ('Desert Springs Resort', 'Cuevas del Almanzora', 'Pista 2', 'standard', 'cesped', 14.00, 18.00),
    ('Desert Springs Resort', 'Cuevas del Almanzora', 'Pista 3', 'cristal', 'cesped', 18.00, 22.00)
) AS seed(
  venue_name,
  venue_location,
  court_name,
  court_type,
  surface,
  price_per_hour,
  peak_price_per_hour
)
JOIN app.padel_venues v
  ON LOWER(BTRIM(v.name)) = LOWER(BTRIM(seed.venue_name))
 AND LOWER(BTRIM(v.location)) = LOWER(BTRIM(seed.venue_location))
 AND v.is_active = true
ON CONFLICT (venue_id, name) DO NOTHING;
