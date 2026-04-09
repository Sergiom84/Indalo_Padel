# Indalo Padel

Producto activo: app Flutter para Android/iOS con backend Node.js/Express.

El frontend React/Vite original ha quedado en cuarentena en `quarantine/react-vite-web/` y no forma parte del flujo de desarrollo actual.

## Estructura del proyecto

```
├── flutter_app/               → App Flutter (Android, iOS y preview web)
├── backend/                   → API REST Node.js/Express + PostgreSQL
└── quarantine/react-vite-web/ → Frontend legado retirado del flujo activo
```

## Cómo ejecutar

### Backend
```bash
cd backend
npm install
npm run dev
# API disponible en http://localhost:3011
```

### App Flutter móvil
```bash
cd flutter_app
flutter pub get
flutter run
```

### Preview web para revisar cambios
```bash
cd flutter_app
flutter pub get
flutter run -d chrome
```

### Build web para publicar revisión
```bash
cd flutter_app
flutter build web
```

El resultado queda en `flutter_app/build/web` y se puede publicar como static site en Render.

## Variables de entorno

El backend carga el `.env` de la raíz del proyecto.

- `DATABASE_URL`: conexión a PostgreSQL
- `DB_SEARCH_PATH`: esquema de trabajo
- `JWT_SECRET`: clave JWT
- `PORT`: puerto de la API
- `DEMO_MODE`: arranca sin base de datos si vale `true`
- `CORS_ORIGINS`: lista opcional de orígenes web separados por comas

## Notas de conexión Flutter

- Android emulator: `http://10.0.2.2:3011/api`
- iOS simulator: `http://localhost:3011/api`
- Dispositivo físico: `flutter run --dart-define=API_BASE_URL=http://TU_IP:3011/api`

## Validación realizada
```bash
cd flutter_app
flutter analyze
flutter test
```
