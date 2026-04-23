import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';

class CurrentProfileController
    extends StateNotifier<AsyncValue<Map<String, dynamic>?>> {
  CurrentProfileController(this._api) : super(const AsyncValue.loading()) {
    refresh();
  }

  final ApiClient _api;

  Future<void> refresh() async {
    final previousProfile = state.valueOrNull;
    if (previousProfile == null) {
      state = const AsyncValue.loading();
    }

    try {
      final data = await _api.get('/padel/players/profile');
      final profile = data['profile'];
      if (profile is Map) {
        state = AsyncValue.data(Map<String, dynamic>.from(profile));
        return;
      }

      state = const AsyncValue.data(null);
    } catch (error, stackTrace) {
      if (previousProfile != null) {
        state = AsyncValue.data(Map<String, dynamic>.from(previousProfile));
        return;
      }

      state = AsyncValue.error(error, stackTrace);
    }
  }

  void setProfile(Map<String, dynamic>? profile) {
    if (profile == null) {
      state = const AsyncValue.data(null);
      return;
    }

    state = AsyncValue.data(Map<String, dynamic>.from(profile));
  }
}

final currentProfileProvider = StateNotifierProvider<CurrentProfileController,
    AsyncValue<Map<String, dynamic>?>>((ref) {
  final api = ref.watch(apiClientProvider);
  return CurrentProfileController(api);
});
