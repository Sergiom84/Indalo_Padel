import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/adaptive_pickers.dart';
import '../../../shared/widgets/loading_spinner.dart';
import '../../../shared/widgets/padel_badge.dart';
import '../../players/models/player_model.dart';
import '../models/community_model.dart';
import '../providers/community_provider.dart';

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen>
    with SingleTickerProviderStateMixin {
  late DateTime _draftDate;
  late TimeOfDay _draftTime;

  final Set<int> _selectedParticipantIds = <int>{};
  final Set<int> _handledNotificationIds = <int>{};

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
    _tabController = TabController(length: 2, vsync: this);
    final suggested = _nextSuggestedDateTime();
    _draftDate = DateTime(suggested.year, suggested.month, suggested.day);
    _draftTime = TimeOfDay(hour: suggested.hour, minute: suggested.minute);
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
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
        dashboard.activePlan != null) {
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
            final notificationPlan =
                snapshot != null ? _planById(snapshot, notification.planId) : null;
            final isOrganizerOfPlan = notificationPlan?.isOrganizer ?? false;
            final jumpLabel = notification.type == 'member_declined' && isOrganizerOfPlan
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
                      if (snapshot == null) {
                        return;
                      }
                      final targetPlan = _planById(snapshot, notification.planId);
                      if (targetPlan != null && mounted) {
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

  void _selectPlan(CommunityPlanModel plan) {
    setState(() {
      _applyPlanToDraftInternal(plan, token: _planToken(plan));
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

      if (_selectedParticipantIds.length >= 3) {
        _showMessage('Puedes invitar como máximo a tres compañeros.',
            isError: true);
        return;
      }

      _selectedParticipantIds.add(player.userId);
      _markDraftDirty();
    });
  }

  Future<bool> _confirmConflictsIfNeeded(CommunityPlanModel? selectedPlan) async {
    final preview = await ref.read(communityActionsProvider).previewConflicts(
          planId: selectedPlan?.id,
          scheduledDate: _formatApiDate(_draftDate),
          scheduledTime: _formatApiTime(_draftTime),
          participantUserIds: _selectedParticipantIds.toList(growable: false),
        );

    if (!preview.hasConflicts || !mounted) {
      return true;
    }

    final conflictLines = preview.conflicts
        .expand((player) => player.items.map((item) => item.message ?? player.displayName))
        .toList(growable: false);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          preview.hasHardConflicts ? 'Conflictos fuertes detectados' : 'Conflictos detectados',
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

    if (_selectedParticipantIds.length > 3) {
      _showMessage('Puedes invitar como máximo a tres compañeros.',
          isError: true);
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
    final phoneText = (venue?.phone ?? '').trim();
    final venueText = (venue?.name ?? 'Centro deportivo').trim();

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

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(communityDashboardProvider);

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
          tabs: const [
            Tab(text: 'Convocatorias'),
            Tab(text: 'Historial'),
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
                    if (selectedPlan != null || _forceNewDraft) ...[
                      const SizedBox(height: 16),
                      _buildCreateCard(dashboard, selectedPlan),
                      const SizedBox(height: 16),
                      _buildStatusCard(selectedPlan),
                      const SizedBox(height: 16),
                      _buildReservationCard(selectedPlan, reservationVenue),
                    ],
                  ],
                ),
              ),
              // ── Pestaña 2: Historial ──────────────────────────────────
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
          color: selectedPlan == null
              ? AppColors.primary
              : AppColors.border,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }

  void _showHistoryPlanDialog(CommunityPlanModel plan) {
    final color = _statusColorForPlan(plan);
    final venueName = plan.venue?.name ?? 'Centro deportivo';
    final date = _formatDisplayDate(plan.scheduledDate);
    final time = _formatDisplayTime(plan.scheduledTime);

    String statusLabel;
    String statusDetail;
    if (plan.reservationConfirmed) {
      statusLabel = 'Reserva confirmada';
      statusDetail = 'La pista quedó reservada con el club.';
    } else if (plan.isCancelled) {
      statusLabel = 'Cancelada';
      statusDetail = 'Esta convocatoria fue cancelada.';
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              // ── Jugadores ────────────────────────────────────────────
              if (plan.participants.isNotEmpty) ...[
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
                          Text(
                            'Nv ${p.numericLevel}',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
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
    if (dashboard.historyPlans.isEmpty) {
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
      itemCount: dashboard.historyPlans.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final plan = dashboard.historyPlans[index];
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
    final editable = selectedPlan == null
        || (selectedPlan.isOrganizer && !selectedPlan.isTerminal);
    final borderColor = selectedPlan != null && selectedPlan.isOrganizer
        ? AppColors.success
        : AppColors.warning;

    return _CommunityCard(
      borderColor: borderColor,
      title: '1. Convoca a tu red',
      subtitle: editable
          ? 'Elige fecha, hora y hasta tres compañeros de Mi red.'
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
                '${_selectedParticipantIds.length}/3',
                style: const TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Aparecen únicamente los jugadores de tu red que ya han aceptado jugar contigo.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
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
                          side:
                              const BorderSide(color: AppColors.warning))
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
      borderColor:
          plan.reservationConfirmed
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
                      venue?.phone?.trim().isNotEmpty == true
                          ? 'Teléfono: ${venue!.phone}'
                          : 'Sin teléfono configurado todavía.',
                      style: const TextStyle(color: AppColors.muted),
                    ),
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
              onChanged: plan.reservationConfirmed
                  || reservationBlocked
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
                        PadelBadge(label: 'Nivel ${player.level}'),
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
                Text(
                  'Nivel ${participant.numericLevel}',
                  style: const TextStyle(color: AppColors.muted),
                ),
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
