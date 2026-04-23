import {
  APP_TIME_ZONE,
  GOOGLE_APP_TAG,
  formatBookingDescription,
  toGoogleDateTime,
} from './calendarUtils.js';

const GOOGLE_TOKEN_ENDPOINT = 'https://oauth2.googleapis.com/token';
const GOOGLE_CALENDAR_API_BASE = 'https://www.googleapis.com/calendar/v3';

let cachedAccessToken = null;
let cachedAccessTokenExpiresAt = 0;

function buildCalendarId() {
  return process.env.GOOGLE_CALENDAR_ID || 'primary';
}

function normalizeEmail(value) {
  return String(value || '').trim().toLowerCase();
}

function normalizeReminderMinutes(value) {
  const parsed = Number.parseInt(String(value || ''), 10);
  if (!Number.isFinite(parsed)) {
    return 300;
  }

  return Math.min(Math.max(parsed, 5), 40320);
}

export function shouldExcludeCalendarOwnerFromAttendees(
  calendarOwnerEmail,
  calendarId = buildCalendarId(),
) {
  const normalizedOwnerEmail = normalizeEmail(calendarOwnerEmail);
  if (!normalizedOwnerEmail) {
    return false;
  }

  const normalizedCalendarId = normalizeEmail(calendarId);
  return normalizedCalendarId === 'primary'
    || normalizedCalendarId === normalizedOwnerEmail;
}

export function buildEventReminders() {
  const reminderMinutes = normalizeReminderMinutes(
    process.env.GOOGLE_EVENT_REMINDER_MINUTES || '300',
  );

  return {
    useDefault: false,
    overrides: [
      {
        method: 'popup',
        minutes: reminderMinutes,
      },
      {
        method: 'email',
        minutes: reminderMinutes,
      },
    ],
  };
}

export function isGoogleCalendarConfigured() {
  return Boolean(
    process.env.GOOGLE_CLIENT_ID &&
    process.env.GOOGLE_CLIENT_SECRET &&
    process.env.GOOGLE_REFRESH_TOKEN
  );
}

async function getAccessToken() {
  if (!isGoogleCalendarConfigured()) {
    throw new Error('Google Calendar no está configurado');
  }

  if (cachedAccessToken && Date.now() < (cachedAccessTokenExpiresAt - 60_000)) {
    return cachedAccessToken;
  }

  const payload = new URLSearchParams({
    client_id: process.env.GOOGLE_CLIENT_ID,
    client_secret: process.env.GOOGLE_CLIENT_SECRET,
    refresh_token: process.env.GOOGLE_REFRESH_TOKEN,
    grant_type: 'refresh_token',
  });

  const response = await fetch(GOOGLE_TOKEN_ENDPOINT, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: payload,
  });

  const data = await response.json();
  if (!response.ok) {
    const isRevoked = data.error === 'invalid_grant';
    if (isRevoked) {
      console.error(
        '🔴 [Google Calendar] GOOGLE_REFRESH_TOKEN revocado o expirado. ' +
        'Ejecuta: node backend/scripts/get-google-token.js y actualiza la variable de entorno.',
      );
    }
    throw new Error(data.error_description || data.error || 'No se pudo renovar el access token de Google');
  }

  cachedAccessToken = data.access_token;
  cachedAccessTokenExpiresAt = Date.now() + ((data.expires_in || 3600) * 1000);
  return cachedAccessToken;
}

async function requestCalendar(path, { method = 'GET', query, body } = {}) {
  const token = await getAccessToken();
  const url = new URL(`${GOOGLE_CALENDAR_API_BASE}${path}`);

  Object.entries(query || {}).forEach(([key, value]) => {
    if (value === undefined || value === null || value === '') {
      return;
    }

    if (Array.isArray(value)) {
      value.forEach((entry) => {
        if (entry !== undefined && entry !== null && entry !== '') {
          url.searchParams.append(key, String(entry));
        }
      });
      return;
    }

    url.searchParams.set(key, String(value));
  });

  const response = await fetch(url, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: body ? JSON.stringify(body) : undefined,
  });

  if (response.status === 204) {
    return null;
  }

  const text = await response.text();
  let data = null;
  if (text) {
    try {
      data = JSON.parse(text);
    } catch (_) {
      data = { raw: text };
    }
  }
  if (!response.ok) {
    const error = new Error(data?.error?.message || data?.error || data?.raw || `Google Calendar API error (${response.status})`);
    error.statusCode = response.status;
    error.googleError = data?.error || null;
    throw error;
  }

  return data;
}

export function buildBookingEventPayload({ booking, venue, court, players = [], organizerEmail }) {
  const startDateTime = toGoogleDateTime(booking.booking_date, booking.start_time, APP_TIME_ZONE);
  const endDateTime = toGoogleDateTime(booking.booking_date, booking.end_time, APP_TIME_ZONE);
  const venueName = venue.name || venue.venue_name || 'Sede';
  const venueLocation = venue.location || venue.venue_location || '';
  const venueAddress = venue.address || venue.venue_address || '';
  const courtName = court.name || court.court_name || 'Pista';

  const calendarOwnerEmail = normalizeEmail(
    organizerEmail || process.env.GOOGLE_ORGANIZER_EMAIL || '',
  );
  const excludeCalendarOwner = shouldExcludeCalendarOwnerFromAttendees(
    calendarOwnerEmail,
  );
  const seenAttendees = new Set();
  const attendees = players
    .filter((player) => Boolean(player.email))
    .filter((player) => {
      const email = normalizeEmail(player.email);
      if (!email) {
        return false;
      }

      if (excludeCalendarOwner && email === calendarOwnerEmail) {
        return false;
      }

      if (seenAttendees.has(email)) {
        return false;
      }

      seenAttendees.add(email);
      return true;
    })
    .map((player) => ({
      email: player.email,
      displayName: player.nombre || player.display_name || player.email,
      responseStatus: player.google_response_status || player.responseStatus || 'needsAction',
      optional: false,
    }));

  return {
    summary: `Pádel · ${venueName} · ${courtName}`,
    location: [venueAddress, venueLocation].filter(Boolean).join(' - ') || venueName,
    description: formatBookingDescription({
      bookingId: booking.id,
      venueName,
      venueLocation,
      courtName,
      durationMinutes: booking.duration_minutes,
      notes: booking.notes,
      players,
    }),
    start: {
      dateTime: startDateTime,
      timeZone: APP_TIME_ZONE,
    },
    end: {
      dateTime: endDateTime,
      timeZone: APP_TIME_ZONE,
    },
    attendees,
    guestsCanModify: false,
    guestsCanInviteOthers: false,
    guestsCanSeeOtherGuests: true,
    reminders: buildEventReminders(),
    extendedProperties: {
      private: {
        app: GOOGLE_APP_TAG,
        booking_id: String(booking.id),
        court_id: String(booking.court_id),
        venue_id: String(venue.id),
        duration_minutes: String(booking.duration_minutes),
      },
    },
  };
}

export async function createCalendarEvent(eventPayload, calendarId = buildCalendarId()) {
  return requestCalendar(`/calendars/${encodeURIComponent(calendarId)}/events`, {
    method: 'POST',
    query: {
      sendUpdates: 'all',
    },
    body: eventPayload,
  });
}

export async function updateCalendarEvent(eventId, eventPayload, calendarId = buildCalendarId()) {
  return requestCalendar(`/calendars/${encodeURIComponent(calendarId)}/events/${encodeURIComponent(eventId)}`, {
    method: 'PATCH',
    query: {
      sendUpdates: 'all',
    },
    body: eventPayload,
  });
}

export async function deleteCalendarEvent(eventId, calendarId = buildCalendarId()) {
  return requestCalendar(`/calendars/${encodeURIComponent(calendarId)}/events/${encodeURIComponent(eventId)}`, {
    method: 'DELETE',
    query: {
      sendUpdates: 'all',
    },
  });
}

export async function getCalendarEvent(eventId, calendarId = buildCalendarId()) {
  return requestCalendar(`/calendars/${encodeURIComponent(calendarId)}/events/${encodeURIComponent(eventId)}`, {
    method: 'GET',
    query: {
      maxAttendees: 250,
    },
  });
}

export async function listCalendarEvents({
  syncToken,
  pageToken,
  calendarId = buildCalendarId(),
}) {
  return requestCalendar(`/calendars/${encodeURIComponent(calendarId)}/events`, {
    method: 'GET',
    query: {
      singleEvents: 'true',
      showDeleted: 'true',
      maxResults: 2500,
      syncToken: syncToken || undefined,
      pageToken: pageToken || undefined,
      maxAttendees: 250,
    },
  });
}

export function createBaseEventTimes(booking) {
  return {
    startDateTime: toGoogleDateTime(booking.booking_date, booking.start_time, APP_TIME_ZONE),
    endDateTime: toGoogleDateTime(booking.booking_date, booking.end_time, APP_TIME_ZONE),
  };
}

export { buildCalendarId, requestCalendar };
