import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/app_alerts_model.dart';

class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();

  static const _channelId = 'indalo_alerts';
  static const _channelName = 'Alertas de Indalo';
  static const _channelDescription =
      'Invitaciones y avisos importantes de la comunidad.';

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    _channelId,
    _channelName,
    description: _channelDescription,
    importance: Importance.max,
  );

  static const _summaryNotificationId = 7101;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _permissionsRequested = false;

  Future<void> ensureInitialized() async {
    if (_initialized || kIsWeb) {
      return;
    }

    const androidSettings = AndroidInitializationSettings('ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentBanner: true,
      defaultPresentList: true,
      defaultPresentSound: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _plugin.initialize(settings: settings);

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_channel);

    _initialized = true;
  }

  Future<void> requestPermissions() async {
    if (kIsWeb || _permissionsRequested) {
      return;
    }

    await ensureInitialized();
    _permissionsRequested = true;

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    final macos = _plugin.resolvePlatformSpecificImplementation<
        MacOSFlutterLocalNotificationsPlugin>();
    await macos?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> showAlerts(List<AppAlertItem> alerts) async {
    if (alerts.isEmpty || kIsWeb) {
      return;
    }

    await ensureInitialized();
    await requestPermissions();

    final title = alerts.length == 1
        ? alerts.first.title
        : 'Tienes ${alerts.length} nuevas notificaciones';
    final body =
        alerts.length == 1 ? alerts.first.body : _buildSummaryBody(alerts);

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        icon: 'ic_launcher',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
      macOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _plugin.show(
      id: _summaryNotificationId,
      title: title,
      body: body,
      notificationDetails: details,
      payload: alerts.first.uniqueKey,
    );
  }

  String _buildSummaryBody(List<AppAlertItem> alerts) {
    final playerCount =
        alerts.where((alert) => alert.scope == AppAlertScope.players).length;
    final communityCount = alerts.length - playerCount;
    final parts = <String>[];

    if (communityCount > 0) {
      parts.add(
        communityCount == 1
            ? '1 novedad en Comunidad'
            : '$communityCount novedades en Comunidad',
      );
    }

    if (playerCount > 0) {
      parts.add(
        playerCount == 1
            ? '1 invitación en Jugadores'
            : '$playerCount invitaciones en Jugadores',
      );
    }

    return parts.join(' · ');
  }
}
