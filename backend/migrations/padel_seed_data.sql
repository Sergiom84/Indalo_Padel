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

-- Pistas Centro Deportivo Puerto Rey (11 pistas estándar + 2 cristal)
INSERT INTO app.padel_courts (venue_id, name, court_type, surface, price_per_hour, peak_price_per_hour) VALUES
  (1, 'Pista 1', 'standard', 'cesped', 12.00, 16.00),
  (1, 'Pista 2', 'standard', 'cesped', 12.00, 16.00),
  (1, 'Pista 3', 'standard', 'cesped', 12.00, 16.00),
  (1, 'Pista 4', 'standard', 'cesped', 12.00, 16.00),
  (1, 'Pista 5', 'standard', 'cesped', 12.00, 16.00),
  (1, 'Pista 6', 'standard', 'cesped', 12.00, 16.00),
  (1, 'Pista 7', 'standard', 'cesped', 12.00, 16.00),
  (1, 'Pista 8', 'standard', 'cesped', 12.00, 16.00),
  (1, 'Pista 9', 'standard', 'cesped', 12.00, 16.00),
  (1, 'Pista Cristal 1', 'cristal', 'cesped', 16.00, 20.00),
  (1, 'Pista Cristal 2', 'cristal', 'cesped', 16.00, 20.00)
ON CONFLICT DO NOTHING;

-- Pistas Labios Pádel (4 pistas)
INSERT INTO app.padel_courts (venue_id, name, court_type, surface, price_per_hour, peak_price_per_hour) VALUES
  (2, 'Pista 1', 'standard', 'cesped', 10.00, 14.00),
  (2, 'Pista 2', 'standard', 'cesped', 10.00, 14.00),
  (2, 'Pista 3', 'standard', 'cesped', 10.00, 14.00),
  (2, 'Pista 4', 'cristal', 'cesped', 14.00, 18.00)
ON CONFLICT DO NOTHING;

-- Pistas Desert Springs (3 pistas)
INSERT INTO app.padel_courts (venue_id, name, court_type, surface, price_per_hour, peak_price_per_hour) VALUES
  (3, 'Pista 1', 'standard', 'cesped', 14.00, 18.00),
  (3, 'Pista 2', 'standard', 'cesped', 14.00, 18.00),
  (3, 'Pista 3', 'cristal', 'cesped', 18.00, 22.00)
ON CONFLICT DO NOTHING;
