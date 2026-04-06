import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/api/api_client.dart';
import '../../../core/platform/platform_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../models/booking_model.dart';

class BookingFormScreen extends ConsumerStatefulWidget {
  final String courtId;
  final Map<String, dynamic> bookingState;

  const BookingFormScreen({
    super.key,
    required this.courtId,
    required this.bookingState,
  });

  @override
  ConsumerState<BookingFormScreen> createState() => _BookingFormScreenState();
}

class _BookingFormScreenState extends ConsumerState<BookingFormScreen> {
  final _notesCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  String get _date => widget.bookingState['date'] as String? ?? '';
  String get _startTime => widget.bookingState['start_time'] as String? ?? '';
  String get _venueName => widget.bookingState['venue_name'] as String? ?? '';
  String get _courtName => widget.bookingState['court_name'] as String? ?? '';
  double? get _price {
    final value = widget.bookingState['price'];
    if (value == null) {
      return null;
    }
    return (value as num).toDouble();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat("EEEE d 'de' MMMM, yyyy", 'es_ES').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  Future<void> _submit() async {
    if (_date.isEmpty || _startTime.isEmpty) {
      setState(() => _error = 'Faltan datos de la reserva');
      return;
    }
    await appMediumImpact();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.post('/padel/bookings', data: {
        'court_id': int.tryParse(widget.courtId) ?? widget.courtId,
        'booking_date': _date,
        'start_time': _startTime,
        if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
      });

      final bookingRaw = data is Map
          ? (data['booking'] as Map<String, dynamic>? ?? Map<String, dynamic>.from(data))
          : <String, dynamic>{};
      final booking = BookingModel.fromJson(bookingRaw);

      if (!mounted) {
        return;
      }

      context.push(
        '/booking/${booking.id}/confirmation',
        extra: {
          'id': booking.id,
          'venue_name': _venueName,
          'court_name': _courtName,
          'date': _date,
          'start_time': _startTime,
          'price': _price,
          'status': booking.status,
        },
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.bookingState.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.dark,
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'No se encontraron datos de reserva.',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go('/'),
                child: const Text('Volver al inicio'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.dark,
      appBar: AppBar(
        title: const Text('Confirmar reserva'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Resumen',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                _SummaryRow(
                  icon: isCupertinoPlatform
                      ? CupertinoIcons.location_solid
                      : Icons.location_on_outlined,
                  title: _venueName,
                  subtitle: _courtName,
                ),
                const Divider(height: 26),
                _SummaryRow(
                  icon: isCupertinoPlatform
                      ? CupertinoIcons.calendar
                      : Icons.calendar_today_outlined,
                  title: _formatDate(_date),
                ),
                const Divider(height: 26),
                _SummaryRow(
                  icon: isCupertinoPlatform
                      ? CupertinoIcons.time
                      : Icons.schedule_outlined,
                  title: '${_startTime}h',
                  subtitle: 'Duración estimada: 90 min',
                ),
                const Divider(height: 26),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Precio',
                      style: TextStyle(color: AppColors.muted),
                    ),
                    Text(
                      _price != null ? '${_price!.toStringAsFixed(0)}€' : 'N/D',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Notas para el club',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesCtrl,
                  maxLines: 4,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Añade información para la reserva si la necesitas.',
                  ),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
              ),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.dark,
                  ),
                )
              : const Text('Confirmar reserva'),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const _SummaryRow({
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    subtitle!,
                    style: const TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
