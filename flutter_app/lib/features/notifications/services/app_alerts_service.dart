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
  static const _resultSubmittedPrefix = 'padel_result_submitted_';

  final ApiClient _api = ApiClient();

  Future<AppAlertsState> refresh({bool notifyOnNew = true}) async {
    Object? networkError;
    Object? communityError;

    PlayerNetworkSnapshot network = const PlayerNetworkSnapshot();
    CommunityDashboardModel community = const CommunityDashboardModel();

    try {
      network = await _fetchNetwork();
    } catch (error) {
      networkError = error;
    }

    try {
      community = await _fetchCommunity();
    } catch (error) {
      communityError = error;
    }

    if (networkError != null && communityError != null) {
      throw networkError;
    }

    final submittedIds = await _loadSubmittedPlanIds();
    final state = _buildState(
      network: network,
      community: community,
      submittedResultPlanIds: submittedIds,
    );
    if (notifyOnNew) {
      await _notifyNewAlerts(state);
    }
    return state;
  }

  Future<void> markResultSubmitted(int planId) async {
    final key = await _resultStorageKey();
    if (key == null) return;
    final existing = await _loadSubmittedPlanIds();
    await SecureStorage.writeValue(
      key,
      jsonEncode([...existing, planId]),
    );
  }

  Future<void> clearStoredKeys() async {
    final key = await _storageKey();
    if (key == null) {
      return;
    }
    await SecureStorage.deleteValue(key);
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

  AppAlertsState _buildState({
    required PlayerNetworkSnapshot network,
    required CommunityDashboardModel community,
    Set<int> submittedResultPlanIds = const {},
  }) {
    final planById = <int, CommunityPlanModel>{
      for (final plan in [...community.activePlans, ...community.historyPlans])
        plan.id: plan,
    };

    final communityInvitationAlerts = <AppAlertItem>[
      ...community.activePlans
          .where(_planNeedsAttention)
          .map(_buildCommunityInvitationAlert),
      ...community.notifications
          .where((notification) =>
              !(planById[notification.planId]?.isOrganizer ?? true))
          .map(_buildCommunityNotificationAlert),
    ];

    final communityPlannerAlerts = community.notifications
        .where((notification) =>
            planById[notification.planId]?.isOrganizer ?? true)
        .map(_buildCommunityNotificationAlert)
        .toList(growable: false);

    final playerInvitationAlerts = network.incomingRequests
        .map(_buildPlayerInvitationAlert)
        .toList(growable: false);

    final pendingResultPlans = community.historyPlans.where((plan) {
      if (!plan.reservationConfirmed) return false;
      if (submittedResultPlanIds.contains(plan.id)) return false;
      final participant = plan.currentUserParticipant;
      return participant != null && participant.responseState == 'accepted';
    }).toList(growable: false);

    return AppAlertsState(
      communityPlannerAlerts: communityPlannerAlerts,
      communityInvitationAlerts: communityInvitationAlerts,
      playerInvitationAlerts: playerInvitationAlerts,
      pendingResultPlans: pendingResultPlans,
    );
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

    return AppAlertItem(
      uniqueKey:
          'community-plan:${plan.id}:${plan.updatedAt ?? plan.scheduledDate}:${plan.myResponseState ?? 'pending'}',
      scope: AppAlertScope.communityInvitations,
      title: isRescheduled
          ? 'Nuevo horario en tu convocatoria'
          : 'Te han invitado a un partido',
      body: isRescheduled
          ? '${plan.creatorName} propone jugar el $date a las $time.'
          : '${plan.creatorName} te ha invitado a jugar el $date a las $time.',
    );
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

  Future<String?> _resultStorageKey() async {
    try {
      final rawUser = await SecureStorage.getUser();
      if (rawUser == null || rawUser.trim().isEmpty) return null;
      final decoded = jsonDecode(rawUser);
      if (decoded is! Map || decoded['id'] == null) return null;
      return '$_resultSubmittedPrefix${decoded['id']}';
    } catch (_) {
      return null;
    }
  }

  Future<Set<int>> _loadSubmittedPlanIds() async {
    final key = await _resultStorageKey();
    if (key == null) return const {};
    try {
      final raw = await SecureStorage.readValue(key);
      if (raw == null || raw.trim().isEmpty) return const {};
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const {};
      return decoded.whereType<int>().toSet();
    } catch (_) {
      return const {};
    }
  }
}
