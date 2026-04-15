# skill-community-plans

## Cuándo usar
- Cambios en convocatorias de comunidad, propuestas de horario/pista, cierres, participantes, notificaciones o reservas confirmadas desde comunidad.

## Entradas mínimas
- Endpoint(s): `community`, `community/:id/*`.
- Pantalla/provider Flutter afectado.
- Regla de negocio: crear, responder, proponer pista/horario, cerrar, cancelar o mostrar historial.

## Pasos
1. Revisar flujo completo: ruta -> servicio -> DB -> respuesta Flutter.
2. Verificar estados de convocatoria y reserva:
   - participantes confirmados;
   - `reservation_state`;
   - cierre/cancelación;
   - reserva vinculada cuando aplique.
3. Confirmar integridad de participantes:
   - sin duplicados;
   - sin superar aforo;
   - permisos del creador para acciones sensibles.
4. Revisar notificaciones internas y visibilidad para usuarios afectados.
5. Si hay sincronización con Google Calendar, aplicar el playbook `skill-bookings-calendar`.
6. Validar que `community_provider.dart` y las pantallas parsean todos los campos usados.

## Salida esperada
- Convocatorias y participantes consistentes entre backend, Supabase y Flutter.
- Historial/pendientes/convocatorias visibles en la pestaña correcta.
- Reservas confirmadas desde comunidad reflejadas en calendario y home.

## Checklist
- [ ] Estados de convocatoria/reserva coherentes
- [ ] Participantes sin duplicados ni aforo excedido
- [ ] Permisos del creador revisados
- [ ] Notificaciones visibles para destinatarios correctos
- [ ] UI actualiza pendientes, historial y calendario
