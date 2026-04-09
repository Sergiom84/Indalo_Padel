# Roadmap Técnico (2-4 semanas) — Agents + Skills + Quick Wins

## Objetivo
- Reducir regresiones backend/Flutter.
- Acelerar entrega con protocolo común para asistentes de código.
- Consolidar fiabilidad en reservas, calendario, matches y perfil.

## Semana 1 — Estandarización operativa
- Publicar `AGENT.md` y skills de repositorio.
- Incorporar playbooks de incidencias operativas.
- Alinear configuración/documentación de puertos (`3011`) y runbooks.

### Criterio de salida
- Cualquier tarea nueva puede seguir flujo estándar sin decisiones implícitas.

## Semana 1-2 — Contrato API y compatibilidad
- Exponer `player_count` en `GET /api/padel/matches` manteniendo `current_players`.
- Corregir `sync.last_synced_at` en `/api/padel/bookings/my-calendar`.
- Normalizar consumo de `venues/matches` en Flutter para aceptar shape objeto/lista.
- Añadir pruebas unitarias de contrato de modelos Flutter.

### Criterio de salida
- Pantallas de partidos/sedes/calendario no dependen de un único alias frágil.

## Semana 2-3 — Consistencia de dominio
- Revisar integridad de join/leave en partidos.
- Añadir test/escenarios de concurrencia básica en matches.
- Revisar transición de estados de reservas y RSVP frente a Google Calendar.

### Criterio de salida
- Sin desajustes de contadores o estados tras operaciones concurrentes típicas.

## Semana 3-4 — Observabilidad y release safety
- Checklist de smoke release aplicado por defecto en cambios críticos.
- Registro de riesgos y fallback documentado por flujo.
- Consolidar métricas mínimas de errores operativos (sync/CORS/puertos).

### Criterio de salida
- Menor tiempo de diagnóstico en incidencias repetidas.

## Plan de pruebas y criterios de aceptación
### Pruebas de contrato backend
- Validar shape de `GET /api/padel/matches`:
  - devuelve `current_players` y `player_count`.
- Validar shape de `GET /api/padel/venues`:
  - acepta consumo como lista directa o como objeto con `venues`.
- Validar shape de `GET /api/padel/bookings/my-calendar`:
  - incluye `sync.status` y `sync.last_synced_at` cuando exista estado.

### Pruebas de concurrencia (matches)
- Ejecutar joins simultáneos sobre un mismo partido abierto.
- Ejecutar leave repetido/simultáneo y verificar que:
  - `current_players` no queda negativo;
  - el contador se mantiene consistente con filas de `padel_match_players`.

### Pruebas de sincronización calendario
- Cubrir estados `pendiente`, `sincronizada` y `error`.
- Verificar actualización de RSVP desde eventos/calendario y su reflejo local.

### Pruebas Flutter
- Probar parsing de:
  - `MatchModel`
  - `VenueModel`
  - `CalendarFeedModel`
- Validar render mínimo en pantallas críticas:
  - listado de partidos;
  - listado de sedes;
  - calendario personal.

### Criterio de aceptación global
- Cualquier tarea nueva puede ejecutarse siguiendo `AGENT.md` y la skill aplicable
  sin decisiones implícitas ni cambios de criterio entre asistentes.

## Riesgos y mitigaciones
- Riesgo: divergencia entre shape backend y parsing Flutter.
  - Mitigación: `skill-api-contract` + tests de modelo.
- Riesgo: errores externos de Google Calendar bloqueando UX.
  - Mitigación: estado `error` recuperable + playbook de sync.
- Riesgo: cambios simultáneos de asistentes sobre mismos módulos.
  - Mitigación: handoff explícito en `AGENT.md`.
