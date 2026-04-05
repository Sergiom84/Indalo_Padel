-- =============================================
-- Indalo Padel - Database Schema
-- Schema: app
-- =============================================

CREATE SCHEMA IF NOT EXISTS app;

-- =============================================
-- Users table (simplified for padel)
-- =============================================
CREATE TABLE IF NOT EXISTS app.users (
  id SERIAL PRIMARY KEY,
  nombre VARCHAR(50) NOT NULL,
  email VARCHAR(100) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  role VARCHAR(20) DEFAULT 'user',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================
-- Padel Venues (Sedes)
-- =============================================
CREATE TABLE IF NOT EXISTS app.padel_venues (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  location VARCHAR(100) NOT NULL,
  address TEXT,
  phone VARCHAR(20),
  email VARCHAR(100),
  image_url TEXT,
  opening_time TIME DEFAULT '08:00',
  closing_time TIME DEFAULT '22:00',
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================
-- Padel Courts (Pistas)
-- =============================================
CREATE TABLE IF NOT EXISTS app.padel_courts (
  id SERIAL PRIMARY KEY,
  venue_id INTEGER NOT NULL REFERENCES app.padel_venues(id) ON DELETE CASCADE,
  name VARCHAR(50) NOT NULL,
  court_type VARCHAR(20) DEFAULT 'standard',
  surface VARCHAR(20) DEFAULT 'cesped',
  has_lighting BOOLEAN DEFAULT true,
  price_per_hour DECIMAL(6,2),
  peak_price_per_hour DECIMAL(6,2),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================
-- Padel Player Profiles
-- =============================================
CREATE TABLE IF NOT EXISTS app.padel_player_profiles (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES app.users(id) ON DELETE CASCADE,
  display_name VARCHAR(50),
  main_level VARCHAR(5) NOT NULL DEFAULT 'bajo',
  sub_level VARCHAR(5) NOT NULL DEFAULT 'bajo',
  numeric_level INTEGER GENERATED ALWAYS AS (
    CASE main_level WHEN 'bajo' THEN 0 WHEN 'medio' THEN 3 WHEN 'alto' THEN 6 END +
    CASE sub_level WHEN 'bajo' THEN 1 WHEN 'medio' THEN 2 WHEN 'alto' THEN 3 END
  ) STORED,
  preferred_side VARCHAR(10) DEFAULT 'ambos',
  preferred_venue_id INTEGER REFERENCES app.padel_venues(id),
  bio TEXT,
  avatar_url TEXT,
  matches_played INTEGER DEFAULT 0,
  matches_won INTEGER DEFAULT 0,
  is_available BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id),
  CHECK (main_level IN ('bajo', 'medio', 'alto')),
  CHECK (sub_level IN ('bajo', 'medio', 'alto')),
  CHECK (preferred_side IN ('drive', 'reves', 'ambos'))
);

-- =============================================
-- Padel Bookings (Reservas)
-- =============================================
CREATE TABLE IF NOT EXISTS app.padel_bookings (
  id SERIAL PRIMARY KEY,
  court_id INTEGER NOT NULL REFERENCES app.padel_courts(id),
  booked_by INTEGER NOT NULL REFERENCES app.users(id),
  booking_date DATE NOT NULL,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  status VARCHAR(20) DEFAULT 'pendiente',
  total_price DECIMAL(6,2),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(court_id, booking_date, start_time),
  CHECK (status IN ('pendiente', 'confirmada', 'cancelada', 'completada'))
);

-- =============================================
-- Padel Matches (Partidos)
-- =============================================
CREATE TABLE IF NOT EXISTS app.padel_matches (
  id SERIAL PRIMARY KEY,
  booking_id INTEGER REFERENCES app.padel_bookings(id),
  created_by INTEGER NOT NULL REFERENCES app.users(id),
  match_type VARCHAR(10) DEFAULT 'abierto',
  min_level INTEGER DEFAULT 1,
  max_level INTEGER DEFAULT 9,
  max_players INTEGER DEFAULT 4,
  current_players INTEGER DEFAULT 1,
  status VARCHAR(20) DEFAULT 'buscando',
  match_date DATE,
  start_time TIME,
  venue_id INTEGER REFERENCES app.padel_venues(id),
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CHECK (match_type IN ('abierto', 'privado')),
  CHECK (status IN ('buscando', 'completo', 'en_juego', 'finalizado', 'cancelado'))
);

-- =============================================
-- Padel Match Players (Jugadores en partido)
-- =============================================
CREATE TABLE IF NOT EXISTS app.padel_match_players (
  id SERIAL PRIMARY KEY,
  match_id INTEGER NOT NULL REFERENCES app.padel_matches(id) ON DELETE CASCADE,
  user_id INTEGER NOT NULL REFERENCES app.users(id),
  team INTEGER CHECK (team IN (1, 2)),
  status VARCHAR(20) DEFAULT 'confirmado',
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(match_id, user_id)
);

-- =============================================
-- Padel Player Ratings (Valoraciones)
-- =============================================
CREATE TABLE IF NOT EXISTS app.padel_player_ratings (
  id SERIAL PRIMARY KEY,
  rater_id INTEGER NOT NULL REFERENCES app.users(id),
  rated_id INTEGER NOT NULL REFERENCES app.users(id),
  match_id INTEGER REFERENCES app.padel_matches(id),
  rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(rater_id, rated_id, match_id),
  CHECK (rater_id != rated_id)
);

-- =============================================
-- Padel Favorites (Favoritos)
-- =============================================
CREATE TABLE IF NOT EXISTS app.padel_favorites (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES app.users(id) ON DELETE CASCADE,
  favorite_id INTEGER NOT NULL REFERENCES app.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, favorite_id),
  CHECK (user_id != favorite_id)
);

-- =============================================
-- Indexes
-- =============================================
CREATE INDEX IF NOT EXISTS idx_padel_courts_venue ON app.padel_courts(venue_id);
CREATE INDEX IF NOT EXISTS idx_padel_bookings_court_date ON app.padel_bookings(court_id, booking_date);
CREATE INDEX IF NOT EXISTS idx_padel_bookings_user ON app.padel_bookings(booked_by);
CREATE INDEX IF NOT EXISTS idx_padel_matches_date ON app.padel_matches(match_date);
CREATE INDEX IF NOT EXISTS idx_padel_matches_status ON app.padel_matches(status);
CREATE INDEX IF NOT EXISTS idx_padel_match_players_match ON app.padel_match_players(match_id);
CREATE INDEX IF NOT EXISTS idx_padel_player_profiles_level ON app.padel_player_profiles(numeric_level);
CREATE INDEX IF NOT EXISTS idx_padel_favorites_user ON app.padel_favorites(user_id);
CREATE INDEX IF NOT EXISTS idx_padel_ratings_rated ON app.padel_player_ratings(rated_id);
