import 'package:acolhe_mobile/core/config/app_identity.dart';
import 'package:acolhe_mobile/core/config/backend_config.dart';
import 'package:acolhe_mobile/core/theme/app_theme.dart';
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
    final (connectionTone, connectionIcon) = _connectionPresentation(backend);
    return AppShell(
      title: 'Configuracoes e privacidade',
      subtitle:
          'Discricao, bloqueio local, conexao inteligente e limpeza rapida.',
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
                    title: 'Conexao inteligente',
                    subtitle:
                        'O Acolhe tenta descobrir e validar automaticamente o backend mais adequado para este aparelho.',
                  ),
                  const SizedBox(height: 10),
                  StatusNoticeBanner(
                    message: backend.statusMessage,
                    icon: connectionIcon,
                    tone: connectionTone,
                    actionLabel: backend.isDiscovering ? null : 'Reconectar',
                    onAction: backend.isDiscovering
                        ? null
                        : () => ref
                            .read(backendConfigProvider.notifier)
                            .retryDiscovery(),
                  ),
                  if (backend.preferredBaseUrl.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Endereco preferido: ${backend.preferredBaseUrl}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Origem: ${backend.sourceLabel}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            AppButton.secondary(
              label: 'Ver conexao inteligente',
              icon: Icons.wifi_find_rounded,
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
          : backend.preferredBaseUrl;
    }

    final rawValue = _urlController.text.trim();
    final loopbackWarning = _looksLikeLoopback(rawValue);
    final theme = Theme.of(context);

    return AppShell(
      title: 'Conexao inteligente',
      subtitle:
          'O app tenta descobrir sozinho o melhor backend. A URL manual fica como opcao avancada.',
      maxContentWidth: 760,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionTitle(
                  title: backend.statusHeadline,
                  subtitle: backend.statusMessage,
                ),
                const SizedBox(height: 12),
                StatusNoticeBanner(
                  message: backend.preferredBaseUrl.isEmpty
                      ? 'Nenhum endereco foi validado ainda. O modo offline seguro continua disponivel.'
                      : 'Endereco em uso: ${backend.preferredBaseUrl}\nOrigem: ${backend.sourceLabel}',
                  icon: _connectionPresentation(backend).$2,
                  tone: _connectionPresentation(backend).$1,
                ),
                const SizedBox(height: 18),
                const SectionTitle(
                  title: 'URL manual opcional',
                  subtitle:
                      'Use esta area apenas se quiser fixar um endereco especifico. Em celular fisico, prefira o IP do computador na mesma rede.',
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _urlController,
                  label: 'URL personalizada',
                  hint: 'http://192.168.0.15:8000',
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 12),
                if (loopbackWarning) ...[
                  const SizedBox(height: 4),
                  StatusNoticeBanner(
                    message:
                        'Em celular fisico, nao use localhost, 127.0.0.1 ou 0.0.0.0. Use o IP do seu computador na rede.',
                    icon: Icons.warning_amber_rounded,
                    tone: theme.colorScheme.error,
                  ),
                ],
                const SizedBox(height: 12),
                const Text(
                  'Dica: se o backend estiver no seu computador, ele precisa subir em 0.0.0.0 para ficar visivel na rede local.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          AdaptiveTwoPane(
            breakpoint: 680,
            primary: AppButton.primary(
              label: backend.isDiscovering
                  ? 'Reconectando...'
                  : 'Tentar descoberta agora',
              icon: Icons.sync_rounded,
              onPressed: backend.isDiscovering
                  ? null
                  : () =>
                      ref.read(backendConfigProvider.notifier).retryDiscovery(),
            ),
            secondary: Column(
              children: [
                AppButton.secondary(
                  label: _saving ? 'Salvando...' : 'Salvar URL manual',
                  icon: Icons.link_rounded,
                  onPressed: _saving
                      ? null
                      : () async {
                          setState(() => _saving = true);
                          await ref
                              .read(backendConfigProvider.notifier)
                              .saveOverride(_urlController.text);
                          if (!mounted) {
                            return;
                          }
                          setState(() => _saving = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'URL manual salva. O app ja esta validando a nova conexao.'),
                            ),
                          );
                        },
                ),
                const SizedBox(height: 12),
                AppButton.secondary(
                  label: 'Remover URL manual',
                  onPressed: _saving
                      ? null
                      : () async {
                          setState(() => _saving = true);
                          _urlController.clear();
                          await ref
                              .read(backendConfigProvider.notifier)
                              .clearOverride();
                          if (!mounted) {
                            return;
                          }
                          setState(() => _saving = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'URL manual removida. O app voltou a procurar a melhor conexao automaticamente.'),
                            ),
                          );
                        },
                ),
                const SizedBox(height: 12),
                AppButton.secondary(
                  label: 'Limpar ultima descoberta',
                  onPressed: _saving
                      ? null
                      : () async {
                          setState(() => _saving = true);
                          await ref
                              .read(backendConfigProvider.notifier)
                              .clearDiscoveryCache();
                          if (!mounted) {
                            return;
                          }
                          setState(() => _saving = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Cache de descoberta limpo. O app vai procurar um backend novamente.'),
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
}

(Color, IconData) _connectionPresentation(BackendConfigState backend) {
  return switch (backend.connectionState) {
    BackendConnectionState.connected => (
        AcolheTheme.forest,
        Icons.cloud_done_outlined
      ),
    BackendConnectionState.discovering => (
        AcolheTheme.mutedTeal,
        Icons.sync_rounded
      ),
    BackendConnectionState.offline => (
        AcolheTheme.clay,
        Icons.cloud_off_outlined
      ),
  };
}

bool _looksLikeLoopback(String value) {
  if (value.isEmpty) {
    return false;
  }
  final normalized = value.startsWith('http') ? value : 'http://$value';
  final host = Uri.tryParse(normalized)?.host.toLowerCase() ?? '';
  return host == 'localhost' || host == '127.0.0.1' || host == '0.0.0.0';
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
