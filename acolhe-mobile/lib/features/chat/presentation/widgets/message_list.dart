import 'package:acolhe_mobile/core/theme/app_theme.dart';
import 'package:acolhe_mobile/features/chat/domain/chat_intelligence_ui.dart';
import 'package:acolhe_mobile/features/chat/presentation/widgets/quick_actions.dart';
import 'package:acolhe_mobile/features/chat/presentation/widgets/risk_banner.dart';
import 'package:acolhe_mobile/shared/models/app_models.dart';
import 'package:acolhe_mobile/shared/widgets/design_system.dart';
import 'package:flutter/material.dart';

class MessageList extends StatelessWidget {
  const MessageList({
    required this.conversation,
    required this.risk,
    required this.ctas,
    required this.isTyping,
    required this.scrollController,
    required this.onNavigate,
    super.key,
    this.situationType,
    this.responseMode,
    this.conversationContext,
    this.lastResponseUsedFallback = false,
    this.lastResponseWasRepaired = false,
  });

  final ConversationModel conversation;
  final RiskAssessment risk;
  final List<String> ctas;
  final bool isTyping;
  final ScrollController scrollController;
  final ValueChanged<String> onNavigate;
  final String? situationType;
  final String? responseMode;
  final Map<String, dynamic>? conversationContext;
  final bool lastResponseUsedFallback;
  final bool lastResponseWasRepaired;

  @override
  Widget build(BuildContext context) {
    final showRiskBanner =
        risk.level != RiskLevel.low || risk.requiresImmediateAction;
    final localFallback = isLocalFallbackContext(conversationContext);
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      children: [
        if (conversation.messages.isNotEmpty) ...[
          const StatusNoticeBanner(
            message:
                'Posso oferecer acolhimento inicial e orientacao geral. Nao substituo apoio psicologico, juridico, medico ou policial.',
            icon: Icons.info_outline_rounded,
          ),
          const SizedBox(height: 12),
          if (showRiskBanner) ...[
            AdaptiveRiskBanner(risk: risk, onNavigate: onNavigate),
            const SizedBox(height: 12),
          ],
          ChatQuickActions(
            risk: risk,
            ctas: ctas,
            situationType: situationType,
            onNavigate: onNavigate,
          ),
          const SizedBox(height: 12),
          if (lastResponseUsedFallback || lastResponseWasRepaired) ...[
            StatusNoticeBanner(
              message: localFallback
                  ? 'Sem conexao agora, mantive uma resposta segura neste aparelho. Quando a conexao voltar, voce pode tentar novamente para sincronizar.'
                  : 'A resposta foi mantida em um formato mais seguro e objetivo para preservar clareza.',
              icon: localFallback
                  ? Icons.cloud_off_outlined
                  : Icons.verified_user_outlined,
              tone: localFallback ? AcolheTheme.clay : AcolheTheme.forest,
            ),
            const SizedBox(height: 12),
          ],
        ],
        for (final message in conversation.messages)
          ChatBubble(message: message),
        if (isTyping) const TypingIndicatorBubble(),
      ],
    );
  }
}
