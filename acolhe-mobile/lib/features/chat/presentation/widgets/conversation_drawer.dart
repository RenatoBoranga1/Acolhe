import 'package:acolhe_mobile/shared/models/app_models.dart';
import 'package:acolhe_mobile/shared/widgets/brand_logo.dart';
import 'package:acolhe_mobile/shared/widgets/design_system.dart';
import 'package:flutter/material.dart';

class ConversationDrawer extends StatelessWidget {
  const ConversationDrawer({
    required this.currentRoute,
    required this.activeConversationId,
    required this.conversations,
    required this.onNewConversation,
    required this.onSelectConversation,
    required this.onRenameConversation,
    required this.onDeleteConversation,
    required this.onNavigate,
    super.key,
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
            : Colors.white.withValues(alpha: 0.92),
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
              AcolheBrandLockup(
                markSize: 42,
                showTagline: false,
                onDark: theme.brightness == Brightness.dark,
              ),
              const SizedBox(height: 10),
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
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
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
