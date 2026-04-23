import '../loadEnv.js';
import { isGoogleCalendarConfigured, listCalendarEvents } from '../services/googleCalendar.js';

if (!isGoogleCalendarConfigured()) {
  console.error('❌ Google Calendar no está configurado (faltan variables de entorno)');
  process.exit(1);
}

console.log('🔍 Probando conexión con Google Calendar...\n');

try {
  const events = await listCalendarEvents({ maxResults: 3, timeMin: new Date().toISOString() });
  console.log(`✅ Conexión OK. Próximos eventos en el calendario: ${events?.items?.length ?? 0}`);
  if (events?.items?.length) {
    events.items.forEach((e) => console.log(`   - ${e.summary || '(sin título)'} → ${e.start?.dateTime || e.start?.date}`));
  }
} catch (err) {
  console.error('❌ Error:', err.message);
  if (err.message.includes('invalid_grant') || err.message.includes('Token has been expired')) {
    console.error('   El token está revocado. Ejecuta: node backend/scripts/get-google-token.js');
  }
  process.exit(1);
}
