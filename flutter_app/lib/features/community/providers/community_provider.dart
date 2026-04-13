import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../models/community_model.dart';

final communityDashboardProvider = FutureProvider<CommunityDashboardModel>((
  ref,
) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.get('/padel/community');
  final json = data is Map<String, dynamic>
      ? data
      : Map<String, dynamic>.from(data as Map);
  return CommunityDashboardModel.fromJson(json);
});

final communityActionsProvider = Provider<CommunityActions>((ref) {
  return CommunityActions(ref.watch(apiClientProvider), ref);
});

class CommunityActions {
  final ApiClient _api;
  final Ref _ref;

  CommunityActions(this._api, this._ref);

  Future<void> createPlan({
    required String scheduledDate,
    required String scheduledTime,
    required List<int> participantUserIds,
    bool forceSend = false,
  }) async {
    await _api.post('/padel/community', data: {
      'scheduled_date': scheduledDate,
      'scheduled_time': scheduledTime,
      'participant_user_ids': participantUserIds,
      'force_send': forceSend,
    });
    _ref.invalidate(communityDashboardProvider);
  }

  Future<void> updatePlan({
    required int planId,
    required String scheduledDate,
    required String scheduledTime,
    required List<int> participantUserIds,
    String? updatedAt,
    bool forceSend = false,
  }) async {
    await _api.put('/padel/community/$planId', data: {
      'scheduled_date': scheduledDate,
      'scheduled_time': scheduledTime,
      'participant_user_ids': participantUserIds,
      'updated_at': updatedAt,
      'force_send': forceSend,
    });
    _ref.invalidate(communityDashboardProvider);
  }

  Future<void> respondToPlan({
    required int planId,
    required String action,
    String? updatedAt,
  }) async {
    await _api.post('/padel/community/$planId/respond', data: {
      'action': action,
      'updated_at': updatedAt,
    });
    _ref.invalidate(communityDashboardProvider);
  }

  Future<void> proposeTime({
    required int planId,
    required String scheduledDate,
    required String scheduledTime,
    String? updatedAt,
  }) async {
    await _api.post('/padel/community/$planId/propose-time', data: {
      'scheduled_date': scheduledDate,
      'scheduled_time': scheduledTime,
      'updated_at': updatedAt,
    });
    _ref.invalidate(communityDashboardProvider);
  }

  Future<String?> updateReservationStatus({
    required int planId,
    required String status,
    int? handledByUserId,
    String? updatedAt,
  }) async {
    final response = await _api.post(
      '/padel/community/$planId/reservation-status',
      data: {
        'status': status,
        'handled_by_user_id': handledByUserId,
        'updated_at': updatedAt,
      },
    );
    _ref.invalidate(communityDashboardProvider);
    if (response is Map && response['calendar_sync_error'] != null) {
      return response['calendar_sync_error'].toString();
    }
    return null;
  }

  Future<void> cancelPlan({
    required int planId,
    String? updatedAt,
  }) async {
    await _api.delete('/padel/community/$planId', data: {
      'updated_at': updatedAt,
    });
    _ref.invalidate(communityDashboardProvider);
  }

  Future<CommunityConflictPreviewModel> previewConflicts({
    int? planId,
    required String scheduledDate,
    required String scheduledTime,
    required List<int> participantUserIds,
  }) async {
    final response = await _api.post(
      '/padel/community/conflicts/preview',
      data: {
        'plan_id': planId,
        'scheduled_date': scheduledDate,
        'scheduled_time': scheduledTime,
        'participant_user_ids': participantUserIds,
      },
    );

    final json = response is Map<String, dynamic>
        ? response
        : Map<String, dynamic>.from(response as Map);
    return CommunityConflictPreviewModel.fromJson(json);
  }

  Future<void> markNotificationRead(
    int notificationId, {
    bool refresh = false,
  }) async {
    await _api
        .post('/padel/community/notifications/$notificationId/read', data: {});
    if (refresh) {
      _ref.invalidate(communityDashboardProvider);
    }
  }
}
