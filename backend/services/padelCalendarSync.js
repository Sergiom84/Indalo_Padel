import { applyIncomingCalendarSync, applyOutgoingCalendarSync } from './padelBookingService.js';
import { isGoogleCalendarConfigured } from './googleCalendar.js';

let syncRunning = false;
let syncTimer = null;

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

export function startCalendarSyncJob() {
  const intervalMinutes = Number.parseInt(process.env.CALENDAR_SYNC_INTERVAL_MINUTES || '2', 10);
  const intervalMs = Math.max(1, intervalMinutes) * 60 * 1000;

  if (syncTimer) {
    return syncTimer;
  }

  if (!isGoogleCalendarConfigured()) {
    console.log('ℹ️ Google Calendar no está configurado; el sync automático queda desactivado.');
    return null;
  }

  const runSafeCycle = async () => {
    try {
      const result = await runCalendarSyncCycle();
      if (!result.skipped) {
        console.log('🔄 Sync de calendario completado:', result);
      }
    } catch (error) {
      console.error('❌ Error en sync automático de calendario:', error.message);
    }
  };

  setTimeout(runSafeCycle, 5_000);
  syncTimer = setInterval(runSafeCycle, intervalMs);
  return syncTimer;
}

