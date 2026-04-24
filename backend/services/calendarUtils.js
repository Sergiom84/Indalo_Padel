import { DateTime } from 'luxon';

export const APP_TIME_ZONE = process.env.CALENDAR_TIME_ZONE || 'Europe/Madrid';
export const GOOGLE_APP_TAG = 'indalo_padel';
export const DEFAULT_DURATION_MINUTES = 90;
export const DEFAULT_SLOT_STEP_MINUTES = 30;

function pad(value) {
  return String(value).padStart(2, '0');
}

export function normalizeDateValue(dateValue, timeZone = APP_TIME_ZONE) {
  if (!dateValue) {
    return null;
  }

  if (dateValue instanceof Date) {
    return DateTime.fromJSDate(dateValue, { zone: 'utc' })
      .setZone(timeZone)
      .toISODate();
  }

  if (typeof dateValue === 'string') {
    if (dateValue.length === 10) {
      return dateValue;
    }

    const parsed = DateTime.fromISO(dateValue, { setZone: true });
    if (parsed.isValid) {
      return parsed.setZone(timeZone).toISODate();
    }

    const fallback = DateTime.fromJSDate(new Date(dateValue), { zone: 'utc' });
    if (fallback.isValid) {
      return fallback.setZone(timeZone).toISODate();
    }
  }

  return String(dateValue).slice(0, 10);
}

export function clampDurationMinutes(value, fallback = DEFAULT_DURATION_MINUTES) {
  const parsed = Number.parseInt(value, 10);
  if (Number.isNaN(parsed) || parsed <= 0) {
    return fallback;
  }

  return Math.min(Math.max(parsed, 30), 240);
}

export function normalizeSlotStepMinutes(value, fallback = DEFAULT_SLOT_STEP_MINUTES) {
  const parsed = Number.parseInt(value, 10);
  if (Number.isNaN(parsed) || parsed <= 0) {
    return fallback;
  }

  return Math.min(Math.max(parsed, 15), 120);
}

export function parseTimeToMinutes(time) {
  if (!time) {
    return 0;
  }

  const [hours = '0', minutes = '0'] = String(time).split(':');
  return (Number.parseInt(hours, 10) * 60) + Number.parseInt(minutes, 10);
}

export function formatMinutesToTime(totalMinutes) {
  const normalized = ((totalMinutes % 1440) + 1440) % 1440;
  const hours = Math.floor(normalized / 60);
  const minutes = normalized % 60;
  return `${pad(hours)}:${pad(minutes)}:00`;
}

export function combineDateAndTime(dateStr, timeStr, timeZone = APP_TIME_ZONE) {
  const normalizedDate = normalizeDateValue(dateStr, timeZone);
  return DateTime.fromISO(`${normalizedDate}T${timeStr}`, { zone: timeZone });
}

export function nowInAppZone(timeZone = APP_TIME_ZONE) {
  return DateTime.now().setZone(timeZone);
}

export function toGoogleDateTime(dateStr, timeStr, timeZone = APP_TIME_ZONE) {
  return combineDateAndTime(dateStr, timeStr, timeZone).toISO({ suppressMilliseconds: true });
}

export function toLocalDateParts(dateTimeValue, timeZone = APP_TIME_ZONE) {
  if (!dateTimeValue) {
    return {
      date: null,
      time: null,
    };
  }

  if (String(dateTimeValue).length === 10) {
    const dt = DateTime.fromISO(dateTimeValue, { zone: timeZone });
    return {
      date: dt.toISODate(),
      time: dt.toFormat('HH:mm:ss'),
    };
  }

  const dt = DateTime.fromISO(dateTimeValue, { setZone: true }).setZone(timeZone);
  return {
    date: dt.toISODate(),
    time: dt.toFormat('HH:mm:ss'),
  };
}

export function calculateEndTime(dateStr, startTime, durationMinutes, timeZone = APP_TIME_ZONE) {
  return combineDateAndTime(dateStr, startTime, timeZone).plus({ minutes: durationMinutes });
}

export function formatBookingDescription({
  bookingId,
  venueName,
  venueLocation,
  courtName,
  durationMinutes,
  notes,
  players = [],
}) {
  const formattedPlayers = players.length > 0
    ? players
        .map((player) => player.display_name || player.nombre || 'Jugador')
        .join('\n')
    : 'Sin jugadores invitados';

  return [
    'Indalo Padel',
    `Reserva ID: ${bookingId}`,
    venueName ? `Sede: ${venueName}` : null,
    venueLocation ? `Ubicacion: ${venueLocation}` : null,
    courtName ? `Pista: ${courtName}` : null,
    durationMinutes ? `Duracion: ${durationMinutes} min` : null,
    'Observaciones:',
    notes?.trim() ? notes.trim() : 'Sin observaciones',
    '',
    'Jugadores:',
    formattedPlayers,
  ]
    .filter((line) => line !== null)
    .join('\n');
}

export function parseBookingDescription(description = '') {
  const lines = String(description).split(/\r?\n/);
  const normalized = lines.map((line) => line.trim());
  const reservationLine = normalized.find((line) => /^Reserva ID:/i.test(line));
  const bookingId = reservationLine ? Number.parseInt(reservationLine.replace(/^Reserva ID:\s*/i, ''), 10) : null;

  const notesStart = normalized.findIndex((line) => /^Observaciones:/i.test(line));
  const playersStart = normalized.findIndex((line) => /^Jugadores:/i.test(line));
  let notes = '';

  if (notesStart >= 0) {
    const endIndex = playersStart >= 0 ? playersStart : normalized.length;
    notes = normalized
      .slice(notesStart + 1, endIndex)
      .join('\n')
      .trim();
    if (notes === 'Sin observaciones') {
      notes = '';
    }
  }

  return {
    bookingId: Number.isFinite(bookingId) ? bookingId : null,
    notes,
  };
}

export function isBookingOverlap({
  bookingStartMinutes,
  bookingEndMinutes,
  candidateStartMinutes,
  candidateEndMinutes,
}) {
  return bookingStartMinutes < candidateEndMinutes && bookingEndMinutes > candidateStartMinutes;
}

export function calculatePrice({
  pricePerHour,
  peakPricePerHour,
  startTime,
  durationMinutes,
}) {
  const hasBasePrice = pricePerHour !== null && pricePerHour !== undefined && pricePerHour !== '';
  const hasPeakPrice = peakPricePerHour !== null && peakPricePerHour !== undefined && peakPricePerHour !== '';

  if (!hasBasePrice && !hasPeakPrice) {
    return null;
  }

  const hour = Number.parseInt(String(startTime).split(':')[0], 10);
  const preferredRate = hour >= 18 && hour < 22 ? peakPricePerHour : pricePerHour;
  const fallbackRate = hour >= 18 && hour < 22 ? pricePerHour : peakPricePerHour;
  const rate = preferredRate ?? fallbackRate;

  if (rate === null || rate === undefined || rate === '') {
    return null;
  }

  return Number(rate) * (durationMinutes / 60);
}

export function normalizeGoogleResponseStatus(status) {
  switch (status) {
    case 'accepted':
      return 'aceptada';
    case 'declined':
      return 'rechazada';
    case 'cancelled':
      return 'cancelada';
    case 'tentative':
    case 'needsAction':
    default:
      return 'pendiente';
  }
}

export function normalizeInviteStatus(status) {
  switch (status) {
    case 'aceptada':
    case 'rechazada':
    case 'cancelada':
      return status;
    case 'accepted':
      return 'aceptada';
    case 'declined':
      return 'rechazada';
    case 'cancelled':
      return 'cancelada';
    case 'tentative':
    case 'needsAction':
    case 'pendiente':
    default:
      return 'pendiente';
  }
}

export function bookingStateToCalendarStatus(bookingStatus) {
  if (bookingStatus === 'cancelada') {
    return 'cancelada';
  }

  return 'pendiente';
}
