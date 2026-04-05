import { handleMockRequest } from './mockPadelApi';

const BASE_URL = import.meta.env.VITE_API_URL
  ? `${import.meta.env.VITE_API_URL.replace(/\/$/, '')}/api`
  : '/api';

let runtimeMode = import.meta.env.VITE_DEMO_MODE === 'true' ? 'mock' : 'network';

function numericLevelFrom(mainLevel = 'bajo', subLevel = 'bajo') {
  const mainMap = { bajo: 0, medio: 3, alto: 6 };
  const subMap = { bajo: 1, medio: 2, alto: 3 };
  return (mainMap[mainLevel] ?? 0) + (subMap[subLevel] ?? 1);
}

function normalizeVenue(venue) {
  return {
    ...venue,
    name: venue?.name ?? venue?.nombre,
    location: venue?.location ?? venue?.ubicacion,
  };
}

function normalizeCourt(court) {
  return {
    ...court,
    surface_type: court?.surface_type ?? court?.surface,
  };
}

function normalizeBooking(booking) {
  return {
    ...booking,
    date: booking?.date ?? booking?.booking_date,
    price: booking?.price ?? booking?.total_price,
  };
}

function normalizeMatch(match) {
  return {
    ...match,
    creator_id: match?.creator_id ?? match?.created_by,
    player_count: match?.player_count ?? match?.current_players ?? match?.players?.length ?? 0,
  };
}

function normalizeMatchPlayer(player) {
  return {
    ...player,
    id: player?.id ?? player?.user_id,
    name: player?.name ?? player?.display_name ?? player?.nombre,
    level: player?.level ?? player?.numeric_level ?? 0,
  };
}

function normalizePlayer(player) {
  const rawAvgRating = Number(player?.avg_rating ?? 0);

  return {
    ...player,
    display_name: player?.display_name ?? player?.nombre,
    level:
      player?.level ??
      player?.numeric_level ??
      numericLevelFrom(player?.main_level, player?.sub_level),
    avg_rating: Number.isFinite(rawAvgRating) ? rawAvgRating : 0,
    total_ratings: Number(player?.total_ratings ?? 0),
  };
}

function normalizeAvailability(data) {
  const timeSlots = (data?.time_slots || data?.slots || []).map((slot) => {
    if (slot.start_time) {
      return {
        ...slot,
        courts: slot.courts || {},
      };
    }

    const mappedCourts = {};
    (slot.courts || []).forEach((courtSlot) => {
      mappedCourts[courtSlot.court_id] = {
        available: courtSlot.available,
        price: courtSlot.price,
      };
    });

    return {
      start_time: slot.time,
      courts: mappedCourts,
    };
  });

  return {
    ...data,
    courts: (data?.courts || []).map(normalizeCourt),
    time_slots: timeSlots,
  };
}

function normalizeResponse(url, method, data) {
  if (method === 'GET' && url === '/padel/venues') {
    return (data?.venues || data || []).map(normalizeVenue);
  }

  if (method === 'GET' && /^\/padel\/venues\/\d+$/.test(url)) {
    return data?.venue
      ? { ...normalizeVenue(data.venue), courts: (data.courts || []).map(normalizeCourt) }
      : normalizeVenue(data);
  }

  if (method === 'GET' && /^\/padel\/venues\/\d+\/availability/.test(url)) {
    return normalizeAvailability(data);
  }

  if (method === 'POST' && url === '/padel/bookings') {
    return normalizeBooking(data?.booking || data);
  }

  if (method === 'GET' && url === '/padel/bookings/my') {
    return {
      upcoming: (data?.upcoming || []).map(normalizeBooking),
      past: (data?.past || []).map(normalizeBooking),
    };
  }

  if (method === 'PUT' && /^\/padel\/bookings\/\d+\/(confirm|cancel)$/.test(url)) {
    return normalizeBooking(data?.booking || data);
  }

  if (method === 'GET' && url.startsWith('/padel/matches')) {
    if (/^\/padel\/matches\/\d+$/.test(url)) {
      return {
        match: normalizeMatch(data?.match || data),
        players: (data?.players || []).map(normalizeMatchPlayer),
      };
    }

    return (data?.matches || data || []).map(normalizeMatch);
  }

  if (method === 'POST' && url === '/padel/matches') {
    return { match: normalizeMatch(data?.match || data) };
  }

  if (method === 'PUT' && /^\/padel\/matches\/\d+\/status$/.test(url)) {
    return { ...data, match: normalizeMatch(data?.match || data) };
  }

  if (method === 'GET' && url.startsWith('/padel/players/search')) {
    return (data?.players || data || []).map(normalizePlayer);
  }

  if (method === 'GET' && url === '/padel/players/favorites') {
    return { favorites: (data?.favorites || []).map(normalizePlayer) };
  }

  if ((method === 'GET' || method === 'PUT') && url === '/padel/players/profile') {
    return { profile: normalizePlayer(data?.profile || data) };
  }

  if (method === 'GET' && /^\/padel\/players\/\d+$/.test(url)) {
    return {
      player: normalizePlayer(data?.player || data),
      ratings: (data?.ratings || []).map((rating) => ({
        ...rating,
        rating: Number(rating?.rating ?? 0),
      })),
    };
  }

  return data;
}

function createApiError(status, data) {
  const error = new Error(data?.error || `HTTP ${status}`);
  error.status = status;
  error.data = data;
  return error;
}

function shouldFallbackToMock(error) {
  return error instanceof TypeError || /fetch|network|Failed to fetch/i.test(error.message || '');
}

class ApiClient {
  constructor(baseURL) {
    this.baseURL = baseURL;
  }

  getToken() {
    return localStorage.getItem('padel_token');
  }

  getHeaders(customHeaders = {}) {
    const headers = { 'Content-Type': 'application/json', ...customHeaders };
    const token = this.getToken();
    if (token) {
      headers.Authorization = `Bearer ${token}`;
    }
    return headers;
  }

  async request(url, options = {}) {
    const method = (options.method || 'GET').toUpperCase();
    const fullUrl = `${this.baseURL}${url}`;
    const requestOptions = {
      ...options,
      method,
      headers: this.getHeaders(options.headers),
    };

    if (runtimeMode === 'mock') {
      return normalizeResponse(url, method, await handleMockRequest(url, requestOptions));
    }

    try {
      const response = await fetch(fullUrl, requestOptions);
      const data = await response.json();

      if (response.status === 401) {
        localStorage.removeItem('padel_token');
        localStorage.removeItem('padel_user');
        if (!window.location.pathname.includes('/login') && !window.location.pathname.includes('/register')) {
          window.location.href = '/login';
        }
        throw createApiError(response.status, data);
      }

      if (!response.ok) {
        throw createApiError(response.status, data);
      }

      return normalizeResponse(url, method, data);
    } catch (error) {
      if (shouldFallbackToMock(error)) {
        runtimeMode = 'mock';
        return normalizeResponse(url, method, await handleMockRequest(url, requestOptions));
      }

      throw error;
    }
  }

  get(url) {
    return this.request(url, { method: 'GET' });
  }

  post(url, data) {
    return this.request(url, { method: 'POST', body: JSON.stringify(data) });
  }

  put(url, data) {
    return this.request(url, { method: 'PUT', body: data === undefined ? undefined : JSON.stringify(data) });
  }

  delete(url) {
    return this.request(url, { method: 'DELETE' });
  }
}

const apiClient = new ApiClient(BASE_URL);
export default apiClient;
