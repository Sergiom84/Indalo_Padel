import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../notifications/providers/app_alerts_provider.dart';
import '../models/community_model.dart';
import '../models/match_result_model.dart';

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

final communityClubOptionsProvider = FutureProvider<List<CommunityVenueModel>>((
  ref,
) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.get('/padel/venues');
  final list = data is Map<String, dynamic>
      ? data['venues']
      : (data as Map)['venues'];
  if (list is! List) {
    return const [];
  }

  return list
      .whereType<Map>()
      .map(
        (item) => CommunityVenueModel.fromJson(
          Map<String, dynamic>.from(item),
        ),
      )
      .toList(growable: false);
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
    String modality = 'amistoso',
    int? capacity,
    int? clubId,
    String? postPadelPlan,
    String? notes,
    bool forceSend = false,
  }) async {
    await _api.post('/padel/community', data: {
      'scheduled_date': scheduledDate,
      'scheduled_time': scheduledTime,
      'participant_user_ids': participantUserIds,
      'modality': modality,
      if (capacity != null) 'capacity': capacity,
      if (clubId != null) 'club_id': clubId,
      if (postPadelPlan != null) 'post_padel_plan': postPadelPlan,
      if (notes != null) 'notes': notes,
      'force_send': forceSend,
    });
    _ref.invalidate(communityDashboardProvider);
    _ref.read(appAlertsProvider.notifier).refresh(notifyOnNew: false);
  }

  Future<void> updatePlan({
    required int planId,
    required String scheduledDate,
    required String scheduledTime,
    required List<int> participantUserIds,
    String? modality,
    int? capacity,
    int? clubId,
    String? postPadelPlan,
    String? notes,
    String? updatedAt,
    bool forceSend = false,
  }) async {
    await _api.put('/padel/community/$planId', data: {
      'scheduled_date': scheduledDate,
      'scheduled_time': scheduledTime,
      'participant_user_ids': participantUserIds,
      if (modality != null) 'modality': modality,
      if (capacity != null) 'capacity': capacity,
      if (clubId != null) 'club_id': clubId,
      if (postPadelPlan != null) 'post_padel_plan': postPadelPlan,
      if (notes != null) 'notes': notes,
      'updated_at': updatedAt,
      'force_send': forceSend,
    });
    _ref.invalidate(communityDashboardProvider);
    _ref.read(appAlertsProvider.notifier).refresh(notifyOnNew: false);
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
    _ref.read(appAlertsProvider.notifier).refresh(notifyOnNew: false);
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
    _ref.read(appAlertsProvider.notifier).refresh(notifyOnNew: false);
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
    _ref.read(appAlertsProvider.notifier).refresh(notifyOnNew: false);
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
    _ref.read(appAlertsProvider.notifier).refresh(notifyOnNew: false);
  }

  Future<CommunityConflictPreviewModel> previewConflicts({
    int? planId,
    required String scheduledDate,
    required String scheduledTime,
    required List<int> participantUserIds,
    String? modality,
    int? capacity,
  }) async {
    final response = await _api.post(
      '/padel/community/conflicts/preview',
      data: {
        'plan_id': planId,
        'scheduled_date': scheduledDate,
        'scheduled_time': scheduledTime,
        'participant_user_ids': participantUserIds,
        if (modality != null) 'modality': modality,
        if (capacity != null) 'capacity': capacity,
      },
    );

    final json = response is Map<String, dynamic>
        ? response
        : Map<String, dynamic>.from(response as Map);
    return CommunityConflictPreviewModel.fromJson(json);
  }

  Future<MatchResultModel> fetchMatchResult(int planId) async {
    final response = await _api.get('/padel/community/$planId/result');
    final json = response is Map<String, dynamic>
        ? response
        : Map<String, dynamic>.from(response as Map);
    return MatchResultModel.fromPayload(planId: planId, payload: json);
  }

  Future<MatchResultModel> submitMatchResult({
    required int planId,
    int? partnerUserId,
    required int winnerTeam,
    required List<SetScore> sets,
  }) async {
    final response = await _api.post(
      '/padel/community/$planId/result/submit',
      data: {
        'partner_user_id': partnerUserId,
        'winner_team': winnerTeam,
        'sets': sets.map((s) => s.toJson()).toList(),
      },
    );
    final json = response is Map<String, dynamic>
        ? response
        : Map<String, dynamic>.from(response as Map);
    _ref.invalidate(communityDashboardProvider);
    _ref.read(appAlertsProvider.notifier).refresh(notifyOnNew: false);
    return MatchResultModel.fromPayload(planId: planId, payload: json);
  }

  Future<void> markNotificationRead(
    int notificationId, {
    bool refresh = false,
  }) async {
    await _api
        .post('/padel/community/notifications/$notificationId/read', data: {});
    _ref.read(appAlertsProvider.notifier).refresh(notifyOnNew: false);
    if (refresh) {
      _ref.invalidate(communityDashboardProvider);
    }
  }
}
