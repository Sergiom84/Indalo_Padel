# skill-api-contract

## Cuándo usar
- Cambios de payload/shape entre backend y Flutter.
- Añadir alias compatibles (ej. `player_count` y `current_players`).
- Depurar pantallas vacías por parsing o shape inconsistente.

## Entradas mínimas
- Endpoint(s) afectados.
- Modelo(s) Flutter afectados.
- Compatibilidad requerida (retrocompatible o no).

## Pasos
1. Identificar shape actual en backend (respuesta real).
2. Comparar con parsing Flutter (`fromJson` y consumo en pantalla).
3. Si hay divergencia, priorizar cambios no disruptivos:
   - mantener campo previo;
   - añadir alias nuevo;
   - actualizar parsing tolerante.
4. Añadir/ajustar tests unitarios de modelos.
5. Actualizar documentación técnica si cambió contrato.

## Salida esperada
- Contrato estable y explícito.
- UI sin dependencia frágil de un único alias.
- Tests que fallen ante regresiones de shape.

## Checklist
- [ ] Endpoint responde campos necesarios
- [ ] Flutter parsea ambos aliases necesarios
- [ ] Hay test unitario del contrato mínimo
- [ ] No se rompe compatibilidad existente
