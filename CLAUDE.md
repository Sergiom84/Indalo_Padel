# CLAUDE.md — Instrucciones para Claude Code en Indalo Padel

> Lee también `AGENT.md` para la guía operativa completa (arquitectura, flujos de trabajo, DoD, seguridad).

## Proyecto

App de reserva de pistas de padel para **Mojácar, Garrucha, Vera y alrededores** (sureste de Almería).
- Backend: `backend/` — Node.js + Express + PostgreSQL (Supabase)
- Frontend activo: `flutter_app/` — Flutter (Android/iOS/web preview)
- Frontend legacy: `quarantine/react-vite-web/` — **NO TOCAR**

## Comandos de desarrollo

```bash
# Backend
cd backend && npm install && npm run dev    # API en http://localhost:3011

# Flutter
cd flutter_app && flutter pub get && flutter run
cd flutter_app && flutter analyze           # Linter
cd flutter_app && flutter test              # Tests

# Migraciones
cd backend && node migrations/run.js
```

## Convenciones

- **Commits:** en español, descriptivos. Ejemplo: `feat: añadir middleware de autorización por roles`
- **Variables:** snake_case en DB, camelCase en JS, camelCase en Dart
- **UI:** en español. Tema dark mode, color primario `#C8F04D` (lima), Material 3
- **Timezone:** siempre `Europe/Madrid`
- **Puerto:** 3011 (`.env`, `server.js`, `api_client.dart` alineados)

## Reglas de dominio padel

### Niveles de jugador
- `main_level`: bajo | medio | alto
- `sub_level`: bajo | medio | alto
- `numeric_level`: columna GENERATED en PostgreSQL (0-9). **NO modificar el cálculo manualmente.**
  - bajo+bajo=1, bajo+medio=2, bajo+alto=3, medio+bajo=4, medio+medio=5, medio+alto=6, alto+bajo=7, alto+medio=8, alto+alto=9

### Partidos
- Máximo 4 jugadores, 2 equipos
- Posiciones: drive | revés | ambos
- Estados: buscando → completo → en_juego → finalizado | cancelado
- Filtro por nivel: `min_level` ≤ `numeric_level` del jugador ≤ `max_level`

### Reservas
- Duración: 30-240 minutos (default 90)
- Horario clubs: 08:00-22:00
- No se permite solapamiento: constraint UNIQUE en (court_id, booking_date, start_time)
- Estados: pendiente → confirmada → completada | cancelada
- Google Calendar sync: pendiente | sincronizada | error

### Precios
- Por hora: estándar vs cristal
- Normal vs hora punta (peak). Lógica en `calendarUtils.js` → `calculatePrice()`
- Precios seed: estándar 10-14€/h, cristal 14-18€/h, peak +4€/h

### Sedes actuales (seed data)
- Centro Deportivo Puerto Rey (Vera) — 11 pistas
- Labios Pádel (Cuevas del Almanzora) — 4 pistas
- Desert Springs Resort (Cuevas del Almanzora) — 3 pistas

## Base de datos

- **Schema:** `app` (no public). Configurado vía `DB_SEARCH_PATH=app,public`
- **RLS:** habilitado en todas las tablas, deny PUBLIC. Backend accede vía server role.
- **MCP Supabase** disponible para consultas directas.

### Tablas principales
| Tabla | Descripción | FK clave |
|-------|-------------|----------|
| `app.users` | Usuarios con role (user\|admin) | — |
| `app.padel_venues` | Sedes/clubs | — |
| `app.padel_courts` | Pistas individuales | → venues |
| `app.padel_bookings` | Reservas | → courts, → users |
| `app.padel_booking_players` | Participantes de reserva + RSVP | → bookings, → users |
| `app.padel_matches` | Partidos abiertos/privados | → bookings, → users, → venues |
| `app.padel_match_players` | Jugadores en partido | → matches, → users |
| `app.padel_player_profiles` | Perfil de jugador (nivel, posición, bio) | → users (UNIQUE) |
| `app.padel_player_ratings` | Valoraciones 1-5 entre jugadores | → users, → matches |
| `app.padel_favorites` | Jugadores favoritos | → users |
| `app.padel_calendar_sync_state` | Estado de sync con Google Calendar | — |

## Deuda técnica conocida

1. **Autorización inexistente** — `backend/middleware/auth.js` valida JWT pero **nunca verifica roles**. `users.role` tiene admin|user pero no se comprueba. Cualquier usuario autenticado puede crear/editar venues.
2. **State management parcial** — Solo `flutter_app/lib/features/auth/providers/auth_provider.dart` usa Riverpod. El resto de pantallas hacen API calls directas con `setState()`. No hay caché ni estado compartido.
3. **Servicio monolítico** — `backend/services/padelBookingService.js` tiene 1000+ líneas. Necesita refactoring en módulos cohesivos.
4. **Sin validación de schema** — No hay Zod/Joi. Validación ad-hoc con `if (!campo)`. Sin verificación de formato email, fuerza de password, ni sanitización.
5. **Tests mínimos** — Backend: 0 tests. Flutter: 2 archivos de test básicos.
6. **Sin push notifications** — No hay infraestructura de notificaciones.

## Infraestructura — Render + Supabase

### Render free tier: limitaciones críticas

| Limitación | Efecto | Solución aplicada |
|---|---|---|
| **Sin IPv6 de salida** | `ENETUNREACH` + proceso Node mata con exit 2 | Usar pooler Supabase (IPv4) |
| **Cold start tras ~15 min de inactividad** | Primera request tarda 30-60s → timeout en cliente | Timeouts Flutter 60/90s + pre-warm en login |
| **Reinicio automático si exit ≠ 0** | La API aparece como "Instance failed" en el dashboard | Global handlers + `pool.on('error')` |

### Supabase: qué URL usar en Render

**REGLA CRÍTICA:** En Render (y cualquier entorno sin IPv6), usar siempre la URL del **Transaction Pooler**, no la conexión directa.

| Tipo de URL | Hostname | IPv4/IPv6 | ¿Funciona en Render? |
|---|---|---|---|
| Conexión directa | `db.PROJECT.supabase.co` | **Solo IPv6** | ❌ NUNCA |
| Transaction Pooler | `aws-1-eu-central-1.pooler.supabase.com:6543` | **Solo IPv4** | ✅ SÍ |
| Session Pooler | `aws-1-eu-central-1.pooler.supabase.com:5432` | **Solo IPv4** | ✅ SÍ |

La `DATABASE_URL` en Render debe apuntar al pooler:
```
postgresql://postgres.PROJECT:PASSWORD@aws-1-eu-central-1.pooler.supabase.com:5432/postgres
```

### Síntomas del problema IPv6

Si ves en los logs de Render alguno de estos mensajes, el `DATABASE_URL` apunta a la conexión directa (IPv6):
```
❌ Error conectando a PostgreSQL: connect ENETUNREACH 2a05:d012:xxx:xxxx::xxxx:xxxx:1234
Instance failed: srv-xxx, Exited with status 2
```

**Acción:** Ir a Render → Environment → cambiar `DATABASE_URL` al pooler. El servicio se reinicia automáticamente.

### Estabilidad del proceso Node en Render

Se han aplicado estas defensas en el código para evitar crashes por red transitoria:

- `pool.on('error', handler)` en `backend/db.js` — captura errores de clientes idle antes de que escalen
- `process.on('unhandledRejection')` + `process.on('uncaughtException')` en `backend/server.js`
- `--dns-result-order=ipv4first` en `package.json` start script
- Backoff exponencial en `padelCalendarSync.js` (base × 2^n, cap 30 min)

## NO hacer

- **NO** tocar `quarantine/react-vite-web/`
- **NO** cambiar el schema de `app` a `public`
- **NO** modificar el cálculo de `numeric_level` (columna GENERATED en PostgreSQL)
- **NO** romper el modo demo (fallback sin DB cuando `DEMO_MODE=true`)
- **NO** commitear secretos (.env, tokens, claves Google)
- **NO** modificar migraciones ya aplicadas; crear migración nueva
- **NO** bloquear la API por errores de Google Calendar (tratar como fallo recuperable)
- **NO** usar la URL de conexión directa de Supabase (`db.PROJECT.supabase.co`) en Render — es IPv6 y Render free no tiene IPv6 de salida. Usar siempre el pooler (`aws-1-eu-central-1.pooler.supabase.com`)

## Skills del proyecto

### Playbooks operativos (docs/skills/)
Guías paso a paso para tareas recurrentes. Leer antes de trabajar en el área correspondiente:
- `docs/skills/skill-api-contract.md` — Cambios de contrato backend/Flutter
- `docs/skills/skill-bookings-calendar.md` — Reservas y sync Google Calendar
- `docs/skills/skill-matches-players.md` — Partidos, join/leave, contadores
- `docs/skills/skill-profile-search.md` — Perfil, búsqueda, favoritos, ratings
- `docs/skills/skill-release-smoke.md` — Checklist pre-release

### Playbooks de incidencia
- `docs/playbooks/incidencias.md` — Sync calendario, CORS, puertos, consistencia datos

### Skills de Claude Code (invocables)
- `/simplify` — Revisar código modificado buscando duplicación y mejoras. Ideal tras editar servicios grandes.
- `/commit` — Crear commit con mensaje bien formado (en español para este proyecto).

## Verificación tras cambios

```bash
cd flutter_app && flutter analyze    # Debe pasar limpio
cd flutter_app && flutter test       # Debe pasar
cd backend && npm run dev            # Debe arrancar sin errores
# Probar endpoints tocados con curl o desde la app
```
