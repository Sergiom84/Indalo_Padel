import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/api/api_client.dart';
import '../../../core/platform/platform_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/adaptive_pickers.dart';
import '../../../shared/widgets/loading_spinner.dart';
import '../models/venue_model.dart';

class VenueDetailScreen extends ConsumerStatefulWidget {
  final String venueId;
  const VenueDetailScreen({super.key, required this.venueId});

  @override
  ConsumerState<VenueDetailScreen> createState() => _VenueDetailScreenState();
}

class _VenueDetailScreenState extends ConsumerState<VenueDetailScreen> {
  bool _loadingVenue = true;
  bool _loadingAvailability = false;
  VenueModel? _venue;
  AvailabilityModel? _availability;
  String? _error;
  DateTime _selectedDate = DateTime.now();
  int _durationMinutes = 90;

  @override
  void initState() {
    super.initState();
    _fetchVenue();
  }

  Future<void> _fetchVenue() async {
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.get('/padel/venues/${widget.venueId}');
      final venueData = data is Map
          ? (data['venue'] != null
              ? {
                  ...Map<String, dynamic>.from(data['venue'] as Map),
                  'courts': data['courts'] ?? [],
                  'schedule_windows': data['schedule_windows'] ?? [],
                }
              : Map<String, dynamic>.from(data))
          : <String, dynamic>{};
      if (!mounted) {
        return;
      }
      setState(() {
        _venue = VenueModel.fromJson(venueData);
        _loadingVenue = false;
      });
      await _fetchAvailability();
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Error al cargar el club';
          _loadingVenue = false;
        });
      }
    }
  }

  Future<void> _fetchAvailability() async {
    setState(() => _loadingAvailability = true);
    try {
      final api = ref.read(apiClientProvider);
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final data = await api.get(
        '/padel/venues/${widget.venueId}/availability?date=$dateStr&duration_minutes=$_durationMinutes',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _availability =
            AvailabilityModel.fromJson(data as Map<String, dynamic>);
        _loadingAvailability = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loadingAvailability = false);
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showAdaptiveAppDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (picked != null) {
      await appSelectionHaptic();
      setState(() {
        _selectedDate = picked;
        _availability = null;
      });
      await _fetchAvailability();
    }
  }

  Future<void> _setDuration(int minutes) async {
    if (_durationMinutes == minutes) {
      return;
    }
    await appSelectionHaptic();
    setState(() {
      _durationMinutes = minutes;
      _availability = null;
    });
    await _fetchAvailability();
  }

  Future<void> _handleSlotTap(
      CourtModel court, TimeSlotModel slot, double? price) async {
    await appLightImpact();
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    if (!mounted) {
      return;
    }
    await context.push(
      '/booking/${court.id}',
      extra: {
        'date': dateStr,
        'start_time': slot.startTime,
        'duration_minutes': _durationMinutes,
        'venue_name': _venue?.name ?? '',
        'court_name': court.name,
        'price': price,
      },
    );

    if (mounted) {
      await _fetchAvailability();
    }
  }

  List<_CourtAvailabilitySlot> _slotsForCourt(CourtModel court) {
    final slots = _availability?.timeSlots ?? [];
    final courtSlots = slots
        .map((value) {
          final state = value.courts[court.id.toString()];
          if (state == null) {
            return null;
          }
          return _CourtAvailabilitySlot(slot: value, state: state);
        })
        .whereType<_CourtAvailabilitySlot>()
        .toList();

    courtSlots.sort(
      (left, right) => left.slot.startTime.compareTo(right.slot.startTime),
    );
    return courtSlots;
  }

  List<_CourtTimeSlotGroup> _groupSlotsByDayPeriod(
    List<_CourtAvailabilitySlot> slots,
  ) {
    final morning = <_CourtAvailabilitySlot>[];
    final midday = <_CourtAvailabilitySlot>[];
    final afternoon = <_CourtAvailabilitySlot>[];

    for (final slot in slots) {
      final hour = _hourFromTime(slot.slot.startTime);
      if (hour == null || hour < 13) {
        morning.add(slot);
      } else if (hour < 17) {
        midday.add(slot);
      } else {
        afternoon.add(slot);
      }
    }

    return [
      if (morning.isNotEmpty)
        _CourtTimeSlotGroup(
          label: 'Mañana',
          slots: morning,
          subtitle: _buildTimeRange(morning),
        ),
      if (midday.isNotEmpty)
        _CourtTimeSlotGroup(
          label: 'Mediodía',
          slots: midday,
          subtitle: _buildTimeRange(midday),
        ),
      if (afternoon.isNotEmpty)
        _CourtTimeSlotGroup(
          label: 'Tarde',
          slots: afternoon,
          subtitle: _buildTimeRange(afternoon),
        ),
    ];
  }

  int? _hourFromTime(String rawTime) {
    final match = RegExp(r'^(\d{1,2})').firstMatch(rawTime);
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(1)!);
  }

  String _buildTimeRange(List<_CourtAvailabilitySlot> slots) {
    if (slots.isEmpty) {
      return '';
    }

    final first = _formatHour(slots.first.slot.startTime);
    final last = _formatHour(slots.last.slot.startTime);
    if (slots.length == 1 || first == last) {
      return first;
    }
    return '$first - $last';
  }

  String _formatHour(String raw) => raw.length >= 5 ? raw.substring(0, 5) : raw;

  String _buildCourtCountLabel(int courtCount) {
    if (courtCount <= 0) {
      return 'Pistas no localizadas públicamente';
    }
    return '$courtCount ${courtCount == 1 ? 'pista' : 'pistas'}';
  }

  String? _buildScheduleLabel(VenueModel venue) {
    final windows = _availability?.scheduleWindows ?? const [];
    if (windows.isNotEmpty) {
      return windows
          .map((window) =>
              '${_formatHour(window.startTime)}-${_formatHour(window.endTime)}')
          .join(' · ');
    }

    final venueGenericWindows = venue.scheduleWindows
        .where((window) => window.dayOfWeek == null)
        .toList();
    if (venueGenericWindows.isNotEmpty) {
      return venueGenericWindows
          .map((window) =>
              '${_formatHour(window.startTime)}-${_formatHour(window.endTime)}')
          .join(' · ');
    }

    if (venue.openingTime != null && venue.closingTime != null) {
      return '${_formatHour(venue.openingTime!)}-${_formatHour(venue.closingTime!)}';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingVenue) {
      return Scaffold(
        backgroundColor: AppColors.dark,
        appBar: AppBar(),
        body: const Center(child: LoadingSpinner()),
      );
    }

    if (_error != null || _venue == null) {
      return Scaffold(
        backgroundColor: AppColors.dark,
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _error ?? 'Club no encontrado',
                style: const TextStyle(color: AppColors.danger),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => context.pop(),
                child: const Text('Volver'),
              ),
            ],
          ),
        ),
      );
    }

    final venue = _venue!;
    final scheduleLabel = _buildScheduleLabel(venue);

    return Scaffold(
      backgroundColor: AppColors.dark,
      appBar: AppBar(
        title: Text(venue.name),
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
                Text(
                  venue.location,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                _InfoPill(
                  icon: isCupertinoPlatform
                      ? CupertinoIcons.sportscourt
                      : Icons.sports_tennis,
                  label: _buildCourtCountLabel(venue.courtCount),
                ),
                const SizedBox(height: 8),
                _InfoPill(
                  icon: isCupertinoPlatform
                      ? CupertinoIcons.time
                      : Icons.schedule_outlined,
                  label: scheduleLabel ?? 'Horario no localizado públicamente',
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Duracion del partido',
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
                          onSelected: (_) => _setDuration(minutes),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
                const Text(
                  'La disponibilidad se filtra segun la duracion seleccionada.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(22),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      isCupertinoPlatform
                          ? CupertinoIcons.calendar
                          : Icons.calendar_month,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Disponibilidad',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat("EEEE d 'de' MMMM", 'es_ES')
                              .format(_selectedDate),
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isCupertinoPlatform
                        ? CupertinoIcons.chevron_down
                        : Icons.expand_more,
                    color: AppColors.muted,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (_loadingAvailability)
            const LoadingSpinner()
          else if ((_availability?.courts ?? []).isEmpty)
            _AvailabilityEmptyState(
              message: venue.courtCount <= 0
                  ? 'No hay pistas publicadas con número confirmado para este centro.'
                  : 'No hay disponibilidad para esta fecha.',
            )
          else
            ...(_availability!.courts.map((court) {
              final slots = _slotsForCourt(court);
              final availableSlots =
                  slots.where((slot) => slot.state.available).length;
              final blockedSlots =
                  slots.where((slot) => !slot.state.available).length;
              return Container(
                margin: const EdgeInsets.only(bottom: 14),
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                court.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (court.surfaceType != null)
                                    _SurfaceChip(label: court.surfaceType!),
                                  if (court.isIndoor != null)
                                    _SurfaceChip(
                                      label: court.isIndoor!
                                          ? 'Cubierta'
                                          : 'Exterior',
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Text(
                          blockedSlots > 0
                              ? '$availableSlots libres · $blockedSlots ocupadas'
                              : '$availableSlots libres',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (slots.isEmpty)
                      const Text(
                        'No quedan franjas disponibles para esta fecha.',
                        style: TextStyle(color: AppColors.muted),
                      )
                    else
                      Column(
                        children: _groupSlotsByDayPeriod(slots)
                            .map(
                              (group) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _CourtTimeSlotGroupTile(
                                  group: group,
                                  slotBuilder: (courtSlot) {
                                    final price = courtSlot.state.price;
                                    return _AvailabilitySlotChip(
                                      label:
                                          '${courtSlot.slot.startTime.substring(0, 5)} · ${_durationMinutes}min${price != null ? ' · ${price.toStringAsFixed(0)}€' : ''}',
                                      available: courtSlot.state.available,
                                      onPressed: () => _handleSlotTap(
                                        court,
                                        courtSlot.slot,
                                        price,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            )
                            .toList(),
                      ),
                  ],
                ),
              );
            })),
        ],
      ),
    );
  }
}

class _CourtAvailabilitySlot {
  final TimeSlotModel slot;
  final CourtSlot state;

  const _CourtAvailabilitySlot({required this.slot, required this.state});
}

class _CourtTimeSlotGroup {
  final String label;
  final String subtitle;
  final List<_CourtAvailabilitySlot> slots;

  const _CourtTimeSlotGroup({
    required this.label,
    required this.subtitle,
    required this.slots,
  });
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}

class _SurfaceChip extends StatelessWidget {
  final String label;

  const _SurfaceChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(color: AppColors.muted, fontSize: 12),
      ),
    );
  }
}

class _AvailabilityEmptyState extends StatelessWidget {
  final String message;

  const _AvailabilityEmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.event_busy, color: AppColors.muted, size: 34),
          const SizedBox(height: 12),
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

class _AvailabilitySlotChip extends StatelessWidget {
  final String label;
  final bool available;
  final VoidCallback onPressed;

  const _AvailabilitySlotChip({
    required this.label,
    required this.available,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      backgroundColor: available
          ? AppColors.surface2
          : AppColors.muted.withValues(alpha: 0.22),
      side: BorderSide(
        color: available
            ? AppColors.border
            : AppColors.muted.withValues(alpha: 0.35),
      ),
      avatar: Icon(
        Icons.access_time,
        color: available ? AppColors.primary : AppColors.muted,
        size: 16,
      ),
      label: Text(
        label,
        style: TextStyle(
          color: available ? Colors.white : AppColors.muted,
          fontWeight: available ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      onPressed: available ? onPressed : null,
    );
  }
}

class _CourtTimeSlotGroupTile extends StatelessWidget {
  final _CourtTimeSlotGroup group;
  final Widget Function(_CourtAvailabilitySlot courtSlot) slotBuilder;

  const _CourtTimeSlotGroupTile({
    required this.group,
    required this.slotBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface2.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: ExpansionTile(
            initiallyExpanded: false,
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            iconColor: AppColors.primary,
            collapsedIconColor: AppColors.muted,
            title: Text(
              group.label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            subtitle: Text(
              group.subtitle.isEmpty
                  ? '${group.slots.length} franjas'
                  : '${group.subtitle} · ${group.slots.length} franjas',
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
              ),
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: group.slots.map(slotBuilder).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
