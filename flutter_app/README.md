# Indalo Padel Flutter

Cliente móvil nativo de Indalo Pádel para iOS y Android.

## Comandos útiles

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

## Configuración del backend

La app resuelve la URL base automáticamente:

- Android emulator: `http://10.0.2.2:3010/api`
- iOS simulator: `http://localhost:3010/api`

Para un dispositivo físico o un backend remoto:

```bash
flutter run --dart-define=API_BASE_URL=http://TU_IP:3010/api
```

## Estado de la app

- Shell nativa completa con carpetas `android/` e `ios/`
- Navegación principal con 5 tabs: Inicio, Clubes, Reservas, Partidos y Perfil
- Perfil propio con edición básica, disponibilidad y logout
- Home orientada a móvil con accesos rápidos a jugadores y favoritos
- Reserva de pistas y disponibilidad adaptadas a móvil sin tablas de escritorio
