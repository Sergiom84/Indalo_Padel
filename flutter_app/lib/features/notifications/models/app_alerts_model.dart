import '../../community/models/community_model.dart';

enum AppAlertScope {
  bookings,
  communityPlanner,
  communityInvitations,
  players,
  profileRatings,
}

class AppAlertItem {
  final String uniqueKey;
  final AppAlertScope scope;
  final String kind;
  final String title;
  final String body;

  const AppAlertItem({
    required this.uniqueKey,
    required this.scope,
    this.kind = '',
    required this.title,
    required this.body,
  });

  factory AppAlertItem.fromJson(
    Map<String, dynamic> json, {
    required AppAlertScope scope,
  }) {
    return AppAlertItem(
      uniqueKey: (json['unique_key'] ?? '').toString(),
      scope: scope,
      kind: (json['kind'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
    );
  }
}

class AppAlertsState {
  final bool loading;
  final List<AppAlertItem> bookingInvitationAlerts;
  final List<AppAlertItem> communityPlannerAlerts;
  final List<AppAlertItem> communityInvitationAlerts;
  final List<AppAlertItem> playerInvitationAlerts;
  final List<AppAlertItem> profileRatingAlerts;
  final List<CommunityPlanModel> pendingResultPlans;

  const AppAlertsState({
    this.loading = false,
    this.bookingInvitationAlerts = const [],
    this.communityPlannerAlerts = const [],
    this.communityInvitationAlerts = const [],
    this.playerInvitationAlerts = const [],
    this.profileRatingAlerts = const [],
    this.pendingResultPlans = const [],
  });

  factory AppAlertsState.fromJson(Map<String, dynamic> json) {
    List<AppAlertItem> parseAlerts(dynamic value, AppAlertScope scope) {
      if (value is! List) {
        return const [];
      }

      return value
          .whereType<Map>()
          .map(
            (item) => AppAlertItem.fromJson(
              Map<String, dynamic>.from(item),
              scope: scope,
            ),
          )
          .where((alert) => alert.uniqueKey.isNotEmpty)
          .toList(growable: false);
    }

    List<CommunityPlanModel> parsePlans(dynamic value) {
      if (value is! List) {
        return const [];
      }

      return value
          .whereType<Map>()
          .map(
            (item) =>
                CommunityPlanModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false);
    }

    return AppAlertsState(
      bookingInvitationAlerts: parseAlerts(
        json['booking_invitation_alerts'],
        AppAlertScope.bookings,
      ),
      communityPlannerAlerts: parseAlerts(
        json['community_planner_alerts'],
        AppAlertScope.communityPlanner,
      ),
      communityInvitationAlerts: parseAlerts(
        json['community_invitation_alerts'],
        AppAlertScope.communityInvitations,
      ),
      playerInvitationAlerts: parseAlerts(
        json['player_invitation_alerts'],
        AppAlertScope.players,
      ),
      profileRatingAlerts: parseAlerts(
        json['rating_alerts'],
        AppAlertScope.profileRatings,
      ),
      pendingResultPlans: parsePlans(json['pending_result_plans']),
    );
  }

  AppAlertsState copyWith({
    bool? loading,
    List<AppAlertItem>? bookingInvitationAlerts,
    List<AppAlertItem>? communityPlannerAlerts,
    List<AppAlertItem>? communityInvitationAlerts,
    List<AppAlertItem>? playerInvitationAlerts,
    List<AppAlertItem>? profileRatingAlerts,
    List<CommunityPlanModel>? pendingResultPlans,
  }) {
    return AppAlertsState(
      loading: loading ?? this.loading,
      bookingInvitationAlerts:
          bookingInvitationAlerts ?? this.bookingInvitationAlerts,
      communityPlannerAlerts:
          communityPlannerAlerts ?? this.communityPlannerAlerts,
      communityInvitationAlerts:
          communityInvitationAlerts ?? this.communityInvitationAlerts,
      playerInvitationAlerts:
          playerInvitationAlerts ?? this.playerInvitationAlerts,
      profileRatingAlerts: profileRatingAlerts ?? this.profileRatingAlerts,
      pendingResultPlans: pendingResultPlans ?? this.pendingResultPlans,
    );
  }

  bool get hasResultPendingBadge => pendingResultPlans.isNotEmpty;

  bool get hasCalendarBadge => bookingInvitationAlerts.isNotEmpty;

  bool get hasCommunityBadge =>
      communityPlannerAlerts.isNotEmpty ||
      communityInvitationAlerts.isNotEmpty ||
      pendingResultPlans.isNotEmpty;

  bool get hasCommunityPlannerBadge => communityPlannerAlerts.isNotEmpty;

  bool get hasCommunityInvitationsBadge => communityInvitationAlerts.isNotEmpty;

  bool get hasPlayersBadge => playerInvitationAlerts.isNotEmpty;
  bool get hasProfileBadge => profileRatingAlerts.isNotEmpty;

  bool get hasHomeNotifications =>
      allAlerts.isNotEmpty || pendingResultPlans.isNotEmpty;

  List<AppAlertItem> get allAlerts => [
        ...bookingInvitationAlerts,
        ...communityPlannerAlerts,
        ...communityInvitationAlerts,
        ...playerInvitationAlerts,
        ...profileRatingAlerts,
      ];

  Set<String> get visibleAlertKeys => {
        ...allAlerts.map((alert) => alert.uniqueKey),
        ...pendingResultPlans.map(pendingResultAlertKey),
      };

  AppAlertsState withoutAlertKeys(Set<String> keys) {
    if (keys.isEmpty) {
      return this;
    }

    List<AppAlertItem> filterAlerts(List<AppAlertItem> alerts) => alerts
        .where((alert) => !keys.contains(alert.uniqueKey))
        .toList(growable: false);

    return copyWith(
      bookingInvitationAlerts: filterAlerts(bookingInvitationAlerts),
      communityPlannerAlerts: filterAlerts(communityPlannerAlerts),
      communityInvitationAlerts: filterAlerts(communityInvitationAlerts),
      playerInvitationAlerts: filterAlerts(playerInvitationAlerts),
      profileRatingAlerts: filterAlerts(profileRatingAlerts),
      pendingResultPlans: pendingResultPlans
          .where((plan) => !keys.contains(pendingResultAlertKey(plan)))
          .toList(growable: false),
    );
  }
}

String pendingResultAlertKey(CommunityPlanModel plan) =>
    'pending-result:${plan.id}';
