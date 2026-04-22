import 'package:acolhe_mobile/core/theme/app_theme.dart';
import 'package:acolhe_mobile/features/chat/domain/chat_intelligence_ui.dart';
import 'package:acolhe_mobile/shared/models/app_models.dart';
import 'package:flutter/material.dart';

class ChatQuickActions extends StatelessWidget {
  const ChatQuickActions({
    required this.risk,
    required this.ctas,
    required this.onNavigate,
    super.key,
    this.situationType,
  });

  final RiskAssessment risk;
  final List<String> ctas;
  final String? situationType;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final situation = ChatSituationKindX.fromBackend(situationType);
    final actions = _buildActions(risk: risk, ctas: ctas, situation: situation);
    if (actions.isEmpty && situation == ChatSituationKind.unknown) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final primaryTone = chatRiskNeedsPriority(risk)
        ? AcolheTheme.rose
        : situation.shouldHighlightIncidentRecord
            ? AcolheTheme.clay
            : situation.shouldHighlightSupport
                ? AcolheTheme.forest
                : theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primaryTone.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: primaryTone.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_situationIcon(situation, risk),
                  color: primaryTone, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      situation == ChatSituationKind.unknown
                          ? 'Acoes sugeridas'
                          : situation.label,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      situation == ChatSituationKind.unknown
                          ? 'Escolha uma acao rapida se ela fizer sentido para voce.'
                          : situation.userFacingSummary,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final action in actions)
                  _ActionButton(
                    action: action,
                    prominent:
                        action.priority <= 1 || chatRiskNeedsPriority(risk),
                    onTap: () => onNavigate(action.route),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static List<ChatCtaIntent> _buildActions({
    required RiskAssessment risk,
    required List<String> ctas,
    required ChatSituationKind situation,
  }) {
    final actions = <ChatCtaIntent>[];

    if (chatRiskNeedsPriority(risk) || situation.shouldHighlightSafety) {
      actions.addAll(const [
        ChatCtaIntent(
            label: 'Ajuda urgente', route: '/urgent-help', priority: 0),
        ChatCtaIntent(
            label: 'Abrir plano de seguranca',
            route: '/safety-plan',
            priority: 1),
        ChatCtaIntent(
            label: 'Rede de apoio', route: '/support-network', priority: 2),
      ]);
    }

    if (situation.shouldHighlightIncidentRecord) {
      actions.add(
        const ChatCtaIntent(
          label: 'Gerar resumo cronologico',
          route: '/incident-record',
          priority: 1,
        ),
      );
    }

    if (situation.shouldHighlightSupport) {
      actions.add(
        const ChatCtaIntent(
          label: 'Mensagem para pessoa de confianca',
          route: '/support-network',
          priority: 1,
        ),
      );
    }

    actions.addAll(ctas.map(ChatCtaIntent.fromLabel));
    final byKey = <String, ChatCtaIntent>{};
    for (final action in actions) {
      final key = '${action.route}:${action.label.toLowerCase()}';
      byKey.putIfAbsent(key, () => action);
    }
    final unique = byKey.values.toList();
    unique.sort((a, b) => a.priority.compareTo(b.priority));
    return unique.take(5).toList(growable: false);
  }

  static IconData _situationIcon(
      ChatSituationKind situation, RiskAssessment risk) {
    if (chatRiskNeedsPriority(risk)) {
      return Icons.emergency_outlined;
    }
    return switch (situation) {
      ChatSituationKind.incidentRecord => Icons.event_note_outlined,
      ChatSituationKind.supportRequest => Icons.people_outline_rounded,
      ChatSituationKind.reportingAmbivalence => Icons.alt_route_rounded,
      ChatSituationKind.emotionalCrisis => Icons.self_improvement_outlined,
      ChatSituationKind.fearOfReencounter => Icons.shield_outlined,
      ChatSituationKind.workplaceHarassment => Icons.badge_outlined,
      ChatSituationKind.harassmentUncertainty => Icons.manage_search_outlined,
      ChatSituationKind.stalking => Icons.visibility_outlined,
      ChatSituationKind.coercion => Icons.front_hand_outlined,
      ChatSituationKind.initialDisclosure => Icons.chat_bubble_outline_rounded,
      ChatSituationKind.unknown => Icons.auto_awesome_outlined,
    };
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.action,
    required this.prominent,
    required this.onTap,
  });

  final ChatCtaIntent action;
  final bool prominent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = _iconForRoute(action.route);
    if (prominent) {
      return FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(action.label),
      );
    }
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(action.label),
    );
  }

  static IconData _iconForRoute(String route) {
    return switch (route) {
      '/urgent-help' => Icons.call_outlined,
      '/safety-plan' => Icons.shield_outlined,
      '/support-network' => Icons.people_outline_rounded,
      '/incident-record' => Icons.event_note_outlined,
      '/resources' => Icons.menu_book_outlined,
      _ => Icons.arrow_forward_rounded,
    };
  }
}
