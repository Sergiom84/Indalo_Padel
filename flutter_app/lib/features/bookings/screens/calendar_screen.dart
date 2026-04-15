import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/chronology.dart';
import '../../../shared/widgets/loading_spinner.dart';
import '../../../shared/widgets/padel_badge.dart';
import '../../community/models/community_model.dart';
import '../../community/widgets/match_result_dialog.dart';
import '../models/calendar_booking_model.dart';

PadelBadgeVariant _statusVariant(String status) {
  switch (status) {
    case 'confirmada':
    case 'accepted':
    case 'aceptada':
      return PadelBadgeVariant.success;
    case 'pendiente':
      return PadelBadgeVariant.warning;
    case 'cancelada':
    case 'declined':
    case 'rechazada':
    case 'error':
      return PadelBadgeVariant.danger;
    case 'sincronizada':
      return PadelBadgeVariant.info;
    default:
      return PadelBadgeVariant.neutral;
  }
}

List<CalendarBookingModel> mergeUniqueCalendarBookings({
  required List<CalendarBookingModel> primary,
  required List<CalendarBookingModel> secondary,
}) {
  final unique = <int, CalendarBookingModel>{};

  for (final booking in [...primary, ...secondary]) {
    unique.putIfAbsent(booking.id, () => booking);
  }

  return unique.values.toList();
}

int compareCalendarBookingsChronologically(
  CalendarBookingModel left,
  CalendarBookingModel right,
) {
  final comparison = compareChronology(
    leftDate: left.bookingDate,
    leftTime: left.startTime,
    rightDate: right.bookingDate,
    rightTime: right.startTime,
  );
  if (comparison != 0) {
    return comparison;
  }
  return left.id.compareTo(right.id);
}

class MyBookingsScreen extends ConsumerStatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  ConsumerState<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends ConsumerState<MyBookingsScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final TabController _tabController;
  bool _loading = true;
  String? _error;
  CalendarFeedModel? _feed;
  List<CalendarBookingModel> _communityUpcoming = [];
  List<CalendarBookingModel> _communityHistory = [];
  List<CommunityPlanModel> _communityPlans = [];
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 4, vsync: this);
    _selectedDay = DateTime.now();
    _fetchCalendar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchCalendar();
    }
  }

  Future<void> _fetchCalendar() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    final api = ref.read(apiClientProvider);

    try {
      final data = await api.get('/padel/bookings/my-calendar');
      final feed = CalendarFeedModel.fromJson(
        Map<String, dynamic>.from(data as Map),
      );
      if (!mounted) return;
      setState(() {
        _feed = feed;
        _loading = false;
      });
    } catch (_) {
      try {
        final data = await api.get('/padel/bookings/my');
        final feed = CalendarFeedModel.fromJson(
          Map<String, dynamic>.from(data as Map),
        );
        if (!mounted) return;
        setState(() {
          _feed = feed;
          _loading = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }

    // Cargar convocatorias de comunidad confirmadas
    try {
      final communityData = await api.get('/padel/community');
      if (!mounted) return;
      final allPlans = [
        ..._extractList(communityData, 'plans'),
        ..._extractList(communityData, 'history_plans'),
      ];
      final now = DateTime.now();
      final upcoming = <CalendarBookingModel>[];
      final history = <CalendarBookingModel>[];
      final plansParsed = <CommunityPlanModel>[];
      for (final raw in allPlans) {
        if (raw is! Map) continue;
        final p = Map<String, dynamic>.from(raw);
        try {
          plansParsed.add(CommunityPlanModel.fromJson(p));
        } catch (_) {}
        if (p['reservation_state'] != 'confirmed') continue;
        final dateStr = p['scheduled_date']?.toString() ?? '';
        if (dateStr.isEmpty) continue;
        final date = DateTime.tryParse(dateStr);
        if (date == null) continue;
        final timeStr = p['scheduled_time']?.toString() ?? '';
        final shortTime =
            timeStr.length >= 5 ? timeStr.substring(0, 5) : timeStr;
        final venue = p['venue'] is Map
            ? Map<String, dynamic>.from(p['venue'] as Map)
            : <String, dynamic>{};
        final idRaw = p['id'];
        final planId =
            idRaw is int ? idRaw : int.tryParse(idRaw?.toString() ?? '') ?? 0;
        final participants = (p['participants'] as List? ?? [])
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .map((m) => {
                  'user_id': m['user_id'],
                  'display_name': m['display_name'] ?? m['nombre'] ?? '',
                  'role': m['role'] ?? 'player',
                  'invite_status': 'aceptada',
                  'google_response_status': 'accepted',
                })
            .toList();
        final model = CalendarBookingModel.fromJson({
          'id': 200000 + planId,
          'venue_name': venue['name']?.toString() ?? 'Comunidad',
          'court_name': 'Convocatoria',
          'booking_date': dateStr,
          'start_time': shortTime,
          'duration_minutes': p['duration_minutes'] ?? 90,
          'status': 'confirmada',
          'invite_status': 'aceptada',
          'calendar_sync_status': p['calendar_sync_status'] ?? 'pending',
          'is_managed': p['is_organizer'] == true,
          'participants': participants,
        });
        if (date.isAfter(now.subtract(const Duration(days: 1)))) {
          upcoming.add(model);
        } else {
          history.add(model);
        }
      }
      setState(() {
        _communityUpcoming = upcoming;
        _communityHistory = history;
        _communityPlans = plansParsed;
      });
    } catch (_) {
      // comunidad no crítica, no bloqueamos el calendario
    }
  }

  /// Plans donde el usuario participa aceptado y la hora de fin ya pasó.
  List<CommunityPlanModel> get _finishedAcceptedPlans {
    final now = DateTime.now();
    final result = <CommunityPlanModel>[];
    for (final plan in _communityPlans) {
      final accepted = plan.myResponseState == 'accepted' || plan.isOrganizer;
      if (!accepted) continue;
      final end = _planEndDateTime(plan);
      if (end == null) continue;
      if (end.isBefore(now)) {
        result.add(plan);
      }
    }
    result.sort((a, b) {
      final ea = _planEndDateTime(a) ?? DateTime.now();
      final eb = _planEndDateTime(b) ?? DateTime.now();
      return eb.compareTo(ea);
    });
    return result;
  }

  /// Upcoming filtrado para excluir eventos de hoy (que solo deben verse en Agenda).
  List<CalendarBookingModel> get _upcomingWithoutToday {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    return _allUpcoming.where((b) {
      final dt = chronologyDateTime(b.bookingDate, b.startTime);
      if (dt == null) return true;
      final dayStart = DateTime(dt.year, dt.month, dt.day);
      return dayStart.isAfter(todayStart);
    }).toList();
  }

  static DateTime? _planEndDateTime(CommunityPlanModel plan) {
    if (plan.scheduledDate.isEmpty || plan.scheduledTime.isEmpty) return null;
    try {
      final date = DateTime.parse(plan.scheduledDate);
      final parts = plan.scheduledTime.split(':');
      if (parts.length < 2) return null;
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) return null;
      final start = DateTime(date.year, date.month, date.day, hour, minute);
      return start.add(Duration(minutes: plan.durationMinutes));
    } catch (_) {
      return null;
    }
  }

  static List<dynamic> _extractList(dynamic source, String key) {
    if (source is Map && source[key] is List) {
      return source[key] as List<dynamic>;
    }
    return const [];
  }

  Future<void> _cancelBooking(int bookingId) async {
    final api = ref.read(apiClientProvider);
    try {
      await api.put('/padel/bookings/$bookingId/cancel');
      await _fetchCalendar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  Future<void> _respondBooking(int bookingId, String response) async {
    final api = ref.read(apiClientProvider);
    try {
      await api.put(
        '/padel/bookings/$bookingId/respond',
        data: {'status': response},
      );
      await _fetchCalendar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  void _editBooking(CalendarBookingModel booking) {
    if (booking.courtId == null) return;
    context.push(
      '/booking/${booking.courtId}',
      extra: booking.toBookingFormState(),
    );
  }

  CalendarFeedModel get _feedOrEmpty =>
      _feed ??
      const CalendarFeedModel(
        agendaUpcoming: [],
        agendaHistory: [],
        managedUpcoming: [],
        managedHistory: [],
      );

  /// All upcoming bookings merged and sorted by date and start time.
  List<CalendarBookingModel> get _allUpcoming {
    final all = mergeUniqueCalendarBookings(
      primary: _feedOrEmpty.managedUpcoming,
      secondary: _feedOrEmpty.agendaUpcoming,
    );
    all.addAll(_communityUpcoming);
    all.sort(compareCalendarBookingsChronologically);
    return all;
  }

  List<CalendarBookingModel> get _allHistory {
    final all = mergeUniqueCalendarBookings(
      primary: _feedOrEmpty.managedHistory,
      secondary: _feedOrEmpty.agendaHistory,
    );
    all.addAll(_communityHistory);
    all.sort(compareCalendarBookingsChronologically);
    return all;
  }

  /// Dates that have bookings (for calendar markers).
  Set<DateTime> get _eventDates {
    final dates = <DateTime>{};
    for (final b in _allUpcoming) {
      if (b.bookingDate != null) {
        try {
          final d = DateTime.parse(b.bookingDate!);
          dates.add(DateTime(d.year, d.month, d.day));
        } catch (_) {}
      }
    }
    for (final b in _allHistory) {
      if (b.bookingDate != null) {
        try {
          final d = DateTime.parse(b.bookingDate!);
          dates.add(DateTime(d.year, d.month, d.day));
        } catch (_) {}
      }
    }
    return dates;
  }

  List<CalendarBookingModel> _bookingsForDay(DateTime day) {
    final all = [..._allUpcoming, ..._allHistory];
    final bookings = all.where((b) {
      final bookingDateTime = chronologyDateTime(b.bookingDate, b.startTime);
      if (bookingDateTime == null) return false;
      return bookingDateTime.year == day.year &&
          bookingDateTime.month == day.month &&
          bookingDateTime.day == day.day;
    }).toList();
    bookings.sort(compareCalendarBookingsChronologically);
    return bookings;
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('EEE d MMM yyyy', 'es_ES').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  String _formatTimeRange(CalendarBookingModel booking) {
    final start = booking.startTime ?? '';
    final end =
        booking.endTime ?? _endTimeFromDuration(start, booking.durationMinutes);
    if (start.isEmpty) return '';
    return end.isEmpty ? '$start h' : '$start - $end';
  }

  String _endTimeFromDuration(String startTime, int durationMinutes) {
    final parts = startTime.split(':');
    if (parts.length < 2) return '';
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return '';
    final base = DateTime(2000, 1, 1, hour, minute)
        .add(Duration(minutes: durationMinutes));
    return DateFormat('HH:mm').format(base);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dark,
      appBar: AppBar(
        title: const Text('Calendario'),
        backgroundColor: AppColors.surface,
        actions: [
          IconButton(
            onPressed: _loading ? null : _fetchCalendar,
            icon: const Icon(Icons.refresh),
            tooltip: 'Sincronizar',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.muted,
          tabs: const [
            Tab(text: 'Agenda'),
            Tab(text: 'Próximos'),
            Tab(text: 'Partido'),
            Tab(text: 'Historial'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: LoadingSpinner())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.danger, size: 42),
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: const TextStyle(color: AppColors.danger),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 14),
                      ElevatedButton(
                        onPressed: _fetchCalendar,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _AgendaTab(
                      eventDates: _eventDates,
                      focusedDay: _focusedDay,
                      selectedDay: _selectedDay,
                      onDaySelected: (selected, focused) {
                        setState(() {
                          _selectedDay = selected;
                          _focusedDay = focused;
                        });
                      },
                      onPageChanged: (focused) {
                        setState(() => _focusedDay = focused);
                      },
                      bookingsForDay: _bookingsForDay,
                      onRefresh: _fetchCalendar,
                      formatDate: _formatDate,
                      formatTimeRange: _formatTimeRange,
                      onRespond: _respondBooking,
                      onEdit: _editBooking,
                      onCancel: _cancelBooking,
                    ),
                    _ProximosTab(
                      upcoming: _upcomingWithoutToday,
                      onRefresh: _fetchCalendar,
                      onRespond: _respondBooking,
                      onEdit: _editBooking,
                      onCancel: _cancelBooking,
                      formatDate: _formatDate,
                      formatTimeRange: _formatTimeRange,
                      onNewBooking: () => context.go('/venues'),
                    ),
                    _PartidoTab(
                      plans: _finishedAcceptedPlans,
                      onRefresh: _fetchCalendar,
                      formatDate: _formatDate,
                    ),
                    _HistoryTab(
                      history: _allHistory,
                      onRefresh: _fetchCalendar,
                      formatDate: _formatDate,
                      formatTimeRange: _formatTimeRange,
                    ),
                  ],
                ),
    );
  }
}

// ---------------------------------------------------------------------------
// Agenda tab: Calendar widget + selected day events
// ---------------------------------------------------------------------------
class _AgendaTab extends StatelessWidget {
  final Set<DateTime> eventDates;
  final DateTime focusedDay;
  final DateTime? selectedDay;
  final void Function(DateTime, DateTime) onDaySelected;
  final void Function(DateTime) onPageChanged;
  final List<CalendarBookingModel> Function(DateTime) bookingsForDay;
  final Future<void> Function() onRefresh;
  final Future<void> Function(int, String) onRespond;
  final void Function(CalendarBookingModel) onEdit;
  final Future<void> Function(int) onCancel;
  final String Function(String?) formatDate;
  final String Function(CalendarBookingModel) formatTimeRange;

  const _AgendaTab({
    required this.eventDates,
    required this.focusedDay,
    required this.selectedDay,
    required this.onDaySelected,
    required this.onPageChanged,
    required this.bookingsForDay,
    required this.onRefresh,
    required this.onRespond,
    required this.onEdit,
    required this.onCancel,
    required this.formatDate,
    required this.formatTimeRange,
  });

  @override
  Widget build(BuildContext context) {
    final selectedBookings = selectedDay != null
        ? bookingsForDay(selectedDay!)
        : <CalendarBookingModel>[];

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          // Calendar widget
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: TableCalendar(
              firstDay: DateTime.now().subtract(const Duration(days: 365)),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: focusedDay,
              selectedDayPredicate: (day) => isSameDay(selectedDay, day),
              onDaySelected: onDaySelected,
              onPageChanged: onPageChanged,
              locale: 'es_ES',
              startingDayOfWeek: StartingDayOfWeek.monday,
              calendarStyle: CalendarStyle(
                defaultTextStyle: const TextStyle(color: Colors.white),
                weekendTextStyle: const TextStyle(color: AppColors.muted),
                outsideTextStyle:
                    TextStyle(color: AppColors.muted.withValues(alpha: 0.4)),
                todayDecoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                todayTextStyle: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
                selectedDecoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                selectedTextStyle: const TextStyle(
                  color: AppColors.dark,
                  fontWeight: FontWeight.w700,
                ),
                markerDecoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                markersMaxCount: 1,
                markerSize: 6,
                markerMargin: const EdgeInsets.symmetric(horizontal: 0.5),
              ),
              headerStyle: const HeaderStyle(
                titleCentered: true,
                formatButtonVisible: false,
                titleTextStyle: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
                leftChevronIcon:
                    Icon(Icons.chevron_left, color: AppColors.primary),
                rightChevronIcon:
                    Icon(Icons.chevron_right, color: AppColors.primary),
              ),
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle: TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                weekendStyle: TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              eventLoader: (day) {
                final normalized = DateTime(day.year, day.month, day.day);
                return eventDates.contains(normalized) ? [true] : [];
              },
            ),
          ),

          // Events for selected day
          if (selectedDay != null) ...[
            const SizedBox(height: 16),
            Text(
              'Eventos del ${formatDate(selectedDay!.toIso8601String().substring(0, 10))}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            if (selectedBookings.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Sin eventos este día.',
                  style: TextStyle(color: AppColors.muted),
                ),
              )
            else
              ...selectedBookings.map(
                (b) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _CompactBookingCard(
                    booking: b,
                    formatDate: formatDate,
                    formatTimeRange: formatTimeRange,
                    onRespond: onRespond,
                    onEdit: onEdit,
                    onCancel: onCancel,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Próximos tab
// ---------------------------------------------------------------------------
class _ProximosTab extends StatelessWidget {
  final List<CalendarBookingModel> upcoming;
  final Future<void> Function() onRefresh;
  final Future<void> Function(int, String) onRespond;
  final void Function(CalendarBookingModel) onEdit;
  final Future<void> Function(int) onCancel;
  final String Function(String?) formatDate;
  final String Function(CalendarBookingModel) formatTimeRange;
  final VoidCallback onNewBooking;

  const _ProximosTab({
    required this.upcoming,
    required this.onRefresh,
    required this.onRespond,
    required this.onEdit,
    required this.onCancel,
    required this.formatDate,
    required this.formatTimeRange,
    required this.onNewBooking,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Próximos eventos',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                onPressed: onNewBooking,
                child: const Text('Nueva reserva'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (upcoming.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(Icons.calendar_month_outlined,
                      color: AppColors.muted, size: 34),
                  SizedBox(height: 10),
                  Text(
                    'No tienes eventos próximos.',
                    style: TextStyle(color: AppColors.muted),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ...upcoming.map(
              (b) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _CompactBookingCard(
                  booking: b,
                  formatDate: formatDate,
                  formatTimeRange: formatTimeRange,
                  onRespond: onRespond,
                  onEdit: onEdit,
                  onCancel: onCancel,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Partido tab: convocatorias finalizadas pendientes de registrar resultado
// ---------------------------------------------------------------------------
class _PartidoTab extends StatelessWidget {
  final List<CommunityPlanModel> plans;
  final Future<void> Function() onRefresh;
  final String Function(String?) formatDate;

  const _PartidoTab({
    required this.plans,
    required this.onRefresh,
    required this.formatDate,
  });

  String _timeRange(CommunityPlanModel plan) {
    final start = plan.scheduledTime.length >= 5
        ? plan.scheduledTime.substring(0, 5)
        : plan.scheduledTime;
    final parts = plan.scheduledTime.split(':');
    if (parts.length < 2) return start;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return start;
    final end =
        DateTime(2000, 1, 1, h, m).add(Duration(minutes: plan.durationMinutes));
    final endStr =
        '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
    return '$start - $endStr';
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: onRefresh,
      child: plans.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 80),
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.sports_tennis,
                          color: AppColors.muted, size: 34),
                      SizedBox(height: 10),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'No hay partidos recientes pendientes de resultado.',
                          style: TextStyle(color: AppColors.muted),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              itemCount: plans.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final plan = plans[i];
                final venueName = plan.venue?.name ?? 'Centro deportivo';
                return InkWell(
                  onTap: () async {
                    await showMatchResultDialog(context, plan: plan);
                    await onRefresh();
                  },
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.emoji_events,
                              color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                venueName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${formatDate(plan.scheduledDate)} · ${_timeRange(plan)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: AppColors.muted),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// History tab
// ---------------------------------------------------------------------------
class _HistoryTab extends StatelessWidget {
  final List<CalendarBookingModel> history;
  final Future<void> Function() onRefresh;
  final String Function(String?) formatDate;
  final String Function(CalendarBookingModel) formatTimeRange;

  const _HistoryTab({
    required this.history,
    required this.onRefresh,
    required this.formatDate,
    required this.formatTimeRange,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: onRefresh,
      child: history.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 80),
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.history, color: AppColors.muted, size: 34),
                      SizedBox(height: 10),
                      Text(
                        'No hay elementos en el historial.',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              itemCount: history.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _CompactBookingCard(
                booking: history[i],
                formatDate: formatDate,
                formatTimeRange: formatTimeRange,
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Compact booking card (used in both tabs)
// ---------------------------------------------------------------------------
class _CompactBookingCard extends StatefulWidget {
  final CalendarBookingModel booking;
  final String Function(String?) formatDate;
  final String Function(CalendarBookingModel) formatTimeRange;
  final Future<void> Function(int, String)? onRespond;
  final void Function(CalendarBookingModel)? onEdit;
  final Future<void> Function(int)? onCancel;

  const _CompactBookingCard({
    required this.booking,
    required this.formatDate,
    required this.formatTimeRange,
    this.onRespond,
    this.onEdit,
    this.onCancel,
  });

  @override
  State<_CompactBookingCard> createState() => _CompactBookingCardState();
}

class _CompactBookingCardState extends State<_CompactBookingCard> {
  bool _busy = false;

  /// Devuelve 'en_juego', 'finalizado' o null según la hora actual vs inicio/fin.
  String? _liveStateLabel() {
    final booking = widget.booking;
    if (booking.bookingDate == null || booking.startTime == null) return null;
    try {
      final date = DateTime.parse(booking.bookingDate!);
      final parts = booking.startTime!.split(':');
      if (parts.length < 2) return null;
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h == null || m == null) return null;
      final start = DateTime(date.year, date.month, date.day, h, m);
      final end = start.add(Duration(minutes: booking.durationMinutes));
      final now = DateTime.now();
      if (now.isBefore(start)) return null;
      if (now.isBefore(end)) return 'en_juego';
      return 'finalizado';
    } catch (_) {
      return null;
    }
  }

  Widget _buildActionButton({
    required String label,
    required VoidCallback? onPressed,
    Color? foregroundColor,
  }) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: foregroundColor,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.schedule,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.venueName ?? 'Reserva',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.formatDate(booking.bookingDate)} · ${widget.formatTimeRange(booking)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  PadelBadge(
                    label: booking.status,
                    variant: _statusVariant(booking.status),
                  ),
                  if (_liveStateLabel() != null) ...[
                    const SizedBox(height: 4),
                    PadelBadge(
                      label: _liveStateLabel() == 'en_juego'
                          ? 'En juego'
                          : 'Finalizado',
                      variant: _liveStateLabel() == 'en_juego'
                          ? PadelBadgeVariant.success
                          : PadelBadgeVariant.neutral,
                    ),
                  ],
                ],
              ),
            ],
          ),
          if (booking.participants.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: booking.participants
                  .map((p) => PadelBadge(
                        label: p.displayName,
                        variant: p.inviteStatus == 'aceptada'
                            ? PadelBadgeVariant.success
                            : p.inviteStatus == 'rechazada'
                                ? PadelBadgeVariant.danger
                                : PadelBadgeVariant.neutral,
                      ))
                  .toList(),
            ),
          ],
          if (widget.onRespond != null ||
              widget.onEdit != null ||
              widget.onCancel != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final actions = <Widget>[
                    if (widget.onRespond != null &&
                        booking.inviteStatus != 'cancelada' &&
                        booking.status != 'cancelada') ...[
                      _buildActionButton(
                        label: booking.inviteStatus == 'aceptada'
                            ? 'Aceptada'
                            : 'Aceptar',
                        onPressed: _busy
                            ? null
                            : () async {
                                setState(() => _busy = true);
                                await widget.onRespond!(booking.id, 'accepted');
                                if (mounted) setState(() => _busy = false);
                              },
                      ),
                      _buildActionButton(
                        label: booking.inviteStatus == 'rechazada'
                            ? 'Rechazada'
                            : 'Rechazar',
                        onPressed: _busy
                            ? null
                            : () async {
                                setState(() => _busy = true);
                                await widget.onRespond!(booking.id, 'declined');
                                if (mounted) setState(() => _busy = false);
                              },
                      ),
                    ],
                    if (widget.onEdit != null)
                      _buildActionButton(
                        label: 'Editar',
                        onPressed: () => widget.onEdit!(booking),
                      ),
                    if (widget.onCancel != null &&
                        booking.status != 'cancelada')
                      _buildActionButton(
                        label: _busy ? 'Cancelando...' : 'Cancelar',
                        onPressed: _busy
                            ? null
                            : () async {
                                setState(() => _busy = true);
                                await widget.onCancel!(booking.id);
                                if (mounted) setState(() => _busy = false);
                              },
                        foregroundColor: AppColors.danger,
                      ),
                  ];

                  final priceWidget = booking.price != null
                      ? Text(
                          '${booking.price!.toStringAsFixed(0)}€',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      : null;

                  if (constraints.maxWidth >= 420) {
                    return Row(
                      children: [
                        if (priceWidget != null) priceWidget,
                        const Spacer(),
                        ...actions.map(
                          (action) => Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: action,
                          ),
                        ),
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (priceWidget != null) priceWidget,
                      if (priceWidget != null && actions.isNotEmpty)
                        const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          alignment: WrapAlignment.end,
                          children: actions,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
