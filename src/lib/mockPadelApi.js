const STORAGE_KEY = 'padel_mock_state_v1';

const baseVenues = [
  {
    id: 1,
    name: 'Centro Deportivo Puerto Rey',
    location: 'Vera',
    address: 'Urbanizacion Puerto Rey, Vera, Almeria',
    phone: null,
    email: null,
    image_url: null,
    opening_time: '08:00',
    closing_time: '23:00',
    is_active: true,
  },
  {
    id: 2,
    name: 'Labios Padel Cuevas',
    location: 'Cuevas del Almanzora',
    address: 'Cuevas del Almanzora, Almeria',
    phone: null,
    email: null,
    image_url: null,
    opening_time: '09:00',
    closing_time: '22:00',
    is_active: true,
  },
  {
    id: 3,
    name: 'Desert Springs Resort',
    location: 'Cuevas del Almanzora',
    address: 'Desert Springs Resort, Cuevas del Almanzora, Almeria',
    phone: null,
    email: null,
    image_url: null,
    opening_time: '08:00',
    closing_time: '21:00',
    is_active: true,
  },
];

const baseCourts = [
  { id: 1, venue_id: 1, name: 'Pista 1', court_type: 'standard', surface: 'cesped', has_lighting: true, price_per_hour: 12, peak_price_per_hour: 16, is_active: true },
  { id: 2, venue_id: 1, name: 'Pista 2', court_type: 'standard', surface: 'cesped', has_lighting: true, price_per_hour: 12, peak_price_per_hour: 16, is_active: true },
  { id: 3, venue_id: 1, name: 'Pista Cristal 1', court_type: 'cristal', surface: 'cesped', has_lighting: true, price_per_hour: 16, peak_price_per_hour: 20, is_active: true },
  { id: 4, venue_id: 2, name: 'Pista 1', court_type: 'standard', surface: 'cesped', has_lighting: true, price_per_hour: 10, peak_price_per_hour: 14, is_active: true },
  { id: 5, venue_id: 2, name: 'Pista 2', court_type: 'cristal', surface: 'cesped', has_lighting: true, price_per_hour: 14, peak_price_per_hour: 18, is_active: true },
  { id: 6, venue_id: 3, name: 'Pista 1', court_type: 'standard', surface: 'cesped', has_lighting: true, price_per_hour: 14, peak_price_per_hour: 18, is_active: true },
  { id: 7, venue_id: 3, name: 'Pista 2', court_type: 'cristal', surface: 'cesped', has_lighting: true, price_per_hour: 18, peak_price_per_hour: 22, is_active: true },
];

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

function toIsoDate(date) {
  return new Date(date.getTime() - date.getTimezoneOffset() * 60000).toISOString().slice(0, 10);
}

function dateOffset(days) {
  const date = new Date();
  date.setHours(0, 0, 0, 0);
  date.setDate(date.getDate() + days);
  return toIsoDate(date);
}

function nowIso() {
  return new Date().toISOString();
}

function numericLevelFrom(mainLevel = 'bajo', subLevel = 'bajo') {
  const mainMap = { bajo: 0, medio: 3, alto: 6 };
  const subMap = { bajo: 1, medio: 2, alto: 3 };
  return (mainMap[mainLevel] ?? 0) + (subMap[subLevel] ?? 1);
}

function createInitialState() {
  const createdAt = nowIso();

  return {
    nextIds: {
      user: 5,
      profile: 5,
      booking: 3,
      match: 3,
      matchPlayer: 9,
      rating: 4,
      favorite: 3,
    },
    venues: clone(baseVenues),
    courts: clone(baseCourts),
    users: [
      { id: 1, nombre: 'Ana Martin', email: 'ana@indalo.demo', password: 'demo1234', role: 'user', created_at: createdAt, updated_at: createdAt },
      { id: 2, nombre: 'Luis Garcia', email: 'luis@indalo.demo', password: 'demo1234', role: 'user', created_at: createdAt, updated_at: createdAt },
      { id: 3, nombre: 'Carmen Ruiz', email: 'carmen@indalo.demo', password: 'demo1234', role: 'user', created_at: createdAt, updated_at: createdAt },
      { id: 4, nombre: 'Pedro Lopez', email: 'pedro@indalo.demo', password: 'demo1234', role: 'user', created_at: createdAt, updated_at: createdAt },
    ],
    profiles: [
      { id: 1, user_id: 1, display_name: 'Ana Martin', main_level: 'medio', sub_level: 'bajo', numeric_level: 4, preferred_side: 'drive', preferred_venue_id: 1, bio: 'Busco partidos entre semana por la tarde.', avatar_url: null, matches_played: 18, matches_won: 10, is_available: true, created_at: createdAt, updated_at: createdAt },
      { id: 2, user_id: 2, display_name: 'Luis Garcia', main_level: 'medio', sub_level: 'alto', numeric_level: 6, preferred_side: 'reves', preferred_venue_id: 1, bio: 'Prefiero partidos competitivos y organizados.', avatar_url: null, matches_played: 26, matches_won: 14, is_available: true, created_at: createdAt, updated_at: createdAt },
      { id: 3, user_id: 3, display_name: 'Carmen Ruiz', main_level: 'bajo', sub_level: 'alto', numeric_level: 3, preferred_side: 'ambos', preferred_venue_id: 2, bio: 'Me adapto a distintos niveles y horarios.', avatar_url: null, matches_played: 12, matches_won: 5, is_available: true, created_at: createdAt, updated_at: createdAt },
      { id: 4, user_id: 4, display_name: 'Pedro Lopez', main_level: 'alto', sub_level: 'bajo', numeric_level: 7, preferred_side: 'drive', preferred_venue_id: 3, bio: 'Juego rapido y agresivo. Disponible fines de semana.', avatar_url: null, matches_played: 34, matches_won: 22, is_available: false, created_at: createdAt, updated_at: createdAt },
    ],
    bookings: [
      { id: 1, court_id: 1, booked_by: 1, booking_date: dateOffset(1), start_time: '20:00', end_time: '21:00', status: 'pendiente', total_price: 16, notes: 'Reserva demo pendiente', created_at: createdAt, updated_at: createdAt },
      { id: 2, court_id: 4, booked_by: 1, booking_date: dateOffset(-6), start_time: '18:00', end_time: '19:00', status: 'completada', total_price: 14, notes: 'Partido ya jugado', created_at: createdAt, updated_at: createdAt },
    ],
    matches: [
      { id: 1, booking_id: null, created_by: 1, match_type: 'abierto', min_level: 3, max_level: 6, max_players: 4, current_players: 2, status: 'buscando', match_date: dateOffset(1), start_time: '19:00', venue_id: 1, description: 'Partido abierto para nivel intermedio.', created_at: createdAt, updated_at: createdAt },
      { id: 2, booking_id: null, created_by: 3, match_type: 'abierto', min_level: 2, max_level: 8, max_players: 4, current_players: 4, status: 'completo', match_date: dateOffset(2), start_time: '18:30', venue_id: 2, description: 'Quedada cerrada, a la espera de jugar.', created_at: createdAt, updated_at: createdAt },
    ],
    matchPlayers: [
      { id: 1, match_id: 1, user_id: 1, team: 1, status: 'confirmado', joined_at: createdAt },
      { id: 2, match_id: 1, user_id: 2, team: 2, status: 'confirmado', joined_at: createdAt },
      { id: 3, match_id: 2, user_id: 3, team: 1, status: 'confirmado', joined_at: createdAt },
      { id: 4, match_id: 2, user_id: 4, team: 1, status: 'confirmado', joined_at: createdAt },
      { id: 5, match_id: 2, user_id: 1, team: 2, status: 'confirmado', joined_at: createdAt },
      { id: 6, match_id: 2, user_id: 2, team: 2, status: 'confirmado', joined_at: createdAt },
    ],
    ratings: [
      { id: 1, rater_id: 2, rated_id: 1, match_id: 2, rating: 5, comment: 'Muy buena companera de partido.', created_at: createdAt },
      { id: 2, rater_id: 3, rated_id: 1, match_id: null, rating: 4, comment: 'Puntual y facil para organizar.', created_at: createdAt },
      { id: 3, rater_id: 1, rated_id: 2, match_id: null, rating: 5, comment: 'Nivel alto y buen ambiente.', created_at: createdAt },
    ],
    favorites: [
      { id: 1, user_id: 1, favorite_id: 2, created_at: createdAt },
      { id: 2, user_id: 1, favorite_id: 4, created_at: createdAt },
    ],
  };
}

function readState() {
  if (typeof window === 'undefined') {
    return createInitialState();
  }

  const raw = window.localStorage.getItem(STORAGE_KEY);
  if (!raw) {
    const state = createInitialState();
    writeState(state);
    return state;
  }

  try {
    return JSON.parse(raw);
  } catch {
    const state = createInitialState();
    writeState(state);
    return state;
  }
}

function writeState(state) {
  if (typeof window === 'undefined') {
    return;
  }
  window.localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
}

function nextId(state, key) {
  const value = state.nextIds[key];
  state.nextIds[key] += 1;
  return value;
}

function parseRequestBody(body) {
  if (!body) {
    return {};
  }

  if (typeof body === 'string') {
    try {
      return JSON.parse(body);
    } catch {
      return {};
    }
  }

  return body;
}

function createMockError(status, error, extra = {}) {
  const err = new Error(error);
  err.status = status;
  err.data = { error, ...extra };
  return err;
}

function extractToken(headers = {}) {
  const authHeader = headers.Authorization || headers.authorization;
  if (!authHeader) {
    return null;
  }

  return authHeader.startsWith('Bearer ') ? authHeader.slice(7) : authHeader;
}

function getAuthenticatedUser(state, headers = {}) {
  const token = extractToken(headers);
  if (!token) {
    throw createMockError(401, 'Token de acceso requerido');
  }

  const match = token.match(/^mock-token-(\d+)$/);
  if (!match) {
    throw createMockError(403, 'Token invalido');
  }

  const userId = Number(match[1]);
  const user = state.users.find((item) => item.id === userId);
  if (!user) {
    throw createMockError(401, 'Usuario no encontrado');
  }

  return user;
}

function getVenue(state, venueId) {
  return state.venues.find((venue) => venue.id === Number(venueId) && venue.is_active);
}

function getCourt(state, courtId) {
  return state.courts.find((court) => court.id === Number(courtId) && court.is_active);
}

function getUserById(state, userId) {
  return state.users.find((user) => user.id === Number(userId));
}

function getProfileByUserId(state, userId) {
  return state.profiles.find((profile) => profile.user_id === Number(userId));
}

function buildPublicUser(user) {
  return {
    id: user.id,
    nombre: user.nombre,
    email: user.email,
  };
}

function getAverageRating(state, userId) {
  const ratings = state.ratings.filter((rating) => rating.rated_id === Number(userId));
  if (ratings.length === 0) {
    return 0;
  }

  const total = ratings.reduce((sum, rating) => sum + rating.rating, 0);
  return total / ratings.length;
}

function buildPlayerSummary(state, userId, viewerId = null) {
  const user = getUserById(state, userId);
  const profile = getProfileByUserId(state, userId);
  const avgRating = getAverageRating(state, userId);
  const totalRatings = state.ratings.filter((rating) => rating.rated_id === Number(userId)).length;
  const isFavorited = viewerId
    ? state.favorites.some((favorite) => favorite.user_id === Number(viewerId) && favorite.favorite_id === Number(userId))
    : false;

  return {
    user_id: user?.id,
    nombre: user?.nombre,
    email: user?.email,
    display_name: profile?.display_name || user?.nombre,
    main_level: profile?.main_level || 'bajo',
    sub_level: profile?.sub_level || 'bajo',
    numeric_level: profile?.numeric_level ?? numericLevelFrom(profile?.main_level, profile?.sub_level),
    preferred_side: profile?.preferred_side || 'ambos',
    preferred_venue_id: profile?.preferred_venue_id || null,
    bio: profile?.bio || '',
    avatar_url: profile?.avatar_url || null,
    matches_played: profile?.matches_played || 0,
    matches_won: profile?.matches_won || 0,
    is_available: profile?.is_available ?? true,
    avg_rating: avgRating,
    total_ratings: totalRatings,
    is_favorited: isFavorited,
  };
}

function enrichBooking(state, booking) {
  const court = getCourt(state, booking.court_id);
  const venue = getVenue(state, court?.venue_id);

  return {
    ...booking,
    court_name: court?.name || 'Pista',
    court_type: court?.court_type || 'standard',
    venue_name: venue?.name || 'Sede',
    venue_location: venue?.location || 'Sin ubicacion',
  };
}

function enrichMatch(state, match) {
  const venue = getVenue(state, match.venue_id);
  const creator = getUserById(state, match.created_by);
  const players = state.matchPlayers
    .filter((player) => player.match_id === match.id)
    .map((player) => {
      const user = getUserById(state, player.user_id);
      const profile = getProfileByUserId(state, player.user_id);

      return {
        user_id: player.user_id,
        team: player.team,
        nombre: user?.nombre || 'Jugador',
        display_name: profile?.display_name || user?.nombre || 'Jugador',
        numeric_level: profile?.numeric_level || 0,
      };
    });

  return {
    ...match,
    venue_name: venue?.name || 'Sin sede',
    venue_location: venue?.location || 'Sin ubicacion',
    creator_name: creator?.nombre || 'Organizador',
    players,
  };
}

function buildAvailability(state, venueId, date) {
  const venue = getVenue(state, venueId);
  if (!venue) {
    throw createMockError(404, 'Sede no encontrada');
  }

  const courts = state.courts
    .filter((court) => court.venue_id === venue.id && court.is_active)
    .sort((left, right) => left.name.localeCompare(right.name));

  const bookings = state.bookings.filter(
    (booking) =>
      courts.some((court) => court.id === booking.court_id) &&
      booking.booking_date === date &&
      booking.status !== 'cancelada'
  );

  const openHour = Number(venue.opening_time.split(':')[0]);
  const closeHour = Number(venue.closing_time.split(':')[0]);
  const slots = [];

  for (let hour = openHour; hour < closeHour; hour += 1) {
    const slotTime = `${String(hour).padStart(2, '0')}:00`;
    const slotCourts = courts.map((court) => {
      const isBooked = bookings.some(
        (booking) => booking.court_id === court.id && booking.start_time.slice(0, 5) === slotTime
      );
      const isPeak = hour >= 18 && hour < 22;

      return {
        court_id: court.id,
        court_name: court.name,
        available: !isBooked,
        price: isPeak ? court.peak_price_per_hour : court.price_per_hour,
      };
    });

    slots.push({
      time: slotTime,
      courts: slotCourts,
    });
  }

  return {
    date,
    venue_id: venue.id,
    opening_time: venue.opening_time,
    closing_time: venue.closing_time,
    courts,
    slots,
  };
}

function sortBookings(bookings) {
  return [...bookings].sort((left, right) => {
    const leftValue = `${left.booking_date}T${left.start_time}`;
    const rightValue = `${right.booking_date}T${right.start_time}`;
    return leftValue.localeCompare(rightValue);
  });
}

export async function handleMockRequest(url, options = {}) {
  const method = (options.method || 'GET').toUpperCase();
  const parsedUrl = new URL(url, window.location.origin);
  const pathname = parsedUrl.pathname;
  const body = parseRequestBody(options.body);
  const state = readState();

  if (pathname === '/padel/auth/register' && method === 'POST') {
    const { nombre, email, password, main_level, sub_level, preferred_side } = body;

    if (!nombre || !email || !password) {
      throw createMockError(400, 'Nombre, email y contrasena son requeridos');
    }

    const existing = state.users.find((user) => user.email.toLowerCase() === String(email).toLowerCase());
    if (existing) {
      throw createMockError(400, 'Ya existe un usuario con este email');
    }

    const createdAt = nowIso();
    const user = {
      id: nextId(state, 'user'),
      nombre,
      email,
      password,
      role: 'user',
      created_at: createdAt,
      updated_at: createdAt,
    };

    const profile = {
      id: nextId(state, 'profile'),
      user_id: user.id,
      display_name: nombre,
      main_level: main_level || 'bajo',
      sub_level: sub_level || 'bajo',
      numeric_level: numericLevelFrom(main_level || 'bajo', sub_level || 'bajo'),
      preferred_side: preferred_side || 'ambos',
      preferred_venue_id: null,
      bio: '',
      avatar_url: null,
      matches_played: 0,
      matches_won: 0,
      is_available: true,
      created_at: createdAt,
      updated_at: createdAt,
    };

    state.users.push(user);
    state.profiles.push(profile);
    writeState(state);

    return {
      message: 'Usuario registrado exitosamente',
      user: buildPublicUser(user),
      token: `mock-token-${user.id}`,
    };
  }

  if (pathname === '/padel/auth/login' && method === 'POST') {
    const { email, password } = body;

    if (!email || !password) {
      throw createMockError(400, 'Email y contrasena son requeridos');
    }

    const user = state.users.find((item) => item.email.toLowerCase() === String(email).toLowerCase());
    if (!user || user.password !== password) {
      throw createMockError(401, 'Credenciales incorrectas');
    }

    return {
      message: 'Login exitoso',
      user: buildPublicUser(user),
      token: `mock-token-${user.id}`,
    };
  }

  if (pathname === '/padel/auth/verify' && method === 'GET') {
    const user = getAuthenticatedUser(state, options.headers);
    return { user: buildPublicUser(user) };
  }

  if (pathname === '/padel/venues' && method === 'GET') {
    return {
      venues: state.venues
        .filter((venue) => venue.is_active)
        .map((venue) => ({
          ...venue,
          court_count: state.courts.filter((court) => court.venue_id === venue.id && court.is_active).length,
        })),
    };
  }

  const availabilityMatch = pathname.match(/^\/padel\/venues\/(\d+)\/availability$/);
  if (availabilityMatch && method === 'GET') {
    const venueId = Number(availabilityMatch[1]);
    const date = parsedUrl.searchParams.get('date');
    if (!date) {
      throw createMockError(400, 'Parametro date requerido (YYYY-MM-DD)');
    }

    return buildAvailability(state, venueId, date);
  }

  const venueMatch = pathname.match(/^\/padel\/venues\/(\d+)$/);
  if (venueMatch && method === 'GET') {
    const venue = getVenue(state, Number(venueMatch[1]));
    if (!venue) {
      throw createMockError(404, 'Sede no encontrada');
    }

    const courts = state.courts
      .filter((court) => court.venue_id === venue.id && court.is_active)
      .sort((left, right) => left.name.localeCompare(right.name));

    return {
      venue: {
        ...venue,
        court_count: courts.length,
      },
      courts,
    };
  }

  if (pathname === '/padel/bookings' && method === 'POST') {
    const user = getAuthenticatedUser(state, options.headers);
    const courtId = Number(body.court_id);
    const bookingDate = body.booking_date || body.date;
    const startTime = body.start_time;

    if (!courtId || !bookingDate || !startTime) {
      throw createMockError(400, 'court_id, booking_date y start_time son requeridos');
    }

    const court = getCourt(state, courtId);
    if (!court) {
      throw createMockError(404, 'Pista no encontrada');
    }

    const existing = state.bookings.find(
      (booking) =>
        booking.court_id === courtId &&
        booking.booking_date === bookingDate &&
        booking.start_time === startTime &&
        booking.status !== 'cancelada'
    );

    if (existing) {
      throw createMockError(409, 'Este horario ya esta reservado');
    }

    const hour = Number(startTime.split(':')[0]);
    const isPeak = hour >= 18 && hour < 22;
    const createdAt = nowIso();
    const booking = {
      id: nextId(state, 'booking'),
      court_id: courtId,
      booked_by: user.id,
      booking_date: bookingDate,
      start_time: startTime,
      end_time: body.end_time || `${String(hour + 1).padStart(2, '0')}:00`,
      status: 'pendiente',
      total_price: isPeak ? court.peak_price_per_hour : court.price_per_hour,
      notes: body.notes || '',
      created_at: createdAt,
      updated_at: createdAt,
    };

    state.bookings.push(booking);
    writeState(state);

    return { booking: enrichBooking(state, booking) };
  }

  if (pathname === '/padel/bookings/my' && method === 'GET') {
    const user = getAuthenticatedUser(state, options.headers);
    const now = new Date();
    const mine = sortBookings(
      state.bookings
        .filter((booking) => booking.booked_by === user.id)
        .map((booking) => enrichBooking(state, booking))
    );

    const upcoming = [];
    const past = [];

    mine.forEach((booking) => {
      const bookingDate = new Date(`${booking.booking_date}T${booking.start_time}`);
      if (bookingDate >= now && booking.status !== 'cancelada') {
        upcoming.push(booking);
      } else {
        past.push(booking);
      }
    });

    return { upcoming, past };
  }

  const bookingActionMatch = pathname.match(/^\/padel\/bookings\/(\d+)\/(confirm|cancel)$/);
  if (bookingActionMatch && method === 'PUT') {
    const user = getAuthenticatedUser(state, options.headers);
    const bookingId = Number(bookingActionMatch[1]);
    const action = bookingActionMatch[2];
    const booking = state.bookings.find((item) => item.id === bookingId && item.booked_by === user.id);

    if (!booking) {
      throw createMockError(404, 'Reserva no encontrada');
    }

    if (action === 'confirm' && booking.status === 'pendiente') {
      booking.status = 'confirmada';
    }

    if (action === 'cancel' && ['pendiente', 'confirmada'].includes(booking.status)) {
      booking.status = 'cancelada';
    }

    booking.updated_at = nowIso();
    writeState(state);

    return { booking: enrichBooking(state, booking) };
  }

  if (pathname === '/padel/matches' && method === 'GET') {
    const level = parsedUrl.searchParams.get('level');
    const date = parsedUrl.searchParams.get('date');
    const venueId = parsedUrl.searchParams.get('venue_id');

    const matches = state.matches
      .filter((match) => ['buscando', 'completo'].includes(match.status))
      .filter((match) => (level ? match.min_level <= Number(level) && match.max_level >= Number(level) : true))
      .filter((match) => (date ? match.match_date === date : true))
      .filter((match) => (venueId ? match.venue_id === Number(venueId) : true))
      .sort((left, right) => `${left.match_date}T${left.start_time}`.localeCompare(`${right.match_date}T${right.start_time}`))
      .map((match) => enrichMatch(state, match));

    return { matches };
  }

  if (pathname === '/padel/matches' && method === 'POST') {
    const user = getAuthenticatedUser(state, options.headers);
    const createdAt = nowIso();
    const match = {
      id: nextId(state, 'match'),
      booking_id: body.booking_id || null,
      created_by: user.id,
      match_type: body.match_type || 'abierto',
      min_level: Number(body.min_level || 1),
      max_level: Number(body.max_level || 9),
      max_players: Number(body.max_players || 4),
      current_players: 1,
      status: 'buscando',
      match_date: body.match_date,
      start_time: body.start_time,
      venue_id: Number(body.venue_id),
      description: body.description || '',
      created_at: createdAt,
      updated_at: createdAt,
    };

    state.matches.push(match);
    state.matchPlayers.push({
      id: nextId(state, 'matchPlayer'),
      match_id: match.id,
      user_id: user.id,
      team: 1,
      status: 'confirmado',
      joined_at: createdAt,
    });
    writeState(state);

    return { match: enrichMatch(state, match) };
  }

  const matchDetailMatch = pathname.match(/^\/padel\/matches\/(\d+)$/);
  if (matchDetailMatch && method === 'GET') {
    const match = state.matches.find((item) => item.id === Number(matchDetailMatch[1]));
    if (!match) {
      throw createMockError(404, 'Partido no encontrado');
    }

    const players = state.matchPlayers
      .filter((player) => player.match_id === match.id)
      .sort((left, right) => {
        const leftTeam = left.team ?? 99;
        const rightTeam = right.team ?? 99;
        if (leftTeam !== rightTeam) {
          return leftTeam - rightTeam;
        }
        return left.joined_at.localeCompare(right.joined_at);
      })
      .map((player) => {
        const user = getUserById(state, player.user_id);
        const profile = getProfileByUserId(state, player.user_id);

        return {
          ...player,
          nombre: user?.nombre || 'Jugador',
          display_name: profile?.display_name || user?.nombre || 'Jugador',
          main_level: profile?.main_level || 'bajo',
          sub_level: profile?.sub_level || 'bajo',
          numeric_level: profile?.numeric_level || 0,
          preferred_side: profile?.preferred_side || 'ambos',
        };
      });

    return {
      match: enrichMatch(state, match),
      players,
    };
  }

  const joinMatchAction = pathname.match(/^\/padel\/matches\/(\d+)\/join$/);
  if (joinMatchAction && method === 'POST') {
    const user = getAuthenticatedUser(state, options.headers);
    const match = state.matches.find((item) => item.id === Number(joinMatchAction[1]));
    if (!match) {
      throw createMockError(404, 'Partido no encontrado');
    }

    if (match.status !== 'buscando') {
      throw createMockError(400, 'El partido ya no acepta jugadores');
    }

    if (match.current_players >= match.max_players) {
      throw createMockError(400, 'El partido esta completo');
    }

    const existing = state.matchPlayers.find(
      (player) => player.match_id === match.id && player.user_id === user.id
    );
    if (existing) {
      throw createMockError(409, 'Ya estas en este partido');
    }

    const profile = getProfileByUserId(state, user.id);
    const numericLevel = profile?.numeric_level || 0;
    if (numericLevel < match.min_level || numericLevel > match.max_level) {
      throw createMockError(400, 'Tu nivel no es compatible con este partido');
    }

    state.matchPlayers.push({
      id: nextId(state, 'matchPlayer'),
      match_id: match.id,
      user_id: user.id,
      team: body.team ?? null,
      status: 'confirmado',
      joined_at: nowIso(),
    });
    match.current_players += 1;
    if (match.current_players >= match.max_players) {
      match.status = 'completo';
    }
    match.updated_at = nowIso();
    writeState(state);

    return {
      message: 'Te has unido al partido',
      current_players: match.current_players,
      status: match.status,
    };
  }

  const leaveMatchAction = pathname.match(/^\/padel\/matches\/(\d+)\/leave$/);
  if (leaveMatchAction && method === 'POST') {
    const user = getAuthenticatedUser(state, options.headers);
    const match = state.matches.find((item) => item.id === Number(leaveMatchAction[1]));
    if (!match) {
      throw createMockError(404, 'Partido no encontrado');
    }

    if (match.created_by === user.id) {
      throw createMockError(400, 'El creador no puede abandonar el partido');
    }

    const index = state.matchPlayers.findIndex(
      (player) => player.match_id === match.id && player.user_id === user.id
    );
    if (index === -1) {
      throw createMockError(404, 'No estas en este partido');
    }

    state.matchPlayers.splice(index, 1);
    match.current_players = Math.max(0, match.current_players - 1);
    match.status = 'buscando';
    match.updated_at = nowIso();
    writeState(state);

    return { message: 'Has abandonado el partido' };
  }

  const matchStatusAction = pathname.match(/^\/padel\/matches\/(\d+)\/status$/);
  if (matchStatusAction && method === 'PUT') {
    const user = getAuthenticatedUser(state, options.headers);
    const match = state.matches.find((item) => item.id === Number(matchStatusAction[1]));
    if (!match || match.created_by !== user.id) {
      throw createMockError(404, 'Partido no encontrado o no tienes permisos');
    }

    match.status = body.status;
    match.updated_at = nowIso();
    writeState(state);

    return { match: enrichMatch(state, match) };
  }

  if (pathname === '/padel/players/search' && method === 'GET') {
    const viewer = extractToken(options.headers) ? getAuthenticatedUser(state, options.headers) : null;
    const name = (parsedUrl.searchParams.get('name') || '').trim().toLowerCase();
    const level = parsedUrl.searchParams.get('level');
    const available = parsedUrl.searchParams.get('available');

    const players = state.users
      .map((user) => buildPlayerSummary(state, user.id, viewer?.id))
      .filter((player) => (name ? `${player.display_name} ${player.nombre}`.toLowerCase().includes(name) : true))
      .filter((player) => (level ? player.numeric_level === Number(level) : true))
      .filter((player) => (available === 'true' ? player.is_available : true))
      .sort((left, right) => {
        if (right.numeric_level !== left.numeric_level) {
          return right.numeric_level - left.numeric_level;
        }
        return left.display_name.localeCompare(right.display_name);
      });

    return { players };
  }

  if (pathname === '/padel/players/profile' && method === 'GET') {
    const user = getAuthenticatedUser(state, options.headers);
    return { profile: buildPlayerSummary(state, user.id, user.id) };
  }

  if (pathname === '/padel/players/profile' && method === 'PUT') {
    const user = getAuthenticatedUser(state, options.headers);
    const profile = getProfileByUserId(state, user.id);
    if (!profile) {
      throw createMockError(404, 'Perfil no encontrado');
    }

    Object.assign(profile, {
      display_name: body.display_name ?? profile.display_name,
      preferred_side: body.preferred_side ?? profile.preferred_side,
      bio: body.bio ?? profile.bio,
      is_available: body.is_available ?? profile.is_available,
      preferred_venue_id: body.preferred_venue_id ?? profile.preferred_venue_id,
      main_level: body.main_level ?? profile.main_level,
      sub_level: body.sub_level ?? profile.sub_level,
      updated_at: nowIso(),
    });
    profile.numeric_level = numericLevelFrom(profile.main_level, profile.sub_level);
    writeState(state);

    return { profile: buildPlayerSummary(state, user.id, user.id) };
  }

  if (pathname === '/padel/players/favorites' && method === 'GET') {
    const user = getAuthenticatedUser(state, options.headers);
    const favorites = state.favorites
      .filter((favorite) => favorite.user_id === user.id)
      .sort((left, right) => right.created_at.localeCompare(left.created_at))
      .map((favorite) => ({
        ...buildPlayerSummary(state, favorite.favorite_id, user.id),
        favorited_at: favorite.created_at,
      }));

    return { favorites };
  }

  const playerDetailMatch = pathname.match(/^\/padel\/players\/(\d+)$/);
  if (playerDetailMatch && method === 'GET') {
    const viewer = extractToken(options.headers) ? getAuthenticatedUser(state, options.headers) : null;
    const userId = Number(playerDetailMatch[1]);
    const player = buildPlayerSummary(state, userId, viewer?.id);
    if (!player.user_id) {
      throw createMockError(404, 'Jugador no encontrado');
    }

    const ratings = state.ratings
      .filter((rating) => rating.rated_id === userId)
      .sort((left, right) => right.created_at.localeCompare(left.created_at))
      .slice(0, 10)
      .map((rating) => ({
        ...rating,
        rater_name: getUserById(state, rating.rater_id)?.nombre || 'Jugador',
      }));

    return {
      player,
      ratings,
    };
  }

  const ratePlayerMatch = pathname.match(/^\/padel\/players\/(\d+)\/rate$/);
  if (ratePlayerMatch && method === 'POST') {
    const user = getAuthenticatedUser(state, options.headers);
    const ratedId = Number(ratePlayerMatch[1]);

    if (user.id === ratedId) {
      throw createMockError(400, 'No puedes valorarte a ti mismo');
    }

    const ratingValue = Number(body.rating);
    if (!ratingValue || ratingValue < 1 || ratingValue > 5) {
      throw createMockError(400, 'La valoracion debe ser entre 1 y 5');
    }

    let rating = state.ratings.find(
      (item) =>
        item.rater_id === user.id &&
        item.rated_id === ratedId &&
        (item.match_id || null) === (body.match_id || null)
    );

    if (rating) {
      rating.rating = ratingValue;
      rating.comment = body.comment || '';
      rating.created_at = nowIso();
    } else {
      rating = {
        id: nextId(state, 'rating'),
        rater_id: user.id,
        rated_id: ratedId,
        match_id: body.match_id || null,
        rating: ratingValue,
        comment: body.comment || '',
        created_at: nowIso(),
      };
      state.ratings.push(rating);
    }

    writeState(state);
    return { rating };
  }

  const favoritePlayerMatch = pathname.match(/^\/padel\/players\/(\d+)\/favorite$/);
  if (favoritePlayerMatch && method === 'POST') {
    const user = getAuthenticatedUser(state, options.headers);
    const favoriteId = Number(favoritePlayerMatch[1]);

    if (user.id === favoriteId) {
      throw createMockError(400, 'No puedes anadirte como favorito');
    }

    const existingIndex = state.favorites.findIndex(
      (favorite) => favorite.user_id === user.id && favorite.favorite_id === favoriteId
    );

    if (existingIndex >= 0) {
      state.favorites.splice(existingIndex, 1);
      writeState(state);
      return { favorited: false, message: 'Eliminado de favoritos' };
    }

    state.favorites.push({
      id: nextId(state, 'favorite'),
      user_id: user.id,
      favorite_id: favoriteId,
      created_at: nowIso(),
    });
    writeState(state);

    return { favorited: true, message: 'Anadido a favoritos' };
  }

  throw createMockError(404, `Ruta mock no implementada: ${method} ${pathname}`);
}
