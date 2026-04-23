import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../models/app_alerts_model.dart';
import '../services/app_alerts_service.dart';
import '../services/local_notification_service.dart';

final appAlertsProvider =
    StateNotifierProvider<AppAlertsController, AppAlertsState>((ref) {
  final controller = AppAlertsController(ref);
  ref.listen<AuthState>(authProvider, (_, next) {
    unawaited(controller.handleAuthState(next));
  });
  unawaited(controller.handleAuthState(ref.read(authProvider)));
  return controller;
});

class AppAlertsController extends StateNotifier<AppAlertsState> {
  AppAlertsController(this._ref) : super(const AppAlertsState());

  final Ref _ref;
  Timer? _pollTimer;
  bool _refreshing = false;

  Future<void> handleAuthState(AuthState authState) async {
    if (!authState.isAuthenticated) {
      _stopPolling();
      state = const AppAlertsState();
      await AppAlertsService.instance.clearStoredKeys();
      return;
    }

    await LocalNotificationService.instance.ensureInitialized();
    await LocalNotificationService.instance.requestPermissions();
    await refresh();
    _startPolling();
  }

  Future<void> refresh({bool notifyOnNew = true}) async {
    if (_refreshing || !_ref.read(authProvider).isAuthenticated) {
      return;
    }

    _refreshing = true;
    try {
      state = await AppAlertsService.instance.refresh(
        notifyOnNew: notifyOnNew,
      );
    } catch (_) {
      // Conservamos el estado previo para no apagar las bolitas por un error de red.
    } finally {
      _refreshing = false;
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(refresh());
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }
}
