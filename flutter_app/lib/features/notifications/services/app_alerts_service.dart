import 'dart:convert';

import '../../../core/api/api_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../community/models/community_model.dart';
import '../../players/models/player_model.dart';
import '../models/app_alerts_model.dart';
import 'local_notification_service.dart';

class AppAlertsService {
  AppAlertsService._();

  static final AppAlertsService instance = AppAlertsService._();

  static const _storagePrefix = 'padel_notified_alerts_';
  static const _communityModalityLabels = {
    'amistoso': 'Amistoso',
    'competitivo': 'Competitivo',
    'americana': 'Americana',
  };

  final ApiClient _api = ApiClient();

  Future<AppAlertsState> refresh({bool notifyOnNew = true}) async {
    Object? networkError;
    Object? communityError;

    PlayerNetworkSnapshot network = const PlayerNetworkSnapshot();
    CommunityDashboardModel community = const CommunityDashboardModel();
    _CommunityBootstrapSnapshot? bootstrap;

    await Future.wait<void>([
      () async {
        try {
          network = await _fetchNetwork();
        } catch (error) {
          networkError = error;
        }
      }(),
      () async {
        try {
          community = await _fetchCommunity();
        } catch (error) {
          communityError = error;
        }
      }(),
      () async {
        try {
          bootstrap = await _fetchCommunityBootstrap();
        } catch (_) {}
      }(),
    ]);

    if (networkError != null && communityError != null) {
      throw networkError!;
    }

    final state = _buildState(
      network: network,
      community: community,
      bootstrap: bootstrap,
    );
    if (notifyOnNew) {
      await _notifyNewAlerts(state);
    }
    return state;
  }

  Future<void> clearStoredKeys() async {
    final key = await _storageKey();
    if (key != null) {
      await SecureStorage.deleteValue(key);
    }
  }

  Future<PlayerNetworkSnapshot> _fetchNetwork() async {
    final data = await _api.get('/padel/players/network');
    return PlayerNetworkSnapshot.fromJson(
      data is Map<String, dynamic>
          ? data
          : Map<String, dynamic>.from(data as Map),
    );
  }

  Future<CommunityDashboardModel> _fetchCommunity() async {
    final data = await _api.get('/padel/community');
    return CommunityDashboardModel.fromJson(
      data is Map<String, dynamic>
          ? data
          : Map<String, dynamic>.from(data as Map),
    );
  }

  Future<_CommunityBootstrapSnapshot> _fetchCommunityBootstrap() async {
    final data = await _api.get('/padel/community/bootstrap');
    final json = data is Map<String, dynamic>
        ? data
        : Map<String, dynamic>.from(data as Map);
    return _CommunityBootstrapSnapshot.fromJson(json);
  }

  AppAlertsState _buildState({
    required PlayerNetworkSnapshot network,
    required CommunityDashboardModel community,
    required _CommunityBootstrapSnapshot? bootstrap,
  }) {
    final allPlans = <int, CommunityPlanModel>{
      for (final plan in [...community.activePlans, ...community.historyPlans])
        plan.id: plan,
    };

    final communityInvitationAlerts = <AppAlertItem>[
      ...community.activePlans
          .where(_planNeedsAttention)
          .map(_buildCommunityInvitationAlert),
      ...community.notifications
          .where((notification) =>
              !(allPlans[notification.planId]?.isOrganizer ?? true))
          .map(_buildCommunityNotificationAlert),
    ];

    final communityPlannerAlerts = community.notifications
        .where((notification) =>
            allPlans[notification.planId]?.isOrganizer ?? true)
        .map(_buildCommunityNotificationAlert)
        .toList(growable: false);

    final playerInvitationAlerts = network.incomingRequests
        .map(_buildPlayerInvitationAlert)
        .toList(growable: false);

    final pendingResultPlanIdSet = bootstrap?.hasPendingResultPlanIds == true
        ? bootstrap!.pendingResultPlanIds.toSet()
        : null;

    final pendingResultPlans = (pendingResultPlanIdSet != null
            ? pendingResultPlanIdSet
                .map((planId) => allPlans[planId])
                .whereType<CommunityPlanModel>()
            : _fallbackPendingResultPlans(allPlans.values))
        .toList(growable: false)
      ..sort((left, right) {
        final leftEnd =
            left.endDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        final rightEnd =
            right.endDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        return rightEnd.compareTo(leftEnd);
      });

    return AppAlertsState(
      communityPlannerAlerts: communityPlannerAlerts,
      communityInvitationAlerts: communityInvitationAlerts,
      playerInvitationAlerts: playerInvitationAlerts,
      pendingResultPlans: pendingResultPlans,
    );
  }

  Iterable<CommunityPlanModel> _fallbackPendingResultPlans(
    Iterable<CommunityPlanModel> plans,
  ) {
    final now = DateTime.now();

    return plans.where((plan) {
      if (!plan.needsResultNotification) return false;
      final participant = plan.currentUserParticipant;
      if (participant == null || participant.responseState != 'accepted') {
        return false;
      }
      return plan.canCaptureResult(reference: now);
    });
  }

  bool _planNeedsAttention(CommunityPlanModel plan) {
    if (plan.isOrganizer || plan.isTerminal) {
      return false;
    }

    final response = (plan.myResponseState ?? 'pending').toLowerCase();
    return response == 'pending' || response == 'doubt';
  }

  AppAlertItem _buildPlayerInvitationAlert(PlayerModel player) {
    final requestedAt = player.connectionRequestedAt ?? '';
    return AppAlertItem(
      uniqueKey:
          'player-request:${player.connectionId ?? player.userId}:$requestedAt',
      scope: AppAlertScope.players,
      title: 'Nueva invitación en Jugadores',
      body: '${player.displayName} quiere jugar contigo.',
    );
  }

  AppAlertItem _buildCommunityInvitationAlert(CommunityPlanModel plan) {
    final date = _formatDate(plan.scheduledDate);
    final time = _formatTime(plan.scheduledTime);
    final isRescheduled = plan.inviteState == 'reschedule_pending';
    final body = _buildCommunityInvitationBody(
      plan: plan,
      date: date,
      time: time,
      isRescheduled: isRescheduled,
    );

    return AppAlertItem(
      uniqueKey:
          'community-plan:${plan.id}:${plan.updatedAt ?? plan.scheduledDate}:${plan.myResponseState ?? 'pending'}',
      scope: AppAlertScope.communityInvitations,
      title: isRescheduled
          ? 'Nuevo horario en tu convocatoria'
          : 'Te han invitado a un partido',
      body: body,
    );
  }

  String _buildCommunityInvitationBody({
    required CommunityPlanModel plan,
    required String date,
    required String time,
    required bool isRescheduled,
  }) {
    final details = <String>[];
    final venueName = _trimmedOrNull(plan.venue?.name);
    final modality = _communityModalityLabels[plan.modality] ?? plan.modality;
    final postPadelPlan = _trimmedOrNull(plan.postPadelPlan);
    final notes = _trimmedOrNull(plan.notes);

    if (venueName != null) {
      details.add(venueName);
    }
    details.add('Modalidad: $modality');
    if (postPadelPlan != null) {
      details.add('Post pádel: $postPadelPlan');
    }
    if (notes != null) {
      details.add('Observaciones: $notes');
    }

    final summary = isRescheduled
        ? '${plan.creatorName} propone jugar el $date a las $time'
        : '${plan.creatorName} te ha invitado a jugar el $date a las $time';
    if (details.isEmpty) {
      return '$summary.';
    }
    return '$summary. ${details.join(' · ')}.';
  }

  AppAlertItem _buildCommunityNotificationAlert(
    CommunityNotificationModel notification,
  ) {
    final scope = notification.actionType == 'review_plan'
        ? AppAlertScope.communityPlanner
        : AppAlertScope.communityInvitations;

    return AppAlertItem(
      uniqueKey: 'community-notification:${notification.id}',
      scope: scope,
      title: notification.title,
      body: notification.message,
    );
  }

  String _formatDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return raw;
    }
    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    return '$day/$month';
  }

  String _formatTime(String raw) {
    return raw.length >= 5 ? raw.substring(0, 5) : raw;
  }

  String? _trimmedOrNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _notifyNewAlerts(AppAlertsState state) async {
    final currentKeys =
        state.allAlerts.map((alert) => alert.uniqueKey).toList();
    final previousKeys = await _loadStoredKeys();
    final newAlerts = state.allAlerts
        .where((alert) => !previousKeys.contains(alert.uniqueKey))
        .toList(growable: false);

    final localAlerts = newAlerts
        .where((alert) => alert.scope == AppAlertScope.players)
        .toList(growable: false);

    if (localAlerts.isNotEmpty) {
      await LocalNotificationService.instance.showAlerts(localAlerts);
    }

    await _saveStoredKeys(currentKeys);
  }

  Future<List<String>> _loadStoredKeys() async {
    final key = await _storageKey();
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

  Future<void> _saveStoredKeys(List<String> keys) async {
    final key = await _storageKey();
    if (key == null) {
      return;
    }

    final trimmed = keys.take(60).toList(growable: false);
    await SecureStorage.writeValue(key, jsonEncode(trimmed));
  }

  Future<String?> _storageKey() async {
    try {
      final rawUser = await SecureStorage.getUser();
      if (rawUser == null || rawUser.trim().isEmpty) {
        return null;
      }
      final decoded = jsonDecode(rawUser);
      if (decoded is! Map || decoded['id'] == null) {
        return null;
      }
      return '$_storagePrefix${decoded['id']}';
    } catch (_) {
      return null;
    }
  }
}

class _CommunityBootstrapSnapshot {
  final bool hasPendingResultPlanIds;
  final List<int> pendingResultPlanIds;

  const _CommunityBootstrapSnapshot({
    this.hasPendingResultPlanIds = false,
    this.pendingResultPlanIds = const [],
  });

  factory _CommunityBootstrapSnapshot.fromJson(Map<String, dynamic> json) {
    final rawPlanIds = json['pending_result_plan_ids'];
    final pendingResultPlanIds = rawPlanIds is List
        ? rawPlanIds
            .map(_asNullableInt)
            .whereType<int>()
            .toList(growable: false)
        : const <int>[];

    return _CommunityBootstrapSnapshot(
      hasPendingResultPlanIds: json.containsKey('pending_result_plan_ids'),
      pendingResultPlanIds: pendingResultPlanIds,
    );
  }
}

int? _asNullableInt(dynamic value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  if (value is String) {
    return int.tryParse(value);
  }

  return null;
}
