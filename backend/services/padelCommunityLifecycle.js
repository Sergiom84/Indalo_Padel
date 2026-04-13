import { runCommunityLifecycleMaintenance } from './padelCommunityService.js';

let lifecycleTimer = null;
let lifecycleRunning = false;

export async function runCommunityLifecycleCycle() {
  if (lifecycleRunning) {
    return { skipped: true, reason: 'already_running' };
  }

  lifecycleRunning = true;
  try {
    const result = await runCommunityLifecycleMaintenance();
    return { skipped: false, ...result };
  } finally {
    lifecycleRunning = false;
  }
}

export function startCommunityLifecycleJob() {
  if (lifecycleTimer) {
    return lifecycleTimer;
  }

  const intervalMinutes = Number.parseInt(
    process.env.COMMUNITY_LIFECYCLE_INTERVAL_MINUTES || '5',
    10,
  );
  const intervalMs = Math.max(1, intervalMinutes) * 60 * 1000;

  const runSafeCycle = async () => {
    try {
      const result = await runCommunityLifecycleCycle();
      if (!result.skipped) {
        console.log('🔄 Ciclo de comunidad completado:', result);
      }
    } catch (error) {
      console.error('❌ Error en el ciclo automático de comunidad:', error.message);
    } finally {
      lifecycleTimer = setTimeout(runSafeCycle, intervalMs);
    }
  };

  lifecycleTimer = setTimeout(runSafeCycle, 7_000);
  return lifecycleTimer;
}
