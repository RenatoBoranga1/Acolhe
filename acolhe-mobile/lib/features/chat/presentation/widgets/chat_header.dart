import 'package:acolhe_mobile/core/theme/app_theme.dart';
import 'package:acolhe_mobile/features/chat/application/chat_controller.dart';
import 'package:acolhe_mobile/features/chat/domain/chat_intelligence_ui.dart';
import 'package:acolhe_mobile/shared/models/app_models.dart';
import 'package:acolhe_mobile/shared/widgets/brand_logo.dart';
import 'package:flutter/material.dart';

class ChatHeader extends StatelessWidget {
  const ChatHeader({
    required this.appName,
    required this.title,
    required this.subtitle,
    required this.risk,
    required this.syncStatus,
    required this.isWideLayout,
    required this.onOpenMenu,
    required this.onNewConversation,
    required this.onQuickExit,
    super.key,
    this.situationType,
    this.responseMode,
    this.lastSyncedAt,
    this.showDebug = false,
  });

  final String appName;
  final String title;
  final String subtitle;
  final RiskAssessment risk;
  final ChatSyncStatus syncStatus;
  final String? situationType;
  final String? responseMode;
  final DateTime? lastSyncedAt;
  final bool showDebug;
  final bool isWideLayout;
  final VoidCallback onOpenMenu;
  final VoidCallback onNewConversation;
  final VoidCallback onQuickExit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final situation = ChatSituationKindX.fromBackend(situationType);
    final mode = ChatResponseModeKindX.fromBackend(responseMode);
    return Container(
      padding: EdgeInsets.fromLTRB(
        isWideLayout ? 32 : 16,
        18,
        isWideLayout ? 32 : 16,
        18,
      ),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF10171D).withValues(alpha: 0.92)
            : Colors.white.withValues(alpha: 0.90),
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
              Tooltip(
                message: appName,
                child: AcolheBrandPill(
                    onDark: theme.brightness == Brightness.dark),
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
              const _HeaderInfoChip(
                icon: Icons.lock_outline_rounded,
                label: 'Historico protegido',
              ),
              _HeaderInfoChip(
                icon: Icons.shield_outlined,
                label: 'Risco ${risk.level.label}',
                tone: _riskTone(risk.level),
              ),
              if (situation != ChatSituationKind.unknown)
                _HeaderInfoChip(
                  icon: Icons.psychology_alt_outlined,
                  label: situation.label,
                  tone: theme.colorScheme.secondary,
                ),
              _HeaderInfoChip(
                icon: syncStatus == ChatSyncStatus.synced
                    ? Icons.cloud_done_outlined
                    : Icons.cloud_off_outlined,
                label: _syncLabel(syncStatus, lastSyncedAt),
                tone: syncStatus == ChatSyncStatus.synced
                    ? AcolheTheme.forest
                    : AcolheTheme.clay,
              ),
              if (showDebug && mode != ChatResponseModeKind.unknown)
                _HeaderInfoChip(
                  icon: Icons.bug_report_outlined,
                  label: 'Modo: ${mode.label}',
                  tone: AcolheTheme.mutedTeal,
                ),
            ],
          ),
        ],
      ),
    );
  }

  static Color _riskTone(RiskLevel level) => switch (level) {
        RiskLevel.low => AcolheTheme.forest,
        RiskLevel.moderate => AcolheTheme.clay,
        RiskLevel.high => AcolheTheme.rose,
        RiskLevel.critical => const Color(0xFFD98585),
      };

  static String _syncLabel(ChatSyncStatus status, DateTime? lastSyncedAt) {
    if (status != ChatSyncStatus.synced || lastSyncedAt == null) {
      return status.label;
    }
    final local = lastSyncedAt.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return 'Sincronizado $hour:$minute';
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
        color: resolvedTone.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: resolvedTone.withValues(alpha: 0.14)),
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
