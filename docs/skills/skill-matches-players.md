# skill-matches-players

## Cuándo usar
- Cambios en creación de partido, join/leave, estados (`buscando`, `completo`, etc.) y listado de jugadores.

## Entradas mínimas
- Endpoint de matches afectado.
- Regla de negocio (aforo, nivel, permisos del creador).

## Pasos
1. Revisar validaciones de estado antes de join/leave.
2. Asegurar consistencia entre:
   - `padel_matches.current_players`
   - `padel_match_players` (filas reales).
3. Verificar control de permisos del creador para cambios de estado.
4. Mantener campos de respuesta usados por Flutter (`player_count/current_players`, `creator_name`, etc.).
5. Probar escenarios de concurrencia básica (doble join, leave repetido).

## Salida esperada
- Contadores y estado del partido consistentes.
- UX estable en `match_list_screen` y `match_detail_screen`.

## Checklist
- [ ] Sin duplicados de jugador en un mismo partido
- [ ] Join respeta aforo y nivel
- [ ] Leave actualiza contador sin negativos
- [ ] Estado del partido no entra en transición inválida
