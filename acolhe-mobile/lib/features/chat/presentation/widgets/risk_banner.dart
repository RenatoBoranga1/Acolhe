import 'package:acolhe_mobile/core/theme/app_theme.dart';
import 'package:acolhe_mobile/features/chat/domain/chat_intelligence_ui.dart';
import 'package:acolhe_mobile/shared/models/app_models.dart';
import 'package:acolhe_mobile/shared/widgets/design_system.dart';
import 'package:flutter/material.dart';

class AdaptiveRiskBanner extends StatelessWidget {
  const AdaptiveRiskBanner({
    required this.risk,
    required this.onNavigate,
    super.key,
  });

  final RiskAssessment risk;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    if (!chatRiskNeedsPriority(risk)) {
      return RiskBanner(risk: risk);
    }

    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AcolheTheme.rose.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.20 : 0.12,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AcolheTheme.rose.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AcolheTheme.rose.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.emergency_outlined,
                    color: AcolheTheme.rose),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Seguranca em primeiro lugar',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'O backend classificou esta conversa como risco ${risk.level.label}. Antes de continuar, priorize local seguro, apoio humano e passos curtos.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: () => onNavigate('/urgent-help'),
                icon: const Icon(Icons.call_outlined),
                label: const Text('Ajuda urgente'),
              ),
              OutlinedButton.icon(
                onPressed: () => onNavigate('/safety-plan'),
                icon: const Icon(Icons.shield_outlined),
                label: const Text('Plano de seguranca'),
              ),
              OutlinedButton.icon(
                onPressed: () => onNavigate('/support-network'),
                icon: const Icon(Icons.people_outline_rounded),
                label: const Text('Pessoa de confianca'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
