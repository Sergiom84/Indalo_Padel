# skill-profile-search

## Cuándo usar
- Cambios en perfil de jugador, búsqueda, red de jugadores, invitaciones "Jugamos?", favoritos y valoraciones.

## Entradas mínimas
- Endpoint(s): `players/profile`, `players/search`, `players/:id`, `players/network`, `players/:id/network/request`, `players/:id/network/respond`, `favorites`, `rate`.
- Regla de negocio a modificar (visibilidad, filtros, límites, validaciones).

## Pasos
1. Confirmar ownership en endpoints de perfil propio.
2. Revisar filtros de búsqueda (`name`, `level`, `available`) y orden.
3. Verificar integridad en favoritos (toggle idempotente y sin auto-favorito).
4. Verificar integridad en red de jugadores:
   - par normalizado en `padel_player_connections`;
   - `requested_by` marca emisor;
   - `status` solo `pending`, `accepted`, `rejected`;
   - UI distingue `incoming_pending` y `outgoing_pending`.
5. Verificar integridad en ratings (sin auto-rating, rango 1..5).
6. Validar parseo Flutter en `PlayerModel` y pantallas relacionadas.

## Salida esperada
- Búsqueda estable y coherente con filtros.
- Perfil/red/favoritos/ratings sin inconsistencias.

## Checklist
- [ ] Validaciones de negocio activas
- [ ] Sin exposición innecesaria de datos sensibles
- [ ] Invitaciones entrantes/salientes aparecen en la pestaña correcta
- [ ] Favoritos y ratings mantienen constraints esperadas
- [ ] UI refleja cambios de forma consistente
