# Playbooks de Incidencia — Indalo Padel

## 1) Sync Google Calendar en `error`
### Síntomas
- Reservas con `calendar_sync_status = error`.
- En UI, banner de sincronización con incidencias.

### Diagnóstico rápido
1. Verificar variables:
   - `GOOGLE_CLIENT_ID`
   - `GOOGLE_CLIENT_SECRET`
   - `GOOGLE_REFRESH_TOKEN`
   - `GOOGLE_CALENDAR_ID`
2. Revisar logs backend al ejecutar ciclo de sync.
3. Confirmar conectividad y permisos del calendario destino.

### Acciones
- Corregir credenciales/permisos.
- Forzar nueva sincronización (refresco calendario en app o ciclo backend).
- Confirmar transición a `sincronizada`.

## 2) Error CORS
### Síntomas
- Fallo de peticiones desde web preview o dominio deployado.

### Diagnóstico rápido
1. Revisar `CORS_ORIGINS` en `.env`.
2. Confirmar patrón permitido en `backend/server.js`.
3. Inspeccionar origen real de la petición.

### Acciones
- Añadir origen explícito a `CORS_ORIGINS` si no entra por patrón.
- Reiniciar backend y validar `/api/health`.

## 3) Conflicto de puertos (EADDRINUSE)
### Síntomas
- Backend no arranca y muestra `EADDRINUSE`.

### Diagnóstico rápido
1. Verificar `PORT` en `.env` (base actual: `3011`).
2. Detectar proceso ocupando el puerto.

### Acciones
- Parar proceso en conflicto o cambiar `PORT`.
- Mantener alineadas docs y `API_BASE_URL` Flutter.

## 4) Inconsistencia de datos (reservas/partidos)
### Síntomas
- Contadores incorrectos en partidos.
- Reservas visibles pero con datos parciales o estados inesperados.

### Diagnóstico rápido
1. Contrastar tabla principal y tabla detalle:
   - `padel_matches` vs `padel_match_players`
   - `padel_bookings` vs `padel_booking_players`
2. Revisar constraints/indexes vigentes.
3. Reproducir flujo mínimo en entorno local.

### Acciones
- Corregir lógica de actualización en servicio.
- Añadir test de regresión.
- Si aplica, crear migración de saneamiento de datos.
