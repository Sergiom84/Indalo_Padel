import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/adaptive_pickers.dart';
import '../models/chat_models.dart';
import '../providers/chat_provider.dart';
import '../widgets/chat_conversation_tile.dart';

class ChatConversationsScreen extends ConsumerStatefulWidget {
  const ChatConversationsScreen({super.key});

  @override
  ConsumerState<ChatConversationsScreen> createState() =>
      _ChatConversationsScreenState();
}

class _ChatConversationsScreenState
    extends ConsumerState<ChatConversationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conversationsAsync = ref.watch(chatConversationsProvider);
    final socialEventsAsync = ref.watch(chatSocialEventsProvider);

    return Scaffold(
      backgroundColor: AppColors.dark,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Chat'),
        actions: [
          IconButton(
            tooltip: 'Nuevo evento',
            onPressed: _openCreateEventSheet,
            icon: const Icon(Icons.event_available_outlined),
          ),
          IconButton(
            tooltip: 'Nuevo chat o grupo',
            onPressed: _openCreateSheet,
            icon: const Icon(Icons.add_comment_outlined),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.muted,
          tabs: const [
            Tab(text: 'Chats'),
            Tab(text: 'Agenda'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ConversationsTab(
            conversationsAsync: conversationsAsync,
            onCreatePressed: _openCreateSheet,
          ),
          _SocialAgendaTab(
            eventsAsync: socialEventsAsync,
            onCreatePressed: _openCreateEventSheet,
          ),
        ],
      ),
    );
  }

  Future<void> _openCreateSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateConversationSheet(ref: ref),
    );
  }

  Future<void> _openCreateEventSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CreateSocialEventSheet(),
    );
  }
}

class _ConversationsTab extends ConsumerWidget {
  const _ConversationsTab({
    required this.conversationsAsync,
    required this.onCreatePressed,
  });

  final AsyncValue<List<ChatConversationModel>> conversationsAsync;
  final VoidCallback onCreatePressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return conversationsAsync.when(
      data: (conversations) {
        if (conversations.isEmpty) {
          return _EmptyChatState(onCreatePressed: onCreatePressed);
        }

        return RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          onRefresh: () async => ref.refresh(chatConversationsProvider.future),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            itemCount: conversations.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final conversation = conversations[index];
              return ChatConversationTile(
                conversation: conversation,
                onTap: () {
                  context.push(
                    '/players/chat/${conversation.id}',
                    extra: conversation,
                  );
                },
              );
            },
          ),
        );
      },
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            error.toString(),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.danger),
          ),
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}

class _SocialAgendaTab extends ConsumerWidget {
  const _SocialAgendaTab({
    required this.eventsAsync,
    required this.onCreatePressed,
  });

  final AsyncValue<List<ChatSocialEventModel>> eventsAsync;
  final VoidCallback onCreatePressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return eventsAsync.when(
      data: (events) {
        if (events.isEmpty) {
          return _EmptySocialAgendaState(onCreatePressed: onCreatePressed);
        }

        return RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          onRefresh: () async => ref.refresh(chatSocialEventsProvider.future),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            itemCount: events.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return _SocialEventTile(event: events[index]);
            },
          ),
        );
      },
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            error.toString(),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.danger),
          ),
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}

class _SocialEventTile extends ConsumerStatefulWidget {
  const _SocialEventTile({required this.event});

  final ChatSocialEventModel event;

  @override
  ConsumerState<_SocialEventTile> createState() => _SocialEventTileState();
}

class _SocialEventTileState extends ConsumerState<_SocialEventTile> {
  bool _opening = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final formatter = DateFormat('EEE d MMM · HH:mm', 'es_ES');
    final scheduleLabel = event.scheduledAt == null
        ? 'Fecha pendiente'
        : formatter.format(event.scheduledAt!.toLocal());
    final venueParts = [
      event.venueName,
      event.location,
    ].where((value) => value != null && value.trim().isNotEmpty).join(' · ');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.35)),
                ),
                child: const Icon(
                  Icons.event_available_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      scheduleLabel,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (venueParts.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.place_outlined,
                  color: AppColors.muted,
                  size: 15,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    venueParts,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (event.description != null && event.description!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              event.description!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.groups_outlined,
                color: event.isJoined ? AppColors.primary : AppColors.muted,
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${event.participantCount} en el chat',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: _opening ? null : _openChat,
                icon: _opening
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.forum_outlined, size: 18),
                label: Text(event.isJoined ? 'Abrir chat' : 'Unirme'),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(
                color: AppColors.danger,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openChat() async {
    setState(() {
      _opening = true;
      _error = null;
    });

    try {
      final conversation =
          await ref.read(chatActionsProvider).openSocialEventConversation(
                widget.event.id,
              );
      if (!mounted) {
        return;
      }

      context.push('/players/chat/${conversation.id}', extra: conversation);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _opening = false;
        _error = error.toString();
      });
    }
  }
}

class _CreateSocialEventSheet extends ConsumerStatefulWidget {
  const _CreateSocialEventSheet();

  @override
  ConsumerState<_CreateSocialEventSheet> createState() =>
      _CreateSocialEventSheetState();
}

class _CreateSocialEventSheetState
    extends ConsumerState<_CreateSocialEventSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _venueController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  late DateTime _selectedDate;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 19, minute: 0);
  int _durationMinutes = 90;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _venueController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('EEE d MMM y', 'es_ES').format(_selectedDate);
    final timeLabel = _formatTimeOfDay(_selectedTime);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Nuevo evento',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _titleController,
                textInputAction: TextInputAction.next,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Titulo',
                  prefixIcon: Icon(Icons.event_note_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _venueController,
                textInputAction: TextInputAction.next,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Club o lugar',
                  prefixIcon: Icon(Icons.sports_tennis_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _locationController,
                textInputAction: TextInputAction.next,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Zona o direccion',
                  prefixIcon: Icon(Icons.place_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                minLines: 2,
                maxLines: 4,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Detalles',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : _pickDate,
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(dateLabel),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : _pickTime,
                      icon: const Icon(Icons.schedule_outlined),
                      label: Text(timeLabel),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _durationMinutes,
                dropdownColor: AppColors.surface,
                decoration: const InputDecoration(
                  labelText: 'Duracion',
                  prefixIcon: Icon(Icons.timer_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 60, child: Text('1 hora')),
                  DropdownMenuItem(value: 90, child: Text('1 h 30 min')),
                  DropdownMenuItem(value: 120, child: Text('2 horas')),
                  DropdownMenuItem(value: 180, child: Text('3 horas')),
                ],
                onChanged: _saving
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _durationMinutes = value);
                        }
                      },
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.danger),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _saving ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _submit,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add),
                      label: Text(_saving ? 'Creando...' : 'Crear'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showAdaptiveAppDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 180)),
    );
    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  Future<void> _pickTime() async {
    final picked = await showAdaptiveAppTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked == null || !mounted) {
      return;
    }

    setState(() => _selectedTime = picked);
  }

  Future<void> _submit() async {
    if (_saving) {
      return;
    }

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() {
        _error = 'Indica un titulo para el evento.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final conversation =
          await ref.read(chatActionsProvider).createSocialEvent(
                title: title,
                description: _descriptionController.text,
                venueName: _venueController.text,
                location: _locationController.text,
                scheduledDate: DateFormat('yyyy-MM-dd').format(_selectedDate),
                scheduledTime: '${_formatTimeOfDay(_selectedTime)}:00',
                durationMinutes: _durationMinutes,
              );
      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
      context.push('/players/chat/${conversation.id}', extra: conversation);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
        _error = error.toString();
      });
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _EmptySocialAgendaState extends StatelessWidget {
  const _EmptySocialAgendaState({required this.onCreatePressed});

  final VoidCallback onCreatePressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.event_available_outlined,
              color: AppColors.muted,
              size: 48,
            ),
            const SizedBox(height: 12),
            const Text(
              'No hay eventos abiertos.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Crea una quedada, clinic, pachanga o plan post padel para que otros jugadores se unan al chat.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreatePressed,
              icon: const Icon(Icons.add),
              label: const Text('Crear evento'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateConversationSheet extends ConsumerStatefulWidget {
  const _CreateConversationSheet({required this.ref});

  final WidgetRef ref;

  @override
  ConsumerState<_CreateConversationSheet> createState() =>
      _CreateConversationSheetState();
}

class _CreateConversationSheetState
    extends ConsumerState<_CreateConversationSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _titleController = TextEditingController();
  final Set<int> _selectedParticipants = <int>{};
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final networkAsync = ref.watch(chatNetworkOptionsProvider);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Nueva conversación',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              TabBar(
                controller: _tabController,
                indicatorColor: AppColors.primary,
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.muted,
                tabs: const [
                  Tab(text: 'Privado'),
                  Tab(text: 'Grupo'),
                ],
              ),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Los eventos abiertos se crean desde la pestaña Agenda.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 320,
                child: networkAsync.when(
                  data: (players) => TabBarView(
                    controller: _tabController,
                    children: [
                      _DirectTab(
                        players: players,
                        onStart: _submitDirect,
                        saving: _saving,
                      ),
                      _GroupTab(
                        players: players,
                        titleController: _titleController,
                        selectedParticipants: _selectedParticipants,
                        onToggleParticipant: _toggleParticipant,
                      ),
                    ],
                  ),
                  error: (error, _) => Center(
                    child: Text(
                      error.toString(),
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ),
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.danger),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _saving ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : _submitCurrentTab,
                      child: Text(_saving ? 'Creando...' : 'Crear'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleParticipant(int userId) {
    setState(() {
      if (_selectedParticipants.contains(userId)) {
        _selectedParticipants.remove(userId);
      } else {
        _selectedParticipants.add(userId);
      }
    });
  }

  Future<void> _submitCurrentTab() async {
    switch (_tabController.index) {
      case 1:
        await _submitGroup();
        return;
      default:
        setState(() {
          _error = 'Selecciona un jugador de tu red para iniciar el chat.';
        });
    }
  }

  Future<void> _submitDirect(int userId) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final conversation =
          await ref.read(chatActionsProvider).createDirectConversation(userId);
      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
      context.push('/players/chat/${conversation.id}', extra: conversation);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _submitGroup() async {
    if (_titleController.text.trim().isEmpty || _selectedParticipants.isEmpty) {
      setState(() {
        _error = 'Indica un nombre y al menos un jugador.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final conversation =
          await ref.read(chatActionsProvider).createGroupConversation(
                title: _titleController.text.trim(),
                participantUserIds: _selectedParticipants.toList(
                  growable: false,
                ),
              );
      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
      context.push('/players/chat/${conversation.id}', extra: conversation);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
        _error = error.toString();
      });
    }
  }
}

class _DirectTab extends StatelessWidget {
  const _DirectTab({
    required this.players,
    required this.onStart,
    required this.saving,
  });

  final List<ChatParticipantModel> players;
  final Future<void> Function(int userId) onStart;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) {
      return const _EmptyMemberList();
    }

    return ListView.separated(
      itemCount: players.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final player = players[index];
        return ListTile(
          tileColor: AppColors.surface2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: AppColors.border),
          ),
          title: Text(
            player.displayName,
            style: const TextStyle(color: Colors.white),
          ),
          subtitle: const Text(
            'Chat privado',
            style: TextStyle(color: AppColors.muted),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.send_outlined),
            color: AppColors.primary,
            onPressed: saving ? null : () => onStart(player.userId),
          ),
        );
      },
    );
  }
}

class _GroupTab extends StatelessWidget {
  const _GroupTab({
    required this.players,
    required this.titleController,
    required this.selectedParticipants,
    required this.onToggleParticipant,
  });

  final List<ChatParticipantModel> players;
  final TextEditingController titleController;
  final Set<int> selectedParticipants;
  final void Function(int userId) onToggleParticipant;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: titleController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Nombre del grupo',
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: players.isEmpty
              ? const _EmptyMemberList()
              : ListView.separated(
                  itemCount: players.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final player = players[index];
                    final selected =
                        selectedParticipants.contains(player.userId);
                    return CheckboxListTile(
                      value: selected,
                      onChanged: (_) => onToggleParticipant(player.userId),
                      title: Text(
                        player.displayName,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: const Text(
                        'Anadir al grupo',
                        style: TextStyle(color: AppColors.muted),
                      ),
                      tileColor: AppColors.surface2,
                      activeColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _EmptyChatState extends StatelessWidget {
  const _EmptyChatState({required this.onCreatePressed});

  final VoidCallback onCreatePressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.mark_chat_unread_outlined,
              color: AppColors.muted,
              size: 48,
            ),
            const SizedBox(height: 12),
            const Text(
              'Todavia no tienes conversaciones.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Abre un chat privado con tu red, monta un grupo o crea un plan abierto desde Agenda.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreatePressed,
              icon: const Icon(Icons.add_comment_outlined),
              label: const Text('Crear conversacion'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyMemberList extends StatelessWidget {
  const _EmptyMemberList();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          'Necesitas companeros en tu red para empezar un chat.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
