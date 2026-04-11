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

- Android emulator: `http://10.0.2.2:3011/api`
- iOS simulator: `http://localhost:3011/api`

Para un dispositivo físico o un backend remoto:

```bash
flutter run --dart-define=API_BASE_URL=http://TU_IP:3011/api
```

En release para Play Console debes compilar siempre con una URL publica.
`10.0.2.2` y `localhost` solo sirven en desarrollo local.

## Build Android release (AAB)

1. Desde la raíz del repo, crea el keystore:

```powershell
.\scripts\create_android_keystore.ps1
```

2. Verifica y completa contraseñas en `android/key.properties`.
3. Ejecuta desde la raíz del repo:

```powershell
.\scripts\build_android_release.ps1 `
  -ApiBaseUrl "https://TU_API_PUBLICA/api" `
  -BuildName "1.0.1" `
  -BuildNumber "2"
```

Salida:
- `build/app/outputs/bundle/release/app-release.aab`

## Estado de la app

- Shell nativa completa con carpetas `android/` e `ios/`
- Navegación principal con 5 tabs: Inicio, Clubes, Reservas, Partidos y Perfil
- Perfil propio con edición básica, disponibilidad y logout
- Home orientada a móvil con accesos rápidos a jugadores y favoritos
- Reserva de pistas y disponibilidad adaptadas a móvil sin tablas de escritorio
