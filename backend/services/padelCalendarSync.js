import { applyIncomingCalendarSync, applyOutgoingCalendarSync } from './padelBookingService.js';
import { isGoogleCalendarConfigured } from './googleCalendar.js';

let syncRunning = false;
let syncTimer = null;
let syncQueued = false;
let consecutiveFailures = 0;

// Errores de red transitorios cuyo tratamiento debe ser "callar y backoff",
// no inundar logs ni martillear el pool de PostgreSQL durante una ventana mala.
const TRANSIENT_NET_ERRORS = new Set([
  'EAI_AGAIN',
  'ENOTFOUND',
  'ECONNRESET',
  'ECONNREFUSED',
  'ETIMEDOUT',
  'EHOSTUNREACH',
  'ENETUNREACH',
]);

function isTransientNetworkError(error) {
  if (!error) return false;
  if (error.code && TRANSIENT_NET_ERRORS.has(error.code)) return true;
  const msg = String(error.message || error);
  return (
    msg.includes('EAI_AGAIN') ||
    msg.includes('Connection terminated') ||
    msg.includes('connection timeout')
  );
}

export async function runCalendarSyncCycle() {
  if (!isGoogleCalendarConfigured()) {
    return { skipped: true, reason: 'google_not_configured' };
  }

  if (syncRunning) {
    return { skipped: true, reason: 'already_running' };
  }

  syncRunning = true;
  try {
    const incoming = await applyIncomingCalendarSync();
    const outgoing = await applyOutgoingCalendarSync();
    return {
      skipped: false,
      incoming,
      outgoing,
    };
  } finally {
    syncRunning = false;
  }
}

export function scheduleCalendarSyncCycle() {
  if (!isGoogleCalendarConfigured() || syncRunning || syncQueued) {
    return false;
  }

  syncQueued = true;

  setTimeout(async () => {
    try {
      await runCalendarSyncCycle();
    } catch (error) {
      console.error('❌ Error en sync bajo demanda de calendario:', error.message);
    } finally {
      syncQueued = false;
    }
  }, 0);

  return true;
}

export function startCalendarSyncJob() {
  const intervalMinutes = Number.parseInt(process.env.CALENDAR_SYNC_INTERVAL_MINUTES || '2', 10);
  const baseIntervalMs = Math.max(1, intervalMinutes) * 60 * 1000;
  // Cap del backoff: ante una caida prolongada de DNS/red no esperamos mas
  // de 30 minutos para volver a probar. Asi recuperamos rapido cuando vuelve.
  const maxBackoffMs = 30 * 60 * 1000;

  if (syncTimer) {
    return syncTimer;
  }

  if (!isGoogleCalendarConfigured()) {
    console.log('ℹ️ Google Calendar no está configurado; el sync automático queda desactivado.');
    return null;
  }

  // Calcula el siguiente delay aplicando backoff exponencial mientras
  // acumulamos fallos transitorios consecutivos. Esto evita martillear el pool
  // de PostgreSQL durante ventanas de DNS roto, que es justo lo que disparaba
  // los crashes de Render.
  const computeNextDelay = () => {
    if (consecutiveFailures === 0) return baseIntervalMs;
    const exponential = baseIntervalMs * Math.pow(2, consecutiveFailures);
    return Math.min(exponential, maxBackoffMs);
  };

  const scheduleNext = (delayMs) => {
    if (syncTimer) {
      clearTimeout(syncTimer);
    }
    syncTimer = setTimeout(runSafeCycle, delayMs);
  };

  const runSafeCycle = async () => {
    try {
      const result = await runCalendarSyncCycle();
      if (!result.skipped) {
        console.log('🔄 Sync de calendario completado:', result);
      }
      if (consecutiveFailures > 0) {
        console.log(`✅ Sync recuperado tras ${consecutiveFailures} fallo(s) consecutivo(s).`);
      }
      consecutiveFailures = 0;
    } catch (error) {
      consecutiveFailures += 1;
      if (isTransientNetworkError(error)) {
        const nextDelayMin = Math.round(computeNextDelay() / 60000);
        console.warn(
          `⚠️ Sync de calendario falló por red transitoria (intento ${consecutiveFailures}): ` +
          `${error.message}. Reintento en ~${nextDelayMin} min.`
        );
      } else {
        console.error('❌ Error en sync automático de calendario:', error.message);
      }
    } finally {
      scheduleNext(computeNextDelay());
    }
  };

  // Primer ciclo a los 5 segundos del arranque (igual que antes); a partir de
  // ahi el propio runSafeCycle se vuelve a programar via scheduleNext.
  syncTimer = setTimeout(runSafeCycle, 5_000);
  return syncTimer;
}
