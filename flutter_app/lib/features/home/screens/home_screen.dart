import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/platform/platform_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/chronology.dart';
import '../../../shared/widgets/loading_spinner.dart';
import '../../../shared/widgets/padel_badge.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chat/providers/chat_provider.dart';
import '../../players/models/player_model.dart';
import '../../players/providers/player_provider.dart';
import '../../profile/providers/current_profile_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _loadingVenues = true;
  bool _loadingBookings = true;
  bool _loadingMatches = true;
  List<dynamic> _venues = [];
  Map<String, dynamic> _bookings = {'upcoming': [], 'past': []};
  List<dynamic> _matches = [];
  List<Map<String, dynamic>> _confirmedCommunityPlans = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final api = ref.read(apiClientProvider);
    if (mounted) {
      setState(() {
        _loadingVenues = true;
        _loadingBookings = true;
        _loadingMatches = true;
      });
    }

    try {
      final result = await api.get('/padel/dashboard');
      final json = _asMap(result);

      if (!mounted) {
        return;
      }

      final bookings = _asMap(json?['bookings']) ??
          const {
            'upcoming': [],
            'past': [],
          };
      final community = _asMap(json?['community']);

      setState(() {
        _venues = _asList(json?['venues']);
        _bookings = bookings;
        _matches = _asList(json?['matches']);
        _confirmedCommunityPlans = community == null
            ? const []
            : _buildCommunityBookingsFromDashboard(community);
        _loadingVenues = false;
        _loadingBookings = false;
        _loadingMatches = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingVenues = false;
        _loadingBookings = false;
        _loadingMatches = false;
      });
    }
  }

  List<dynamic> _asList(dynamic value) {
    if (value is List) {
      return value;
    }
    return [];
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return null;
  }

  List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is! List) {
      return const [];
    }

    return value
        .map(_asMap)
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _buildCommunityBookingsFromDashboard(
    dynamic payload,
  ) {
    final json = _asMap(payload);
    if (json == null) {
      return const [];
    }

    final plans = [
      ..._asMapList(json['active_plans']),
      ..._asMapList(json['history_plans']),
    ];

    return _buildCommunityBookingsFromPlans(plans);
  }

  List<Map<String, dynamic>> _buildCommunityBookingsFromPlans(
    List<Map<String, dynamic>> plans,
  ) {
    return plans.where(_isUpcomingConfirmedCommunityPlan).map((plan) {
      final venue = _asMap(plan['venue']);
      final startTime = plan['scheduled_time']?.toString() ?? '';
      return <String, dynamic>{
        '_type': 'community',
        'id': plan['id'],
        'venue_name': venue?['name']?.toString() ?? 'Convocatoria',
        'booking_date': plan['scheduled_date']?.toString() ?? '',
        'start_time':
            startTime.length >= 5 ? startTime.substring(0, 5) : startTime,
        'status': 'confirmada',
      };
    }).toList(growable: false);
  }

  bool _isUpcomingConfirmedCommunityPlan(Map<String, dynamic> plan) {
    if (plan['reservation_state']?.toString() != 'confirmed') {
      return false;
    }

    final hasBackendFlags =
        plan.containsKey('is_upcoming') || plan.containsKey('is_finished');
    if (hasBackendFlags) {
      return _asBool(plan['is_upcoming']) && !_asBool(plan['is_finished']);
    }

    return !_hasPlanEnded(plan);
  }

  bool _hasPlanEnded(Map<String, dynamic> plan) {
    final scheduledDate = plan['scheduled_date']?.toString();
    final scheduledTime = plan['scheduled_time']?.toString();
    if (scheduledDate == null ||
        scheduledDate.isEmpty ||
        scheduledTime == null ||
        scheduledTime.isEmpty) {
      return false;
    }

    final date = DateTime.tryParse(scheduledDate);
    if (date == null) {
      return false;
    }

    final timeParts = scheduledTime.split(':');
    if (timeParts.length < 2) {
      return false;
    }

    final hour = int.tryParse(timeParts[0]);
    final minute = int.tryParse(timeParts[1]);
    final second = timeParts.length > 2 ? int.tryParse(timeParts[2]) ?? 0 : 0;
    if (hour == null || minute == null) {
      return false;
    }

    final durationMinutes = _asInt(plan['duration_minutes']) ?? 90;
    final start = DateTime(
      date.year,
      date.month,
      date.day,
      hour,
      minute,
      second,
    );

    return !start
        .add(Duration(minutes: durationMinutes))
        .isAfter(DateTime.now());
  }

  bool _asBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') {
        return true;
      }
      if (normalized == 'false' || normalized == '0') {
        return false;
      }
    }

    return false;
  }

  int? _asInt(dynamic value) {
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

  List<dynamic> get _openMatches {
    final matches = _matches
        .whereType<Map>()
        .map((match) => Map<String, dynamic>.from(match))
        .where((match) =>
            match['status'] == 'buscando' || match['status'] == 'abierto')
        .toList();

    matches.sort((left, right) {
      final comparison = compareChronology(
        leftDate: left['match_date']?.toString(),
        leftTime: left['start_time']?.toString() ?? left['hora']?.toString(),
        rightDate: right['match_date']?.toString(),
        rightTime: right['start_time']?.toString() ?? right['hora']?.toString(),
      );
      if (comparison != 0) {
        return comparison;
      }
      final leftId = (left['id'] as num?)?.toInt() ?? 0;
      final rightId = (right['id'] as num?)?.toInt() ?? 0;
      return leftId.compareTo(rightId);
    });

    return matches.take(3).toList();
  }

  List<dynamic> get _upcomingBookings {
    final bookings = _asList(_bookings['upcoming'])
        .whereType<Map>()
        .map((booking) => Map<String, dynamic>.from(booking))
        .toList();

    final all = [...bookings, ..._confirmedCommunityPlans];

    all.sort((left, right) {
      final comparison = compareChronology(
        leftDate: left['booking_date']?.toString() ?? left['fecha']?.toString(),
        leftTime:
            left['start_time']?.toString() ?? left['hora_inicio']?.toString(),
        rightDate:
            right['booking_date']?.toString() ?? right['fecha']?.toString(),
        rightTime:
            right['start_time']?.toString() ?? right['hora_inicio']?.toString(),
      );
      if (comparison != 0) {
        return comparison;
      }
      final leftId = (left['id'] as num?)?.toInt() ?? 0;
      final rightId = (right['id'] as num?)?.toInt() ?? 0;
      return leftId.compareTo(rightId);
    });

    return all.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final networkAsync = ref.watch(networkProvider);
    final incomingRequests =
        networkAsync.valueOrNull?.incomingRequests ?? const <PlayerModel>[];
    final chatUnreadCount = ref.watch(chatUnreadCountProvider);
    final greeting = (profile?['display_name'] ??
            profile?['nombre'] ??
            user?.nombre ??
            'Jugador')
        .toString();
    final avatarUrl = profile?['avatar_url']?.toString();
    final loadingSummary =
        _loadingVenues || _loadingBookings || _loadingMatches;
    final upcomingBookings = _upcomingBookings;
    final openMatches = _openMatches;

    return Scaffold(
      backgroundColor: AppColors.dark,
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: _fetchData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _headlineDate(),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Hola, $greeting',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                _NotificationBellButton(
                  pendingCount: incomingRequests.length,
                  loading: networkAsync.isLoading && incomingRequests.isEmpty,
                  onTap: () => _openNotificationsDialog(
                    incomingRequests,
                    loading: networkAsync.isLoading && incomingRequests.isEmpty,
                  ),
                ),
                const SizedBox(width: 10),
                _ChatBubbleButton(
                  unreadCount: chatUnreadCount,
                  onTap: () {
                    appLightImpact();
                    context.push('/players/chat');
                  },
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () {
                    appLightImpact();
                    context.push('/profile');
                  },
                  child: UserAvatar(
                    displayName: greeting,
                    avatarUrl: avatarUrl,
                    size: 56,
                    fontSize: 20,
                    backgroundColor: AppColors.surface,
                    borderColor: AppColors.border,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sesión de hoy',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Todo lo importante en una vista',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricTile(
                          label: 'Clubes',
                          value: _loadingVenues ? '—' : '${_venues.length}',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricTile(
                          label: 'Reservas',
                          value: _loadingBookings
                              ? '—'
                              : '${upcomingBookings.length}',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricTile(
                          label: 'Partidos',
                          value:
                              _loadingMatches ? '—' : '${openMatches.length}',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _HomeSection(
              title: 'Próximas reservas',
              actionLabel: 'Ver calendario',
              onAction: () => context.go('/calendar'),
              child: _loadingBookings && upcomingBookings.isEmpty
                  ? const LoadingSpinner()
                  : upcomingBookings.isEmpty
                      ? const _EmptyState(
                          icon: Icons.calendar_today_outlined,
                          message: 'No tienes reservas próximas.',
                        )
                      : Column(
                          children: upcomingBookings
                              .map((booking) =>
                                  _BookingPreviewCard(booking: booking))
                              .toList(),
                        ),
            ),
            const SizedBox(height: 18),
            const _HomeSection(
              title: 'Clubes destacados',
              actionLabel: 'Próximamente',
              child: _EmptyState(
                icon: Icons.sports_tennis_outlined,
                message: 'Clubes disponible próximamente.',
              ),
            ),
            if (loadingSummary)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Actualizando contenido...',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openNotificationsDialog(List<PlayerModel> initialRequests,
      {required bool loading}) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final requests = List<PlayerModel>.from(initialRequests);
        final busyIds = <int>{};
        final navigator = Navigator.of(dialogContext);

        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> handleAction(PlayerModel player, String action) async {
              if (busyIds.contains(player.userId)) {
                return;
              }

              setDialogState(() => busyIds.add(player.userId));

              try {
                final message = await _respondToNetworkRequest(player, action);
                notifyPlayerNetworkChanged(ref);
                if (!mounted) {
                  return;
                }

                setDialogState(() {
                  busyIds.remove(player.userId);
                  requests.removeWhere(
                    (request) => request.userId == player.userId,
                  );
                });

                _showMessage(
                  message ??
                      (action == 'accepted'
                          ? '${player.displayName} ya forma parte de tu red.'
                          : 'Has rechazado la solicitud de ${player.displayName}.'),
                );

                if (requests.isEmpty && navigator.canPop()) {
                  navigator.pop();
                }
              } catch (error) {
                if (!mounted) {
                  return;
                }
                setDialogState(() => busyIds.remove(player.userId));
                _showMessage(error.toString(), isError: true);
              }
            }

            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: AppColors.border),
              ),
              titlePadding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
              contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              title: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Solicitudes de red',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => navigator.pop(),
                    icon: const Icon(Icons.close, color: AppColors.muted),
                  ),
                ],
              ),
              content: SizedBox(
                width: 420,
                child: loading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            LoadingSpinner(),
                            SizedBox(height: 12),
                            Text(
                              'Cargando solicitudes...',
                              style: TextStyle(color: AppColors.muted),
                            ),
                          ],
                        ),
                      )
                    : requests.isEmpty
                        ? const _EmptyState(
                            icon: Icons.notifications_none_outlined,
                            message: 'No tienes solicitudes pendientes.',
                          )
                        : SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: requests
                                  .map(
                                    (player) => Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: _NetworkRequestDialogCard(
                                        player: player,
                                        busy: busyIds.contains(player.userId),
                                        onAccept: () =>
                                            handleAction(player, 'accepted'),
                                        onReject: () =>
                                            handleAction(player, 'rejected'),
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                          ),
              ),
            );
          },
        );
      },
    );
  }

  Future<String?> _respondToNetworkRequest(
    PlayerModel player,
    String action,
  ) async {
    final api = ref.read(apiClientProvider);
    final data = await api.post(
      '/padel/players/${player.userId}/network/respond',
      data: {'action': action},
    );
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return null;
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : AppColors.surface,
      ),
    );
  }

  String _headlineDate() {
    final now = DateTime.now();
    const weekDays = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    const months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    return '${weekDays[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}';
  }
}

class _ChatBubbleButton extends StatelessWidget {
  final int unreadCount;
  final VoidCallback onTap;

  const _ChatBubbleButton({
    required this.unreadCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadCount > 0;

    return Tooltip(
      message: 'Mensajes',
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(18),
              child: Ink(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: hasUnread
                      ? AppColors.primary.withValues(alpha: 0.16)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: hasUnread
                        ? AppColors.primary.withValues(alpha: 0.55)
                        : AppColors.border,
                  ),
                ),
                child: Icon(
                  hasUnread ? Icons.forum : Icons.forum_outlined,
                  color: hasUnread ? AppColors.primary : Colors.white,
                ),
              ),
            ),
          ),
          if (hasUnread)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.dark, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  unreadCount > 9 ? '9+' : '$unreadCount',
                  style: const TextStyle(
                    color: AppColors.dark,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NotificationBellButton extends StatelessWidget {
  final int pendingCount;
  final bool loading;
  final VoidCallback onTap;

  const _NotificationBellButton({
    required this.pendingCount,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Ink(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: pendingCount > 0
                      ? AppColors.primary.withValues(alpha: 0.45)
                      : AppColors.border,
                ),
              ),
              child: loading
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: AppColors.primary,
                      ),
                    )
                  : Icon(
                      pendingCount > 0
                          ? Icons.notifications_active_outlined
                          : Icons.notifications_none_outlined,
                      color:
                          pendingCount > 0 ? AppColors.primary : Colors.white,
                    ),
            ),
          ),
        ),
        if (!loading && pendingCount > 0)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.dark, width: 2),
              ),
              alignment: Alignment.center,
              child: Text(
                pendingCount > 9 ? '9+' : '$pendingCount',
                style: const TextStyle(
                  color: AppColors.dark,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;

  const _MetricTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _HomeSection extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback? onAction;
  final Widget child;

  const _HomeSection({
    required this.title,
    required this.actionLabel,
    this.onAction,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                onPressed: onAction,
                child: Text(actionLabel),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _BookingPreviewCard extends StatelessWidget {
  final dynamic booking;

  const _BookingPreviewCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => context.go('/calendar'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.schedule, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    booking['venue_name']?.toString() ?? 'Reserva',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${booking['booking_date'] ?? booking['fecha'] ?? ''} · ${booking['start_time'] ?? booking['hora_inicio'] ?? ''}',
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            PadelBadge(
              label: booking['status']?.toString() ?? 'pendiente',
              variant: _badgeForBooking(booking['status']?.toString() ?? ''),
            ),
          ],
        ),
      ),
    );
  }

  PadelBadgeVariant _badgeForBooking(String status) {
    switch (status) {
      case 'confirmada':
        return PadelBadgeVariant.success;
      case 'cancelada':
        return PadelBadgeVariant.danger;
      case 'pendiente':
        return PadelBadgeVariant.warning;
      default:
        return PadelBadgeVariant.neutral;
    }
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(icon, color: AppColors.muted, size: 30),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(color: AppColors.muted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _NetworkRequestDialogCard extends StatelessWidget {
  final PlayerModel player;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _NetworkRequestDialogCard({
    required this.player,
    required this.busy,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(
                displayName: player.displayName,
                avatarUrl: player.avatarUrl,
                size: 44,
                fontSize: 16,
                backgroundColor: AppColors.surface,
                borderColor: AppColors.border,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: player.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const TextSpan(
                        text: ' ha solicitado unirse a tu red.',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : onReject,
                  child: const Text('Rechazar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: busy ? null : onAccept,
                  child: busy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Aceptar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
