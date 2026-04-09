# skill-bookings-calendar

## Cuándo usar
- Cambios en reservas, invitaciones, `my-calendar`, RSVP o sincronización con Google Calendar.

## Entradas mínimas
- Endpoint o pantalla afectada.
- Caso de negocio (crear, editar, cancelar, responder invitación, sync).
- Impacto esperado en tablas (`padel_bookings`, `padel_booking_players`, `padel_calendar_sync_state`).

## Pasos
1. Revisar flujo completo: ruta -> servicio -> DB -> respuesta.
2. Validar reglas de horario y solape de reservas.
3. Verificar mapeo de estados locales y Google (`needsAction/accepted/declined/cancelled`).
4. Garantizar que errores de Google dejan traza (`calendar_sync_status = 'error'`) sin romper API.
5. Confirmar shape consumido por Flutter en `calendar_screen` y modelos.

## Salida esperada
- Cambio funcional coherente entre backend y Flutter.
- Estado de sync consistente y observable.
- Respuestas con campos necesarios para UI (estado reserva, invitados, sync).

## Checklist
- [ ] No rompe creación/edición/cancelación de reserva
- [ ] RSVP actualiza estado local
- [ ] Manejo de errores externos robusto
- [ ] `my-calendar` devuelve `sync.status` y `sync.last_synced_at` válidos
- [ ] `flutter analyze` y `flutter test` en verde
