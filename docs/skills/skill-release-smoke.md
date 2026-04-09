# skill-release-smoke

## Cuándo usar
- Antes de merge/release o cuando se toquen flujos críticos multi-módulo.

## Entradas mínimas
- Lista de cambios del PR/tarea.
- Entorno objetivo (local/staging).

## Pasos
1. Backend:
   - levantar API;
   - comprobar `/api/health`;
   - verificar endpoints tocados.
2. Flutter:
   - `flutter analyze`;
   - `flutter test`;
   - abrir flujo principal en emulador/web.
3. Smoke funcional mínimo:
   - login/register;
   - ver sedes y disponibilidad;
   - crear/editar/cancelar reserva;
   - abrir calendario;
   - listar partidos y abrir detalle;
   - perfil/favoritos básicos.
4. Validar logs de error críticos tras las pruebas.

## Salida esperada
- Evidencia de validación técnica y funcional mínima.
- Lista de riesgos conocidos (si aplica).

## Checklist
- [ ] `flutter analyze` en verde
- [ ] `flutter test` en verde
- [ ] API health OK
- [ ] Flujos críticos navegables
- [ ] Riesgos residuales documentados
