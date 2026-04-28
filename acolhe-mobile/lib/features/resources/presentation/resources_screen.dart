import 'package:acolhe_mobile/features/resources/application/resources_controller.dart';
import 'package:acolhe_mobile/shared/widgets/app_shell.dart';
import 'package:acolhe_mobile/shared/widgets/design_system.dart';
import 'package:acolhe_mobile/shared/widgets/responsive_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ResourcesScreen extends ConsumerWidget {
  const ResourcesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final articles = ref.watch(resourcesProvider);
    return AppShell(
      title: 'Informacoes e direitos',
      subtitle:
          'Conteudo geral, claro e pronto para evolucao por pais ou regiao.',
      maxContentWidth: 1200,
      child: Column(
        children: [
          const GlassCard(
            child: Text(
              'Os textos desta area oferecem orientacao geral e nao substituem aconselhamento psicologico, juridico, medico ou policial.',
            ),
          ),
          const SizedBox(height: 16),
          AdaptiveCardGrid(
            minItemWidth: 320,
            spacing: 14,
            children: [
              for (final article in articles)
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(article.category,
                          style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 8),
                      Text(article.title,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 10),
                      Text(article.summary),
                      const SizedBox(height: 12),
                      Text(article.body),
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Chip(label: Text(article.ctaLabel)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
