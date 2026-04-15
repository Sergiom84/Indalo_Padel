# AGENT.md — Guía Operativa de Agentes para Indalo Padel

## 1) Objetivo y alcance
- Esta guía estandariza cómo trabajan asistentes de código (Codex y Claude) en este repositorio.
- No define un agente de IA dentro de la app de usuario final.
- Prioriza cambios seguros, trazables y compatibles entre backend y Flutter.

## 2) Arquitectura real del proyecto
- Backend: `backend/` con Node.js + Express + PostgreSQL.
- Frontend activo: `flutter_app/` (Android/iOS/web preview).
- Frontend legacy: `quarantine/react-vite-web/` (fuera de flujo activo).

### Módulos backend relevantes
- API root: `backend/server.js`
- DB connection/config: `backend/db.js`
- Auth middleware: `backend/middleware/auth.js`
- Rutas:
  - `backend/routes/padelAuth.js`
  - `backend/routes/padelVenues.js`
  - `backend/routes/padelBookings.js`
  - `backend/routes/padelMatches.js`
  - `backend/routes/padelCommunity.js`
  - `backend/routes/padelPlayers.js`
- Servicios de negocio:
  - `backend/services/padelBookingService.js`
  - `backend/services/padelCalendarSync.js`
  - `backend/services/padelCommunityService.js`
  - `backend/services/padelCommunityLifecycle.js`
  - `backend/services/googleCalendar.js`
  - `backend/services/calendarUtils.js`
  - `backend/services/authEmailService.js`
- Validadores Zod:
  - `backend/validators/*.js`
- Migraciones SQL:
  - `backend/migrations/padel_tables.sql`
  - `backend/migrations/padel_calendar.sql`
  - `backend/migrations/padel_community.sql`
  - `backend/migrations/padel_clubs_community_closure.sql`
  - `backend/migrations/padel_player_connections.sql`
  - `backend/migrations/padel_player_profile_*.sql`
  - `backend/migrations/padel_auth_account_lifecycle.sql`
  - `backend/migrations/padel_venue_dedup.sql`
  - `backend/migrations/padel_seed_data.sql`

### Módulos Flutter relevantes
- App shell/router:
  - `flutter_app/lib/app.dart`
  - `flutter_app/lib/core/router/app_router.dart`
  - `flutter_app/lib/shared/widgets/app_bottom_nav.dart`
- API client:
  - `flutter_app/lib/core/api/api_client.dart`
- Features:
  - Auth
  - Venues/availability
  - Bookings/calendar
  - Matches
  - Community/convocatorias
  - Players/profile/network/invitations/ratings

## 3) Reglas de dominio padel

### Niveles de jugador
- `main_level`: bajo | medio | alto
- `sub_level`: bajo | medio | alto
- `numeric_level`: columna GENERATED en PostgreSQL, escala 0-9
  - Cálculo: main (bajo=0, medio=3, alto=6) + sub (bajo=1, medio=2, alto=3)
  - Ejemplo: medio+alto = 3+3 = 6
- **No modificar la fórmula de numeric_level**: es una columna generada en la tabla `padel_player_profiles`

### Partidos
- Máximo 4 jugadores, 2 equipos
- Posiciones: drive | revés | ambos
- Estados: buscando → completo → en_juego → finalizado | cancelado
- Filtro por nivel: `min_level` ≤ `numeric_level` ≤ `max_level`

### Reservas
- Duración: 30-240 minutos (default 90)
- Horarios por sede: usar `padel_venues.opening_time/closing_time` y `padel_venue_schedule_windows`; no asumir un rango global.
- Constraint UNIQUE en (court_id, booking_date, start_time): no solapamiento
- Estados: pendiente → confirmada → completada | cancelada
- Google Calendar sync: pendiente | sincronizada | error

### Precios
- Tipos de pista: estándar y cristal
- Precio normal vs hora punta (peak). Lógica en `calendarUtils.js`
- Seed: estándar 10-14€/h, cristal 14-18€/h, peak +4€/h

### Sedes actuales (seed data)
- La fuente funcional vive en `backend/migrations/padel_seed_data.sql` y ajustes posteriores de sedes/comunidad.
- No hardcodear la lista en UI/docs operativas: consultar `padel_venues`, `padel_courts`, `is_active`, `is_bookable` y ventanas horarias.
- En producción puede haber sedes históricas activas por migraciones de deduplicación/cierre.

## 4) Entorno y convenciones del repo
- Puerto por defecto backend: `3011`.
- URL base Flutter por defecto:
  - Android emulator: `http://10.0.2.2:3011/api`
  - iOS/web/desktop local: `http://localhost:3011/api`
- El backend carga `.env` en la raíz del repo.
- Time zone de negocio/calendario: `Europe/Madrid` (vía `CALENDAR_TIME_ZONE`).

## 5) Schema de base de datos

- **Schema:** `app` (no public). `DB_SEARCH_PATH=app,public`
- **RLS:** habilitado en la mayoría de tablas expuestas con política deny PUBLIC; algunas tablas internas históricas no lo tienen activado. El acceso de la app pasa por el backend con conexión PostgreSQL server-side.

| Tabla | Descripción | Relaciones clave |
|-------|-------------|-----------------|
| `app.users` | Usuarios (role: user\|admin) | — |
| `app.padel_venues` | Sedes/clubs | UNIQUE(name, location) si is_active |
| `app.padel_courts` | Pistas | FK → venues, UNIQUE(venue_id, name) |
| `app.padel_bookings` | Reservas | FK → courts, → users. UNIQUE(court_id, booking_date, start_time) |
| `app.padel_booking_players` | Participantes reserva + RSVP | FK → bookings, → users |
| `app.padel_matches` | Partidos | FK → bookings, → users, → venues |
| `app.padel_match_players` | Jugadores en partido | FK → matches, → users. UNIQUE(match_id, user_id) |
| `app.padel_player_profiles` | Perfil jugador | FK → users (UNIQUE). numeric_level GENERATED |
| `app.padel_player_ratings` | Valoraciones 1-5 | FK → users, → matches. UNIQUE(rater, rated, match) |
| `app.padel_favorites` | Favoritos | FK → users. CHECK(user ≠ favorite) |
| `app.padel_player_connections` | Red de jugadores e invitaciones "Jugamos?" | Par normalizado user_a/user_b, status pending/accepted/rejected |
| `app.padel_community_plans` | Convocatorias de comunidad | Creador, sede/pista propuesta, estado de reserva |
| `app.padel_community_plan_players` | Participantes de convocatorias | FK → community_plans, → users |
| `app.padel_community_notifications` | Notificaciones internas de comunidad | FK → users, → community_plans |
| `app.padel_calendar_sync_state` | Sync Google Calendar | PK: calendar_id |

## 6) Deuda técnica conocida

1. **Autorización parcial** — `requireRole('admin')` protege sedes, pero cada endpoint nuevo debe revisar ownership/permisos explícitos.
2. **State management mixto (Flutter)** — Hay providers Riverpod por feature, pero varias pantallas aún combinan llamadas API directas con `setState`.
3. **Servicio monolítico** — `services/padelBookingService.js` tiene 1000+ líneas.
4. **Validación mixta** — Hay Zod en `backend/validators`, pero siguen existiendo validaciones de negocio ad-hoc en rutas/servicios.
5. **Tests mínimos** — Backend: 0 tests. Flutter: pocos tests básicos.
6. **Sin push notifications** — No hay FCM ni infraestructura de notificaciones.

## 7) Comandos oficiales de trabajo
### Backend
```bash
cd backend
npm install
npm run dev
npm run migrate
```

### Flutter
```bash
cd flutter_app
flutter pub get
flutter analyze
flutter test
flutter run
```

### Preview web Flutter
```bash
pwsh ./scripts/start_flutter_web_preview.ps1
```

## 8) Reglas de seguridad operativa
- Nunca commitear secretos reales (`.env`, tokens, claves Google, JWT de producción).
- No ejecutar comandos destructivos de git para “limpiar” cambios ajenos.
- Los commits deben ir firmados con SSH salvo instrucción explícita en contra. Antes de commit/push, verificar:
  - `git config --global gpg.format` debe devolver `ssh`.
  - `git config --global commit.gpgsign` debe devolver `true`.
  - `git config --global core.sshCommand` debe apuntar a `C:/Windows/System32/OpenSSH/ssh.exe` para usar el `ssh-agent` de Windows.
  - Si la firma pide passphrase o bloquea el proceso, no desactivar firma ni forzar HTTPS; cargar la clave con `ssh-add C:\Users\sergi\.ssh\github_sergi_ed25519_secure` y repetir.
- Los push a GitHub deben ir por SSH (`git@github.com:...`). No usar HTTPS como workaround salvo autorización explícita.
- No modificar migraciones pasadas ya aplicadas en entornos compartidos; crear migración nueva.
- En cambios de reservas/calendario:
  - preservar consistencia entre estado local (`padel_bookings`) y sync (`calendar_sync_status`);
  - tratar errores de Google Calendar como fallo recuperable, nunca como éxito silencioso.
- En auth/players:
  - no exponer datos sensibles;
  - mantener validaciones de ownership/permisos.

## 9) Flujo de trabajo por tipo de tarea
### A) Cambios backend
1. Identificar ruta + servicio + tablas impactadas.
2. Implementar lógica en servicio primero, ruta después.
3. Revisar compatibilidad de shape JSON con Flutter.
4. Si hay cambios de schema, crear migración incremental.
5. Probar endpoint con casos de éxito/error.

### B) Cambios Flutter
1. Verificar shape real de API en backend antes de tocar UI/modelos.
2. Adaptar modelos para tolerar aliases compatibles cuando aplique.
3. Evitar hardcodes de formato de respuesta no garantizados.
4. Ejecutar `flutter analyze` y `flutter test`.

### C) Cambios DB/migraciones
1. SQL idempotente cuando sea posible.
2. Incluir índices/constraints mínimos para integridad.
3. Probar con `npm run migrate` en entorno local.
4. Documentar impacto (tablas, columnas, defaults, checks).

### D) Integración Google Calendar
1. Verificar variables de entorno requeridas.
2. Mantener semántica de estados: `pendiente | sincronizada | error`.
3. Para RSVP/eventos borrados, actualizar estado local de invitados y reserva.
4. Nunca bloquear toda la API por una incidencia externa puntual de Calendar.

## 10) Definición de Done (DoD)
Una tarea se considera cerrada solo si cumple:
- Código compila y pasa validaciones locales relevantes.
- Compatibilidad de contrato backend/Flutter preservada o documentada.
- Casos de error principales cubiertos.
- No se introducen secretos ni cambios destructivos no justificados.
- Se actualiza documentación si cambia comportamiento operativo.

Checklist rápido:
- [ ] `flutter analyze` OK
- [ ] `flutter test` OK
- [ ] Endpoint(s) tocados responden shape esperado
- [ ] Sin regresiones obvias en reservas/matches/players
- [ ] Docs y notas de operación al día

## 11) Protocolo de colaboración Codex + Claude
- Trabajar con handoff explícito:
  - “Contexto actual”
  - “Cambios aplicados”
  - “Pendientes”
  - “Riesgos”
- No pisar cambios no relacionados.
- Si hay conflicto de criterio, priorizar:
  1. Integridad de datos
  2. Compatibilidad de API
  3. Simplicidad operativa
- Toda decisión no obvia debe quedar documentada en PR/commit o en docs.

## 12) Playbooks/skills documentales de este repo
- Ruta: `docs/skills/`
- Son guías Markdown del proyecto; no son skills invocables tipo `SKILL.md` salvo que se conviertan a ese formato.
- Playbooks disponibles:
  - `skill-bookings-calendar.md`
  - `skill-api-contract.md`
  - `skill-community-plans.md`
  - `skill-matches-players.md`
  - `skill-profile-search.md`
  - `skill-release-smoke.md`

## 13) Playbooks de incidencia
- Ruta: `docs/playbooks/incidencias.md`
- Cubre:
  - sync de calendario
  - CORS/orígenes
  - conflictos de puerto
  - consistencia de datos en reservas/partidos
  - **crashes Render / "Instance failed: Exited with status 2"** (nuevo)

## 14) Infraestructura Render + Supabase — Lecciones aprendidas

### Problema raíz: Render free tier no tiene IPv6 de salida

**Síntoma:** El servicio en Render aparece como `Instance failed: Exited with status 2` de forma periódica.
**Logs:** `connect ENETUNREACH 2a05:d012:xxx::xxxx` o `getaddrinfo EAI_AGAIN db.PROJECT.supabase.co`

**Causa:** La URL de conexión directa de Supabase (`db.PROJECT.supabase.co`) resuelve **solo a IPv6**. Render free tier no tiene conectividad IPv6 de salida → `ENETUNREACH` → `uncaughtException` → Node muere con exit 2 → Render reinicia el contenedor → bucle.

### Regla permanente: usar Transaction Pooler

La `DATABASE_URL` en variables de entorno de Render **siempre debe apuntar al pooler**:
```
postgresql://postgres.PROJECT:PASS@aws-1-eu-central-1.pooler.supabase.com:5432/postgres
```

| URL | Resultado en Render |
|---|---|
| `db.PROJECT.supabase.co` | ❌ ENETUNREACH (IPv6 only) |
| `aws-1-eu-central-1.pooler.supabase.com` | ✅ Funciona (IPv4 only) |

### Fixes de estabilidad aplicados en el código

1. **`backend/db.js`** — `pool.on('error', handler)`: captura errores de clientes idle del pool antes de que escalen a `uncaughtException`
2. **`backend/server.js`** — `process.on('unhandledRejection')` + `process.on('uncaughtException')`: red de seguridad global para errores DNS/red transitorios
3. **`backend/package.json`** — `node --dns-result-order=ipv4first server.js`: fuerza resolución IPv4 primero
4. **`backend/services/padelCalendarSync.js`** — backoff exponencial (base × 2^n, cap 30 min): evita martillear el pool durante ventanas de red rota

### Flutter: cold starts de Render free tier

Render free tier duerme el servicio tras ~15 min de inactividad. La primera request puede tardar 30-60s.

- **`flutter_app/lib/core/api/api_client.dart`**: `connectTimeout: 60s`, `receiveTimeout: 90s`
- **`flutter_app/lib/features/auth/screens/login_screen.dart`**: pre-warm con `GET /health` en `initState()` mientras el usuario teclea credenciales
