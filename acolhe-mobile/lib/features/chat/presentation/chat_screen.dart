import 'package:acolhe_mobile/core/theme/app_theme.dart';
import 'package:acolhe_mobile/features/auth/application/auth_controller.dart';
import 'package:acolhe_mobile/features/chat/application/chat_controller.dart';
import 'package:acolhe_mobile/features/chat/presentation/widgets/chat_header.dart';
import 'package:acolhe_mobile/features/chat/presentation/widgets/composer.dart';
import 'package:acolhe_mobile/features/chat/presentation/widgets/conversation_drawer.dart';
import 'package:acolhe_mobile/features/chat/presentation/widgets/message_list.dart';
import 'package:acolhe_mobile/shared/models/app_models.dart';
import 'package:acolhe_mobile/shared/widgets/design_system.dart';
import 'package:acolhe_mobile/shared/widgets/responsive_layout.dart';
import 'package:flutter/material.dart';
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

  static const bool _showChatDebug = bool.fromEnvironment('ACOLHE_DEBUG_CHAT');

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _composerFocusNode = FocusNode();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _lastScrollSignature = '';
  double _lastKeyboardInset = 0;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_handleComposerChanged);
    _composerFocusNode.addListener(_handleComposerFocusChanged);
  }

  @override
  void dispose() {
    _messageController.removeListener(_handleComposerChanged);
    _composerFocusNode.removeListener(_handleComposerFocusChanged);
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

  void _handleComposerFocusChanged() {
    if (_composerFocusNode.hasFocus) {
      _scheduleScrollToBottom(animated: true);
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

  double _messageBottomPadding(BuildContext context, double keyboardInset) {
    final height = MediaQuery.sizeOf(context).height;
    if (keyboardInset > 0) {
      return (height * 0.18).clamp(108.0, 156.0);
    }
    return 36;
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
            onPressed: () =>
                Navigator.of(context).pop(titleController.text.trim()),
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

  Future<void> _confirmDeleteConversation(
    ConversationModel conversation,
  ) async {
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
      await ref
          .read(chatControllerProvider.notifier)
          .deleteConversation(conversation.id);
    }
  }

  Future<void> _newConversation({bool closeDrawer = false}) async {
    await ref.read(chatControllerProvider.notifier).newConversation();
    if (closeDrawer && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _selectConversation(String id,
      {bool closeDrawer = false}) async {
    await ref.read(chatControllerProvider.notifier).switchConversation(id);
    if (closeDrawer && mounted) {
      Navigator.of(context).pop();
    }
  }

  void _navigateTo(String route) {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
    if (route != '/chat') {
      context.go(route);
      return;
    }
    context.go('/chat');
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
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final isWideLayout = AppResponsive.showsInlineSidebar(width);
    final chatMaxWidth = AppResponsive.chatMaxWidth(width);
    final conversation = chat.activeConversation;
    final hasMessages = conversation.messages.isNotEmpty;
    final scrollSignature =
        '${conversation.id}:${conversation.messages.length}:${chat.isTyping}:${chat.errorMessage ?? ''}:${chat.latestRisk.level.name}';
    final canSend = !chat.isTyping && _messageController.text.trim().isNotEmpty;

    if (_lastScrollSignature != scrollSignature &&
        (hasMessages || chat.isTyping)) {
      _lastScrollSignature = scrollSignature;
      _scheduleScrollToBottom(animated: true);
    }
    if ((_lastKeyboardInset - keyboardInset).abs() > 1) {
      final shouldKeepLatestVisible =
          hasMessages || _composerFocusNode.hasFocus;
      _lastKeyboardInset = keyboardInset;
      if (shouldKeepLatestVisible) {
        _scheduleScrollToBottom(animated: true);
      }
    }

    return Scaffold(
      key: _scaffoldKey,
      resizeToAvoidBottomInset: true,
      drawer: isWideLayout
          ? null
          : Drawer(
              child: ConversationDrawer(
                currentRoute: '/chat',
                activeConversationId: conversation.id,
                conversations: chat.conversations,
                onNewConversation: () => _newConversation(closeDrawer: true),
                onSelectConversation: (id) =>
                    _selectConversation(id, closeDrawer: true),
                onRenameConversation: _showRenameDialog,
                onDeleteConversation: _confirmDeleteConversation,
                onNavigate: _navigateTo,
              ),
            ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: theme.brightness == Brightness.dark
                ? const [
                    Color(0xFF0D141A),
                    Color(0xFF14202A),
                    Color(0xFF0D141A),
                  ]
                : const [
                    AcolheTheme.warmShell,
                    Color(0xFFF4F7FA),
                    Color(0xFFF7F2EC),
                  ],
          ),
        ),
        child: SafeArea(
          child: Row(
            children: [
              if (isWideLayout)
                SizedBox(
                  width: AppResponsive.chatSidebarWidth(width),
                  child: ConversationDrawer(
                    currentRoute: '/chat',
                    activeConversationId: conversation.id,
                    conversations: chat.conversations,
                    onNewConversation: _newConversation,
                    onSelectConversation: _selectConversation,
                    onRenameConversation: _showRenameDialog,
                    onDeleteConversation: _confirmDeleteConversation,
                    onNavigate: _navigateTo,
                  ),
                ),
              Expanded(
                child: Column(
                  children: [
                    ChatHeader(
                      appName: auth.currentAppName,
                      title: conversation.title,
                      subtitle: auth.discreetMode
                          ? 'Espaco protegido com historico local e apoio inicial.'
                          : 'Assistente de acolhimento inicial, orientacao segura e historico local protegido.',
                      risk: chat.latestRisk,
                      syncStatus: chat.syncStatus,
                      situationType: chat.situationType,
                      responseMode: chat.responseMode,
                      lastSyncedAt: chat.lastSyncedAt,
                      showDebug: _showChatDebug,
                      isWideLayout: isWideLayout,
                      onOpenMenu: () => _scaffoldKey.currentState?.openDrawer(),
                      onNewConversation: _newConversation,
                      onQuickExit: _openQuickExit,
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: chatMaxWidth),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            child: !chat.isHydrated
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : hasMessages
                                    ? MessageList(
                                        key: ValueKey(
                                          'conversation-${conversation.id}',
                                        ),
                                        conversation: conversation,
                                        risk: chat.latestRisk,
                                        ctas: chat.latestCtas,
                                        situationType: chat.situationType,
                                        responseMode: chat.responseMode,
                                        conversationContext:
                                            chat.conversationContext,
                                        lastResponseUsedFallback:
                                            chat.lastResponseUsedFallback,
                                        lastResponseWasRepaired:
                                            chat.lastResponseWasRepaired,
                                        isTyping: chat.isTyping,
                                        scrollController: _scrollController,
                                        bottomPadding: _messageBottomPadding(
                                          context,
                                          keyboardInset,
                                        ),
                                        onNavigate: _navigateTo,
                                      )
                                    : ChatEmptyState(
                                        key: ValueKey(
                                          'empty-${conversation.id}',
                                        ),
                                        title: 'Como voce quer comecar?',
                                        subtitle:
                                            'Voce pode escrever do seu jeito ou usar um atalho. Esta conversa fica salva apenas neste aparelho.',
                                        suggestions:
                                            chat.quickSuggestions.isEmpty
                                                ? _quickSuggestions
                                                : chat.quickSuggestions,
                                        onSuggestionTap: _submitMessage,
                                      ),
                          ),
                        ),
                      ),
                    ),
                    ChatComposer(
                      controller: _messageController,
                      focusNode: _composerFocusNode,
                      canSend: canSend,
                      isBusy: chat.isTyping,
                      keyboardInset: keyboardInset,
                      maxWidth: chatMaxWidth,
                      errorMessage: chat.errorMessage,
                      onRetry: chat.hasRetryAvailable
                          ? () {
                              ref
                                  .read(chatControllerProvider.notifier)
                                  .retryLastResponse();
                            }
                          : null,
                      onSend: _submitMessage,
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
