# Roadmap Técnico — Agents + Skills

## Objetivo
- Ordenar la ejecución por dependencias reales de producto y de dominio.
- Reducir regresiones entre backend y Flutter antes de abrir nuevas superficies.
- Dejar criterios de verificación explícitos para cada fase.

## Fase 1 — Estabilidad de lifecycle, resultados y valoraciones
- Unificar reglas de estado para `matches`, reservas y convocatorias cerradas.
- Gatear captura de resultados por hora real de fin, no solo por bucket histórico.
- Rehidratar submissions de resultado ya guardadas y evitar prompts repetidos.
- Mantener partidos futuros fuera de historial y del flujo de rating.
- Bloquear/permitir valoraciones solo cuando el partido esté realmente resuelto.

### Dependencias
- Ninguna. Esta fase desbloquea el resto.

### Salida
- Estados y transiciones consistentes para resultado, historial y rating.

## Fase 2 — Convocatoria: campos de producto y modelo de preferencias
- Exponer en modelos/UI los campos nuevos de convocatoria: sede, contacto, responsable de reserva, sync y cierre.
- Consolidar el modelo de preferencias de jugador en Flutter para perfil, búsqueda y comunidad.
- Cambiar la representación visible de nivel de numérica a etiquetas textuales.
- Mantener compatibilidad con aliases/API existentes mientras el contrato se estabiliza.

### Dependencias
- Fase 1 cerrada para no mezclar cambios de presentación con estados inestables.

### Salida
- Convocatorias y perfiles muestran los campos operativos correctos y usan un modelo común.

## Fase 3 — Startup performance y dashboard bootstrap
- Sacar del arranque bloqueante toda inicialización no crítica.
- Cargar shell, auth cacheada y dashboard mínimo antes de tareas secundarias.
- Dejar refresh de alertas, notificaciones y datos secundarios en segundo plano.
- Asegurar que home/dashboard no dependa de un bootstrap monolítico.

### Dependencias
- Fases 1-2 para no optimizar sobre modelos aún cambiantes.

### Salida
- Primer frame más rápido y bootstrap del dashboard desacoplado de init no esencial.

## Fase 4 — Chat directo
- Definir hilo 1:1, unread state, notificaciones y persistencia mínima.
- Integrar con identidad/red de jugadores sin acoplarlo todavía a eventos.
- Validar entrega, lectura y recuperación de conversación.

### Dependencias
- Fase 3 para no degradar startup con la nueva capa de mensajería.

### Salida
- Mensajería directa utilizable con estados básicos fiables.

## Fase 5 — Chat de grupo
- Añadir grupos persistentes, membresía, roles básicos y mute/unread.
- Reutilizar transporte, storage y notificaciones del chat directo.
- Definir límites operativos antes de conectar chats a entidades de producto.

### Dependencias
- Fase 4 completada.

### Salida
- Chat multiusuario estable sin depender todavía de convocatorias/eventos.

## Fase 6 — Chat ligado a eventos/convocatorias
- Vincular hilos a convocatorias, partidos y eventos con membresía automática.
- Añadir mensajes de sistema para altas, bajas, cambios de hora y cierre.
- Sincronizar visibilidad del hilo con lifecycle real del evento.

### Dependencias
- Fases 1-2 para lifecycle/campos.
- Fase 5 para la base de chat de grupo.

### Salida
- Conversaciones de evento alineadas con estados de comunidad y match lifecycle.

## Verificación
- `flutter analyze` y `flutter test` en cada fase con foco en modelos/providers tocados.
- Pruebas de contrato para payloads de matches, community plans, profile/preferences y dashboard.
- Escenarios de regresión mínimos:
  - resultado antes/después de hora fin;
  - historial sin partidos futuros;
  - rating solo tras cierre válido;
  - preferencias visibles coherentes en perfil/búsqueda/comunidad;
  - bootstrap sin bloquear primer render;
  - unread/notificaciones coherentes en chat por fase.
- No avanzar de fase si los contratos o los criterios de salida quedan ambiguos.
