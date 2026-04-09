import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/platform/platform_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/padel_badge.dart';
import '../../players/models/player_model.dart';
import '../models/booking_model.dart';
import '../widgets/player_invite_picker.dart';

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
  late int _durationMinutes;
  late List<PlayerModel> _selectedPlayers;
  bool _loading = false;
  String? _error;

  String get _date => widget.bookingState['date'] as String? ?? '';
  String get _startTime => widget.bookingState['start_time'] as String? ?? '';
  String get _venueName => widget.bookingState['venue_name'] as String? ?? '';
  String get _courtName => widget.bookingState['court_name'] as String? ?? '';
  int? get _bookingId {
    final value =
        widget.bookingState['booking_id'] ?? widget.bookingState['id'];
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  double? get _price {
    final value = widget.bookingState['price'];
    if (value == null) {
      return null;
    }
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.replaceAll(',', '.'));
    }
    return null;
  }

  bool get _isEditing => _bookingId != null;

  @override
  void initState() {
    super.initState();
    _durationMinutes = _extractDurationMinutes(widget.bookingState);
    _selectedPlayers = _extractPlayers(widget.bookingState);
    _notesCtrl.text = (widget.bookingState['notes'] as String?) ?? '';
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  int _extractDurationMinutes(Map<String, dynamic> state) {
    final duration = state['duration_minutes'] ?? state['duration'];
    if (duration is int) {
      return duration;
    }
    if (duration is num) {
      return duration.round();
    }
    if (duration is String) {
      return int.tryParse(duration) ?? 90;
    }
    return 90;
  }

  List<PlayerModel> _extractPlayers(Map<String, dynamic> state) {
    final rawPlayers =
        (state['players'] ?? state['participants'] ?? []) as List<dynamic>;
    return rawPlayers
        .whereType<Map>()
        .map(
            (player) => PlayerModel.fromJson(Map<String, dynamic>.from(player)))
        .toList();
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat("EEEE d 'de' MMMM, yyyy", 'es_ES').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  String _formatTimeRange() {
    if (_startTime.isEmpty) {
      return '';
    }
    final parts = _startTime.split(':');
    if (parts.length < 2) {
      return _startTime;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return _startTime;
    }
    final start = DateTime(2000, 1, 1, hour, minute);
    final end = start.add(Duration(minutes: _durationMinutes));
    return '${DateFormat('HH:mm').format(start)} - ${DateFormat('HH:mm').format(end)}';
  }

  Future<void> _pickPlayers() async {
    final result = await showPlayerInvitePicker(
      context: context,
      selectedPlayers: _selectedPlayers,
    );
    if (result != null && mounted) {
      setState(() => _selectedPlayers = result);
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
      final payload = <String, dynamic>{
        'court_id': int.tryParse(widget.courtId) ?? widget.courtId,
        'booking_date': _date,
        'start_time': _startTime,
        'duration_minutes': _durationMinutes,
        'notes': _notesCtrl.text.trim(),
        'player_user_ids':
            _selectedPlayers.map((player) => player.userId).toList(),
      };

      final response = _isEditing
          ? await api.put('/padel/bookings/$_bookingId', data: payload)
          : await api.post('/padel/bookings', data: payload);

      final responseMap = response is Map
          ? Map<String, dynamic>.from(response)
          : <String, dynamic>{};
      final bookingRaw = responseMap['booking'] is Map
          ? Map<String, dynamic>.from(responseMap['booking'] as Map)
          : responseMap;
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
          'duration_minutes': _durationMinutes,
          'price': _price,
          'status': booking.status,
          'notes': _notesCtrl.text.trim(),
          'players': _selectedPlayers
              .map(
                (player) => {
                  'user_id': player.userId,
                  'display_name': player.displayName,
                  'email': player.email,
                },
              )
              .toList(),
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
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

    final priceText = _price != null ? '${_price!.toStringAsFixed(0)}€' : 'N/D';

    return Scaffold(
      backgroundColor: AppColors.dark,
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar reserva' : 'Confirmar reserva'),
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
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Resumen',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    PadelBadge(
                      label: '$_durationMinutes min',
                      variant: PadelBadgeVariant.info,
                    ),
                  ],
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
                  title: _formatTimeRange(),
                  subtitle: 'Duracion seleccionada: $_durationMinutes min',
                ),
                const Divider(height: 26),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Precio estimado',
                      style: TextStyle(color: AppColors.muted),
                    ),
                    Text(
                      priceText,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                      ),
                    ),
                  ],
                ),
                if (_selectedPlayers.isNotEmpty) ...[
                  const Divider(height: 26),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _selectedPlayers
                        .map(
                          (player) => PadelBadge(
                            label: player.displayName,
                            variant: PadelBadgeVariant.neutral,
                          ),
                        )
                        .toList(),
                  ),
                ],
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
                  'Duracion',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [60, 90, 120]
                      .map(
                        (minutes) => ChoiceChip(
                          label: Text('$minutes min'),
                          selected: _durationMinutes == minutes,
                          selectedColor:
                              AppColors.primary.withValues(alpha: 0.18),
                          side: BorderSide(
                            color: _durationMinutes == minutes
                                ? AppColors.primary
                                : AppColors.border,
                          ),
                          labelStyle: TextStyle(
                            color: _durationMinutes == minutes
                                ? Colors.white
                                : AppColors.muted,
                            fontWeight: FontWeight.w700,
                          ),
                          onSelected: (_) {
                            setState(() => _durationMinutes = minutes);
                          },
                        ),
                      )
                      .toList(),
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
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Jugadores invitados',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _pickPlayers,
                      child: const Text('Seleccionar'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Solo se mostraran usuarios registrados de la app.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                if (_selectedPlayers.isEmpty)
                  const _InlineHint(
                    icon: Icons.people_outline,
                    text: 'No has seleccionado invitados todavia.',
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _selectedPlayers
                        .map(
                          (player) => InputChip(
                            backgroundColor: AppColors.surface2,
                            selectedColor:
                                AppColors.primary.withValues(alpha: 0.18),
                            label: Text(player.displayName),
                            labelStyle: const TextStyle(color: Colors.white),
                            onDeleted: () {
                              setState(() {
                                _selectedPlayers.removeWhere(
                                    (item) => item.userId == player.userId);
                              });
                            },
                          ),
                        )
                        .toList(),
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
                  'Observaciones',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Estas observaciones se incluiran en la invitacion del calendario.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesCtrl,
                  maxLines: 4,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Ej: llegamos 10 min antes, reservar agua, etc.',
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
                border:
                    Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
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
              : Text(_isEditing ? 'Guardar cambios' : 'Confirmar reserva'),
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
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InlineHint extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InlineHint({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.muted, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
