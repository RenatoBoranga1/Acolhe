import 'package:acolhe_mobile/core/config/app_identity.dart';
import 'package:acolhe_mobile/core/config/backend_config.dart';
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
    final backend = ref.watch(backendConfigProvider);
    return AppShell(
      title: 'Configuracoes e privacidade',
      subtitle:
          'Discricao, bloqueio local, conexao do celular e limpeza rapida.',
      maxContentWidth: 1160,
      child: AdaptiveTwoPane(
        primary: GlassCard(
          child: Column(
            children: [
              SwitchListTile(
                value: auth.discreetMode,
                onChanged: (value) => ref
                    .read(authControllerProvider.notifier)
                    .updateSecurityPreferences(
                      discreetMode: value,
                      aliasName: AppIdentity.appName,
                    ),
                title: const Text('Modo discreto'),
                subtitle: const Text(
                    'Mantem a interface mais neutra sem trocar o nome do app.'),
              ),
              SwitchListTile(
                value: auth.biometricsEnabled,
                onChanged: (value) => ref
                    .read(authControllerProvider.notifier)
                    .updateSecurityPreferences(
                      biometricsEnabled: value,
                    ),
                title: const Text('Biometria'),
                subtitle:
                    const Text('Permite desbloqueio rapido quando suportado.'),
              ),
              SwitchListTile(
                value: auth.notificationsHidden,
                onChanged: (value) => ref
                    .read(authControllerProvider.notifier)
                    .updateSecurityPreferences(
                      notificationsHidden: value,
                    ),
                title: const Text('Ocultar notificacoes sensiveis'),
                subtitle: const Text('Mantem titulos e previews mais neutros.'),
              ),
              SwitchListTile(
                value: auth.quickExitEnabled,
                onChanged: (value) => ref
                    .read(authControllerProvider.notifier)
                    .updateSecurityPreferences(
                      quickExitEnabled: value,
                    ),
                title: const Text('Saida rapida'),
                subtitle: const Text(
                    'Mostra atalho para ocultar a interface imediatamente.'),
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
                      ref
                          .read(authControllerProvider.notifier)
                          .updateSecurityPreferences(
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
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle(
                    title: 'Conexao no celular',
                    subtitle:
                        'Use esta area para apontar o app para o backend real quando estiver em um telefone ou tablet na mesma rede do seu computador.',
                  ),
                  const SizedBox(height: 10),
                  StatusNoticeBanner(
                    message: backend.usesRemoteApi
                        ? 'Endereco atual: ${backend.effectiveBaseUrl}'
                        : 'Sem backend remoto configurado. O app continua em modo local seguro.',
                    icon: backend.usesRemoteApi
                        ? Icons.wifi_tethering_rounded
                        : Icons.cloud_off_outlined,
                    tone: backend.usesRemoteApi
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.secondary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            AppButton.secondary(
              label: 'Configurar backend do celular',
              icon: Icons.settings_ethernet_rounded,
              onPressed: () => context.push('/backend-connection'),
            ),
            const SizedBox(height: 12),
            AppButton.secondary(
              label: 'Limpar conversa atual',
              onPressed: () => ref
                  .read(chatControllerProvider.notifier)
                  .clearCurrentConversation(),
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
                ref.invalidate(backendConfigProvider);
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

class BackendConnectionScreen extends ConsumerStatefulWidget {
  const BackendConnectionScreen({super.key});

  @override
  ConsumerState<BackendConnectionScreen> createState() =>
      _BackendConnectionScreenState();
}

class _BackendConnectionScreenState
    extends ConsumerState<BackendConnectionScreen> {
  final TextEditingController _urlController = TextEditingController();
  bool _syncedInitialValue = false;
  bool _saving = false;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final backend = ref.watch(backendConfigProvider);
    if (!_syncedInitialValue && !backend.isLoading) {
      _syncedInitialValue = true;
      _urlController.text = backend.usesCustomUrl
          ? backend.customBaseUrl
          : backend.effectiveBaseUrl;
    }

    final rawValue = _urlController.text.trim();
    final loopbackWarning = _looksLikeLoopback(rawValue);
    final theme = Theme.of(context);

    return AppShell(
      title: 'Conexao do backend',
      subtitle: 'Deixe o celular apontar para a API real sem recompilar o app.',
      maxContentWidth: 760,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle(
                  title: 'URL usada pelo celular',
                  subtitle:
                      'Se o backend estiver no seu computador, use o IP da maquina na mesma rede Wi-Fi. Exemplo: http://192.168.0.15:8000',
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _urlController,
                  label: 'URL do backend',
                  hint: 'http://192.168.0.15:8000',
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 12),
                StatusNoticeBanner(
                  message: backend.usesRemoteApi
                      ? 'Endereco ativo: ${backend.effectiveBaseUrl}'
                      : 'Nenhum backend remoto ativo. O chat usa o fallback local seguro.',
                  icon: backend.usesRemoteApi
                      ? Icons.cloud_done_outlined
                      : Icons.cloud_off_outlined,
                  tone: backend.usesRemoteApi
                      ? theme.colorScheme.primary
                      : theme.colorScheme.secondary,
                ),
                if (loopbackWarning) ...[
                  const SizedBox(height: 12),
                  StatusNoticeBanner(
                    message:
                        'Em celular fisico, nao use localhost, 127.0.0.1 ou 0.0.0.0. Use o IP do seu computador na rede.',
                    icon: Icons.warning_amber_rounded,
                    tone: theme.colorScheme.error,
                  ),
                ],
                const SizedBox(height: 12),
                const Text(
                  'Dica: o backend precisa subir em 0.0.0.0 para ficar visivel na rede local.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          AdaptiveTwoPane(
            breakpoint: 680,
            primary: AppButton.primary(
              label: _saving ? 'Salvando...' : 'Salvar e reconectar chat',
              onPressed: _saving
                  ? null
                  : () async {
                      setState(() => _saving = true);
                      await ref
                          .read(backendConfigProvider.notifier)
                          .saveOverride(_urlController.text);
                      ref.invalidate(chatControllerProvider);
                      if (!mounted) {
                        return;
                      }
                      setState(() => _saving = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Configuracao salva. O chat vai usar a nova URL.'),
                        ),
                      );
                    },
            ),
            secondary: Column(
              children: [
                AppButton.secondary(
                  label: 'Limpar URL personalizada',
                  onPressed: _saving
                      ? null
                      : () async {
                          setState(() => _saving = true);
                          _urlController.clear();
                          await ref
                              .read(backendConfigProvider.notifier)
                              .clearOverride();
                          ref.invalidate(chatControllerProvider);
                          if (!mounted) {
                            return;
                          }
                          setState(() => _saving = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'URL personalizada removida. O app voltou ao modo padrao.'),
                            ),
                          );
                        },
                ),
                const SizedBox(height: 12),
                AppButton.secondary(
                  label: 'Abrir chat',
                  onPressed: () => context.go('/chat'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _looksLikeLoopback(String value) {
    if (value.isEmpty) {
      return false;
    }
    final normalized = value.startsWith('http') ? value : 'http://$value';
    final host = Uri.tryParse(normalized)?.host.toLowerCase() ?? '';
    return host == 'localhost' || host == '127.0.0.1' || host == '0.0.0.0';
  }
}

class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    return AppShell(
      title: auth.currentAppName,
      subtitle: 'Tela neutra para reduzir exposicao acidental.',
      showBack: false,
      maxContentWidth: 560,
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Conteudo ocultado',
                style: Theme.of(context).textTheme.titleLarge),
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
