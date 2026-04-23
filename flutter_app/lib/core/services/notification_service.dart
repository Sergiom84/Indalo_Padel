import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../api/api_client.dart';

/// Handler de mensajes en segundo plano (top-level, requerido por FCM).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase ya muestra la notificación del sistema automáticamente.
  // Aquí podríamos actualizar caché local si fuera necesario.
  debugPrint('📬 Push en background: ${message.notification?.title}');
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _messaging = FirebaseMessaging.instance;
  bool _initialized = false;
  bool _foregroundBound = false;
  bool _permissionRequested = false;
  bool _tokenRefreshBound = false;

  /// Inicializa FCM sin forzar permisos en el camino crítico de arranque.
  Future<void> initialize({bool requestPermissions = false}) async {
    if (_initialized) {
      if (requestPermissions) {
        await requestPermissionsIfNeeded();
      }
      return;
    }

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    if (!_foregroundBound) {
      FirebaseMessaging.onMessage.listen((message) {
        debugPrint('📬 Push en foreground: ${message.notification?.title}');
      });
      _foregroundBound = true;
    }

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    _initialized = true;

    if (requestPermissions) {
      await requestPermissionsIfNeeded();
    }
  }

  Future<void> requestPermissionsIfNeeded() async {
    if (_permissionRequested) {
      return;
    }

    _permissionRequested = true;
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  /// Obtiene el token FCM actual del dispositivo.
  Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      debugPrint('⚠️  No se pudo obtener FCM token: $e');
      return null;
    }
  }

  /// Registra el token en el backend y se suscribe a renovaciones.
  Future<void> registerToken(ApiClient api) async {
    await initialize();
    final token = await getToken();
    if (token == null) return;

    await _sendTokenToBackend(api, token);

    if (_tokenRefreshBound) {
      return;
    }

    _tokenRefreshBound = true;
    _messaging.onTokenRefresh.listen((newToken) {
      _sendTokenToBackend(api, newToken);
    });
  }

  Future<void> _sendTokenToBackend(ApiClient api, String token) async {
    try {
      await api.post('/padel/notifications/fcm-token', data: {
        'token': token,
        'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      });
      debugPrint('✅ FCM token registrado en backend');
    } catch (e) {
      debugPrint('⚠️  No se pudo registrar FCM token: $e');
    }
  }

  /// Elimina el token del backend al cerrar sesión.
  Future<void> unregisterToken(ApiClient api) async {
    final token = await getToken();
    if (token == null) return;
    try {
      await api.delete('/padel/notifications/fcm-token', data: {'token': token});
    } catch (_) {}
  }
}
