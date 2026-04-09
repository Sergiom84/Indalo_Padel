import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/loading_spinner.dart';
import '../../../shared/widgets/padel_badge.dart';
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
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 2, vsync: this);
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

  /// All upcoming bookings merged and sorted by date.
  List<CalendarBookingModel> get _allUpcoming {
    final all = [
      ..._feedOrEmpty.agendaUpcoming,
      ..._feedOrEmpty.managedUpcoming,
    ];
    all.sort((a, b) => (a.bookingDate ?? '').compareTo(b.bookingDate ?? ''));
    return all;
  }

  List<CalendarBookingModel> get _allHistory {
    final all = [
      ..._feedOrEmpty.agendaHistory,
      ..._feedOrEmpty.managedHistory,
    ];
    all.sort((a, b) => (b.bookingDate ?? '').compareTo(a.bookingDate ?? ''));
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
    return all.where((b) {
      if (b.bookingDate == null) return false;
      try {
        final d = DateTime.parse(b.bookingDate!);
        return d.year == day.year && d.month == day.month && d.day == day.day;
      } catch (_) {
        return false;
      }
    }).toList();
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
                      upcoming: _allUpcoming,
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
                      onRespond: _respondBooking,
                      onEdit: _editBooking,
                      onCancel: _cancelBooking,
                      formatDate: _formatDate,
                      formatTimeRange: _formatTimeRange,
                      onNewBooking: () => context.go('/venues'),
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
// Agenda tab: Calendar widget + next 3 events + selected day events
// ---------------------------------------------------------------------------
class _AgendaTab extends StatelessWidget {
  final List<CalendarBookingModel> upcoming;
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
  final VoidCallback onNewBooking;

  const _AgendaTab({
    required this.upcoming,
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
    required this.onNewBooking,
  });

  @override
  Widget build(BuildContext context) {
    final selectedBookings =
        selectedDay != null ? bookingsForDay(selectedDay!) : <CalendarBookingModel>[];
    final next3 = upcoming.take(3).toList();

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
          if (selectedDay != null && selectedBookings.isNotEmpty) ...[
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

          // Next 3 upcoming
          const SizedBox(height: 20),
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
          if (next3.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
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
            ...next3.map(
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.formatDate(booking.bookingDate)} · ${widget.formatTimeRange(booking)}',
                      style:
                          const TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              PadelBadge(
                label: booking.status,
                variant: _statusVariant(booking.status),
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
          if (widget.onRespond != null || widget.onEdit != null || widget.onCancel != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  if (booking.price != null)
                    Text(
                      '${booking.price!.toStringAsFixed(0)}€',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  const Spacer(),
                  if (widget.onRespond != null &&
                      booking.inviteStatus != 'cancelada' &&
                      booking.status != 'cancelada') ...[
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () async {
                              setState(() => _busy = true);
                              await widget.onRespond!(booking.id, 'accepted');
                              if (mounted) setState(() => _busy = false);
                            },
                      child: Text(
                          booking.inviteStatus == 'aceptada'
                              ? 'Aceptada'
                              : 'Aceptar'),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () async {
                              setState(() => _busy = true);
                              await widget.onRespond!(booking.id, 'declined');
                              if (mounted) setState(() => _busy = false);
                            },
                      child: Text(
                          booking.inviteStatus == 'rechazada'
                              ? 'Rechazada'
                              : 'Rechazar'),
                    ),
                  ],
                  if (widget.onEdit != null)
                    TextButton(
                      onPressed: () => widget.onEdit!(booking),
                      child: const Text('Editar'),
                    ),
                  if (widget.onCancel != null &&
                      booking.status != 'cancelada')
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () async {
                              setState(() => _busy = true);
                              await widget.onCancel!(booking.id);
                              if (mounted) setState(() => _busy = false);
                            },
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.danger),
                      child:
                          Text(_busy ? 'Cancelando...' : 'Cancelar'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
