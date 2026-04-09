import { pool } from '../db.js';
import {
  APP_TIME_ZONE,
  DEFAULT_DURATION_MINUTES,
  DEFAULT_SLOT_STEP_MINUTES,
  calculateEndTime,
  calculatePrice,
  clampDurationMinutes,
  combineDateAndTime,
  formatMinutesToTime,
  isBookingOverlap,
  normalizeGoogleResponseStatus,
  normalizeInviteStatus,
  normalizeSlotStepMinutes,
  parseBookingDescription,
  parseTimeToMinutes,
  nowInAppZone,
  toLocalDateParts,
  normalizeDateValue,
} from './calendarUtils.js';
import {
  buildBookingEventPayload,
  createCalendarEvent,
  deleteCalendarEvent,
  getCalendarEvent,
  isGoogleCalendarConfigured,
  listCalendarEvents,
  updateCalendarEvent,
} from './googleCalendar.js';

function mapBookingRow(row) {
  return {
    id: row.id,
    court_id: row.court_id,
    booked_by: row.booked_by,
    venue_id: row.venue_id,
    venue_name: row.venue_name,
    venue_location: row.venue_location,
    venue_address: row.venue_address,
    court_name: row.court_name,
    court_type: row.court_type,
    booking_date: normalizeDateValue(row.booking_date, APP_TIME_ZONE),
    start_time: row.start_time,
    end_time: row.end_time,
    duration_minutes: row.duration_minutes,
    status: row.status,
    total_price: normalizeNumericValue(row.total_price),
    notes: row.notes,
    google_event_id: row.google_event_id,
    calendar_sync_status: row.calendar_sync_status || 'pendiente',
    last_synced_at: row.last_synced_at,
    created_at: row.created_at,
    updated_at: row.updated_at,
  };
}

function normalizeNumericValue(value) {
  if (value == null || value === '') {
    return null;
  }

  const parsed = Number.parseFloat(String(value).replace(',', '.'));
  return Number.isFinite(parsed) ? parsed : null;
}

async function queryUsersByIds(client, userIds) {
  const uniqueIds = [...new Set((userIds || []).map((value) => Number.parseInt(value, 10)).filter(Number.isFinite))];
  if (uniqueIds.length === 0) {
    return [];
  }

  const result = await client.query(
    `SELECT u.id, u.nombre, u.email, pp.display_name, pp.numeric_level
     FROM app.users u
     LEFT JOIN app.padel_player_profiles pp ON pp.user_id = u.id
     WHERE u.id = ANY($1::int[])
     ORDER BY u.nombre ASC`,
    [uniqueIds]
  );

  return result.rows;
}

async function loadCourtAndVenue(client, courtId) {
  const result = await client.query(
    `SELECT c.id as court_id, c.name as court_name, c.court_type, c.price_per_hour, c.peak_price_per_hour,
            v.id as venue_id, v.name as venue_name, v.location as venue_location, v.address as venue_address,
            v.opening_time, v.closing_time
     FROM app.padel_courts c
     JOIN app.padel_venues v ON v.id = c.venue_id
     WHERE c.id = $1 AND c.is_active = true AND v.is_active = true`,
    [courtId]
  );

  return result.rows[0] || null;
}

async function loadBookingRecord(client, bookingId) {
  const result = await client.query(
    `SELECT b.*,
            c.name as court_name, c.court_type,
            c.price_per_hour, c.peak_price_per_hour,
            v.id as venue_id, v.name as venue_name, v.location as venue_location, v.address as venue_address
     FROM app.padel_bookings b
     JOIN app.padel_courts c ON b.court_id = c.id
     JOIN app.padel_venues v ON c.venue_id = v.id
     WHERE b.id = $1`,
    [bookingId]
  );

  if (result.rows.length === 0) {
    return null;
  }

  return result.rows[0];
}

async function loadBookingPlayers(client, bookingIds) {
  const ids = [...new Set((bookingIds || []).map((value) => Number.parseInt(value, 10)).filter(Number.isFinite))];
  if (ids.length === 0) {
    return [];
  }

  const result = await client.query(
    `SELECT bp.booking_id, bp.user_id, bp.role, bp.invite_status, bp.google_response_status, bp.responded_at,
            u.nombre, u.email, pp.display_name, pp.numeric_level
     FROM app.padel_booking_players bp
     JOIN app.users u ON u.id = bp.user_id
     LEFT JOIN app.padel_player_profiles pp ON pp.user_id = u.id
     WHERE bp.booking_id = ANY($1::int[])
     ORDER BY bp.booking_id, bp.role DESC, u.nombre ASC`,
    [ids]
  );

  return result.rows;
}

function buildBookingDto(row, players = [], currentUserId = null) {
  const enrichedPlayers = players.map((player) => ({
    user_id: player.user_id,
    nombre: player.nombre,
    email: player.email,
    display_name: player.display_name,
    numeric_level: player.numeric_level,
    role: player.role,
    invite_status: normalizeInviteStatus(player.invite_status),
    google_response_status: player.google_response_status,
    responded_at: player.responded_at,
    is_current_user: currentUserId ? Number(player.user_id) === Number(currentUserId) : false,
  }));

  const myInviteRow = enrichedPlayers.find((player) => player.is_current_user);

  return {
    ...mapBookingRow(row),
    start_at: combineDateAndTime(row.booking_date, row.start_time, APP_TIME_ZONE).toISO({ suppressMilliseconds: true }),
    end_at: combineDateAndTime(row.booking_date, row.end_time, APP_TIME_ZONE).toISO({ suppressMilliseconds: true }),
    is_organizer: Number(row.booked_by) === Number(currentUserId),
    my_invite_status: Number(row.booked_by) === Number(currentUserId) ? 'aceptada' : (myInviteRow?.invite_status || null),
    my_google_response_status: Number(row.booked_by) === Number(currentUserId) ? 'accepted' : (myInviteRow?.google_response_status || null),
    players: enrichedPlayers,
  };
}

async function loadBookingBundle(client, bookingId, currentUserId = null) {
  const booking = await loadBookingRecord(client, bookingId);
  if (!booking) {
    return null;
  }

  const players = await loadBookingPlayers(client, [bookingId]);
  return buildBookingDto(booking, players, currentUserId);
}

function buildCalendarBuckets(bookings, currentUserId) {
  const upcoming = [];
  const history = [];
  const now = nowInAppZone(APP_TIME_ZONE);

  bookings.forEach((booking) => {
    const endMoment = combineDateAndTime(booking.booking_date, booking.end_time, APP_TIME_ZONE);
    const bucket = (endMoment >= now && booking.status !== 'cancelada') ? upcoming : history;
    bucket.push(buildBookingDto(booking, booking.players || [], currentUserId));
  });

  return { upcoming, history };
}

function normalizeScheduleWindow({ dayOfWeek = null, startTime, endTime, label = null, source = 'schedule' }) {
  const startMinutes = parseTimeToMinutes(startTime);
  const endMinutes = parseTimeToMinutes(endTime);

  if (!Number.isFinite(startMinutes) || !Number.isFinite(endMinutes) || endMinutes <= startMinutes) {
    return null;
  }

  return {
    day_of_week: dayOfWeek,
    start_time: formatMinutesToTime(startMinutes),
    end_time: formatMinutesToTime(endMinutes),
    start_minutes: startMinutes,
    end_minutes: endMinutes,
    label,
    source,
  };
}

async function loadVenueScheduleWindowsForDate(client, {
  venueId,
  date,
  fallbackOpeningTime = null,
  fallbackClosingTime = null,
}) {
  const result = await client.query(
    `SELECT day_of_week, start_time, end_time, label
     FROM app.padel_venue_schedule_windows
     WHERE venue_id = $1
       AND is_active = true
       AND ($2::date >= COALESCE(valid_from, $2::date))
       AND ($2::date <= COALESCE(valid_until, $2::date))
       AND (
         day_of_week IS NULL
         OR day_of_week = EXTRACT(ISODOW FROM $2::date)::int
       )
     ORDER BY start_time ASC`,
    [venueId, date]
  );

  const scheduleWindows = result.rows
    .map((row) => normalizeScheduleWindow({
      dayOfWeek: row.day_of_week == null ? null : Number.parseInt(row.day_of_week, 10),
      startTime: row.start_time,
      endTime: row.end_time,
      label: row.label || null,
      source: 'schedule',
    }))
    .filter(Boolean);

  if (scheduleWindows.length > 0) {
    return scheduleWindows;
  }

  const fallbackWindow = normalizeScheduleWindow({
    dayOfWeek: null,
    startTime: fallbackOpeningTime,
    endTime: fallbackClosingTime,
    label: 'Horario general',
    source: 'fallback',
  });

  return fallbackWindow ? [fallbackWindow] : [];
}

function isRangeInsideScheduleWindows({ startTime, endTime, scheduleWindows }) {
  const startMinutes = parseTimeToMinutes(startTime);
  const endMinutes = parseTimeToMinutes(endTime);
  if (!Number.isFinite(startMinutes) || !Number.isFinite(endMinutes) || endMinutes <= startMinutes) {
    return false;
  }

  return scheduleWindows.some((window) => (
    startMinutes >= window.start_minutes &&
    endMinutes <= window.end_minutes
  ));
}

export async function getVenueAvailability({ venueId, date, durationMinutes = DEFAULT_DURATION_MINUTES, slotStepMinutes = DEFAULT_SLOT_STEP_MINUTES }) {
  const client = await pool.connect();
  try {
    const venueResult = await client.query(
      'SELECT * FROM app.padel_venues WHERE id = $1 AND is_active = true',
      [venueId]
    );

    if (venueResult.rows.length === 0) {
      return { status: 404, body: { error: 'Sede no encontrada' } };
    }

    const venue = venueResult.rows[0];
    const courtsResult = await client.query(
      `SELECT id, name, court_type, surface, price_per_hour, peak_price_per_hour
       FROM app.padel_courts
       WHERE venue_id = $1 AND is_active = true
       ORDER BY name`,
      [venueId]
    );

    const bookingsResult = await client.query(
      `SELECT court_id, start_time, end_time, status
       FROM app.padel_bookings
       WHERE court_id = ANY(SELECT id FROM app.padel_courts WHERE venue_id = $1)
         AND booking_date = $2
         AND status != 'cancelada'`,
      [venueId, date]
    );

    const scheduleWindows = await loadVenueScheduleWindowsForDate(client, {
      venueId,
      date,
      fallbackOpeningTime: venue.opening_time,
      fallbackClosingTime: venue.closing_time,
    });
    const normalizedDuration = clampDurationMinutes(durationMinutes, DEFAULT_DURATION_MINUTES);
    const normalizedStep = normalizeSlotStepMinutes(slotStepMinutes, DEFAULT_SLOT_STEP_MINUTES);
    const slotMap = new Map();

    for (const window of scheduleWindows) {
      for (
        let currentMinutes = window.start_minutes;
        currentMinutes + normalizedDuration <= window.end_minutes;
        currentMinutes += normalizedStep
      ) {
        const slotStart = formatMinutesToTime(currentMinutes);
        const slotEnd = formatMinutesToTime(currentMinutes + normalizedDuration);
        const slotKey = `${slotStart}-${slotEnd}`;
        if (slotMap.has(slotKey)) {
          continue;
        }

        const courtSlots = courtsResult.rows.map((court) => {
          const blockedByCourt = bookingsResult.rows.some((booking) => (
            Number(booking.court_id) === Number(court.id) &&
            isBookingOverlap({
              bookingStartMinutes: parseTimeToMinutes(booking.start_time),
              bookingEndMinutes: parseTimeToMinutes(booking.end_time),
              candidateStartMinutes: currentMinutes,
              candidateEndMinutes: currentMinutes + normalizedDuration,
            })
          ));

          return {
            court_id: court.id,
            court_name: court.name,
            available: !blockedByCourt,
            price: calculatePrice({
              pricePerHour: court.price_per_hour,
              peakPricePerHour: court.peak_price_per_hour,
              startTime: slotStart,
              durationMinutes: normalizedDuration,
            }),
          };
        });

        slotMap.set(slotKey, {
          time: slotStart,
          start_time: slotStart,
          end_time: slotEnd,
          duration_minutes: normalizedDuration,
          courts: courtSlots,
        });
      }
    }

    const slots = Array.from(slotMap.values()).sort(
      (a, b) => parseTimeToMinutes(a.start_time) - parseTimeToMinutes(b.start_time)
    );

    const openingTime = scheduleWindows.length > 0
      ? scheduleWindows[0].start_time
      : (venue.opening_time ?? null);
    const closingTime = scheduleWindows.length > 0
      ? scheduleWindows[scheduleWindows.length - 1].end_time
      : (venue.closing_time ?? null);

    return {
      status: 200,
      body: {
        date,
        venue_id: Number.parseInt(venueId, 10),
        opening_time: openingTime,
        closing_time: closingTime,
        schedule_windows: scheduleWindows.map((window) => ({
          day_of_week: window.day_of_week,
          start_time: window.start_time,
          end_time: window.end_time,
          label: window.label,
          source: window.source,
        })),
        courts: courtsResult.rows,
        slots,
        time_slots: slots,
        duration_minutes: normalizedDuration,
        slot_step_minutes: normalizedStep,
      },
    };
  } finally {
    client.release();
  }
}

export async function createBooking({ userId, courtId, bookingDate, startTime, durationMinutes, notes, playerUserIds = [] }) {
  const normalizedDuration = clampDurationMinutes(durationMinutes, DEFAULT_DURATION_MINUTES);
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    const courtBundle = await loadCourtAndVenue(client, courtId);
    if (!courtBundle) {
      await client.query('ROLLBACK');
      return { status: 404, body: { error: 'Pista no encontrada' } };
    }

    const endDateTime = calculateEndTime(bookingDate, startTime, normalizedDuration, APP_TIME_ZONE);
    const endTime = endDateTime.toFormat('HH:mm:ss');
    const scheduleWindows = await loadVenueScheduleWindowsForDate(client, {
      venueId: courtBundle.venue_id,
      date: bookingDate,
      fallbackOpeningTime: courtBundle.opening_time,
      fallbackClosingTime: courtBundle.closing_time,
    });

    if (!isRangeInsideScheduleWindows({ startTime, endTime, scheduleWindows })) {
      await client.query('ROLLBACK');
      return { status: 400, body: { error: 'La reserva no cabe dentro del horario de la sede' } };
    }

    const overlapCheck = await client.query(
      `SELECT id
       FROM app.padel_bookings
       WHERE court_id = $1
         AND booking_date = $2
         AND status != 'cancelada'
         AND start_time < $4::time
         AND end_time > $3::time
       LIMIT 1`,
      [courtId, bookingDate, startTime, endTime]
    );

    if (overlapCheck.rows.length > 0) {
      await client.query('ROLLBACK');
      return { status: 409, body: { error: 'Este horario ya está reservado' } };
    }

    const invitedUsers = await queryUsersByIds(client, playerUserIds);
    const filteredInvitedUsers = invitedUsers.filter((player) => Number(player.id) !== Number(userId));

    const totalPrice = calculatePrice({
      pricePerHour: courtBundle.price_per_hour,
      peakPricePerHour: courtBundle.peak_price_per_hour,
      startTime,
      durationMinutes: normalizedDuration,
    });

    const bookingResult = await client.query(
      `INSERT INTO app.padel_bookings (
        court_id, booked_by, booking_date, start_time, end_time, duration_minutes, total_price, notes, status, calendar_sync_status
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'confirmada', 'pendiente')
      RETURNING *`,
      [
        courtId,
        userId,
        bookingDate,
        startTime,
        endTime,
        normalizedDuration,
        totalPrice,
        notes || null,
      ]
    );

    const booking = bookingResult.rows[0];

    await client.query(
      `INSERT INTO app.padel_booking_players (
        booking_id, user_id, role, invite_status, google_response_status, responded_at
      ) VALUES ($1, $2, 'organizer', 'aceptada', 'accepted', NOW())
      ON CONFLICT (booking_id, user_id) DO UPDATE
      SET role = EXCLUDED.role,
          invite_status = EXCLUDED.invite_status,
          google_response_status = EXCLUDED.google_response_status,
          responded_at = EXCLUDED.responded_at,
          updated_at = NOW()`,
      [booking.id, userId]
    );

    for (const player of filteredInvitedUsers) {
      await client.query(
        `INSERT INTO app.padel_booking_players (
          booking_id, user_id, role, invite_status, google_response_status, responded_at
        ) VALUES ($1, $2, 'guest', 'pendiente', 'needsAction', NULL)
        ON CONFLICT (booking_id, user_id) DO NOTHING`,
        [booking.id, player.id]
      );
    }

    await client.query('COMMIT');

    let googleSyncError = null;
    let googleEvent = null;

    if (isGoogleCalendarConfigured()) {
      try {
        const bundle = await getBookingById(booking.id, userId);
        const eventPayload = buildBookingEventPayload({
          booking: bundle,
          venue: courtBundle,
          court: courtBundle,
          players: bundle.players || [],
          organizerEmail: process.env.GOOGLE_ORGANIZER_EMAIL || null,
        });

        googleEvent = await createCalendarEvent(eventPayload);
        await pool.query(
          `UPDATE app.padel_bookings
           SET google_event_id = $1,
               calendar_sync_status = 'sincronizada',
               last_synced_at = NOW(),
               updated_at = NOW()
           WHERE id = $2`,
          [googleEvent.id, booking.id]
        );
      } catch (error) {
        googleSyncError = error;
        await pool.query(
          `UPDATE app.padel_bookings
           SET calendar_sync_status = 'error',
               updated_at = NOW()
           WHERE id = $1`,
          [booking.id]
        );
      }
    } else {
      await pool.query(
        `UPDATE app.padel_bookings
         SET calendar_sync_status = 'sincronizada',
             last_synced_at = NOW(),
             updated_at = NOW()
         WHERE id = $1`,
        [booking.id]
      );
    }

    const finalBundle = await getBookingById(booking.id, userId);

    return {
      status: 201,
      body: {
        booking: finalBundle,
        google_event: googleEvent,
        calendar_sync_status: googleSyncError ? 'error' : 'sincronizada',
        calendar_sync_error: googleSyncError ? googleSyncError.message : null,
      },
    };
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    throw error;
  } finally {
    client.release();
  }
}

export async function listBookingsForUser(userId) {
  const client = await pool.connect();
  try {
    const result = await client.query(
      `SELECT b.*,
              c.name as court_name, c.court_type,
              v.id as venue_id, v.name as venue_name, v.location as venue_location, v.address as venue_address
       FROM app.padel_bookings b
       JOIN app.padel_courts c ON b.court_id = c.id
       JOIN app.padel_venues v ON c.venue_id = v.id
       WHERE b.booked_by = $1
       ORDER BY b.booking_date DESC, b.start_time DESC`,
      [userId]
    );

    const players = await loadBookingPlayers(client, result.rows.map((booking) => booking.id));
    const playerMap = new Map();
    players.forEach((player) => {
      const key = Number(player.booking_id);
      if (!playerMap.has(key)) {
        playerMap.set(key, []);
      }
      playerMap.get(key).push(player);
    });

    const bookings = result.rows.map((booking) => buildBookingDto(booking, playerMap.get(Number(booking.id)) || [], userId));
    const now = nowInAppZone(APP_TIME_ZONE);
    const upcoming = [];
    const past = [];

    bookings.forEach((booking) => {
      const endMoment = combineDateAndTime(booking.booking_date, booking.end_time, APP_TIME_ZONE);
      if (endMoment >= now && booking.status !== 'cancelada') {
        upcoming.push(booking);
      } else {
        past.push(booking);
      }
    });

    return { upcoming, past };
  } finally {
    client.release();
  }
}

export async function getBookingById(bookingId, currentUserId = null) {
  const client = await pool.connect();
  try {
    return await loadBookingBundle(client, bookingId, currentUserId);
  } finally {
    client.release();
  }
}

export async function listMyCalendar(userId) {
  const client = await pool.connect();
  try {
    const result = await client.query(
      `SELECT DISTINCT b.*,
              c.name as court_name, c.court_type,
              v.id as venue_id, v.name as venue_name, v.location as venue_location, v.address as venue_address
       FROM app.padel_bookings b
       JOIN app.padel_courts c ON b.court_id = c.id
       JOIN app.padel_venues v ON c.venue_id = v.id
       LEFT JOIN app.padel_booking_players bp
         ON bp.booking_id = b.id
        AND bp.user_id = $1
       WHERE b.booked_by = $1 OR bp.user_id = $1
       ORDER BY b.booking_date DESC, b.start_time DESC`,
      [userId]
    );

    const playerRows = await loadBookingPlayers(client, result.rows.map((booking) => booking.id));
    const playerMap = new Map();
    playerRows.forEach((player) => {
      const key = Number(player.booking_id);
      if (!playerMap.has(key)) {
        playerMap.set(key, []);
      }
      playerMap.get(key).push(player);
    });

    const bundles = result.rows.map((booking) => buildBookingDto(booking, playerMap.get(Number(booking.id)) || [], userId));
    const now = nowInAppZone(APP_TIME_ZONE);
    const agendaUpcoming = [];
    const agendaHistory = [];
    const managedUpcoming = [];
    const managedHistory = [];

    for (const bundle of bundles) {
      const endMoment = combineDateAndTime(bundle.booking_date, bundle.end_time, APP_TIME_ZONE);
      const participantActive = bundle.is_organizer || !['rechazada', 'cancelada'].includes(bundle.my_invite_status || '');
      const isUpcoming = endMoment >= now && bundle.status !== 'cancelada' && participantActive;
      (isUpcoming ? agendaUpcoming : agendaHistory).push(bundle);

      if (Number(bundle.booked_by) === Number(userId)) {
        (isUpcoming ? managedUpcoming : managedHistory).push(bundle);
      }
    }

    return {
      agenda: {
        upcoming: agendaUpcoming,
        history: agendaHistory,
      },
      managed: {
        upcoming: managedUpcoming,
        history: managedHistory,
      },
    };
  } finally {
    client.release();
  }
}

export async function getCalendarData(userId) {
  const client = await pool.connect();
  try {
    const calendarId = process.env.GOOGLE_CALENDAR_ID || 'primary';
    const result = await client.query(
      `SELECT DISTINCT b.*,
              c.name as court_name, c.court_type,
              v.id as venue_id, v.name as venue_name, v.location as venue_location, v.address as venue_address
       FROM app.padel_bookings b
       JOIN app.padel_courts c ON b.court_id = c.id
       JOIN app.padel_venues v ON c.venue_id = v.id
       LEFT JOIN app.padel_booking_players bp
         ON bp.booking_id = b.id
        AND bp.user_id = $1
       WHERE b.booked_by = $1 OR bp.user_id = $1
       ORDER BY b.booking_date DESC, b.start_time DESC`,
      [userId]
    );

    const playerRows = await loadBookingPlayers(client, result.rows.map((booking) => booking.id));
    const syncStateResult = await client.query(
      `SELECT last_synced_at
       FROM app.padel_calendar_sync_state
       WHERE calendar_id = $1
       LIMIT 1`
      ,
      [calendarId]
    );
    const playerMap = new Map();
    playerRows.forEach((player) => {
      const key = Number(player.booking_id);
      if (!playerMap.has(key)) {
        playerMap.set(key, []);
      }
      playerMap.get(key).push(player);
    });

    const bundles = result.rows.map((booking) => buildBookingDto(booking, playerMap.get(Number(booking.id)) || [], userId));
    const now = nowInAppZone(APP_TIME_ZONE);
    const agendaUpcoming = [];
    const agendaHistory = [];
    const managedUpcoming = [];
    const managedHistory = [];

    for (const bundle of bundles) {
      const endMoment = combineDateAndTime(bundle.booking_date, bundle.end_time, APP_TIME_ZONE);
      const participantActive = bundle.is_organizer || !['rechazada', 'cancelada'].includes(bundle.my_invite_status || '');
      const isUpcoming = endMoment >= now && bundle.status !== 'cancelada' && participantActive;
      (isUpcoming ? agendaUpcoming : agendaHistory).push(bundle);

      if (bundle.booked_by === userId) {
        (isUpcoming ? managedUpcoming : managedHistory).push(bundle);
      }
    }

    return {
      agenda: {
        upcoming: agendaUpcoming,
        history: agendaHistory,
      },
      managed: {
        upcoming: managedUpcoming,
        history: managedHistory,
      },
      sync: {
        status: bundles.some((booking) => booking.calendar_sync_status === 'error')
            ? 'error'
            : (isGoogleCalendarConfigured() ? 'sincronizada' : 'local'),
        last_synced_at: syncStateResult.rows.length > 0
          ? syncStateResult.rows[0].last_synced_at
          : null,
      },
    };
  } finally {
    client.release();
  }
}

async function syncGoogleEventToBooking(client, event) {
  const bookingId = event?.extendedProperties?.private?.booking_id
    ? Number.parseInt(event.extendedProperties.private.booking_id, 10)
    : parseBookingDescription(event?.description || '').bookingId;

  if (!Number.isFinite(bookingId)) {
    return false;
  }

  const booking = await loadBookingRecord(client, bookingId);
  if (!booking) {
    return false;
  }

  const status = event.status === 'cancelled'
    ? 'cancelada'
    : (booking.status === 'cancelada' ? 'cancelada' : 'confirmada');

  const startInfo = event.start?.dateTime
    ? toLocalDateParts(event.start.dateTime, APP_TIME_ZONE)
    : { date: booking.booking_date, time: booking.start_time };
  const endInfo = event.end?.dateTime
    ? toLocalDateParts(event.end.dateTime, APP_TIME_ZONE)
    : { date: booking.booking_date, time: booking.end_time };
  const parsedDescription = parseBookingDescription(event.description || '');

  const attendeeRows = await loadBookingPlayers(client, [bookingId]);
  const attendeeMap = new Map(attendeeRows.map((player) => [String(player.email || '').toLowerCase(), player]));
  const googleAttendees = event.attendees || [];
  const seenAttendees = new Set();

  if (event.status === 'cancelled') {
    await client.query(
      `UPDATE app.padel_booking_players
       SET invite_status = 'cancelada',
           google_response_status = 'cancelled',
           responded_at = COALESCE(responded_at, NOW()),
           updated_at = NOW()
       WHERE booking_id = $1 AND role = 'guest'`,
      [bookingId]
    );
  }

  for (const attendee of googleAttendees) {
    const email = String(attendee.email || '').toLowerCase();
    if (email) {
      seenAttendees.add(email);
    }

    const localPlayer = attendeeMap.get(email);
    if (!localPlayer) {
      continue;
    }

    const inviteStatus = normalizeInviteStatus(normalizeGoogleResponseStatus(attendee.responseStatus));
    const responseStatus = attendee.responseStatus || 'needsAction';
    await client.query(
      `UPDATE app.padel_booking_players
       SET invite_status = $1,
           google_response_status = $2,
           responded_at = CASE WHEN $3 IN ('accepted', 'declined', 'cancelled') THEN COALESCE(responded_at, NOW()) ELSE responded_at END,
           updated_at = NOW()
       WHERE booking_id = $4 AND user_id = $5`,
      [inviteStatus, responseStatus, responseStatus, bookingId, localPlayer.user_id]
    );
  }

  if (event.status !== 'cancelled') {
    for (const localPlayer of attendeeRows.filter((player) => player.role === 'guest')) {
      const playerEmail = String(localPlayer.email || '').toLowerCase();
      if (!playerEmail || seenAttendees.has(playerEmail)) {
        continue;
      }

      await client.query(
        `UPDATE app.padel_booking_players
         SET invite_status = 'cancelada',
             google_response_status = 'cancelled',
             responded_at = COALESCE(responded_at, NOW()),
             updated_at = NOW()
         WHERE booking_id = $1 AND user_id = $2`,
        [bookingId, localPlayer.user_id]
      );
    }
  }

  await client.query(
    `UPDATE app.padel_bookings
     SET booking_date = $1,
         start_time = $2,
         end_time = $3,
         duration_minutes = GREATEST(30, ROUND(EXTRACT(EPOCH FROM ($3::time - $2::time)) / 60.0)::INTEGER),
         status = $4,
         notes = COALESCE(NULLIF($5, ''), notes),
         google_event_id = COALESCE($6, google_event_id),
         calendar_sync_status = 'sincronizada',
         last_synced_at = NOW(),
         updated_at = NOW()
     WHERE id = $7`,
    [
      startInfo.date,
      startInfo.time,
      endInfo.time,
      status,
      parsedDescription.notes,
      event.id,
      bookingId,
    ]
  );

  return true;
}

async function reconcilePendingBooking(client, booking) {
  const bundle = await loadBookingBundle(client, booking.id, booking.booked_by);
  const invitedPlayers = (bundle?.players || []).filter((player) => (
    player.invite_status !== 'cancelada'
  ));

  if (booking.status === 'cancelada') {
    if (booking.google_event_id) {
      try {
        await deleteCalendarEvent(booking.google_event_id);
      } catch (error) {
        if (error.statusCode !== 404 && error.statusCode !== 410) {
          throw error;
        }
      }
    }

    await client.query(
      `UPDATE app.padel_bookings
       SET calendar_sync_status = 'sincronizada',
           last_synced_at = NOW(),
           updated_at = NOW()
       WHERE id = $1`,
      [booking.id]
    );
    return;
  }

  const courtBundle = await loadCourtAndVenue(client, booking.court_id);
  if (!courtBundle) {
    return;
  }

  const eventPayload = buildBookingEventPayload({
    booking: bundle,
    venue: courtBundle,
    court: courtBundle,
    players: invitedPlayers,
    organizerEmail: process.env.GOOGLE_ORGANIZER_EMAIL || null,
  });

  if (!booking.google_event_id) {
    const createdEvent = await createCalendarEvent(eventPayload);
    await client.query(
      `UPDATE app.padel_bookings
       SET google_event_id = $1,
           calendar_sync_status = 'sincronizada',
           last_synced_at = NOW(),
           updated_at = NOW()
       WHERE id = $2`,
      [createdEvent.id, booking.id]
    );
    return;
  }

  await updateCalendarEvent(booking.google_event_id, eventPayload);
  await client.query(
    `UPDATE app.padel_bookings
     SET calendar_sync_status = 'sincronizada',
         last_synced_at = NOW(),
         updated_at = NOW()
     WHERE id = $1`,
    [booking.id]
  );
}

export async function applyOutgoingCalendarSync() {
  if (!isGoogleCalendarConfigured()) {
    return { processed: 0, skipped: true };
  }

  const client = await pool.connect();
  try {
    const result = await client.query(
      `SELECT *
       FROM app.padel_bookings
       WHERE calendar_sync_status IN ('pendiente', 'error')
       ORDER BY created_at ASC
       LIMIT 20`
    );

    let processed = 0;
    for (const booking of result.rows) {
      try {
        await reconcilePendingBooking(client, booking);
        processed += 1;
      } catch (error) {
        await client.query(
          `UPDATE app.padel_bookings
           SET calendar_sync_status = 'error',
               updated_at = NOW()
           WHERE id = $1`,
          [booking.id]
        );
        console.error('Error sincronizando reserva hacia Google Calendar:', error.message);
      }
    }

    return { processed, skipped: false };
  } finally {
    client.release();
  }
}

export async function applyIncomingCalendarSync() {
  if (!isGoogleCalendarConfigured()) {
    return { processed: 0, skipped: true };
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(
      `INSERT INTO app.padel_calendar_sync_state (calendar_id)
       VALUES ('primary')
       ON CONFLICT (calendar_id) DO NOTHING`
    );

    const stateResult = await client.query(
      `SELECT calendar_id, sync_token, last_synced_at, last_error
       FROM app.padel_calendar_sync_state
       WHERE calendar_id = 'primary'
       FOR UPDATE`
    );

    const state = stateResult.rows[0];
    let syncToken = state?.sync_token || null;
    let processed = 0;

    const processPage = async (page) => {
      for (const event of page.items || []) {
        const handled = await syncGoogleEventToBooking(client, event);
        if (handled) {
          processed += 1;
        }
      }
    };

    const runSyncPass = async (initialSyncToken = null) => {
      let localPageToken = null;
      let localSyncToken = initialSyncToken;

      do {
        const page = await listCalendarEvents({
          syncToken: localSyncToken || undefined,
          pageToken: localPageToken || undefined,
        });
        await processPage(page);
        localPageToken = page.nextPageToken || null;
        if (page.nextSyncToken) {
          localSyncToken = page.nextSyncToken;
        }
      } while (localPageToken);

      return localSyncToken;
    };

    try {
      syncToken = await runSyncPass(syncToken);
    } catch (error) {
      if (error.statusCode === 410) {
        syncToken = await runSyncPass(null);
      } else {
        await client.query(
          `UPDATE app.padel_calendar_sync_state
           SET last_error = $1,
               updated_at = NOW()
           WHERE calendar_id = 'primary'`,
          [error.message]
        );
        throw error;
      }
    }

    await client.query(
      `UPDATE app.padel_calendar_sync_state
       SET sync_token = $1,
           last_synced_at = NOW(),
           last_error = NULL,
           updated_at = NOW()
       WHERE calendar_id = 'primary'`,
      [syncToken]
    );

    await client.query('COMMIT');
    return { processed, skipped: false };
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    throw error;
  } finally {
    client.release();
  }
}

export async function updateBooking({ bookingId, userId, payload }) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const booking = await loadBookingRecord(client, bookingId);
    if (!booking) {
      await client.query('ROLLBACK');
      return { status: 404, body: { error: 'Reserva no encontrada' } };
    }

    if (Number(booking.booked_by) !== Number(userId)) {
      await client.query('ROLLBACK');
      return { status: 403, body: { error: 'No tienes permisos para editar esta reserva' } };
    }

    const nextBookingDate = payload.booking_date || booking.booking_date;
    const nextStartTime = payload.start_time || booking.start_time;
    const nextDurationMinutes = clampDurationMinutes(payload.duration_minutes || booking.duration_minutes, booking.duration_minutes || DEFAULT_DURATION_MINUTES);
    const nextNotes = Object.prototype.hasOwnProperty.call(payload, 'notes') ? payload.notes : booking.notes;

    const courtBundle = await loadCourtAndVenue(client, booking.court_id);
    if (!courtBundle) {
      await client.query('ROLLBACK');
      return { status: 404, body: { error: 'Pista no encontrada' } };
    }

    const nextEndTime = calculateEndTime(nextBookingDate, nextStartTime, nextDurationMinutes, APP_TIME_ZONE).toFormat('HH:mm:ss');
    const scheduleWindows = await loadVenueScheduleWindowsForDate(client, {
      venueId: courtBundle.venue_id,
      date: nextBookingDate,
      fallbackOpeningTime: courtBundle.opening_time,
      fallbackClosingTime: courtBundle.closing_time,
    });
    const nextTotalPrice = calculatePrice({
      pricePerHour: courtBundle.price_per_hour,
      peakPricePerHour: courtBundle.peak_price_per_hour,
      startTime: nextStartTime,
      durationMinutes: nextDurationMinutes,
    });

    if (!isRangeInsideScheduleWindows({ startTime: nextStartTime, endTime: nextEndTime, scheduleWindows })) {
      await client.query('ROLLBACK');
      return { status: 400, body: { error: 'La reserva no cabe dentro del horario de la sede' } };
    }

    const overlapCheck = await client.query(
      `SELECT id
       FROM app.padel_bookings
       WHERE court_id = $1
         AND booking_date = $2
         AND status != 'cancelada'
         AND id != $5
         AND start_time < $4::time
         AND end_time > $3::time
       LIMIT 1`,
      [booking.court_id, nextBookingDate, nextStartTime, nextEndTime, bookingId]
    );

    if (overlapCheck.rows.length > 0) {
      await client.query('ROLLBACK');
      return { status: 409, body: { error: 'Este horario ya está reservado' } };
    }

    await client.query(
      `UPDATE app.padel_bookings
       SET booking_date = $1,
           start_time = $2,
           end_time = $3,
           duration_minutes = $4,
           total_price = $5,
           notes = $6,
           calendar_sync_status = 'pendiente',
           updated_at = NOW()
       WHERE id = $7`,
      [nextBookingDate, nextStartTime, nextEndTime, nextDurationMinutes, nextTotalPrice, nextNotes, bookingId]
    );

    if (Object.prototype.hasOwnProperty.call(payload, 'player_user_ids')) {
      const invitedUsers = await queryUsersByIds(client, payload.player_user_ids || []);
      const nextGuestIds = invitedUsers
        .filter((player) => Number(player.id) !== Number(userId))
        .map((player) => Number(player.id));
      const currentGuestRows = await client.query(
        `SELECT booking_id, user_id, invite_status, google_response_status, responded_at
         FROM app.padel_booking_players
         WHERE booking_id = $1 AND role = 'guest'`,
        [bookingId]
      );
      const currentGuestMap = new Map(currentGuestRows.rows.map((row) => [Number(row.user_id), row]));

      await client.query(
        `UPDATE app.padel_booking_players
         SET invite_status = 'cancelada',
             google_response_status = 'cancelled',
             responded_at = COALESCE(responded_at, NOW()),
             updated_at = NOW()
         WHERE booking_id = $1
           AND role = 'guest'
           AND NOT (user_id = ANY($2::int[]))`,
        [bookingId, nextGuestIds.length > 0 ? nextGuestIds : [0]]
      );

      for (const player of invitedUsers.filter((player) => Number(player.id) !== Number(userId))) {
        const previous = currentGuestMap.get(Number(player.id));
        const nextInviteStatus = previous && previous.invite_status !== 'cancelada'
          ? previous.invite_status
          : 'pendiente';
        const nextGoogleStatus = previous && previous.google_response_status !== 'cancelled'
          ? previous.google_response_status
          : 'needsAction';
        await client.query(
          `INSERT INTO app.padel_booking_players (
            booking_id, user_id, role, invite_status, google_response_status, responded_at
          ) VALUES ($1, $2, 'guest', $3, $4, $5)
          ON CONFLICT (booking_id, user_id) DO UPDATE
          SET role = EXCLUDED.role,
              invite_status = EXCLUDED.invite_status,
              google_response_status = EXCLUDED.google_response_status,
              responded_at = EXCLUDED.responded_at,
              updated_at = NOW()`,
          [bookingId, player.id, nextInviteStatus, nextGoogleStatus, previous?.responded_at || null]
        );
      }
    }

    await client.query('COMMIT');

    if (isGoogleCalendarConfigured()) {
      try {
        const refreshedBooking = await getBookingById(bookingId, userId);
        const invitedPlayers = (refreshedBooking.players || []).filter((player) => (
          player.role === 'guest' && player.invite_status !== 'cancelada'
        ));
        const eventPayload = buildBookingEventPayload({
          booking: refreshedBooking,
          venue: courtBundle,
          court: courtBundle,
          players: invitedPlayers,
          organizerEmail: process.env.GOOGLE_ORGANIZER_EMAIL || null,
        });

        if (booking.google_event_id) {
          await updateCalendarEvent(booking.google_event_id, eventPayload);
          await pool.query(
            `UPDATE app.padel_bookings
             SET calendar_sync_status = 'sincronizada',
                 last_synced_at = NOW(),
                 updated_at = NOW()
             WHERE id = $1`,
            [bookingId]
          );
        } else {
          const createdEvent = await createCalendarEvent(eventPayload);
          await pool.query(
            `UPDATE app.padel_bookings
             SET google_event_id = $1,
                 calendar_sync_status = 'sincronizada',
                 last_synced_at = NOW(),
                 updated_at = NOW()
             WHERE id = $2`,
            [createdEvent.id, bookingId]
          );
        }
      } catch (error) {
        await pool.query(
          `UPDATE app.padel_bookings
           SET calendar_sync_status = 'error',
               updated_at = NOW()
           WHERE id = $1`,
          [bookingId]
        );
        console.error('Error sincronizando actualización con Google Calendar:', error.message);
      }
    } else {
      await pool.query(
        `UPDATE app.padel_bookings
         SET calendar_sync_status = 'sincronizada',
             last_synced_at = NOW(),
             updated_at = NOW()
         WHERE id = $1`,
        [bookingId]
      );
    }

    return {
      status: 200,
      body: {
        booking: await getBookingById(bookingId, userId),
      },
    };
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    throw error;
  } finally {
    client.release();
  }
}

export async function cancelBooking({ bookingId, userId }) {
  const client = await pool.connect();
  try {
    const booking = await loadBookingRecord(client, bookingId);
    if (!booking) {
      return { status: 404, body: { error: 'Reserva no encontrada' } };
    }

    if (Number(booking.booked_by) !== Number(userId)) {
      return { status: 403, body: { error: 'No tienes permisos para cancelar esta reserva' } };
    }

    await client.query(
      `UPDATE app.padel_bookings
       SET status = 'cancelada',
           calendar_sync_status = 'pendiente',
           updated_at = NOW()
       WHERE id = $1`,
      [bookingId]
    );

    await client.query(
      `UPDATE app.padel_booking_players
       SET invite_status = 'cancelada',
           google_response_status = 'cancelled',
           responded_at = COALESCE(responded_at, NOW()),
           updated_at = NOW()
       WHERE booking_id = $1`,
      [bookingId]
    );

    if (isGoogleCalendarConfigured() && booking.google_event_id) {
      try {
        await deleteCalendarEvent(booking.google_event_id);
        await client.query(
          `UPDATE app.padel_bookings
           SET calendar_sync_status = 'sincronizada',
               last_synced_at = NOW(),
               updated_at = NOW()
           WHERE id = $1`,
          [bookingId]
        );
      } catch (error) {
        if (error.statusCode === 404 || error.statusCode === 410) {
          await client.query(
            `UPDATE app.padel_bookings
             SET calendar_sync_status = 'sincronizada',
                 last_synced_at = NOW(),
                 updated_at = NOW()
             WHERE id = $1`,
            [bookingId]
          );
        } else {
          await client.query(
            `UPDATE app.padel_bookings
             SET calendar_sync_status = 'error',
                 updated_at = NOW()
             WHERE id = $1`,
            [bookingId]
          );
          console.error('Error cancelando evento en Google Calendar:', error.message);
        }
      }
    } else {
      await client.query(
        `UPDATE app.padel_bookings
         SET calendar_sync_status = 'sincronizada',
             last_synced_at = NOW(),
             updated_at = NOW()
         WHERE id = $1`,
        [bookingId]
      );
    }

    return {
      status: 200,
      body: {
        booking: await getBookingById(bookingId, userId),
      },
    };
  } finally {
    client.release();
  }
}

export async function respondToBooking({ bookingId, userId, status }) {
  const normalizedStatus = normalizeInviteStatus(status);
  if (!['aceptada', 'rechazada'].includes(normalizedStatus)) {
    return { status: 400, body: { error: 'Estado de respuesta inválido' } };
  }

  const client = await pool.connect();
  try {
    const booking = await loadBookingRecord(client, bookingId);
    if (!booking) {
      return { status: 404, body: { error: 'Reserva no encontrada' } };
    }

    if (Number(booking.booked_by) === Number(userId)) {
      return { status: 400, body: { error: 'El organizador no responde como invitado' } };
    }

    const attendee = await client.query(
      `SELECT bp.*, u.email, u.nombre
       FROM app.padel_booking_players bp
       JOIN app.users u ON u.id = bp.user_id
       WHERE bp.booking_id = $1
         AND bp.user_id = $2
       LIMIT 1`,
      [bookingId, userId]
    );

    if (attendee.rows.length === 0) {
      return { status: 404, body: { error: 'No estás invitado en esta reserva' } };
    }

    const googleStatus = normalizedStatus === 'aceptada' ? 'accepted' : 'declined';
    await client.query(
      `UPDATE app.padel_booking_players
       SET invite_status = $1,
           google_response_status = $2,
           responded_at = NOW(),
           updated_at = NOW()
       WHERE booking_id = $3
         AND user_id = $4`,
      [normalizedStatus, googleStatus, bookingId, userId]
    );

    if (isGoogleCalendarConfigured() && booking.google_event_id) {
      try {
        const event = await getCalendarEvent(booking.google_event_id);
        const attendeeEmail = String(attendee.rows[0].email || '').toLowerCase();
        let matchedAttendee = false;
        const attendees = (event.attendees || []).map((entry) => {
          if (String(entry.email || '').toLowerCase() !== attendeeEmail) {
            return entry;
          }

          matchedAttendee = true;
          return {
            ...entry,
            responseStatus: googleStatus,
          };
        });

        if (!matchedAttendee && attendeeEmail) {
          attendees.push({
            email: attendee.rows[0].email,
            displayName: attendee.rows[0].nombre || attendee.rows[0].email,
            responseStatus: googleStatus,
          });
        }

        await updateCalendarEvent(booking.google_event_id, {
          ...event,
          attendees,
        });

        await client.query(
          `UPDATE app.padel_bookings
           SET calendar_sync_status = 'sincronizada',
               last_synced_at = NOW(),
               updated_at = NOW()
           WHERE id = $1`,
          [bookingId]
        );
      } catch (error) {
        await client.query(
          `UPDATE app.padel_bookings
           SET calendar_sync_status = 'error',
               updated_at = NOW()
           WHERE id = $1`,
          [bookingId]
        );
        console.error('Error actualizando RSVP en Google Calendar:', error.message);
      }
    } else {
      await client.query(
        `UPDATE app.padel_bookings
         SET calendar_sync_status = 'sincronizada',
             last_synced_at = NOW(),
             updated_at = NOW()
         WHERE id = $1`,
        [bookingId]
      );
    }

    return {
      status: 200,
      body: {
        booking: await getBookingById(bookingId, userId),
      },
    };
  } finally {
    client.release();
  }
}
