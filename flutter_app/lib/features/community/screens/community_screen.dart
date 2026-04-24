import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../notifications/providers/app_alerts_provider.dart';
import '../../../shared/widgets/adaptive_pickers.dart';
import '../../../shared/widgets/loading_spinner.dart';
import '../../../shared/widgets/notification_dot.dart';
import '../../../shared/widgets/padel_badge.dart';
import '../../../shared/widgets/preference_summary_chips.dart';
import '../../players/models/player_model.dart';
import '../widgets/match_result_dialog.dart';
import '../models/community_model.dart';
import '../models/match_result_model.dart';
import '../providers/community_provider.dart';

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen>
    with SingleTickerProviderStateMixin {
  static const Map<String, String> _modalityLabels = {
    'amistoso': 'Amistoso',
    'competitivo': 'Competitivo',
    'americana': 'Americana',
  };

  late DateTime _draftDate;
  late TimeOfDay _draftTime;
  String _draftModality = 'amistoso';
  int? _draftClubId;

  final Set<int> _selectedParticipantIds = <int>{};
  final Set<int> _handledNotificationIds = <int>{};
  final TextEditingController _postPadelPlanController =
      TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  late TabController _tabController;
  Timer? _pollTimer;
  int? _selectedPlanId;
  int? _reservationHandlerUserId;
  bool _busy = false;
  bool _draftDirty = false;
  bool _forceNewDraft = false;
  bool _notificationFlowActive = false;
  String? _lastSyncedPlanToken;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    final suggested = _nextSuggestedDateTime();
    _draftDate = DateTime(suggested.year, suggested.month, suggested.day);
    _draftTime = TimeOfDay(hour: suggested.hour, minute: suggested.minute);
    _postPadelPlanController.addListener(_onDraftDetailsChanged);
    _notesController.addListener(_onDraftDetailsChanged);
    _pollTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (!mounted) {
        return;
      }
      ref.invalidate(communityDashboardProvider);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pollTimer?.cancel();
    _postPadelPlanController
      ..removeListener(_onDraftDetailsChanged)
      ..dispose();
    _notesController
      ..removeListener(_onDraftDetailsChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _refreshDashboard() async {
    ref.invalidate(communityDashboardProvider);
    await ref.read(communityDashboardProvider.future);
  }

  CommunityPlanModel? _planById(
    CommunityDashboardModel dashboard,
    int? planId,
  ) {
    if (planId == null) {
      return null;
    }

    for (final plan in [...dashboard.activePlans, ...dashboard.historyPlans]) {
      if (plan.id == planId) {
        return plan;
      }
    }
    return null;
  }

  CommunityPlanModel? _effectivePlan(CommunityDashboardModel dashboard) {
    return _planById(dashboard, _selectedPlanId);
  }

  int get _draftCapacity => _draftModality == 'americana' ? 8 : 4;

  int get _maxInvitedParticipants => _draftCapacity - 1;

  void _onDraftDetailsChanged() {
    _markDraftDirty();
  }

  int? _resolvedDraftClubId(CommunityDashboardModel dashboard) {
    return _draftClubId ?? dashboard.venue?.id;
  }

  String? _optionalDraftText(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  void _setDraftModality(String modality) {
    if (_draftModality == modality) {
      return;
    }

    final maxInvites = modality == 'americana' ? 7 : 3;
    final removedCount = _selectedParticipantIds.length > maxInvites
        ? _selectedParticipantIds.length - maxInvites
        : 0;

    setState(() {
      _draftModality = modality;
      if (_selectedParticipantIds.length > maxInvites) {
        final allowedIds = _selectedParticipantIds.take(maxInvites).toList();
        _selectedParticipantIds
          ..clear()
          ..addAll(allowedIds);
      }
      _markDraftDirty();
    });

    if (removedCount > 0) {
      _showMessage(
        'La modalidad ${_modalityLabels[modality] ?? modality} admite $maxInvites invitaciones. He ajustado la selección actual.',
      );
    }
  }

  void _setDraftClubId(int? clubId) {
    setState(() {
      _draftClubId = clubId;
      _markDraftDirty();
    });
  }

  void _maybeSyncDashboard(CommunityDashboardModel dashboard) {
    final selectedPlan = _effectivePlan(dashboard);

    if (_selectedPlanId != null && selectedPlan == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _selectedPlanId = null;
          _lastSyncedPlanToken = null;
          if (!_forceNewDraft) {
            _resetDraftInternal();
          }
        });
      });
      _scheduleNotifications(dashboard.notifications);
      return;
    }

    if (_selectedPlanId == null &&
        !_forceNewDraft &&
        dashboard.activePlan != null &&
        dashboard.activePlan!.isOrganizer) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _applyPlanToDraftInternal(
            dashboard.activePlan!,
            token: _planToken(dashboard.activePlan!),
          );
        });
      });
      _scheduleNotifications(dashboard.notifications);
      return;
    }

    if (selectedPlan != null) {
      final token = _planToken(selectedPlan);
      if (!_draftDirty && _lastSyncedPlanToken != token) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          setState(() {
            _applyPlanToDraftInternal(selectedPlan, token: token);
          });
        });
      }
    }

    _scheduleNotifications(dashboard.notifications);
  }

  void _scheduleNotifications(List<CommunityNotificationModel> notifications) {
    if (_notificationFlowActive) {
      return;
    }

    final pending = notifications
        .where((notification) =>
            !_handledNotificationIds.contains(notification.id))
        .toList(growable: false);
    if (pending.isEmpty) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _presentNotifications(pending);
    });
  }

  Future<void> _presentNotifications(
    List<CommunityNotificationModel> notifications,
  ) async {
    if (_notificationFlowActive || !mounted) {
      return;
    }

    _notificationFlowActive = true;
    final actions = ref.read(communityActionsProvider);

    try {
      for (final notification in notifications) {
        if (!mounted || _handledNotificationIds.contains(notification.id)) {
          continue;
        }

        _handledNotificationIds.add(notification.id);

        await showDialog<void>(
          context: context,
          builder: (dialogContext) {
            final canJump = notification.planId > 0;
            // Gap 6: para bajas, el organizador ve "Seleccionar sustituto"
            final snapshot = ref.read(communityDashboardProvider).valueOrNull;
            final notificationPlan = snapshot != null
                ? _planById(snapshot, notification.planId)
                : null;
            final isOrganizerOfPlan = notificationPlan?.isOrganizer ?? false;
            final jumpLabel =
                notification.type == 'member_declined' && isOrganizerOfPlan
                    ? 'Seleccionar sustituto'
                    : 'Ver convocatoria';

            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: Text(
                notification.title,
                style: const TextStyle(color: Colors.white),
              ),
              content: Text(
                notification.message,
                style: const TextStyle(color: AppColors.light),
              ),
              actions: [
                if (canJump)
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      if (snapshot == null) return;
                      final targetPlan =
                          _planById(snapshot, notification.planId);
                      if (targetPlan == null || !mounted) return;
                      if (!targetPlan.isOrganizer) {
                        // Invitación recibida → ir a pestaña Convocatorias
                        _tabController.animateTo(1);
                      } else {
                        // Plan propio → abrir en pestaña Reservar
                        _tabController.animateTo(0);
                        setState(() {
                          _applyPlanToDraftInternal(
                            targetPlan,
                            token: _planToken(targetPlan),
                          );
                        });
                      }
                    },
                    child: Text(jumpLabel),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Entendido'),
                ),
              ],
            );
          },
        );

        try {
          await actions.markNotificationRead(notification.id);
        } catch (_) {}
      }
    } finally {
      _notificationFlowActive = false;
      if (mounted) {
        ref.invalidate(communityDashboardProvider);
      }
    }
  }

  String _planToken(CommunityPlanModel plan) {
    final participantsState = plan.participants
        .map((participant) =>
            '${participant.userId}:${participant.responseState}')
        .join('|');
    return [
      plan.id,
      plan.updatedAt ?? '',
      plan.modality,
      plan.capacity,
      plan.clubId ?? plan.venueId ?? '',
      plan.postPadelPlan ?? '',
      plan.notes ?? '',
      plan.inviteState,
      plan.reservationState,
      plan.lastDeclinedBy ?? '',
      plan.lastRescheduleDate ?? '',
      plan.lastRescheduleTime ?? '',
      participantsState,
    ].join('::');
  }

  void _applyPlanToDraftInternal(
    CommunityPlanModel plan, {
    required String token,
  }) {
    final parsedDate = _parseApiDate(plan.scheduledDate);
    final parsedTime = _parseApiTime(plan.scheduledTime);
    final declinedUserId =
        plan.isOrganizer && plan.hasDecline ? plan.lastDeclinedBy : null;

    _selectedParticipantIds
      ..clear()
      ..addAll(
        plan.participants
            .where((participant) => !participant.isOrganizer)
            .where((participant) => participant.userId != declinedUserId)
            .map((participant) => participant.userId),
      );

    _draftDate = parsedDate ?? _draftDate;
    _draftTime = parsedTime ?? _draftTime;
    _draftModality =
        _modalityLabels.containsKey(plan.modality) ? plan.modality : 'amistoso';
    _draftClubId = plan.clubId ?? plan.venueId ?? plan.venue?.id;
    _postPadelPlanController.text = plan.postPadelPlan ?? '';
    _notesController.text = plan.notes ?? '';
    _selectedPlanId = plan.id;
    _reservationHandlerUserId =
        plan.reservationHandledBy ?? plan.participants.firstOrNull?.userId;
    _busy = false;
    _draftDirty = false;
    _forceNewDraft = false;
    _lastSyncedPlanToken = token;
  }

  void _resetDraftInternal() {
    final suggested = _nextSuggestedDateTime();
    _draftDate = DateTime(suggested.year, suggested.month, suggested.day);
    _draftTime = TimeOfDay(hour: suggested.hour, minute: suggested.minute);
    _draftModality = 'amistoso';
    _draftClubId = null;
    _postPadelPlanController.clear();
    _notesController.clear();
    _selectedParticipantIds.clear();
    _reservationHandlerUserId = null;
    _selectedPlanId = null;
    _busy = false;
    _draftDirty = false;
    _lastSyncedPlanToken = null;
  }

  void _selectNewDraft() {
    setState(() {
      _forceNewDraft = true;
      _resetDraftInternal();
    });
  }

  void _markDraftDirty() {
    _draftDirty = true;
    _lastSyncedPlanToken = null;
  }

  Future<void> _pickDate() async {
    final selected = await showAdaptiveAppDatePicker(
      context: context,
      initialDate: _draftDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (!mounted || selected == null) {
      return;
    }
    setState(() {
      _draftDate = DateTime(selected.year, selected.month, selected.day);
      _markDraftDirty();
    });
  }

  Future<void> _pickTime() async {
    final selected = await showAdaptiveAppTimePicker(
      context: context,
      initialTime: _draftTime,
    );
    if (!mounted || selected == null) {
      return;
    }
    setState(() {
      _draftTime = selected;
      _markDraftDirty();
    });
  }

  void _toggleParticipant(PlayerModel player) {
    setState(() {
      if (_selectedParticipantIds.contains(player.userId)) {
        _selectedParticipantIds.remove(player.userId);
        _markDraftDirty();
        return;
      }

      if (_selectedParticipantIds.length >= _maxInvitedParticipants) {
        _showMessage(
          _draftModality == 'americana'
              ? 'La modalidad Americana requiere 7 compañeros además de ti.'
              : 'Puedes invitar como máximo a tres compañeros.',
          isError: true,
        );
        return;
      }

      _selectedParticipantIds.add(player.userId);
      _markDraftDirty();
    });
  }

  Future<bool> _confirmConflictsIfNeeded(
      CommunityPlanModel? selectedPlan) async {
    final preview = await ref.read(communityActionsProvider).previewConflicts(
          planId: selectedPlan?.id,
          scheduledDate: _formatApiDate(_draftDate),
          scheduledTime: _formatApiTime(_draftTime),
          participantUserIds: _selectedParticipantIds.toList(growable: false),
          modality: _draftModality,
          capacity: _draftCapacity,
        );

    if (!preview.hasConflicts || !mounted) {
      return true;
    }

    final conflictLines = preview.conflicts
        .expand((player) =>
            player.items.map((item) => item.message ?? player.displayName))
        .toList(growable: false);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          preview.hasHardConflicts
              ? 'Conflictos fuertes detectados'
              : 'Conflictos detectados',
          style: const TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                preview.hasHardConflicts
                    ? 'Puedes enviar la convocatoria, pero quien tenga un conflicto duro no podrá aceptarla hasta liberarlo.'
                    : 'Hay invitaciones cercanas o solapadas. Puedes enviarla igualmente si te compensa.',
                style: const TextStyle(color: AppColors.light),
              ),
              const SizedBox(height: 12),
              ...conflictLines.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '• $line',
                    style: const TextStyle(color: Colors.white, height: 1.35),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Revisar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Enviar igualmente'),
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }

  Future<void> _submitPlan(
    CommunityDashboardModel dashboard,
    CommunityPlanModel? selectedPlan,
  ) async {
    if (_busy) {
      return;
    }

    if (_selectedParticipantIds.isEmpty) {
      _showMessage('Selecciona al menos un compañero de tu red.',
          isError: true);
      return;
    }

    if (_selectedParticipantIds.length > _maxInvitedParticipants) {
      _showMessage(
        _draftModality == 'americana'
            ? 'La modalidad Americana admite 7 compañeros además de ti.'
            : 'Puedes invitar como máximo a tres compañeros.',
        isError: true,
      );
      return;
    }

    if (_draftModality == 'americana' &&
        _selectedParticipantIds.length != _maxInvitedParticipants) {
      _showMessage(
        'La modalidad Americana necesita 8 plazas completas: tú y 7 jugadores más.',
        isError: true,
      );
      return;
    }

    if (selectedPlan != null && !selectedPlan.isOrganizer) {
      _showMessage(
        'Esta convocatoria la ha creado otro jugador. Usa "Nueva convocatoria".',
        isError: true,
      );
      return;
    }

    if (selectedPlan?.isTerminal == true) {
      _showMessage(
        'La convocatoria seleccionada ya está cerrada. Crea una nueva para volver a convocar.',
        isError: true,
      );
      return;
    }

    // Gap 1: cuando hay una baja, el organizador debe seleccionar un sustituto
    if (selectedPlan != null &&
        selectedPlan.isOrganizer &&
        selectedPlan.hasDecline) {
      final originalCount =
          selectedPlan.participants.where((p) => !p.isOrganizer).length;
      if (_selectedParticipantIds.length < originalCount) {
        _showMessage(
          'Debes seleccionar un sustituto para completar los $originalCount jugadores antes de reenviar la convocatoria.',
          isError: true,
        );
        return;
      }
    }

    setState(() => _busy = true);
    final actions = ref.read(communityActionsProvider);

    try {
      final shouldContinue = await _confirmConflictsIfNeeded(selectedPlan);
      if (!shouldContinue) {
        if (mounted) {
          setState(() => _busy = false);
        }
        return;
      }

      if (selectedPlan != null && selectedPlan.isOrganizer) {
        await actions.updatePlan(
          planId: selectedPlan.id,
          scheduledDate: _formatApiDate(_draftDate),
          scheduledTime: _formatApiTime(_draftTime),
          participantUserIds: _selectedParticipantIds.toList(growable: false),
          modality: _draftModality,
          capacity: _draftCapacity,
          clubId: _resolvedDraftClubId(dashboard),
          postPadelPlan: _optionalDraftText(_postPadelPlanController),
          notes: _optionalDraftText(_notesController),
          updatedAt: selectedPlan.updatedAt,
          forceSend: true,
        );
        if (!mounted) {
          return;
        }
        _showMessage('Convocatoria actualizada para tu red.');
      } else {
        await actions.createPlan(
          scheduledDate: _formatApiDate(_draftDate),
          scheduledTime: _formatApiTime(_draftTime),
          participantUserIds: _selectedParticipantIds.toList(growable: false),
          modality: _draftModality,
          capacity: _draftCapacity,
          clubId: _resolvedDraftClubId(dashboard),
          postPadelPlan: _optionalDraftText(_postPadelPlanController),
          notes: _optionalDraftText(_notesController),
          forceSend: true,
        );
        if (!mounted) {
          return;
        }
        _showMessage('Invitación enviada a tu red.');
      }

      setState(() {
        _busy = false;
        _draftDirty = false;
        _forceNewDraft = false;
        _selectedPlanId = selectedPlan?.id;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _busy = false);
      _showMessage(error.toString(), isError: true);
    }
  }

  Future<void> _respondToPlan(
    CommunityPlanModel plan,
    String action,
  ) async {
    if (_busy) {
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(communityActionsProvider).respondToPlan(
            planId: plan.id,
            action: action,
            updatedAt: plan.updatedAt,
          );
      if (!mounted) {
        return;
      }
      setState(() => _busy = false);
      _showMessage(
        action == 'accepted'
            ? 'Has aceptado la convocatoria.'
            : action == 'doubt'
                ? 'Has dejado claro que todavía estás en duda.'
                : 'Has avisado de que no puedes participar.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _busy = false);
      _showMessage(error.toString(), isError: true);
    }
  }

  Future<void> _cancelPlan(CommunityPlanModel plan) async {
    if (_busy) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Cancelar convocatoria',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'La convocatoria quedará cancelada y pasará al historial para todos los implicados. Esta acción no se puede deshacer.',
          style: TextStyle(color: AppColors.light),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Volver'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Cancelar convocatoria'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _busy = true);
    try {
      await ref
          .read(communityActionsProvider)
          .cancelPlan(planId: plan.id, updatedAt: plan.updatedAt);
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _selectedPlanId = null;
        _forceNewDraft = false;
        _resetDraftInternal();
      });
      _showMessage('Convocatoria cancelada.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _busy = false);
      _showMessage(error.toString(), isError: true);
    }
  }

  Future<void> _proposeNewTime(CommunityPlanModel plan) async {
    if (_busy) {
      return;
    }

    final initialDate = _parseApiDate(plan.scheduledDate) ?? _draftDate;
    final initialTime = _parseApiTime(plan.scheduledTime) ?? _draftTime;

    final selectedDate = await showAdaptiveAppDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (!mounted || selectedDate == null) {
      return;
    }

    final selectedTime = await showAdaptiveAppTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (!mounted || selectedTime == null) {
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(communityActionsProvider).proposeTime(
            planId: plan.id,
            scheduledDate: _formatApiDate(selectedDate),
            scheduledTime: _formatApiTime(selectedTime),
            updatedAt: plan.updatedAt,
          );
      if (!mounted) {
        return;
      }
      setState(() => _busy = false);
      _showMessage('Nuevo horario propuesto al resto de la convocatoria.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _busy = false);
      _showMessage(error.toString(), isError: true);
    }
  }

  Future<void> _updateReservation(
    CommunityPlanModel plan,
    String status,
  ) async {
    if (_busy) {
      return;
    }

    if (_reservationHandlerUserId == null) {
      _showMessage('Selecciona quién gestiona la reserva.', isError: true);
      return;
    }

    setState(() => _busy = true);
    try {
      final calendarWarning =
          await ref.read(communityActionsProvider).updateReservationStatus(
                planId: plan.id,
                status: status,
                handledByUserId: _reservationHandlerUserId,
                updatedAt: plan.updatedAt,
              );
      if (!mounted) {
        return;
      }
      setState(() => _busy = false);
      _showMessage(
        status == 'confirmed'
            ? 'Reserva confirmada y aviso enviado al resto.'
            : 'Reserva pendiente. Todos quedan informados del segundo intento.',
      );
      if (calendarWarning != null && calendarWarning.trim().isNotEmpty) {
        _showMessage(
          'La convocatoria se guardó, pero Google Calendar no respondió: $calendarWarning',
          isError: true,
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _busy = false);
      _showMessage(error.toString(), isError: true);
    }
  }

  Future<void> _copyReservationTemplate(
    CommunityPlanModel plan,
    CommunityVenueModel? venue,
  ) async {
    final text = _buildReservationTemplate(plan, venue);
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) {
      return;
    }
    _showMessage('Texto copiado para enviarlo al centro deportivo.');
  }

  String _buildReservationTemplate(
    CommunityPlanModel plan,
    CommunityVenueModel? venue,
  ) {
    final players = plan.participants
        .map((participant) => participant.displayName)
        .join(', ');
    final greeting = _greetingForTime(plan.scheduledTime);
    final phoneText =
        (plan.reservationContactPhone ?? venue?.phone ?? '').trim();
    final venueParts = <String>[
      (venue?.name ?? 'Centro deportivo').trim(),
      (venue?.location ?? '').trim(),
    ]..removeWhere((part) => part.isEmpty);
    final venueText = venueParts.join(' · ');
    final addressText = (venue?.address ?? '').trim();

    final buffer = StringBuffer()
      ..writeln(greeting)
      ..writeln()
      ..write(
        'Solicitamos reservar una pista el ${_formatDisplayDate(plan.scheduledDate)} '
        'a las ${_formatDisplayTime(plan.scheduledTime)}'
        '${venueText.isNotEmpty ? ' en $venueText' : ''}, '
        'los jugadores: $players.',
      )
      ..writeln()
      ..writeln()
      ..write('Gracias.');

    if (addressText.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln()
        ..write('Dirección: $addressText');
    }

    if (phoneText.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln()
        ..write('Contacto del centro: $phoneText');
    }

    return buffer.toString();
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : AppColors.surface2,
      ),
    );
  }

  List<CommunityPlanModel> _finishedAcceptedPlans(
    CommunityDashboardModel dashboard,
  ) {
    final uniquePlans = <int, CommunityPlanModel>{};

    for (final plan in [...dashboard.activePlans, ...dashboard.historyPlans]) {
      uniquePlans[plan.id] = plan;
    }

    return _resultReadyPlans(uniquePlans.values);
  }

  List<CommunityPlanModel> _resultReadyPlans(
    Iterable<CommunityPlanModel> plans,
  ) {
    final now = DateTime.now();
    final result = <CommunityPlanModel>[];

    for (final plan in plans) {
      final accepted = plan.myResponseState == 'accepted' || plan.isOrganizer;
      if (!accepted) {
        continue;
      }

      if (!plan.needsResultNotification) {
        continue;
      }

      if (!plan.canCaptureResult(reference: now)) {
        continue;
      }

      result.add(plan);
    }

    result.sort((a, b) {
      final leftEnd = _planEndDateTime(a) ?? DateTime.now();
      final rightEnd = _planEndDateTime(b) ?? DateTime.now();
      return rightEnd.compareTo(leftEnd);
    });

    return result;
  }

  Future<MatchResultSubmissionModel?> _prepareExistingSubmission(
    CommunityPlanModel plan,
  ) async {
    final currentUserId = plan.currentUserParticipant?.userId;
    if (currentUserId == null) {
      return null;
    }

    try {
      final result = await ref.read(communityActionsProvider).fetchMatchResult(
            plan.id,
          );
      final existingSubmission = result.submissionFor(currentUserId);

      if (existingSubmission != null) {
        if (mounted) {
          ref.read(appAlertsProvider.notifier).refresh(notifyOnNew: false);
        }
      }

      return existingSubmission;
    } catch (_) {
      return null;
    }
  }

  Future<void> _openResultDialog(CommunityPlanModel plan) async {
    if (!plan.canCaptureResult(reference: DateTime.now())) {
      _showMessage(
        'El resultado se podrá registrar cuando el partido haya finalizado.',
      );
      return;
    }

    final existingSubmission = await _prepareExistingSubmission(plan);
    if (!mounted) {
      return;
    }

    await showMatchResultDialog(
      context,
      plan: plan,
      existingSubmission: existingSubmission,
    );
    await _refreshDashboard();
  }

  static DateTime? _planEndDateTime(CommunityPlanModel plan) {
    if (plan.scheduledDate.isEmpty || plan.scheduledTime.isEmpty) {
      return null;
    }

    try {
      final date = DateTime.parse(plan.scheduledDate);
      final parts = plan.scheduledTime.split(':');
      if (parts.length < 2) {
        return null;
      }

      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) {
        return null;
      }

      final start = DateTime(date.year, date.month, date.day, hour, minute);
      return start.add(Duration(minutes: plan.durationMinutes));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(communityDashboardProvider);
    final alerts = ref.watch(appAlertsProvider);

    return Scaffold(
      backgroundColor: AppColors.dark,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.groups_2_outlined, color: AppColors.primary, size: 22),
            SizedBox(width: 8),
            Text('Comunidad'),
          ],
        ),
        backgroundColor: AppColors.surface,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.muted,
          tabs: [
            Tab(
              child: NotificationLabel(
                label: 'Reservar',
                showDot: alerts.hasCommunityPlannerBadge,
              ),
            ),
            Tab(
              child: NotificationLabel(
                label: 'Convocatorias',
                showDot: alerts.hasCommunityInvitationsBadge,
              ),
            ),
            const Tab(text: 'Partido'),
            const Tab(text: 'Historial'),
          ],
        ),
      ),
      body: dashboardAsync.when(
        loading: () => const Center(child: LoadingSpinner()),
        error: (error, _) => _CommunityErrorState(
          message: error.toString(),
          onRetry: _refreshDashboard,
        ),
        data: (dashboard) {
          _maybeSyncDashboard(dashboard);
          final selectedPlan = _effectivePlan(dashboard);
          final reservationVenue = selectedPlan?.venue ?? dashboard.venue;
          final finishedPlans = alerts.loading
              ? _finishedAcceptedPlans(dashboard)
              : _resultReadyPlans(alerts.pendingResultPlans);

          return TabBarView(
            controller: _tabController,
            children: [
              // ── Pestaña 1: Convocatorias ──────────────────────────────
              RefreshIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.surface,
                onRefresh: _refreshDashboard,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  children: [
                    _buildPlanSelector(dashboard, selectedPlan),
                    if (_shouldShowReservationFlow(selectedPlan)) ...[
                      const SizedBox(height: 16),
                      ..._buildReservationFlowCards(
                        dashboard,
                        selectedPlan,
                        reservationVenue,
                      ),
                    ],
                  ],
                ),
              ),
              // ── Pestaña 2: Me invitan ────────────────────────────────
              RefreshIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.surface,
                onRefresh: _refreshDashboard,
                child: _buildMeInvitanTab(dashboard),
              ),
              // ── Pestaña 3: Partido ────────────────────────────────────
              RefreshIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.surface,
                onRefresh: _refreshDashboard,
                child: _buildPartidoTab(finishedPlans),
              ),
              // ── Pestaña 4: Historial ──────────────────────────────────
              RefreshIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.surface,
                onRefresh: _refreshDashboard,
                child: _buildHistorialTab(dashboard),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPlanSelector(
    CommunityDashboardModel dashboard,
    CommunityPlanModel? selectedPlan,
  ) {
    return OutlinedButton.icon(
      onPressed: _selectNewDraft,
      icon: const Icon(Icons.add, size: 18),
      label: const Text(
        'Nueva convocatoria',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: BorderSide(
          color: selectedPlan == null ? AppColors.primary : AppColors.border,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }

  Widget _buildMeInvitanTab(CommunityDashboardModel dashboard) {
    final invitations =
        dashboard.activePlans.where((p) => !p.isOrganizer).toList();

    if (invitations.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mail_outline, color: AppColors.muted, size: 42),
            SizedBox(height: 12),
            Text(
              'Nadie te ha invitado todavía.',
              style: TextStyle(color: AppColors.muted),
            ),
            SizedBox(height: 6),
            Text(
              'Cuando un compañero te convoque, aparecerá aquí.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      itemCount: invitations.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final plan = invitations[index];
        return _InvitationCard(
          plan: plan,
          busy: _busy,
          onAccept: () => _respondToPlan(plan, 'accepted'),
          onDecline: () => _respondToPlan(plan, 'declined'),
          onDoubt: () => _respondToPlan(plan, 'doubt'),
          onSuggestTime: () => _proposeNewTime(plan),
          onOpenChat: () => context.push('/players/chat/event/${plan.id}'),
          formatDate: _formatDisplayDate,
          formatTime: _formatDisplayTime,
        );
      },
    );
  }

  Widget _buildPartidoTab(List<CommunityPlanModel> plans) {
    return _CommunityPartidoTab(
      plans: plans,
      onOpenPlan: _openResultDialog,
      formatDate: _formatDisplayDate,
    );
  }

  bool _shouldShowReservationFlow(CommunityPlanModel? selectedPlan) {
    return _forceNewDraft || selectedPlan != null;
  }

  bool _shouldExpandCreateStep(CommunityPlanModel? selectedPlan) {
    if (_forceNewDraft) {
      return true;
    }

    if (selectedPlan == null) {
      return false;
    }

    return selectedPlan.isOrganizer && selectedPlan.hasDecline;
  }

  bool _isStatusStepCompleted(CommunityPlanModel plan) {
    return plan.isReady ||
        plan.reservationState == 'retry' ||
        plan.reservationConfirmed ||
        plan.isCancelled ||
        plan.isExpired;
  }

  bool _isReservationStepCompleted(CommunityPlanModel plan) {
    return plan.reservationConfirmed || plan.isCancelled || plan.isExpired;
  }

  List<Widget> _buildReservationFlowCards(
    CommunityDashboardModel dashboard,
    CommunityPlanModel? selectedPlan,
    CommunityVenueModel? reservationVenue,
  ) {
    if (_forceNewDraft) {
      return [_buildCreateCard(dashboard, selectedPlan)];
    }

    if (selectedPlan == null) {
      return const [];
    }

    final cards = <Widget>[];
    final expandCreateStep = _shouldExpandCreateStep(selectedPlan);
    final statusCompleted = _isStatusStepCompleted(selectedPlan);
    final reservationCompleted = _isReservationStepCompleted(selectedPlan);

    if (expandCreateStep) {
      cards.add(_buildCreateCard(dashboard, selectedPlan));
      return cards;
    }

    cards.add(
      _CommunityCollapsedStepCard(
        borderColor: AppColors.success,
        title: '1. Convoca a tu red',
        statusLabel: 'Invitación enviada',
        summary: _buildCreateStepSummary(selectedPlan),
      ),
    );

    if (!statusCompleted) {
      cards
        ..add(const SizedBox(height: 16))
        ..add(_buildStatusCard(selectedPlan));
      return cards;
    }

    cards
      ..add(const SizedBox(height: 16))
      ..add(
        _CommunityCollapsedStepCard(
          borderColor: _statusColorForPlan(selectedPlan),
          title: '2. Estado de la convocatoria',
          statusLabel: _statusStepLabel(selectedPlan),
          summary: _buildStatusStepSummary(selectedPlan),
        ),
      );

    if (!reservationCompleted) {
      cards
        ..add(const SizedBox(height: 16))
        ..add(_buildReservationCard(selectedPlan, reservationVenue));
      return cards;
    }

    cards
      ..add(const SizedBox(height: 16))
      ..add(
        _CommunityCollapsedStepCard(
          borderColor: _statusColorForPlan(selectedPlan),
          title: '3. Reserva con el club',
          statusLabel: _reservationStepLabel(selectedPlan),
          summary: _buildReservationStepSummary(
            selectedPlan,
            reservationVenue,
          ),
        ),
      );

    return cards;
  }

  String _buildCreateStepSummary(CommunityPlanModel plan) {
    final invitedCount = plan.participants
        .where((participant) => !participant.isOrganizer)
        .length;
    final playersLabel = invitedCount == 1 ? 'jugador' : 'jugadores';
    return '${_formatDisplayDate(plan.scheduledDate)} a las '
        '${_formatDisplayTime(plan.scheduledTime)} · '
        '$invitedCount $playersLabel convocados';
  }

  String _statusStepLabel(CommunityPlanModel plan) {
    if (plan.reservationConfirmed) {
      return 'Estado resuelto';
    }
    if (plan.reservationState == 'retry') {
      return 'Lista para reintento';
    }
    if (plan.isCancelled) {
      return 'Convocatoria cancelada';
    }
    if (plan.isExpired) {
      return 'Convocatoria expirada';
    }
    return 'Todos han respondido';
  }

  String _buildStatusStepSummary(CommunityPlanModel plan) {
    if (plan.reservationConfirmed) {
      return 'Todos aceptaron y la convocatoria ya pasó a reserva confirmada.';
    }
    if (plan.reservationState == 'retry') {
      return 'Todos aceptaron. La reserva sigue abierta para un segundo intento.';
    }
    if (plan.isCancelled) {
      return 'La convocatoria quedó cancelada y ya no requiere seguimiento.';
    }
    if (plan.isExpired) {
      return 'La fecha pasó y la convocatoria se cerró automáticamente.';
    }
    return 'Todos aceptaron y ya puedes continuar con la reserva del club.';
  }

  String _reservationStepLabel(CommunityPlanModel plan) {
    if (plan.reservationConfirmed) {
      return 'Reserva confirmada';
    }
    if (plan.isCancelled) {
      return 'Reserva cancelada';
    }
    if (plan.isExpired) {
      return 'Reserva expirada';
    }
    return 'Reserva cerrada';
  }

  String _buildReservationStepSummary(
    CommunityPlanModel plan,
    CommunityVenueModel? venue,
  ) {
    final venueName = plan.venue?.name ?? venue?.name ?? 'el club';
    if (plan.reservationConfirmed) {
      return 'Confirmada con $venueName. Al refrescar, esta convocatoria '
          'saldrá de Reservar.';
    }
    if (plan.isCancelled) {
      return 'La reserva quedó cancelada y la convocatoria pasa a historial.';
    }
    if (plan.isExpired) {
      return 'La convocatoria expiró antes de cerrar la reserva.';
    }
    return 'La reserva ya no necesita más acciones.';
  }

  String _calendarSyncLabel(String rawStatus) {
    switch (rawStatus.trim().toLowerCase()) {
      case 'synced':
      case 'sincronizada':
        return 'Calendar sincronizado';
      case 'error':
        return 'Calendar con incidencia';
      default:
        return 'Calendar pendiente';
    }
  }

  PadelBadgeVariant _calendarSyncVariant(String rawStatus) {
    switch (rawStatus.trim().toLowerCase()) {
      case 'synced':
      case 'sincronizada':
        return PadelBadgeVariant.success;
      case 'error':
        return PadelBadgeVariant.danger;
      default:
        return PadelBadgeVariant.warning;
    }
  }

  String? _formatHistoryTimestamp(String? rawValue) {
    if (rawValue == null || rawValue.trim().isEmpty) {
      return null;
    }

    final parsed = DateTime.tryParse(rawValue);
    if (parsed == null) {
      return rawValue;
    }

    final local = parsed.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month a las $hour:$minute';
  }

  void _showHistoryPlanDialog(CommunityPlanModel plan) {
    final color = _statusColorForPlan(plan);
    final venueName = plan.venue?.name ?? 'Centro deportivo';
    final date = _formatDisplayDate(plan.scheduledDate);
    final time = _formatDisplayTime(plan.scheduledTime);
    final contactPhone =
        (plan.reservationContactPhone ?? plan.venue?.phone ?? '').trim();
    final venueAddress = (plan.venue?.address ?? '').trim();
    final venueLocation = (plan.venue?.location ?? '').trim();
    final metadataBadges = <Widget>[
      PadelBadge(
        label: _modalityLabels[plan.modality] ?? plan.modality,
        variant: PadelBadgeVariant.info,
      ),
      PadelBadge(
        label: '${plan.capacity} plazas',
        variant: PadelBadgeVariant.outline,
      ),
      if (venueLocation.isNotEmpty)
        PadelBadge(
          label: venueLocation,
          variant: PadelBadgeVariant.info,
        ),
      if (plan.reservationHandledByName?.trim().isNotEmpty == true)
        PadelBadge(
          label: 'Reserva: ${plan.reservationHandledByName!.trim()}',
          variant: PadelBadgeVariant.outline,
        ),
      PadelBadge(
        label: _calendarSyncLabel(plan.calendarSyncStatus),
        variant: _calendarSyncVariant(plan.calendarSyncStatus),
      ),
    ];

    String statusLabel;
    String statusDetail;
    if (plan.reservationConfirmed) {
      statusLabel = 'Reserva confirmada';
      final detailParts = <String>['La pista quedó reservada con el club.'];
      if (plan.reservationHandledByName?.trim().isNotEmpty == true) {
        detailParts.add(
          'La gestionó ${plan.reservationHandledByName!.trim()}.',
        );
      }
      final confirmedAt = _formatHistoryTimestamp(plan.reservationConfirmedAt);
      if (confirmedAt != null) {
        detailParts.add('Confirmada el $confirmedAt.');
      }
      statusDetail = detailParts.join(' ');
    } else if (plan.isCancelled) {
      statusLabel = 'Cancelada';
      final detailParts = <String>['Esta convocatoria fue cancelada.'];
      if (plan.closedByName?.trim().isNotEmpty == true) {
        detailParts.add('La cerró ${plan.closedByName!.trim()}.');
      }
      final closedAt = _formatHistoryTimestamp(plan.closedAt);
      if (closedAt != null) {
        detailParts.add('Quedó cerrada el $closedAt.');
      }
      statusDetail = detailParts.join(' ');
    } else {
      statusLabel = 'Expirada';
      statusDetail = 'La convocatoria expiró sin llegar a completarse.';
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Cabecera ──────────────────────────────────────────────
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          venueName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$date · $time',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // ── Estado ────────────────────────────────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Icon(
                      plan.reservationConfirmed
                          ? Icons.check_circle_outline
                          : Icons.info_outline,
                      color: color,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            statusLabel,
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            statusDetail,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (metadataBadges.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: metadataBadges,
                ),
              ],
              if ((plan.postPadelPlan ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                _InlineNotice(
                  title: 'Post pádel',
                  message: plan.postPadelPlan!.trim(),
                  color: AppColors.info,
                ),
              ],
              if ((plan.notes ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                _InlineNotice(
                  title: 'Observaciones',
                  message: plan.notes!.trim(),
                  color: AppColors.warning,
                ),
              ],
              // ── Jugadores / Resultado ────────────────────────────────
              if (plan.participants.isNotEmpty)
                _HistoryPlanResultSection(plan: plan),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    context.push('/players/chat/event/${plan.id}');
                  },
                  icon: const Icon(Icons.forum_outlined),
                  label: const Text('Abrir chat del partido'),
                ),
              ),
              const SizedBox(height: 20),
              // ── Contacto del club ─────────────────────────────────────
              const Divider(color: AppColors.border, height: 1),
              const SizedBox(height: 16),
              const Text(
                'Contacto del club',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            contactPhone.isNotEmpty
                                ? contactPhone
                                : 'Teléfono pendiente de configurar',
                            style: TextStyle(
                              color: contactPhone.isNotEmpty
                                  ? Colors.white
                                  : AppColors.muted,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_outlined,
                              size: 18, color: AppColors.muted),
                          tooltip: 'Copiar texto',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            final template =
                                _buildReservationTemplate(plan, plan.venue);
                            Clipboard.setData(ClipboardData(text: template));
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text('Texto copiado'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    if (venueAddress.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        venueAddress,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    if (venueLocation.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        venueLocation,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (plan.closedReason?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Motivo de cierre: ${plan.closedReason!.trim()}',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      _buildReservationTemplate(plan, plan.venue),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // ── Botón cerrar ─────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Cerrar',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistorialTab(CommunityDashboardModel dashboard) {
    final historyPlans = dashboard.historyPlans
        .where((plan) => plan.shouldAppearInHistory())
        .toList(growable: false);

    if (historyPlans.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, color: AppColors.muted, size: 42),
            SizedBox(height: 12),
            Text(
              'Sin historial todavía.',
              style: TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      itemCount: historyPlans.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final plan = historyPlans[index];
        final color = _statusColorForPlan(plan);
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showHistoryPlanDialog(plan),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.venue?.name ?? 'Convocatoria #${plan.id}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatDisplayDate(plan.scheduledDate)} · ${_formatDisplayTime(plan.scheduledTime)}',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                PadelBadge(
                  label: plan.reservationConfirmed
                      ? 'Confirmada'
                      : _inviteStateLabel(plan.inviteState),
                  variant: plan.reservationConfirmed
                      ? PadelBadgeVariant.success
                      : plan.isCancelled || plan.isExpired
                          ? PadelBadgeVariant.danger
                          : PadelBadgeVariant.neutral,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCreateCard(
    CommunityDashboardModel dashboard,
    CommunityPlanModel? selectedPlan,
  ) {
    final editable = selectedPlan == null ||
        (selectedPlan.isOrganizer && !selectedPlan.isTerminal);
    final borderColor = selectedPlan != null && selectedPlan.isOrganizer
        ? AppColors.success
        : AppColors.warning;
    final clubOptionsAsync = ref.watch(communityClubOptionsProvider);
    final clubOptions =
        clubOptionsAsync.valueOrNull ?? const <CommunityVenueModel>[];
    final preferredVenue = dashboard.venue;
    final availableClubOptions = <CommunityVenueModel>[
      if (selectedPlan?.venue != null) selectedPlan!.venue!,
      if (preferredVenue != null) preferredVenue,
      ...clubOptions.where((venue) => venue.id != preferredVenue?.id),
    ];
    final resolvedClubId = _resolvedDraftClubId(dashboard);
    final selectedClubValue = availableClubOptions.any(
      (venue) => venue.id == resolvedClubId,
    )
        ? resolvedClubId
        : null;

    return _CommunityCard(
      borderColor: borderColor,
      title: '1. Convoca a tu red',
      subtitle: editable
          ? 'Elige fecha, hora, modalidad, club y completa la convocatoria con jugadores de Mi red.'
          : selectedPlan.isTerminal
              ? 'Esta convocatoria ya está cerrada. Puedes consultarla, pero no editarla.'
              : 'Esta convocatoria la ha lanzado otro jugador. Para crear la tuya, pulsa en "Nueva convocatoria".',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!editable)
            const _InlineNotice(
              title: 'Convocatoria bloqueada para edición',
              message:
                  'Solo el creador puede cambiar jugadores y horario. Puedes seguir el estado en las otras tarjetas.',
              color: AppColors.info,
            ),
          if (editable &&
              selectedPlan != null &&
              selectedPlan.isOrganizer &&
              selectedPlan.hasDecline)
            const _InlineNotice(
              title: 'Jugador retirado — selecciona un sustituto',
              message:
                  'Elige un nuevo compañero de tu red para completar el grupo y pulsa «Actualizar invitación». No podrás avanzar sin cubrir la baja.',
              color: AppColors.danger,
            ),
          Row(
            children: [
              Expanded(
                child: _PickerTile(
                  label: 'Fecha',
                  value: _formatDisplayDate(_formatApiDate(_draftDate)),
                  onTap: editable ? _pickDate : null,
                  icon: Icons.calendar_today_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PickerTile(
                  label: 'Hora',
                  value: _formatDisplayTime(_formatApiTime(_draftTime)),
                  onTap: editable ? _pickTime : null,
                  icon: Icons.schedule_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Formato del partido',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          _ModalitySegmentedControl(
            labels: _modalityLabels,
            selected: _draftModality,
            onChanged: editable ? _setDraftModality : null,
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              _draftModality == 'americana'
                  ? 'Americana reserva 8 plazas: tú y 7 jugadores más. El marcador específico se definirá en una fase posterior.'
                  : 'Esta convocatoria reserva 4 plazas: tú y hasta 3 jugadores más.',
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<int>(
            key: ValueKey(selectedClubValue),
            initialValue: selectedClubValue,
            isExpanded: true,
            dropdownColor: AppColors.surface,
            decoration: InputDecoration(
              labelText: 'Club',
              hintText: 'Selecciona el club',
              labelStyle: const TextStyle(color: AppColors.muted),
              filled: true,
              fillColor: AppColors.surface2,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
            items: availableClubOptions
                .where((venue) => venue.id != null)
                .map(
                  (venue) => DropdownMenuItem<int>(
                    value: venue.id!,
                    child: Text(
                      venue.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: editable ? _setDraftClubId : null,
          ),
          if (clubOptionsAsync.isLoading && availableClubOptions.isEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Cargando clubes disponibles...',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: _postPadelPlanController,
            enabled: editable,
            maxLength: 80,
            decoration: InputDecoration(
              labelText: 'Post pádel',
              hintText: 'Choripán, cañas, cena o plan después del partido',
              labelStyle: const TextStyle(color: AppColors.muted),
              counterStyle: const TextStyle(color: AppColors.muted),
              filled: true,
              fillColor: AppColors.surface2,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            enabled: editable,
            minLines: 2,
            maxLines: 4,
            maxLength: 240,
            decoration: InputDecoration(
              labelText: 'Observaciones',
              hintText: 'Añade detalles útiles para la invitación',
              labelStyle: const TextStyle(color: AppColors.muted),
              counterStyle: const TextStyle(color: AppColors.muted),
              filled: true,
              fillColor: AppColors.surface2,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Text(
                'Compañeros disponibles',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              Text(
                '${_selectedParticipantIds.length}/$_maxInvitedParticipants',
                style: const TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _draftModality == 'americana'
                ? 'Aparecen únicamente los jugadores de tu red que ya han aceptado jugar contigo. En Americana necesitas completar 8 plazas.'
                : 'Aparecen únicamente los jugadores de tu red que ya han aceptado jugar contigo.',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (dashboard.companions.isEmpty)
            const _EmptyCardMessage(
              message:
                  'Tu red todavía está vacía. Acepta compañeros en Jugadores > Mi red para empezar a convocar partidos.',
            )
          else
            Column(
              children: dashboard.companions
                  .map(
                    (player) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ParticipantTile(
                        player: player,
                        selected:
                            _selectedParticipantIds.contains(player.userId),
                        enabled: editable,
                        onTap:
                            editable ? () => _toggleParticipant(player) : null,
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: !_busy && editable
                  ? () => _submitPlan(dashboard, selectedPlan)
                  : null,
              child: _busy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      selectedPlan != null && selectedPlan.isOrganizer
                          ? 'Actualizar invitación'
                          : 'Enviar invitación',
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(CommunityPlanModel? plan) {
    if (plan == null) {
      return const _CommunityCard(
        borderColor: AppColors.border,
        title: '2. Estado de la convocatoria',
        subtitle: 'Aquí verás a quién has convocado y cómo responde cada uno.',
        child: _EmptyCardMessage(
          message:
              'Cuando lances una convocatoria, esta tarjeta mostrará quién está pendiente, quién acepta y si alguien propone otro horario.',
        ),
      );
    }

    final currentUser = plan.currentUserParticipant;

    return _CommunityCard(
      borderColor: _inviteStateColor(plan.inviteState),
      title: '2. Estado de la convocatoria',
      subtitle:
          'Todos los participantes ven este estado compartido y las alertas que les afecten.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusPill(
                label: _inviteStateLabel(plan.inviteState),
                color: _inviteStateColor(plan.inviteState),
              ),
              PadelBadge(
                label:
                    '${_formatDisplayDate(plan.scheduledDate)} · ${_formatDisplayTime(plan.scheduledTime)}',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PadelBadge(
                label: _modalityLabels[plan.modality] ?? plan.modality,
                variant: PadelBadgeVariant.info,
              ),
              PadelBadge(
                label: '${plan.capacity} plazas',
                variant: PadelBadgeVariant.outline,
              ),
              if ((plan.venue?.name ?? '').trim().isNotEmpty)
                PadelBadge(
                  label: plan.venue!.name,
                  variant: PadelBadgeVariant.outline,
                ),
            ],
          ),
          if ((plan.postPadelPlan ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            _InlineNotice(
              title: 'Post pádel',
              message: plan.postPadelPlan!.trim(),
              color: AppColors.info,
            ),
          ],
          if ((plan.notes ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            _InlineNotice(
              title: 'Observaciones',
              message: plan.notes!.trim(),
              color: AppColors.warning,
            ),
          ],
          const SizedBox(height: 14),
          if (plan.hasDecline)
            _InlineNotice(
              title: 'Hay una baja en la convocatoria',
              message: plan.lastDeclinedByName != null
                  ? '${plan.lastDeclinedByName} no ha podido participar esta vez. El organizador debe sustituirlo o cancelar.'
                  : 'Uno de los jugadores no puede participar esta vez. El organizador debe sustituirlo o cancelar.',
              color: AppColors.danger,
            ),
          if (plan.hasRescheduleProposal)
            _InlineNotice(
              title: 'Nuevo horario propuesto',
              message:
                  '${plan.lastRescheduleByName ?? 'Un jugador'} propone jugar el ${_formatDisplayDate(plan.lastRescheduleDate ?? plan.scheduledDate)} a las ${_formatDisplayTime(plan.lastRescheduleTime ?? plan.scheduledTime)}.',
              color: AppColors.info,
            ),
          if (plan.isReady)
            const _InlineNotice(
              title: 'Convocatoria lista',
              message:
                  'Todos han aceptado. Ya puedes pasar a la reserva con el centro deportivo.',
              color: AppColors.success,
            ),
          if (plan.isCancelled)
            _InlineNotice(
              title: 'Convocatoria cancelada',
              message: plan.closedReason == 'retry_timeout'
                  ? 'Se cerró automáticamente tras 24 horas en segundo intento.'
                  : 'El organizador la ha cancelado y ahora queda guardada en el historial.',
              color: AppColors.danger,
            ),
          if (plan.isExpired)
            const _InlineNotice(
              title: 'Convocatoria expirada',
              message:
                  'La fecha ya pasó y el sistema la ha cerrado automáticamente para que no quede en el aire.',
              color: AppColors.warning,
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/players/chat/event/${plan.id}'),
              icon: const Icon(Icons.forum_outlined),
              label: const Text('Abrir chat del partido'),
            ),
          ),
          const SizedBox(height: 8),
          Column(
            children: plan.participants
                .map(
                  (participant) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _CommunityParticipantStatusTile(
                      participant: participant,
                    ),
                  ),
                )
                .toList(growable: false),
          ),
          // Gap 4: muestra la respuesta actual del invitado y permite cambiarla
          if (!plan.isTerminal &&
              currentUser != null &&
              !currentUser.isOrganizer) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    color: AppColors.muted, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Tu respuesta: ${_responseStateLabel(currentUser.responseState)}',
                  style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Puedes cambiarla en cualquier momento.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton(
                  onPressed:
                      _busy ? null : () => _respondToPlan(plan, 'accepted'),
                  style: currentUser.responseState == 'accepted'
                      ? FilledButton.styleFrom(
                          backgroundColor: AppColors.success)
                      : null,
                  child: const Text('Acepto'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : () => _respondToPlan(plan, 'doubt'),
                  style: currentUser.responseState == 'doubt'
                      ? OutlinedButton.styleFrom(
                          foregroundColor: AppColors.warning,
                          side: const BorderSide(color: AppColors.warning))
                      : null,
                  child: const Text('Estoy en duda'),
                ),
                OutlinedButton(
                  onPressed:
                      _busy ? null : () => _respondToPlan(plan, 'declined'),
                  style: currentUser.responseState == 'declined'
                      ? OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          side: const BorderSide(color: AppColors.danger))
                      : null,
                  child: const Text('No puedo'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : () => _proposeNewTime(plan),
                  child: const Text('Proponer horario'),
                ),
              ],
            ),
          ],
          if (plan.isOrganizer && plan.hasDecline) ...[
            const SizedBox(height: 12),
            const Text(
              'Vuelve a la primera tarjeta para sustituir al jugador que se ha caído.',
              style: TextStyle(color: AppColors.muted),
            ),
          ],
          // Gap 2: nadie ha respondido en >24h — avisa al organizador
          if (_needsAttention24h(plan)) ...[
            const SizedBox(height: 12),
            const _InlineNotice(
              title: 'Nadie ha respondido en 24 horas',
              message:
                  'Tu convocatoria lleva más de un día sin ninguna respuesta. Considera cancelarla y lanzar una nueva.',
              color: AppColors.warning,
            ),
          ],
          if (plan.isOrganizer && !plan.isTerminal) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _busy ? null : () => _cancelPlan(plan),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.danger,
                ),
                child: const Text('Cancelar convocatoria'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReservationCard(
    CommunityPlanModel? plan,
    CommunityVenueModel? venue,
  ) {
    if (plan == null) {
      return const _CommunityCard(
        borderColor: AppColors.border,
        title: '3. Reserva con el club',
        subtitle: 'Aquí se coordina quién llama y qué mensaje se envía.',
        child: _EmptyCardMessage(
          message:
              'Cuando la convocatoria esté creada, esta tarjeta generará la plantilla de reserva y el seguimiento con el centro.',
        ),
      );
    }

    final participants = plan.participants;
    final dropdownValue = participants.any(
      (participant) => participant.userId == _reservationHandlerUserId,
    )
        ? _reservationHandlerUserId
        : participants.firstOrNull?.userId;
    final readyForReservation = plan.isReady || plan.reservationConfirmed;
    final reservationBlocked = plan.isCancelled || plan.isExpired;

    return _CommunityCard(
      borderColor: plan.reservationConfirmed
          ? AppColors.success
          : reservationBlocked
              ? AppColors.danger
              : AppColors.warning,
      title: '3. Reserva con el club',
      subtitle:
          'Una sola persona llama o escribe al centro, pero todos ven el mismo estado.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.sports_tennis,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      venue?.name ?? 'Centro deportivo',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      plan.reservationContactPhone?.trim().isNotEmpty == true
                          ? 'Teléfono de reserva: ${plan.reservationContactPhone}'
                          : venue?.phone?.trim().isNotEmpty == true
                              ? 'Teléfono: ${venue!.phone}'
                              : 'Sin teléfono configurado todavía.',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    if (venue?.address?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        venue!.address!.trim(),
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ],
                    if (venue?.location?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 2),
                      Text(
                        venue!.location!.trim(),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (plan.reservationConfirmed)
                const _StatusPill(
                  label: 'Verde',
                  color: AppColors.success,
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (!readyForReservation)
            const _InlineNotice(
              title: 'Pendiente de aceptación',
              message:
                  'La reserva se activa cuando todos los jugadores aceptan la convocatoria.',
              color: AppColors.warning,
            ),
          if (reservationBlocked)
            const _InlineNotice(
              title: 'Reserva cerrada',
              message:
                  'Esta convocatoria ya no admite intentos de reserva porque ha quedado cancelada o expirada.',
              color: AppColors.danger,
            ),
          if (plan.reservationHandledByName?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(
              'Coordina la reserva: ${plan.reservationHandledByName!.trim()}',
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
              ),
            ),
          ],
          if (plan.reservationConfirmedAt?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              'Confirmada el ${_formatHistoryTimestamp(plan.reservationConfirmedAt)}',
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
              ),
            ),
          ],
          if (participants.isNotEmpty) ...[
            const SizedBox(height: 6),
            DropdownButtonFormField<int>(
              key: ValueKey('reservation-handler-${plan.id}-$dropdownValue'),
              initialValue: dropdownValue,
              dropdownColor: AppColors.surface2,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Quién se encarga de reservar',
              ),
              items: participants
                  .map(
                    (participant) => DropdownMenuItem<int>(
                      value: participant.userId,
                      child: Text(
                        participant.displayName,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: plan.reservationConfirmed || reservationBlocked
                  ? null
                  : (value) {
                      setState(() {
                        _reservationHandlerUserId = value;
                        _markDraftDirty();
                      });
                    },
            ),
          ],
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Plantilla de contacto',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _buildReservationTemplate(plan, venue),
                  style: const TextStyle(
                    color: AppColors.light,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _copyReservationTemplate(plan, venue),
                  icon: const Icon(Icons.copy_all_outlined),
                  label: const Text('Copiar texto'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: !_busy &&
                          readyForReservation &&
                          !reservationBlocked &&
                          !plan.reservationConfirmed
                      ? () => _updateReservation(plan, 'confirmed')
                      : null,
                  child: const Text('Reserva confirmada'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: !_busy &&
                          readyForReservation &&
                          !reservationBlocked &&
                          !plan.reservationConfirmed
                      ? () => _updateReservation(plan, 'retry')
                      : null,
                  child: const Text('Sin reserva'),
                ),
              ),
            ],
          ),
          if (plan.reservationState == 'retry') ...[
            const SizedBox(height: 10),
            const Text(
              'La tarjeta se mantiene en naranja para un segundo intento y todos los convocados reciben el aviso.',
              style: TextStyle(color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }

  Color _statusColorForPlan(CommunityPlanModel plan) {
    if (plan.reservationConfirmed) {
      return AppColors.success;
    }
    if (plan.isCancelled) {
      return AppColors.danger;
    }
    if (plan.isExpired) {
      return AppColors.warning;
    }
    return _inviteStateColor(plan.inviteState);
  }

  Color _inviteStateColor(String state) {
    switch (state) {
      case 'ready':
        return AppColors.success;
      case 'replacement_required':
      case 'cancelled':
        return AppColors.danger;
      case 'reschedule_pending':
        return AppColors.info;
      case 'expired':
        return AppColors.warning;
      case 'pending':
      default:
        return AppColors.warning;
    }
  }

  String _inviteStateLabel(String state) {
    switch (state) {
      case 'ready':
        return 'Todos aceptan';
      case 'replacement_required':
        return 'Hay una baja';
      case 'reschedule_pending':
        return 'Horario propuesto';
      case 'cancelled':
        return 'Cancelada';
      case 'expired':
        return 'Expirada';
      case 'pending':
      default:
        return 'Esperando respuestas';
    }
  }

  DateTime _nextSuggestedDateTime() {
    final now = DateTime.now();
    if (now.hour >= 21) {
      return DateTime(now.year, now.month, now.day + 1, 18, 0);
    }
    return DateTime(now.year, now.month, now.day, now.hour + 1, 0);
  }

  DateTime? _parseApiDate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse('${value.trim()}T00:00:00');
  }

  TimeOfDay? _parseApiTime(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final parts = value.split(':');
    if (parts.length < 2) {
      return null;
    }

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatApiDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _formatApiTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute:00';
  }

  String _formatDisplayDate(String value) {
    final parsed = _parseApiDate(value);
    if (parsed == null) {
      return value;
    }
    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    return '$day/$month/${parsed.year}';
  }

  String _formatDisplayTime(String value) {
    final time = _parseApiTime(value);
    if (time == null) {
      return value;
    }
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  // Gap 4: etiqueta legible para el estado de respuesta del usuario
  String _responseStateLabel(String state) {
    switch (state) {
      case 'accepted':
        return 'Aceptado ✓';
      case 'doubt':
        return 'En duda';
      case 'declined':
        return 'No puedo asistir';
      default:
        return 'Sin contestar';
    }
  }

  // Gap 2: plan activo >24h sin ninguna respuesta de los invitados
  bool _needsAttention24h(CommunityPlanModel plan) {
    if (!plan.isOrganizer) return false;
    if (plan.isTerminal) return false;
    if (plan.inviteState != 'pending') return false;
    if (plan.createdAt == null) return false;
    final created = DateTime.tryParse(plan.createdAt!);
    if (created == null) return false;
    if (DateTime.now().difference(created) < const Duration(hours: 24)) {
      return false;
    }
    return plan.participants.every(
      (p) => p.isOrganizer || p.responseState == 'pending',
    );
  }

  String _greetingForTime(String scheduledTime) {
    final time = _parseApiTime(scheduledTime);
    final hour = time?.hour ?? 10;
    if (hour < 14) {
      return 'Buenos días;';
    }
    if (hour < 20) {
      return 'Buenas tardes;';
    }
    return 'Buenas noches;';
  }
}

class _CommunityPartidoTab extends StatelessWidget {
  final List<CommunityPlanModel> plans;
  final Future<void> Function(CommunityPlanModel plan) onOpenPlan;
  final String Function(String) formatDate;

  const _CommunityPartidoTab({
    required this.plans,
    required this.onOpenPlan,
    required this.formatDate,
  });

  String _timeRange(CommunityPlanModel plan) {
    if (plan.scheduledTime.isEmpty) {
      return '';
    }

    try {
      final parts = plan.scheduledTime.split(':');
      if (parts.length < 2) {
        return plan.scheduledTime;
      }
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) {
        return plan.scheduledTime;
      }

      final start = DateTime(2000, 1, 1, hour, minute);
      final end = start.add(Duration(minutes: plan.durationMinutes));
      final endHour = end.hour.toString().padLeft(2, '0');
      final endMinute = end.minute.toString().padLeft(2, '0');
      return '${plan.scheduledTime.substring(0, 5)} - $endHour:$endMinute';
    } catch (_) {
      return plan.scheduledTime;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (plans.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 32, 16, 120),
        children: const [
          Column(
            children: [
              Icon(Icons.sports_tennis, color: AppColors.muted, size: 40),
              SizedBox(height: 12),
              Text(
                'No hay partidos recientes pendientes de resultado.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted),
              ),
            ],
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      itemCount: plans.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final plan = plans[index];
        final venueName = plan.venue?.name ?? 'Centro deportivo';
        final date = formatDate(plan.scheduledDate);
        final timeRange = _timeRange(plan);

        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async => onOpenPlan(plan),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.emoji_events_outlined,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        venueName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$date · $timeRange',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.muted,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CommunityCollapsedStepCard extends StatelessWidget {
  final Color borderColor;
  final String title;
  final String statusLabel;
  final String summary;

  const _CommunityCollapsedStepCard({
    required this.borderColor,
    required this.title,
    required this.statusLabel,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: borderColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.check_circle_outline,
              color: borderColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusLabel,
                  style: TextStyle(
                    color: borderColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  summary,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityCard extends StatelessWidget {
  final Color borderColor;
  final String title;
  final String subtitle;
  final Widget child;

  const _CommunityCard({
    required this.borderColor,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ModalitySegmentedControl extends StatelessWidget {
  final Map<String, String> labels;
  final String selected;
  final ValueChanged<String>? onChanged;

  const _ModalitySegmentedControl({
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final entries = labels.entries.toList(growable: false);
    final enabled = onChanged != null;
    final borderColor = Colors.white.withValues(alpha: enabled ? 0.88 : 0.42);

    return Opacity(
      opacity: enabled ? 1 : 0.62,
      child: Container(
        height: 48,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        child: Material(
          color: Colors.transparent,
          child: Row(
            children: [
              for (var index = 0; index < entries.length; index++)
                Expanded(
                  child: _ModalitySegment(
                    label: entries[index].value,
                    selected: entries[index].key == selected,
                    showLeadingDivider: index > 0,
                    dividerColor: borderColor,
                    onTap: enabled
                        ? () => onChanged?.call(entries[index].key)
                        : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModalitySegment extends StatelessWidget {
  final String label;
  final bool selected;
  final bool showLeadingDivider;
  final Color dividerColor;
  final VoidCallback? onTap;

  const _ModalitySegment({
    required this.label,
    required this.selected,
    required this.showLeadingDivider,
    required this.dividerColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: selected ? null : onTap,
      child: Container(
        height: double.infinity,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          border: showLeadingDivider
              ? Border(left: BorderSide(color: dividerColor, width: 1.2))
              : null,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              color: selected ? AppColors.dark : Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;
  final IconData icon;

  const _PickerTile({
    required this.label,
    required this.value,
    required this.onTap,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: TextStyle(
                        color: onTap == null ? AppColors.muted : Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  final PlayerModel player;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  const _ParticipantTile({
    required this.player,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasPreferenceSummary = player.courtPreferences.isNotEmpty ||
        player.dominantHands.isNotEmpty ||
        player.availabilityPreferences.isNotEmpty ||
        player.matchPreferences.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.1)
                : AppColors.surface2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                ),
                child: Center(
                  child: Text(
                    player.displayName.isNotEmpty
                        ? player.displayName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      player.displayName,
                      style: TextStyle(
                        color: enabled ? Colors.white : AppColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        LevelBadge(
                          level: player.level,
                          mainLevel: player.mainLevel,
                          subLevel: player.subLevel,
                        ),
                        PadelBadge(
                          label: player.isAvailable
                              ? 'Disponible'
                              : 'No disponible',
                          variant: player.isAvailable
                              ? PadelBadgeVariant.success
                              : PadelBadgeVariant.outline,
                        ),
                      ],
                    ),
                    if (hasPreferenceSummary) ...[
                      const SizedBox(height: 8),
                      PreferenceSummaryChips(
                        courtPreferences: player.courtPreferences,
                        dominantHands: player.dominantHands,
                        availabilityPreferences: player.availabilityPreferences,
                        matchPreferences: player.matchPreferences,
                      ),
                    ],
                  ],
                ),
              ),
              Checkbox(
                value: selected,
                onChanged: enabled ? (_) => onTap?.call() : null,
                activeColor: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  final String title;
  final String message;
  final Color color;

  const _InlineNotice({
    required this.title,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: const TextStyle(color: Colors.white, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyCardMessage extends StatelessWidget {
  final String message;

  const _EmptyCardMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.muted, height: 1.4),
      ),
    );
  }
}

class _CommunityParticipantStatusTile extends StatelessWidget {
  final CommunityParticipantModel participant;

  const _CommunityParticipantStatusTile({
    required this.participant,
  });

  @override
  Widget build(BuildContext context) {
    final hasPreferenceSummary = participant.courtPreferences.isNotEmpty ||
        participant.dominantHands.isNotEmpty ||
        participant.availabilityPreferences.isNotEmpty ||
        participant.matchPreferences.isNotEmpty;
    final badgeVariant = switch (participant.responseState) {
      'accepted' => PadelBadgeVariant.success,
      'declined' => PadelBadgeVariant.danger,
      'doubt' => PadelBadgeVariant.info,
      _ => PadelBadgeVariant.warning,
    };
    final responseLabel = switch (participant.responseState) {
      'accepted' => 'Acepta',
      'declined' => 'No puede',
      'doubt' => 'En duda',
      _ => 'En espera',
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                participant.displayName.isNotEmpty
                    ? participant.displayName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        participant.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (participant.isOrganizer) ...[
                      const SizedBox(width: 8),
                      const PadelBadge(
                        label: 'Organiza',
                        variant: PadelBadgeVariant.info,
                      ),
                    ],
                    if (participant.isCurrentUser) ...[
                      const SizedBox(width: 8),
                      const PadelBadge(
                        label: 'Tú',
                        variant: PadelBadgeVariant.outline,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                LevelBadge(
                  level: participant.numericLevel,
                  mainLevel: participant.mainLevel,
                  subLevel: participant.subLevel,
                ),
                if (hasPreferenceSummary) ...[
                  const SizedBox(height: 8),
                  PreferenceSummaryChips(
                    courtPreferences: participant.courtPreferences,
                    dominantHands: participant.dominantHands,
                    availabilityPreferences:
                        participant.availabilityPreferences,
                    matchPreferences: participant.matchPreferences,
                  ),
                ],
              ],
            ),
          ),
          PadelBadge(label: responseLabel, variant: badgeVariant),
        ],
      ),
    );
  }
}

class _CommunityErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _CommunityErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.danger, size: 42),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNullExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

// ---------------------------------------------------------------------------
// Invitation card widget
// ---------------------------------------------------------------------------
class _InvitationCard extends StatelessWidget {
  final CommunityPlanModel plan;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onDoubt;
  final VoidCallback onSuggestTime;
  final VoidCallback onOpenChat;
  final String Function(String) formatDate;
  final String Function(String) formatTime;

  const _InvitationCard({
    required this.plan,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
    required this.onDoubt,
    required this.onSuggestTime,
    required this.onOpenChat,
    required this.formatDate,
    required this.formatTime,
  });

  Color _responseColor(String? state) {
    switch (state) {
      case 'accepted':
        return AppColors.success;
      case 'declined':
        return AppColors.danger;
      case 'doubt':
        return AppColors.warning;
      default:
        return AppColors.muted;
    }
  }

  String _responseLabel(String? state) {
    switch (state) {
      case 'accepted':
        return 'Has aceptado';
      case 'declined':
        return 'Has declinado';
      case 'doubt':
        return 'Estás en duda';
      default:
        return 'Pendiente de respuesta';
    }
  }

  @override
  Widget build(BuildContext context) {
    final venueName = plan.venue?.name ?? 'Centro deportivo';
    final venueLine = plan.venue?.location?.trim().isNotEmpty == true
        ? '$venueName · ${plan.venue!.location!.trim()}'
        : venueName;
    final date = formatDate(plan.scheduledDate);
    final time = formatTime(plan.scheduledTime);
    final responseColor = _responseColor(plan.myResponseState);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cabecera ─────────────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.person, color: AppColors.primary, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      children: [
                        TextSpan(
                          text: plan.creatorName,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const TextSpan(text: ' te ha invitado a jugar'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // ── Detalles ─────────────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    color: AppColors.muted, size: 14),
                const SizedBox(width: 6),
                Text(
                  '$date · $time',
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    color: AppColors.muted, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    venueLine,
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                PadelBadge(
                  label: _CommunityScreenState._modalityLabels[plan.modality] ??
                      plan.modality,
                  variant: PadelBadgeVariant.info,
                ),
                PadelBadge(
                  label: '${plan.capacity} plazas',
                  variant: PadelBadgeVariant.outline,
                ),
              ],
            ),
            if ((plan.postPadelPlan ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Post pádel: ${plan.postPadelPlan!.trim()}',
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ],
            if ((plan.notes ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                plan.notes!.trim(),
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ],
            const SizedBox(height: 12),
            // ── Estado actual ─────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: responseColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _responseLabel(plan.myResponseState),
                  style: TextStyle(
                    color: responseColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 12),
            // ── Botones de respuesta ──────────────────────────────────
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ResponseButton(
                  label: 'Acepto',
                  icon: Icons.check_circle_outline,
                  color: AppColors.success,
                  selected: plan.myResponseState == 'accepted',
                  onPressed: busy ? null : onAccept,
                ),
                _ResponseButton(
                  label: 'No puedo',
                  icon: Icons.cancel_outlined,
                  color: AppColors.danger,
                  selected: plan.myResponseState == 'declined',
                  onPressed: busy ? null : onDecline,
                ),
                _ResponseButton(
                  label: 'Estoy dudando',
                  icon: Icons.help_outline,
                  color: AppColors.warning,
                  selected: plan.myResponseState == 'doubt',
                  onPressed: busy ? null : onDoubt,
                ),
                _ResponseButton(
                  label: 'Sugerir horario',
                  icon: Icons.schedule,
                  color: AppColors.muted,
                  selected: false,
                  onPressed: busy ? null : onSuggestTime,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onOpenChat,
                icon: const Icon(Icons.forum_outlined),
                label: const Text('Abrir chat del partido'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResponseButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback? onPressed;

  const _ResponseButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 15),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        foregroundColor: selected ? AppColors.dark : color,
        backgroundColor: selected ? color : Colors.transparent,
        side: BorderSide(color: color),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _HistoryPlanResultSection extends ConsumerStatefulWidget {
  final CommunityPlanModel plan;

  const _HistoryPlanResultSection({required this.plan});

  @override
  ConsumerState<_HistoryPlanResultSection> createState() =>
      _HistoryPlanResultSectionState();
}

class _HistoryPlanResultSectionState
    extends ConsumerState<_HistoryPlanResultSection> {
  late Future<MatchResultModel?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<MatchResultModel?> _load() async {
    try {
      return await ref
          .read(communityActionsProvider)
          .fetchMatchResult(widget.plan.id);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MatchResultModel?>(
      future: _future,
      builder: (context, snapshot) {
        final result = snapshot.data;
        if (result != null && result.isConsensuado) {
          return _ConsensusView(plan: widget.plan, result: result);
        }
        return _PlainPlayersView(plan: widget.plan);
      },
    );
  }
}

class _PlainPlayersView extends StatelessWidget {
  final CommunityPlanModel plan;

  const _PlainPlayersView({required this.plan});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          'Jugadores',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        ...plan.participants.map(
          (p) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Icon(
                  p.role == 'organizer'
                      ? Icons.star_rounded
                      : Icons.person_outline,
                  color: p.role == 'organizer'
                      ? AppColors.primary
                      : AppColors.muted,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    p.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (p.numericLevel > 0)
                  LevelBadge(
                    level: p.numericLevel,
                    mainLevel: p.mainLevel,
                    subLevel: p.subLevel,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ConsensusView extends StatelessWidget {
  final CommunityPlanModel plan;
  final MatchResultModel result;

  const _ConsensusView({required this.plan, required this.result});

  String _namesFor(List<int> userIds) {
    final names = <String>[];
    for (final uid in userIds) {
      for (final p in plan.participants) {
        if (p.userId == uid) {
          names.add(p.displayName);
          break;
        }
      }
    }
    return names.join(' + ');
  }

  @override
  Widget build(BuildContext context) {
    final winner = result.winnerTeam;
    final teamAName = _namesFor(result.teamAUserIds);
    final teamBName = _namesFor(result.teamBUserIds);
    final setsAWon = result.sets.where((s) => s.a > s.b).length;
    final setsBWon = result.sets.where((s) => s.b > s.a).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          'Resultado',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        _TeamRow(
          name: teamAName.isEmpty ? 'Equipo 1' : teamAName,
          isWinner: winner == 1,
          setsWon: setsAWon,
        ),
        const SizedBox(height: 8),
        _TeamRow(
          name: teamBName.isEmpty ? 'Equipo 2' : teamBName,
          isWinner: winner == 2,
          setsWon: setsBWon,
        ),
        if (result.sets.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.sports_tennis,
                    color: AppColors.muted, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result.sets.map((s) => '${s.a}-${s.b}').join(' · '),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _TeamRow extends StatelessWidget {
  final String name;
  final bool isWinner;
  final int setsWon;

  const _TeamRow({
    required this.name,
    required this.isWinner,
    required this.setsWon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isWinner
            ? AppColors.primary.withValues(alpha: 0.12)
            : AppColors.surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isWinner ? AppColors.primary : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isWinner ? Icons.emoji_events : Icons.group_outlined,
            color: isWinner ? AppColors.primary : AppColors.muted,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: isWinner ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          if (isWinner)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Text(
                'Ganadores',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Text(
            '$setsWon',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
