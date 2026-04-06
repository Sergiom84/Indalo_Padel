import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/widgets/loading_spinner.dart';
import '../../../shared/widgets/padel_badge.dart';
import '../models/booking_model.dart';

PadelBadgeVariant _statusVariant(String status) {
  switch (status) {
    case 'confirmada':
      return PadelBadgeVariant.success;
    case 'pendiente':
      return PadelBadgeVariant.warning;
    case 'cancelada':
      return PadelBadgeVariant.danger;
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
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _loading = true;
  String? _error;
  List<BookingModel> _upcoming = [];
  List<BookingModel> _past = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchBookings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchBookings() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.get('/padel/bookings/my');
      if (mounted) {
        final upcomingRaw = (data['upcoming'] as List<dynamic>?) ?? [];
        final pastRaw = (data['past'] as List<dynamic>?) ?? [];
        setState(() {
          _upcoming = upcomingRaw
              .map((b) => BookingModel.fromJson(b as Map<String, dynamic>))
              .toList();
          _past = pastRaw
              .map((b) => BookingModel.fromJson(b as Map<String, dynamic>))
              .toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _confirmBooking(int bookingId) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.put('/padel/bookings/$bookingId/confirm');
      await _fetchBookings();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _cancelBooking(int bookingId) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.put('/padel/bookings/$bookingId/cancel');
      await _fetchBookings();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: AppColors.danger),
        );
      }
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dark,
      appBar: AppBar(
        title: const Text('Mis reservas'),
        backgroundColor: AppColors.surface,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.muted,
          tabs: const [
            Tab(text: 'Próximas'),
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
                      Text(_error!, style: const TextStyle(color: AppColors.danger)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _fetchBookings, child: const Text('Reintentar')),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _BookingList(
                      bookings: _upcoming,
                      isUpcoming: true,
                      formatDate: _formatDate,
                      onConfirm: _confirmBooking,
                      onCancel: _cancelBooking,
                    ),
                    _BookingList(
                      bookings: _past,
                      isUpcoming: false,
                      formatDate: _formatDate,
                      onConfirm: _confirmBooking,
                      onCancel: _cancelBooking,
                    ),
                  ],
                ),
    );
  }
}

class _BookingList extends StatelessWidget {
  final List<BookingModel> bookings;
  final bool isUpcoming;
  final String Function(String?) formatDate;
  final Future<void> Function(int) onConfirm;
  final Future<void> Function(int) onCancel;

  const _BookingList({
    required this.bookings,
    required this.isUpcoming,
    required this.formatDate,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_today, color: AppColors.border, size: 48),
            const SizedBox(height: 12),
            Text(
              isUpcoming ? 'No tienes reservas próximas.' : 'No tienes reservas anteriores.',
              style: const TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: () async {},
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: bookings.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final booking = bookings[index];
          return _BookingCard(
            booking: booking,
            isUpcoming: isUpcoming,
            formatDate: formatDate,
            onConfirm: onConfirm,
            onCancel: onCancel,
          );
        },
      ),
    );
  }
}

class _BookingCard extends StatefulWidget {
  final BookingModel booking;
  final bool isUpcoming;
  final String Function(String?) formatDate;
  final Future<void> Function(int) onConfirm;
  final Future<void> Function(int) onCancel;

  const _BookingCard({
    required this.booking,
    required this.isUpcoming,
    required this.formatDate,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<_BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends State<_BookingCard> {
  bool _confirming = false;
  bool _cancelling = false;

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_outlined, color: AppColors.primary, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.venueName ?? 'Sede',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    if (booking.courtName != null)
                      Text(booking.courtName!, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                  ],
                ),
              ),
              PadelBadge(label: booking.status, variant: _statusVariant(booking.status)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.calendar_today, color: AppColors.muted, size: 14),
              const SizedBox(width: 6),
              Text(
                widget.formatDate(booking.date),
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.access_time, color: AppColors.muted, size: 14),
              const SizedBox(width: 6),
              Text(
                '${booking.startTime ?? ''}h',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                booking.price != null ? '${booking.price!.toStringAsFixed(0)}€' : '',
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 16),
              ),
              if (widget.isUpcoming && booking.status != 'cancelada')
                Row(
                  children: [
                    if (booking.status == 'pendiente')
                      TextButton(
                        onPressed: _confirming
                            ? null
                            : () async {
                                setState(() => _confirming = true);
                                await widget.onConfirm(booking.id);
                                if (mounted) setState(() => _confirming = false);
                              },
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        ),
                        child: Text(_confirming ? 'Confirmando...' : 'Confirmar',
                            style: const TextStyle(fontSize: 12)),
                      ),
                    TextButton(
                      onPressed: _cancelling
                          ? null
                          : () async {
                              setState(() => _cancelling = true);
                              await widget.onCancel(booking.id);
                              if (mounted) setState(() => _cancelling = false);
                            },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      ),
                      child: Text(_cancelling ? 'Cancelando...' : 'Cancelar',
                          style: const TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
