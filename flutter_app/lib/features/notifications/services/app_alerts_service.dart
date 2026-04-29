import 'dart:convert';

import '../../../core/api/api_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../models/app_alerts_model.dart';
import 'local_notification_service.dart';

class AppAlertsService {
  AppAlertsService._();

  static final AppAlertsService instance = AppAlertsService._();

  static const _storagePrefix = 'padel_notified_alerts_';
  static const _ratingSeenStoragePrefix = 'padel_seen_rating_alerts_';

  final ApiClient _api = ApiClient();

  Future<AppAlertsState> refresh({bool notifyOnNew = true}) async {
    final fetchedState = await _fetchAlertsSnapshot();
    final state = await _filterSeenRatingAlerts(fetchedState);
    if (notifyOnNew) {
      await _notifyNewAlerts(state);
    }
    return state;
  }

  Future<void> clearStoredKeys() async {
    final key = await _storageKey(_storagePrefix);
    if (key != null) {
      await SecureStorage.deleteValue(key);
    }
    final ratingSeenKey = await _storageKey(_ratingSeenStoragePrefix);
    if (ratingSeenKey != null) {
      await SecureStorage.deleteValue(ratingSeenKey);
    }
  }

  Future<void> markProfileRatingAlertsSeen(
    List<AppAlertItem> alerts,
  ) async {
    if (alerts.isEmpty) {
      return;
    }

    final currentKeys = await _loadStoredKeys(_ratingSeenStoragePrefix);
    final mergedKeys = <String>{
      ...currentKeys,
      ...alerts.map((alert) => alert.uniqueKey),
    }.toList(growable: false);
    await _saveStoredKeys(_ratingSeenStoragePrefix, mergedKeys);
  }

  Future<AppAlertsState> _fetchAlertsSnapshot() async {
    final data = await _api.get('/padel/alerts');
    final json = data is Map<String, dynamic>
        ? data
        : Map<String, dynamic>.from(data as Map);
    return AppAlertsState.fromJson(json);
  }

  Future<AppAlertsState> _filterSeenRatingAlerts(
    AppAlertsState state,
  ) async {
    if (state.profileRatingAlerts.isEmpty) {
      return state;
    }

    final seenKeys = await _loadStoredKeys(_ratingSeenStoragePrefix);
    if (seenKeys.isEmpty) {
      return state;
    }

    final seenSet = seenKeys.toSet();
    return state.copyWith(
      profileRatingAlerts: state.profileRatingAlerts
          .where((alert) => !seenSet.contains(alert.uniqueKey))
          .toList(growable: false),
    );
  }

  Future<void> _notifyNewAlerts(AppAlertsState state) async {
    final currentKeys =
        state.allAlerts.map((alert) => alert.uniqueKey).toList();
    final previousKeys = await _loadStoredKeys(_storagePrefix);
    final newAlerts = state.allAlerts
        .where((alert) => !previousKeys.contains(alert.uniqueKey))
        .toList(growable: false);

    if (newAlerts.isNotEmpty) {
      await LocalNotificationService.instance.showAlerts(newAlerts);
    }

    await _saveStoredKeys(_storagePrefix, currentKeys);
  }

  Future<List<String>> _loadStoredKeys(String prefix) async {
    final key = await _storageKey(prefix);
    if (key == null) {
      return const [];
    }

    try {
      final raw = await SecureStorage.readValue(key);
      if (raw == null || raw.trim().isEmpty) {
        return const [];
      }
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [];
      }
      return decoded.map((item) => item.toString()).toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> _saveStoredKeys(String prefix, List<String> keys) async {
    final key = await _storageKey(prefix);
    if (key == null) {
      return;
    }

    final trimmed = keys.take(60).toList(growable: false);
    await SecureStorage.writeValue(key, jsonEncode(trimmed));
  }

  Future<String?> _storageKey(String prefix) async {
    try {
      final rawUser = await SecureStorage.getUser();
      if (rawUser == null || rawUser.trim().isEmpty) {
        return null;
      }
      final decoded = jsonDecode(rawUser);
      if (decoded is! Map || decoded['id'] == null) {
        return null;
      }
      return '$prefix${decoded['id']}';
    } catch (_) {
      return null;
    }
  }
}
