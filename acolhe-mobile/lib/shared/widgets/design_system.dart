import 'package:acolhe_mobile/core/theme/app_theme.dart';
import 'package:acolhe_mobile/shared/models/app_models.dart';
import 'package:flutter/material.dart';

class AppButton extends StatelessWidget {
  const AppButton.primary({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
  }) : secondary = false;

  const AppButton.secondary({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
  }) : secondary = true;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18),
          const SizedBox(width: 10),
        ],
        Flexible(child: Text(label)),
      ],
    );

    if (secondary) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: child,
      );
    }

    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      child: child,
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    required this.title,
    this.subtitle,
    super.key,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ],
    );
  }
}

class GlassCard extends StatelessWidget {
  const GlassCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18212A) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? const Color(0xFF263645) : const Color(0xFFE8DDD2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.16 : 0.04),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

class HomeFeatureCard extends StatelessWidget {
  const HomeFeatureCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    super.key,
    this.tone,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final color = tone ?? Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Ink(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: color.withOpacity(0.18)),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withOpacity(0.16),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class RiskBanner extends StatelessWidget {
  const RiskBanner({
    required this.risk,
    super.key,
  });

  final RiskAssessment risk;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (risk.level) {
      RiskLevel.low => (
          AcolheTheme.forest.withOpacity(0.12),
          AcolheTheme.forest
        ),
      RiskLevel.moderate => (
          AcolheTheme.clay.withOpacity(0.12),
          AcolheTheme.clay
        ),
      RiskLevel.high => (AcolheTheme.rose.withOpacity(0.12), AcolheTheme.rose),
      RiskLevel.critical => (const Color(0xFF7E2628), const Color(0xFFFFE6E6)),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_outlined, color: foreground),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              risk.level.index >= RiskLevel.high.index
                  ? 'Risco ${risk.level.label}. Priorize seguranca imediata e apoio humano.'
                  : 'Risco ${risk.level.label}. Podemos seguir com cuidado e sem pressa.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

class StatusNoticeBanner extends StatelessWidget {
  const StatusNoticeBanner({
    required this.message,
    super.key,
    this.icon = Icons.info_outline_rounded,
    this.tone,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final IconData icon;
  final Color? tone;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final resolvedTone = tone ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: resolvedTone.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: resolvedTone.withOpacity(0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, color: resolvedTone, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 10),
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.controller,
    required this.label,
    super.key,
    this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.obscureText = false,
    this.focusNode,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool obscureText;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      maxLines: maxLines,
      keyboardType: keyboardType,
      obscureText: obscureText,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        alignLabelWithHint: maxLines > 1,
      ),
    );
  }
}

class QuickChip extends StatelessWidget {
  const QuickChip({
    required this.label,
    required this.onTap,
    super.key,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: icon == null ? null : Icon(icon, size: 16),
      label: Text(label),
      onPressed: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      side: BorderSide(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.18)),
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF19242E)
          : Colors.white,
    );
  }
}

class ConversationHistoryTile extends StatelessWidget {
  const ConversationHistoryTile({
    required this.conversation,
    required this.selected,
    required this.onTap,
    super.key,
    this.onRename,
    this.onDelete,
  });

  final ConversationModel conversation;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedColor = theme.colorScheme.primary;
    final riskColor = switch (conversation.lastRiskLevel) {
      RiskLevel.low => AcolheTheme.forest,
      RiskLevel.moderate => AcolheTheme.clay,
      RiskLevel.high => AcolheTheme.rose,
      RiskLevel.critical => const Color(0xFFD98585),
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: selected
              ? selectedColor.withOpacity(0.12)
              : theme.brightness == Brightness.dark
                  ? const Color(0xFF17212A)
                  : Colors.white.withOpacity(0.72),
          border: Border.all(
            color: selected
                ? selectedColor.withOpacity(0.22)
                : theme.brightness == Brightness.dark
                    ? const Color(0xFF253645)
                    : const Color(0xFFE7DED5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                color: riskColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conversation.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    conversation.previewText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatConversationTime(conversation.updatedAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color:
                          theme.textTheme.bodySmall?.color?.withOpacity(0.70),
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Mais opcoes',
              onSelected: (value) {
                if (value == 'rename') {
                  onRename?.call();
                }
                if (value == 'delete') {
                  onDelete?.call();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'rename',
                  child: Text('Renomear'),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Excluir'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SidebarSectionLabel extends StatelessWidget {
  const SidebarSectionLabel({
    required this.label,
    super.key,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              color: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.color
                  ?.withOpacity(0.72),
            ),
      ),
    );
  }
}

class NavigationActionTile extends StatelessWidget {
  const NavigationActionTile({
    required this.label,
    required this.icon,
    required this.onTap,
    super.key,
    this.selected = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone =
        selected ? theme.colorScheme.primary : theme.colorScheme.onSurface;
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      selected: selected,
      selectedTileColor: theme.colorScheme.primary.withOpacity(0.10),
      leading: Icon(icon, color: tone, size: 20),
      title: Text(label),
      onTap: onTap,
    );
  }
}

class ChatSuggestionCard extends StatelessWidget {
  const ChatSuggestionCard({
    required this.title,
    required this.caption,
    required this.onTap,
    super.key,
    this.icon = Icons.arrow_outward_rounded,
  });

  final String title;
  final String caption;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: theme.brightness == Brightness.dark
              ? const Color(0xFF18212A)
              : Colors.white.withOpacity(0.80),
          border: Border.all(
            color: theme.brightness == Brightness.dark
                ? const Color(0xFF273645)
                : const Color(0xFFE7DED5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(height: 14),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(caption, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    required this.message,
    super.key,
  });

  final ChatMessageModel message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.role == MessageRole.user;
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final maxBubbleWidth = viewportWidth >= 1180
        ? 680.0
        : viewportWidth >= 960
            ? 560.0
            : viewportWidth >= 720
                ? 460.0
                : 320.0;
    final riskAccent =
        !isUser && message.riskLevel.index >= RiskLevel.high.index;
    final background = isUser
        ? theme.colorScheme.primary
        : theme.brightness == Brightness.dark
            ? const Color(0xFF1A2530)
            : Colors.white;
    final foreground =
        isUser ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: maxBubbleWidth),
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: riskAccent
                    ? AcolheTheme.rose.withOpacity(0.45)
                    : isUser
                        ? Colors.transparent
                        : theme.brightness == Brightness.dark
                            ? const Color(0xFF273645)
                            : const Color(0xFFE6DDD5),
                width: riskAccent ? 1.3 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isUser ? 0.10 : 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: _StructuredMessageText(
              content: message.content,
              textColor: foreground,
              textStyle: theme.textTheme.bodyLarge,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              _formatConversationTime(message.createdAt),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.72),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TypingIndicatorBubble extends StatefulWidget {
  const TypingIndicatorBubble({super.key});

  @override
  State<TypingIndicatorBubble> createState() => _TypingIndicatorBubbleState();
}

class _TypingIndicatorBubbleState extends State<TypingIndicatorBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.dark
              ? const Color(0xFF1A2530)
              : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: theme.brightness == Brightness.dark
                ? const Color(0xFF273645)
                : const Color(0xFFE6DDD5),
          ),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) {
                final phase =
                    (_controller.value - (index * 0.16)).clamp(0.0, 1.0);
                final opacity = 0.30 + (phase * 0.70);
                return Container(
                  width: 8,
                  height: 8,
                  margin: EdgeInsets.only(right: index == 2 ? 0 : 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(opacity),
                    shape: BoxShape.circle,
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}

class ChatEmptyState extends StatelessWidget {
  const ChatEmptyState({
    required this.title,
    required this.subtitle,
    required this.suggestions,
    required this.onSuggestionTap,
    super.key,
  });

  final String title;
  final String subtitle;
  final List<String> suggestions;
  final ValueChanged<String> onSuggestionTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompactHeight = constraints.maxHeight < 620;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(0, isCompactHeight ? 16 : 0, 0, 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: isCompactHeight ? 0 : constraints.maxHeight,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  mainAxisAlignment: isCompactHeight
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.10),
                      ),
                      child: Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(title,
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 10),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 28),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final suggestion in suggestions)
                          SizedBox(
                            width: 220,
                            child: ChatSuggestionCard(
                              title: suggestion,
                              caption:
                                  'Use este atalho para comecar sem precisar explicar tudo de uma vez.',
                              onTap: () => onSuggestionTap(suggestion),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class ChatComposerBar extends StatelessWidget {
  const ChatComposerBar({
    required this.controller,
    required this.onSend,
    super.key,
    this.focusNode,
    this.canSend = false,
    this.inputEnabled = true,
    this.isBusy = false,
    this.compactMode = false,
    this.onRetry,
    this.errorMessage,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final FocusNode? focusNode;
  final bool canSend;
  final bool inputEnabled;
  final bool isBusy;
  final bool compactMode;
  final VoidCallback? onRetry;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, compactMode ? 10 : 14, 16, compactMode ? 12 : 16),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF10171D).withOpacity(0.96)
            : Colors.white.withOpacity(0.94),
        border: Border(
          top: BorderSide(
            color: theme.brightness == Brightness.dark
                ? const Color(0xFF263645)
                : const Color(0xFFE7DED5),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 22,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (errorMessage != null) ...[
            StatusNoticeBanner(
              message: errorMessage!,
              icon: Icons.error_outline_rounded,
              tone: theme.colorScheme.error,
              actionLabel: onRetry == null ? null : 'Tentar novamente',
              onAction: onRetry,
            ),
            const SizedBox(height: 12),
          ],
          Container(
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark
                  ? const Color(0xFF17212A)
                  : const Color(0xFFF9F6F1),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: theme.brightness == Brightness.dark
                    ? const Color(0xFF293846)
                    : const Color(0xFFE3DACE),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              16,
              compactMode ? 10 : 12,
              12,
              compactMode ? 10 : 12,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    enabled: inputEnabled,
                    minLines: 1,
                    maxLines: 6,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.newline,
                    scrollPadding: EdgeInsets.only(
                      bottom: compactMode ? 96 : 120,
                    ),
                    decoration: const InputDecoration.collapsed(
                      hintText:
                          'Escreva no seu ritmo. Voce nao precisa contar tudo de uma vez.',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: canSend
                        ? theme.colorScheme.primary
                        : theme.colorScheme.primary.withOpacity(0.36),
                  ),
                  child: IconButton(
                    tooltip: isBusy ? 'Respondendo...' : 'Enviar',
                    onPressed: canSend ? onSend : null,
                    icon: Icon(
                      isBusy
                          ? Icons.more_horiz_rounded
                          : Icons.arrow_upward_rounded,
                      color: theme.colorScheme.onPrimary,
                    ),
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

class ListEditorField extends StatelessWidget {
  const ListEditorField({
    required this.controller,
    required this.label,
    required this.hint,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: controller,
      label: label,
      hint: hint,
      maxLines: 4,
    );
  }
}

class PrivacyShieldOverlay extends StatelessWidget {
  const PrivacyShieldOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).brightness == Brightness.dark
          ? AcolheTheme.night
          : AcolheTheme.sand,
      child: Center(
        child: GlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.shield_moon_outlined, size: 36),
              const SizedBox(height: 12),
              Text('Conteudo protegido',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'A visualizacao foi ocultada para reduzir exposicao acidental.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StructuredMessageText extends StatelessWidget {
  const _StructuredMessageText({
    required this.content,
    required this.textColor,
    required this.textStyle,
  });

  final String content;
  final Color textColor;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final lines = content.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          if (line.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _buildLine(line.trim()),
            ),
      ],
    );
  }

  Widget _buildLine(String line) {
    final bulletMatch = RegExp(r'^-\s+').firstMatch(line);
    if (bulletMatch != null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: textColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              line.replaceFirst(RegExp(r'^-\s+'), ''),
              style: textStyle?.copyWith(color: textColor),
            ),
          ),
        ],
      );
    }

    final numberedMatch = RegExp(r'^(\d+)[\.\)]\s+').firstMatch(line);
    if (numberedMatch != null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${numberedMatch.group(1)}.',
            style: textStyle?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              line.replaceFirst(RegExp(r'^\d+[\.\)]\s+'), ''),
              style: textStyle?.copyWith(color: textColor),
            ),
          ),
        ],
      );
    }

    return Text(
      line,
      style: textStyle?.copyWith(color: textColor),
    );
  }
}

String _formatConversationTime(DateTime value) {
  final now = DateTime.now();
  final localValue = value.toLocal();
  final isToday = localValue.year == now.year &&
      localValue.month == now.month &&
      localValue.day == now.day;
  final hour = localValue.hour.toString().padLeft(2, '0');
  final minute = localValue.minute.toString().padLeft(2, '0');
  if (isToday) {
    return '$hour:$minute';
  }
  final day = localValue.day.toString().padLeft(2, '0');
  final month = localValue.month.toString().padLeft(2, '0');
  return '$day/$month $hour:$minute';
}
