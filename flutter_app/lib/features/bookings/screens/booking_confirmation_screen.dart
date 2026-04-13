import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/padel_badge.dart';

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

class BookingConfirmationScreen extends StatelessWidget {
  final Map<String, dynamic> bookingData;

  const BookingConfirmationScreen({super.key, required this.bookingData});

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat("EEEE d 'de' MMMM, yyyy", 'es_ES').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  double? _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.replaceAll(',', '.'));
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (bookingData.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.dark,
        appBar: AppBar(backgroundColor: AppColors.surface),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('No se encontraron datos de confirmación.',
                  style: TextStyle(color: AppColors.muted)),
              const SizedBox(height: 16),
              ElevatedButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Volver al inicio')),
            ],
          ),
        ),
      );
    }

    final venueName = bookingData['venue_name'] as String? ?? '';
    final courtName = bookingData['court_name'] as String? ?? '';
    final date = bookingData['date'] as String? ?? '';
    final startTime = bookingData['start_time'] as String? ?? '';
    final durationMinutes = _asInt(bookingData['duration_minutes']);
    final price = _asDouble(bookingData['price']);
    final status = bookingData['status'] as String? ?? 'confirmada';
    final notes = bookingData['notes'] as String? ?? '';

    return Scaffold(
      backgroundColor: AppColors.dark,
      appBar: AppBar(
        title: const Text('Reserva confirmada'),
        backgroundColor: AppColors.surface,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 24),
            // Success icon
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline,
                  color: AppColors.success, size: 40),
            ),
            const SizedBox(height: 20),
            const Text(
              '¡Reserva confirmada!',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 24),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tu pista ha sido reservada correctamente.',
              style: TextStyle(color: AppColors.muted, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Booking details
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _DetailRow(
                      icon: Icons.location_on_outlined,
                      title: venueName,
                      subtitle: courtName),
                  const Divider(color: AppColors.border, height: 24),
                  _DetailRow(
                      icon: Icons.calendar_today, title: _formatDate(date)),
                  const Divider(color: AppColors.border, height: 24),
                  _DetailRow(
                    icon: Icons.access_time,
                    title: durationMinutes != null
                        ? '$startTime h · $durationMinutes min'
                        : '$startTime h',
                  ),
                  const Divider(color: AppColors.border, height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Precio',
                          style: TextStyle(color: AppColors.muted)),
                      Text(
                        price != null ? '${price.toStringAsFixed(0)}€' : 'N/D',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w900,
                            fontSize: 20),
                      ),
                    ],
                  ),
                  const Divider(color: AppColors.border, height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Estado',
                          style: TextStyle(color: AppColors.muted)),
                      PadelBadge(
                          label: status, variant: _statusVariant(status)),
                    ],
                  ),
                  if (notes.trim().isNotEmpty) ...[
                    const Divider(color: AppColors.border, height: 24),
                    _DetailRow(
                      icon: Icons.notes_outlined,
                      title: 'Observaciones',
                      subtitle: notes,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Actions
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.go('/calendar'),
                child: const Text('Ver calendario',
                    style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.go('/'),
                child: const Text('Volver al inicio'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const _DetailRow({required this.icon, required this.title, this.subtitle});

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
              Text(title,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
              if (subtitle != null)
                Text(subtitle!,
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}
