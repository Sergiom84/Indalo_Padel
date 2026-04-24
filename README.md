# Indalo Padel

Producto activo: app Flutter para Android/iOS con backend Node.js/Express.

El frontend React/Vite original ha quedado en cuarentena en `quarantine/react-vite-web/` y no forma parte del flujo de desarrollo actual.

## Estado funcional frente al feedback de usuarios

Incluido en la app:
- Convocatorias con modalidad (`Amistoso`, `Competitivo`, `Americana`), club, post padel y observaciones.
- Notificaciones internas/push al confirmar reserva de convocatoria, resultados tras hora de fin, historial sin partidos futuros, submissions de resultado rehidratadas y valoraciones por partido/convocatoria.
- Preferencias visuales de nivel y horario (`Lunes a viernes`, `Fin de semana`, franjas), eliminación de cuenta y chat entre jugadores de Mi Red con grupos/eventos.
- Push de chat con apertura directa de conversación, burbuja de mensajes en Inicio, contador ligero de no leídos y flechas de descubrimiento en la barra inferior scrollable.
- Recordatorios externos de Google Calendar a 60 minutos por defecto, configurable con `GOOGLE_EVENT_REMINDER_MINUTES`.
- Invitaciones de Google Calendar con lista de invitados oculta (`guestsCanSeeOtherGuests=false`) y descripciones con nombres visibles de la app, sin correos.

Pendiente o parcial:
- Verificar en producción/dispositivo real: permisos FCM, recepción foreground/background, tap de push y variable `GOOGLE_EVENT_REMINDER_MINUTES=60`.
- Medir y optimizar carga inicial más allá de las mitigaciones actuales de cache/pre-warm, permisos diferidos y contador ligero de chat.

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

## Distribución Android (Internal Testing)

Prerequisitos:
- Configurar identificador Android definitivo en la app (`com.indalopadel.app`).
- Crear keystore de subida y `flutter_app/android/key.properties` (plantilla: `flutter_app/android/key.properties.example`).
- Tener una URL pública para el backend API.

Crear keystore (Windows, PowerShell):
```powershell
.\scripts\create_android_keystore.ps1
```

Si quieres ejecutar `keytool` manualmente sin tocar `PATH`:
```powershell
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" `
  -genkeypair -v `
  -keystore "$env:USERPROFILE\upload-keystore.jks" `
  -storetype JKS `
  -keyalg RSA -keysize 2048 -validity 10000 `
  -alias upload
```

Build release firmada:
```powershell
.\scripts\build_android_release.ps1 `
  -ApiBaseUrl "https://TU_API_PUBLICA/api" `
  -BuildName "1.0.1" `
  -BuildNumber "2"
```

Importante:
- La release de Play Console no puede usar `localhost` ni `10.0.2.2`.
- Si subes un `.aab` sin `API_BASE_URL`, Android intentará conectar al backend local del emulador y acabará en timeout.

El bundle generado queda en:
- `flutter_app/build/app/outputs/bundle/release/app-release.aab`

Siguiente paso en Play Console:
- Crear release en `Testing > Internal testing`.
- Subir ese `.aab`.
- Añadir emails de testers y compartir el enlace de prueba.

## Variables de entorno

El backend carga el `.env` de la raíz del proyecto.

- `DATABASE_URL`: conexión a PostgreSQL
- `DB_SEARCH_PATH`: esquema de trabajo
- `JWT_SECRET`: clave JWT
- `PORT`: puerto de la API
- `DEMO_MODE`: arranca sin base de datos si vale `true`
- `CORS_ORIGINS`: lista opcional de orígenes web separados por comas
- `PUBLIC_API_BASE_URL`: URL pública base de la API para construir enlaces de verificación y reset
- `REQUIRE_EMAIL_VERIFICATION`: si vale `false`, permite iniciar sesión sin validar correo y desactiva temporalmente ese flujo
- `RESEND_API_KEY`: API key de Resend para el envío de correos transaccionales
- `EMAIL_FROM`: remitente verificado en Resend, por ejemplo `Indalo Padel <no-reply@tu-dominio>`
- `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GOOGLE_REFRESH_TOKEN`: sync con Google Calendar
- `GOOGLE_CALENDAR_ID`: calendario destino (`primary` por defecto)
- `GOOGLE_EVENT_REMINDER_MINUTES`: minutos de antelación del recordatorio externo. Para producto usar `60`.
- `FIREBASE_SERVICE_ACCOUNT_JSON`: service account para enviar push FCM desde backend
- `CALENDAR_TIME_ZONE`: zona horaria de calendario, por defecto `Europe/Madrid`

Importante para producción:
- El registro, la verificación de correo y el reset de contraseña necesitan `RESEND_API_KEY` y `EMAIL_FROM`.
- Si falta esa configuración, la cuenta puede quedar creada pero el correo no se enviará hasta que el servicio de email vuelva a estar disponible.
- Las push requieren `FIREBASE_SERVICE_ACCOUNT_JSON` en backend y configuración Firebase válida en la app móvil.
- Los recordatorios externos de partidos/convocatorias dependen de que Google Calendar sync esté configurado y de que `GOOGLE_EVENT_REMINDER_MINUTES` sea `60`.

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
