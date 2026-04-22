import 'package:acolhe_mobile/core/theme/app_theme.dart';
import 'package:acolhe_mobile/features/auth/application/auth_controller.dart';
import 'package:acolhe_mobile/features/chat/application/chat_controller.dart';
import 'package:acolhe_mobile/shared/models/app_models.dart';
import 'package:acolhe_mobile/shared/widgets/design_system.dart';
import 'package:acolhe_mobile/shared/widgets/responsive_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  static const List<String> _quickSuggestions = [
    'Nao sei por onde comecar',
    'Quero entender se isso foi assedio',
    'Estou com medo',
    'Quero registrar o que aconteceu',
    'Quero pensar nos proximos passos',
    'Quero ajuda para falar com alguem de confianca',
  ];

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _composerFocusNode = FocusNode();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _lastScrollSignature = '';

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_handleComposerChanged);
  }

  @override
  void dispose() {
    _messageController.removeListener(_handleComposerChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _composerFocusNode.dispose();
    super.dispose();
  }

  void _handleComposerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _submitMessage([String? value]) async {
    final controller = ref.read(chatControllerProvider.notifier);
    final text = (value ?? _messageController.text).trim();
    if (text.isEmpty) {
      return;
    }

    _messageController.clear();
    await controller.sendMessage(text);
    _scheduleScrollToBottom(animated: true);
  }

  void _scheduleScrollToBottom({bool animated = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      final offset = _scrollController.position.maxScrollExtent + 120;
      if (animated) {
        _scrollController.animateTo(
          offset,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scrollController.jumpTo(offset);
      }
    });
  }

  Future<void> _showRenameDialog(ConversationModel conversation) async {
    final titleController = TextEditingController(text: conversation.title);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Renomear conversa'),
        content: TextField(
          controller: titleController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Titulo',
            hintText: 'Ex.: Conversa sobre proximos passos',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(titleController.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    titleController.dispose();

    if (result == null || result.trim().isEmpty) {
      return;
    }

    await ref.read(chatControllerProvider.notifier).renameConversation(
          conversation.id,
          result,
        );
  }

  Future<void> _confirmDeleteConversation(ConversationModel conversation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir conversa'),
        content: Text(
          'A conversa "${conversation.title}" sera removida do historico local deste aparelho.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(chatControllerProvider.notifier).deleteConversation(conversation.id);
    }
  }

  void _navigateTo(String route) {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
    context.go(route);
  }

  void _openQuickExit() {
    ref.read(authControllerProvider.notifier).showPrivacyShield();
    context.go('/privacy');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final chat = ref.watch(chatControllerProvider);
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isWideLayout = AppResponsive.isTwoPaneWidth(width);
    final conversation = chat.activeConversation;
    final hasMessages = conversation.messages.isNotEmpty;
    final scrollSignature =
        '${conversation.id}:${conversation.messages.length}:${chat.isTyping}:${chat.errorMessage ?? ''}';
    final canSend = !chat.isTyping && _messageController.text.trim().isNotEmpty;

    if (_lastScrollSignature != scrollSignature && (hasMessages || chat.isTyping)) {
      _lastScrollSignature = scrollSignature;
      _scheduleScrollToBottom(animated: true);
    }

    return Scaffold(
      key: _scaffoldKey,
      resizeToAvoidBottomInset: true,
      drawer: isWideLayout
          ? null
          : Drawer(
              child: _ChatSidebar(
                currentRoute: '/chat',
                activeConversationId: conversation.id,
                conversations: chat.conversations,
                onNewConversation: () {
                  ref.read(chatControllerProvider.notifier).newConversation();
                },
                onSelectConversation: (id) async {
                  await ref.read(chatControllerProvider.notifier).switchConversation(id);
                  if (mounted) {
                    Navigator.of(context).pop();
                  }
                },
                onRenameConversation: (conversation) {
                  _showRenameDialog(conversation);
                },
                onDeleteConversation: (conversation) {
                  _confirmDeleteConversation(conversation);
                },
                onNavigate: _navigateTo,
              ),
            ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: theme.brightness == Brightness.dark
                ? const [Color(0xFF0D141A), Color(0xFF14202A), Color(0xFF0D141A)]
                : const [Color(0xFFF4EEE7), Color(0xFFF3F6F7), Color(0xFFF7F1EB)],
          ),
        ),
        child: SafeArea(
          child: Row(
            children: [
              if (isWideLayout)
                SizedBox(
                  width: 344,
                  child: _ChatSidebar(
                    currentRoute: '/chat',
                    activeConversationId: conversation.id,
                    conversations: chat.conversations,
                    onNewConversation: () {
                      ref.read(chatControllerProvider.notifier).newConversation();
                    },
                    onSelectConversation: (id) {
                      ref.read(chatControllerProvider.notifier).switchConversation(id);
                    },
                    onRenameConversation: (conversation) {
                      _showRenameDialog(conversation);
                    },
                    onDeleteConversation: (conversation) {
                      _confirmDeleteConversation(conversation);
                    },
                    onNavigate: _navigateTo,
                  ),
                ),
              Expanded(
                child: Column(
                  children: [
                    _ChatHeader(
                      appName: auth.currentAppName,
                      title: conversation.title,
                      subtitle: auth.discreetMode
                          ? 'Espaco protegido com historico local e apoio inicial.'
                          : 'Assistente de acolhimento inicial, orientacao segura e historico local protegido.',
                      risk: chat.latestRisk,
                      isWideLayout: isWideLayout,
                      onOpenMenu: () => _scaffoldKey.currentState?.openDrawer(),
                      onNewConversation: () {
                        ref.read(chatControllerProvider.notifier).newConversation();
                      },
                      onQuickExit: _openQuickExit,
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 980),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            child: !chat.isHydrated
                                ? const Center(child: CircularProgressIndicator())
                                : hasMessages
                                    ? _ConversationView(
                                        key: ValueKey('conversation-${conversation.id}'),
                                        conversation: conversation,
                                        risk: chat.latestRisk,
                                        isTyping: chat.isTyping,
                                        scrollController: _scrollController,
                                      )
                                    : ChatEmptyState(
                                        key: ValueKey('empty-${conversation.id}'),
                                        title: 'Como voce quer comecar?',
                                        subtitle:
                                            'Voce pode escrever do seu jeito ou usar um atalho. Esta conversa fica salva apenas neste aparelho.',
                                        suggestions: _quickSuggestions,
                                        onSuggestionTap: _submitMessage,
                                      ),
                          ),
                        ),
                      ),
                    ),
                    Focus(
                      onKeyEvent: (node, event) {
                        if (event is KeyDownEvent &&
                            event.logicalKey == LogicalKeyboardKey.enter &&
                            !HardwareKeyboard.instance.isShiftPressed) {
                          if (canSend) {
                            _submitMessage();
                          }
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: SafeArea(
                        top: false,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 980),
                            child: ChatComposerBar(
                              controller: _messageController,
                              focusNode: _composerFocusNode,
                              canSend: canSend,
                              inputEnabled: true,
                              isBusy: chat.isTyping,
                              errorMessage: chat.errorMessage,
                              onRetry: chat.hasRetryAvailable
                                  ? () {
                                      ref.read(chatControllerProvider.notifier).retryLastResponse();
                                    }
                                  : null,
                              onSend: _submitMessage,
                            ),
                          ),
                        ),
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

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.appName,
    required this.title,
    required this.subtitle,
    required this.risk,
    required this.isWideLayout,
    required this.onOpenMenu,
    required this.onNewConversation,
    required this.onQuickExit,
  });

  final String appName;
  final String title;
  final String subtitle;
  final RiskAssessment risk;
  final bool isWideLayout;
  final VoidCallback onOpenMenu;
  final VoidCallback onNewConversation;
  final VoidCallback onQuickExit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(isWideLayout ? 32 : 16, 18, isWideLayout ? 32 : 16, 18),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF10171D).withOpacity(0.92)
            : Colors.white.withOpacity(0.90),
        border: Border(
          bottom: BorderSide(
            color: theme.brightness == Brightness.dark
                ? const Color(0xFF263645)
                : const Color(0xFFE4DBD1),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (!isWideLayout)
                IconButton(
                  tooltip: 'Abrir menu',
                  onPressed: onOpenMenu,
                  icon: const Icon(Icons.menu_rounded),
                ),
              if (!isWideLayout) const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  appName,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Nova conversa',
                onPressed: onNewConversation,
                icon: const Icon(Icons.add_comment_outlined),
              ),
              IconButton(
                tooltip: 'Saida rapida',
                onPressed: onQuickExit,
                icon: const Icon(Icons.visibility_off_outlined),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(subtitle, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeaderInfoChip(
                icon: Icons.lock_outline_rounded,
                label: 'Historico salvo localmente',
              ),
              _HeaderInfoChip(
                icon: Icons.shield_outlined,
                label: 'Risco ${risk.level.label}',
                tone: switch (risk.level) {
                  RiskLevel.low => AcolheTheme.forest,
                  RiskLevel.moderate => AcolheTheme.clay,
                  RiskLevel.high => AcolheTheme.rose,
                  RiskLevel.critical => const Color(0xFFD98585),
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderInfoChip extends StatelessWidget {
  const _HeaderInfoChip({
    required this.icon,
    required this.label,
    this.tone,
  });

  final IconData icon;
  final String label;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final resolvedTone = tone ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: resolvedTone.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: resolvedTone.withOpacity(0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: resolvedTone),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: resolvedTone,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _ConversationView extends StatelessWidget {
  const _ConversationView({
    required this.conversation,
    required this.risk,
    required this.isTyping,
    required this.scrollController,
    super.key,
  });

  final ConversationModel conversation;
  final RiskAssessment risk;
  final bool isTyping;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      children: [
        if (conversation.messages.isNotEmpty) ...[
          StatusNoticeBanner(
            message:
                'Posso oferecer acolhimento inicial e orientacao geral. Nao substituo apoio psicologico, juridico, medico ou policial.',
            icon: Icons.info_outline_rounded,
          ),
          const SizedBox(height: 12),
          if (risk.level != RiskLevel.low || risk.requiresImmediateAction) ...[
            RiskBanner(risk: risk),
            const SizedBox(height: 12),
          ],
        ],
        for (final message in conversation.messages) ChatBubble(message: message),
        if (isTyping) const TypingIndicatorBubble(),
      ],
    );
  }
}

class _ChatSidebar extends StatelessWidget {
  const _ChatSidebar({
    required this.currentRoute,
    required this.activeConversationId,
    required this.conversations,
    required this.onNewConversation,
    required this.onSelectConversation,
    required this.onRenameConversation,
    required this.onDeleteConversation,
    required this.onNavigate,
  });

  final String currentRoute;
  final String activeConversationId;
  final List<ConversationModel> conversations;
  final VoidCallback onNewConversation;
  final ValueChanged<String> onSelectConversation;
  final ValueChanged<ConversationModel> onRenameConversation;
  final ValueChanged<ConversationModel> onDeleteConversation;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF111920)
            : Colors.white.withOpacity(0.92),
        border: Border(
          right: BorderSide(
            color: theme.brightness == Brightness.dark
                ? const Color(0xFF243544)
                : const Color(0xFFE4DBD1),
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Acolhe', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                'Conversa protegida, historico local e acesso rapido aos outros modulos.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              AppButton.primary(
                label: 'Nova conversa',
                icon: Icons.add_comment_outlined,
                onPressed: onNewConversation,
              ),
              const SizedBox(height: 20),
              const SidebarSectionLabel(label: 'Historico'),
              Expanded(
                child: ListView.separated(
                  itemCount: conversations.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final conversation = conversations[index];
                    return ConversationHistoryTile(
                      conversation: conversation,
                      selected: conversation.id == activeConversationId,
                      onTap: () => onSelectConversation(conversation.id),
                      onRename: () => onRenameConversation(conversation),
                      onDelete: () => onDeleteConversation(conversation),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              const SidebarSectionLabel(label: 'Espacos do app'),
              NavigationActionTile(
                label: 'Chat principal',
                icon: Icons.chat_bubble_outline_rounded,
                selected: currentRoute == '/chat',
                onTap: () => onNavigate('/chat'),
              ),
              NavigationActionTile(
                label: 'Visao geral',
                icon: Icons.home_outlined,
                selected: currentRoute == '/home',
                onTap: () => onNavigate('/home'),
              ),
              NavigationActionTile(
                label: 'Registro do ocorrido',
                icon: Icons.event_note_outlined,
                selected: currentRoute == '/incident-record',
                onTap: () => onNavigate('/incident-record'),
              ),
              NavigationActionTile(
                label: 'Plano de seguranca',
                icon: Icons.shield_outlined,
                selected: currentRoute == '/safety-plan',
                onTap: () => onNavigate('/safety-plan'),
              ),
              NavigationActionTile(
                label: 'Rede de apoio',
                icon: Icons.people_outline_rounded,
                selected: currentRoute == '/support-network',
                onTap: () => onNavigate('/support-network'),
              ),
              NavigationActionTile(
                label: 'Informacoes e direitos',
                icon: Icons.menu_book_outlined,
                selected: currentRoute == '/resources',
                onTap: () => onNavigate('/resources'),
              ),
              NavigationActionTile(
                label: 'Configuracoes',
                icon: Icons.lock_outline_rounded,
                selected: currentRoute == '/settings',
                onTap: () => onNavigate('/settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
