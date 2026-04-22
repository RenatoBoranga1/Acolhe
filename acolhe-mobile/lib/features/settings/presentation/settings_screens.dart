import 'package:acolhe_mobile/features/auth/application/auth_controller.dart';
import 'package:acolhe_mobile/features/chat/application/chat_controller.dart';
import 'package:acolhe_mobile/features/journal/application/journal_controller.dart';
import 'package:acolhe_mobile/features/safety_plan/application/safety_plan_controller.dart';
import 'package:acolhe_mobile/features/support_network/application/support_network_controller.dart';
import 'package:acolhe_mobile/shared/widgets/app_shell.dart';
import 'package:acolhe_mobile/shared/widgets/design_system.dart';
import 'package:acolhe_mobile/shared/widgets/responsive_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    return AppShell(
      title: 'Configuracoes e privacidade',
      subtitle: 'Discricao, bloqueio local e limpeza rapida de dados.',
      maxContentWidth: 1160,
      child: AdaptiveTwoPane(
        primary: GlassCard(
          child: Column(
            children: [
              SwitchListTile(
                value: auth.discreetMode,
                onChanged: (value) => ref.read(authControllerProvider.notifier).updateSecurityPreferences(
                      discreetMode: value,
                      aliasName: value ? 'Aurora' : 'Acolhe',
                    ),
                title: const Text('Modo discreto'),
                subtitle: const Text('Usa nome alternativo e tom visual mais neutro.'),
              ),
              SwitchListTile(
                value: auth.biometricsEnabled,
                onChanged: (value) => ref.read(authControllerProvider.notifier).updateSecurityPreferences(
                      biometricsEnabled: value,
                    ),
                title: const Text('Biometria'),
                subtitle: const Text('Permite desbloqueio rapido quando suportado.'),
              ),
              SwitchListTile(
                value: auth.notificationsHidden,
                onChanged: (value) => ref.read(authControllerProvider.notifier).updateSecurityPreferences(
                      notificationsHidden: value,
                    ),
                title: const Text('Ocultar notificacoes sensiveis'),
                subtitle: const Text('Mantem titulos e previews mais neutros.'),
              ),
              SwitchListTile(
                value: auth.quickExitEnabled,
                onChanged: (value) => ref.read(authControllerProvider.notifier).updateSecurityPreferences(
                      quickExitEnabled: value,
                    ),
                title: const Text('Saida rapida'),
                subtitle: const Text('Mostra atalho para ocultar a interface imediatamente.'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(child: Text('Auto-bloqueio (min)')),
                  DropdownButton<int>(
                    value: auth.autoLockMinutes,
                    items: const [1, 3, 5, 10, 15]
                        .map((minutes) => DropdownMenuItem(
                              value: minutes,
                              child: Text('$minutes'),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      ref.read(authControllerProvider.notifier).updateSecurityPreferences(
                            autoLockMinutes: value,
                          );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        secondary: Column(
          children: [
            const GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionTitle(
                    title: 'Privacidade no tablet',
                    subtitle:
                        'A interface foi ajustada para telas maiores com largura controlada, cards em grade e formularios divididos em colunas.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            AppButton.secondary(
              label: 'Limpar conversa atual',
              onPressed: () => ref.read(chatControllerProvider.notifier).clearCurrentConversation(),
            ),
            const SizedBox(height: 12),
            AppButton.secondary(
              label: 'Tela neutra de privacidade',
              onPressed: () => context.push('/privacy'),
            ),
            const SizedBox(height: 12),
            AppButton.primary(
              label: 'Apagar todos os dados locais',
              onPressed: () async {
                await ref.read(authControllerProvider.notifier).resetApp();
                ref.invalidate(chatControllerProvider);
                ref.invalidate(journalControllerProvider);
                ref.invalidate(safetyPlanControllerProvider);
                ref.invalidate(supportNetworkControllerProvider);
                if (!context.mounted) {
                  return;
                }
                context.go('/onboarding');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    return AppShell(
      title: auth.discreetMode ? auth.aliasName : 'Espaco privado',
      subtitle: 'Tela neutra para reduzir exposicao acidental.',
      showBack: false,
      maxContentWidth: 560,
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Conteudo ocultado', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            Text(
              'A interface sensivel foi escondida temporariamente. Quando estiver em um contexto seguro, volte para o app.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            AppButton.primary(
              label: auth.isUnlocked ? 'Voltar ao app' : 'Desbloquear',
              onPressed: () => context.go(auth.isUnlocked ? '/chat' : '/login'),
            ),
          ],
        ),
      ),
    );
  }
}
