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

  /// Inicializa FCM: permisos, handlers y suscripción al canal por defecto.
  Future<void> initialize() async {
    // Registrar handler de background antes de cualquier otra cosa
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Solicitar permiso (Android 13+ y iOS)
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Handler cuando la app está en primer plano
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('📬 Push en foreground: ${message.notification?.title}');
      // El paquete firebase_messaging muestra la notificación del sistema
      // automáticamente en Android cuando el canal está configurado.
    });

    // Configurar presentación de notificaciones en iOS en foreground
    await _messaging.setForegroundNotificationPresentationOptions(
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
    final token = await getToken();
    if (token == null) return;

    await _sendTokenToBackend(api, token);

    // Renovar token si Firebase lo rota
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
