import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';

final currentProfileProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  final api = ref.watch(apiClientProvider);

  try {
    final data = await api.get('/padel/players/profile');
    final profile = data['profile'];
    if (profile is Map) {
      return Map<String, dynamic>.from(profile);
    }
  } catch (_) {
    return null;
  }

  return null;
});
