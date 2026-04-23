import '../../community/models/community_model.dart';

enum AppAlertScope { communityPlanner, communityInvitations, players }

class AppAlertItem {
  final String uniqueKey;
  final AppAlertScope scope;
  final String title;
  final String body;

  const AppAlertItem({
    required this.uniqueKey,
    required this.scope,
    required this.title,
    required this.body,
  });
}

class AppAlertsState {
  final bool loading;
  final List<AppAlertItem> communityPlannerAlerts;
  final List<AppAlertItem> communityInvitationAlerts;
  final List<AppAlertItem> playerInvitationAlerts;
  final List<CommunityPlanModel> pendingResultPlans;

  const AppAlertsState({
    this.loading = false,
    this.communityPlannerAlerts = const [],
    this.communityInvitationAlerts = const [],
    this.playerInvitationAlerts = const [],
    this.pendingResultPlans = const [],
  });

  AppAlertsState copyWith({
    bool? loading,
    List<AppAlertItem>? communityPlannerAlerts,
    List<AppAlertItem>? communityInvitationAlerts,
    List<AppAlertItem>? playerInvitationAlerts,
    List<CommunityPlanModel>? pendingResultPlans,
  }) {
    return AppAlertsState(
      loading: loading ?? this.loading,
      communityPlannerAlerts:
          communityPlannerAlerts ?? this.communityPlannerAlerts,
      communityInvitationAlerts:
          communityInvitationAlerts ?? this.communityInvitationAlerts,
      playerInvitationAlerts:
          playerInvitationAlerts ?? this.playerInvitationAlerts,
      pendingResultPlans: pendingResultPlans ?? this.pendingResultPlans,
    );
  }

  bool get hasResultPendingBadge => pendingResultPlans.isNotEmpty;

  bool get hasCommunityBadge =>
      communityPlannerAlerts.isNotEmpty ||
      communityInvitationAlerts.isNotEmpty ||
      pendingResultPlans.isNotEmpty;

  bool get hasCommunityPlannerBadge => communityPlannerAlerts.isNotEmpty;

  bool get hasCommunityInvitationsBadge => communityInvitationAlerts.isNotEmpty;

  bool get hasPlayersBadge => playerInvitationAlerts.isNotEmpty;

  List<AppAlertItem> get allAlerts => [
        ...communityPlannerAlerts,
        ...communityInvitationAlerts,
        ...playerInvitationAlerts,
      ];
}
