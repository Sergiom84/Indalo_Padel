import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../models/chat_models.dart';
import '../providers/chat_provider.dart';
import '../widgets/chat_conversation_tile.dart';

class ChatConversationsScreen extends ConsumerWidget {
  const ChatConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(chatConversationsProvider);

    return Scaffold(
      backgroundColor: AppColors.dark,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Chat'),
        actions: [
          IconButton(
            tooltip: 'Nueva conversación',
            onPressed: () => _openCreateSheet(context, ref),
            icon: const Icon(Icons.add_comment_outlined),
          ),
        ],
      ),
      body: conversationsAsync.when(
        data: (conversations) {
          if (conversations.isEmpty) {
            return _EmptyChatState(
              onCreatePressed: () => _openCreateSheet(context, ref),
            );
          }

          return RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.surface,
            onRefresh: () async =>
                ref.refresh(chatConversationsProvider.future),
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
      ),
    );
  }

  Future<void> _openCreateSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateConversationSheet(ref: ref),
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
                  'Los chats de evento se abren desde una convocatoria existente.',
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
              'Abre un chat privado con tu red o monta un grupo. Los chats de evento se crean desde una convocatoria existente.',
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
