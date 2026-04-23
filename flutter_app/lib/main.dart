import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/services/notification_service.dart';
import 'firebase_options.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_ES', null);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    const ProviderScope(
      child: IndaloPadelApp(),
    ),
  );
  unawaited(_initializeNotifications());
}

Future<void> _initializeNotifications() async {
  try {
    await NotificationService.instance.initialize(requestPermissions: false);
  } catch (error) {
    debugPrint('⚠️ No se pudo inicializar notificaciones al arrancar: $error');
  }
}
