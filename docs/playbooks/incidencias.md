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

## 5) Backend Render "Instance failed: Exited with status 2"

### Síntomas
- Dashboard Render muestra `Instance failed: srv-xxx, Exited with status 2` de forma periódica.
- En logs: `connect ENETUNREACH 2a05:d012:xxx::xxxx` (dirección IPv6) o `getaddrinfo EAI_AGAIN db.PROJECT.supabase.co`
- La API deja de responder hasta que Render reinicia el contenedor (varios minutos).

### Causa raíz
La `DATABASE_URL` apunta a la conexión directa de Supabase (`db.PROJECT.supabase.co`), cuyo DNS resuelve **solo a IPv6**. Render free tier **no tiene conectividad IPv6 de salida** → `ENETUNREACH` → el proceso Node muere con exit 2.

### Diagnóstico rápido
```bash
# Comprueba si la dirección IP en los logs es IPv6 (2a05:..., ::, etc.)
# Si es IPv6 → DATABASE_URL apunta a conexión directa, no al pooler
curl https://indalo-padel.onrender.com/api/health
# Si devuelve {"mode":"demo"} en lugar de "database" → confirmado
```

### Acciones
1. Ir a **Render → Service → Environment**
2. Cambiar `DATABASE_URL` al Transaction Pooler de Supabase:
   ```
   postgresql://postgres.PROJECT:PASS@aws-1-eu-central-1.pooler.supabase.com:5432/postgres
   ```
3. Render reiniciará automáticamente. Verificar en logs:
   ```
   ✅ Conexión a PostgreSQL exitosa
   ✅ Tabla users encontrada
   📂 search_path actual: app,public
   ```
4. Confirmar con health check: `{"status":"ok","mode":"database"}`

### Por qué el pooler funciona y la directa no
| Hostname | Resuelve a | Render free |
|---|---|---|
| `db.PROJECT.supabase.co` | IPv6 únicamente | ❌ ENETUNREACH |
| `aws-1-eu-central-1.pooler.supabase.com` | IPv4 únicamente | ✅ OK |

### Fixes preventivos ya aplicados en el código
- `pool.on('error')` en `db.js` — evita que errores idle escalen
- `process.on('unhandledRejection/uncaughtException')` en `server.js` — red de seguridad global
- Backoff exponencial en `padelCalendarSync.js` — no martillea el pool durante outages de red
- `--dns-result-order=ipv4first` en el start script de `package.json`

---

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
