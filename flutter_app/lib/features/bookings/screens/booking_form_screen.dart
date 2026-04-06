import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/api_client.dart';
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
    final p = widget.bookingState['price'];
    if (p == null) return null;
    return (p as num).toDouble();
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
          ? (data['booking'] as Map<String, dynamic>? ?? Map<String, dynamic>.from(data as Map))
          : <String, dynamic>{};
      final booking = BookingModel.fromJson(bookingRaw);

      if (mounted) {
        context.push('/booking/${booking.id}/confirmation', extra: {
          'id': booking.id,
          'venue_name': _venueName,
          'court_name': _courtName,
          'date': _date,
          'start_time': _startTime,
          'price': _price,
          'status': booking.status,
        });
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.bookingState.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.dark,
        appBar: AppBar(backgroundColor: AppColors.surface),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('No se encontraron datos de reserva.', style: TextStyle(color: AppColors.muted)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: () => context.go('/'), child: const Text('Volver al inicio')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.dark,
      appBar: AppBar(
        title: const Text('Confirmar reserva'),
        backgroundColor: AppColors.surface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Resumen de la reserva',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  _InfoRow(
                    icon: Icons.location_on_outlined,
                    title: _venueName,
                    subtitle: _courtName,
                  ),
                  const Divider(color: AppColors.border, height: 24),
                  _InfoRow(
                    icon: Icons.calendar_today,
                    title: _formatDate(_date),
                  ),
                  const Divider(color: AppColors.border, height: 24),
                  _InfoRow(
                    icon: Icons.access_time,
                    title: '${_startTime}h',
                  ),
                  const Divider(color: AppColors.border, height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Precio', style: TextStyle(color: AppColors.muted)),
                      Text(
                        _price != null ? '${_price!.toStringAsFixed(0)}€' : 'N/D',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Notes
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Notas (opcional)',
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notesCtrl,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Añade cualquier nota o comentario...',
                      hintStyle: TextStyle(color: AppColors.muted),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Error
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                ),
                child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
              ),
              const SizedBox(height: 12),
            ],

            // Submit
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.dark),
                      )
                    : const Text('Confirmar reserva', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const _InfoRow({required this.icon, required this.title, this.subtitle});

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
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              if (subtitle != null)
                Text(subtitle!, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}
