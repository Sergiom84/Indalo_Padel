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
- **Android emulator**: conecta a `http://10.0.2.2:3010/api` (por defecto)
- **iOS simulator**: cambia a `http://localhost:3010/api`
- **Dispositivo físico**: usa tu IP LAN en `flutter_app/lib/core/api/api_client.dart`
