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

    unawaited(LocalNotificationService.instance.ensureInitialized());
    await refresh();
    _startPolling();
  }

  Future<void> refresh({bool notifyOnNew = true}) async {
    if (_refreshing || !_ref.read(authProvider).isAuthenticated) {
      return;
    }

    _refreshing = true;
    final previousState = state;
    state = state.copyWith(loading: true);
    try {
      state = (await AppAlertsService.instance.refresh(
        notifyOnNew: notifyOnNew,
      ))
          .copyWith(loading: false);
    } catch (_) {
      // Conservamos el estado previo para no apagar las bolitas por un error de red.
      state = previousState.copyWith(loading: false);
    } finally {
      _refreshing = false;
    }
  }

  Future<void> markProfileRatingsSeen() async {
    final alerts = state.profileRatingAlerts;
    if (alerts.isEmpty) {
      return;
    }

    await AppAlertsService.instance.markProfileRatingAlertsSeen(alerts);
    state = state.copyWith(profileRatingAlerts: const []);
  }

  Future<void> markAlertsSeen(AppAlertsState alerts) async {
    if (!alerts.hasHomeNotifications) {
      return;
    }

    final keys = alerts.visibleAlertKeys;
    state = state.withoutAlertKeys(keys);
    try {
      await AppAlertsService.instance.markAlertsSeen(alerts);
    } catch (_) {
      // El estado visual ya se limpió; el siguiente refresh volverá a traerlo
      // solo si no se pudo persistir la lectura.
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(minutes: 5), (_) {
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
