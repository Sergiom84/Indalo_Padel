# Indalo Padel

App móvil nativa (Flutter) para reservas de pistas de pádel, gestión de partidos y perfiles de jugadores.

## Estructura del proyecto

```
├── flutter_app/   → App Flutter nativa (Android + iOS)
├── backend/       → API REST Node.js/Express + PostgreSQL
```

## Cómo ejecutar

### Backend
```bash
cd backend
npm install
npm run dev
# API disponible en http://localhost:3010
```

### App Flutter
```bash
cd flutter_app
flutter pub get
flutter run
```

## Notas de conexión al backend
- **Android emulator**: `http://10.0.2.2:3010/api` por defecto.
- **iOS simulator**: `http://localhost:3010/api` por defecto.
- **Dispositivo físico**: ejecuta Flutter con `--dart-define=API_BASE_URL=http://TU_IP:3010/api`.

## Validación realizada
```bash
cd flutter_app
flutter analyze
flutter test
```
