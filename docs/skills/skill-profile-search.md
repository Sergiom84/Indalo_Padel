# skill-profile-search

## Cuándo usar
- Cambios en perfil de jugador, búsqueda, favoritos y valoraciones.

## Entradas mínimas
- Endpoint(s): `players/profile`, `players/search`, `players/:id`, `favorites`, `rate`.
- Regla de negocio a modificar (visibilidad, filtros, límites, validaciones).

## Pasos
1. Confirmar ownership en endpoints de perfil propio.
2. Revisar filtros de búsqueda (`name`, `level`, `available`) y orden.
3. Verificar integridad en favoritos (toggle idempotente y sin auto-favorito).
4. Verificar integridad en ratings (sin auto-rating, rango 1..5).
5. Validar parseo Flutter en `PlayerModel` y pantallas relacionadas.

## Salida esperada
- Búsqueda estable y coherente con filtros.
- Perfil/favoritos/ratings sin inconsistencias.

## Checklist
- [ ] Validaciones de negocio activas
- [ ] Sin exposición innecesaria de datos sensibles
- [ ] Favoritos y ratings mantienen constraints esperadas
- [ ] UI refleja cambios de forma consistente
