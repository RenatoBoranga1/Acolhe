import 'package:acolhe_mobile/features/human_support/application/support_controller.dart';
import 'package:acolhe_mobile/features/human_support/domain/support_models.dart';
import 'package:acolhe_mobile/shared/models/app_models.dart';
import 'package:acolhe_mobile/shared/widgets/app_shell.dart';
import 'package:acolhe_mobile/shared/widgets/design_system.dart';
import 'package:acolhe_mobile/shared/widgets/responsive_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class RedeAcolheIntroScreen extends ConsumerWidget {
  const RedeAcolheIntroScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final support = ref.watch(supportControllerProvider);
    return AppShell(
      title: 'Rede Acolhe',
      subtitle:
          'Quando fizer sentido para voce, a IA pode encaminhar a conversa para uma pessoa real da rede.',
      maxContentWidth: 1020,
      child: AdaptiveTwoPane(
        primary: GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle(
                title: 'IA + acolhimento humano',
                subtitle:
                    'A Rede Acolhe conecta voce a uma pessoa voluntaria ou profissional verificado, quando houver disponibilidade.',
              ),
              const SizedBox(height: 16),
              const Text(
                'Este acolhimento oferece escuta inicial, orientacao geral e encaminhamento seguro. Nao substitui atendimento psicologico, juridico, medico ou policial.',
              ),
              const SizedBox(height: 16),
              StatusNoticeBanner(
                message: support.statusMessage ??
                    'Ao entrar na fila, a pessoa apoiadora recebe um resumo seguro gerado pela IA para evitar que voce precise repetir tudo do zero.',
                icon: Icons.shield_outlined,
              ),
              const SizedBox(height: 16),
              const _GuidelineBullet(
                text:
                    'Voce pode sair da fila ou encerrar o atendimento a qualquer momento.',
              ),
              const _GuidelineBullet(
                text:
                    'Em risco alto ou critico, a prioridade continua sendo seguranca imediata e ajuda real.',
              ),
              const _GuidelineBullet(
                text:
                    'Se preferir, voce pode continuar apenas com a IA e usar a Rede Acolhe depois.',
              ),
            ],
          ),
        ),
        secondary: GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Escolha como seguir agora',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                support.connectionLabel,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Quando houver conexao, a fila e o atendimento passam a sincronizar automaticamente.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (support.errorMessage != null) ...[
                const SizedBox(height: 12),
                StatusNoticeBanner(
                  message: support.errorMessage!,
                  icon: Icons.info_outline_rounded,
                  tone: Theme.of(context).colorScheme.error,
                ),
              ],
              const SizedBox(height: 20),
              AppButton.primary(
                label: support.isSubmitting
                    ? 'Entrando na fila...'
                    : 'Entrar na fila',
                icon: Icons.support_agent_outlined,
                onPressed: support.isSubmitting
                    ? null
                    : () async {
                        final created = await ref
                            .read(supportControllerProvider.notifier)
                            .requestHumanSupport();
                        if (!context.mounted || !created) {
                          return;
                        }
                        context.go('/support-queue');
                      },
              ),
              const SizedBox(height: 12),
              AppButton.secondary(
                label: 'Continuar com a IA',
                onPressed: () => context.go('/chat'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SupportQueueScreen extends ConsumerStatefulWidget {
  const SupportQueueScreen({super.key});

  @override
  ConsumerState<SupportQueueScreen> createState() => _SupportQueueScreenState();
}

class _SupportQueueScreenState extends ConsumerState<SupportQueueScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(supportControllerProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final support = ref.watch(supportControllerProvider);
    final request = support.currentRequest;

    return AppShell(
      title: 'Fila da Rede Acolhe',
      subtitle:
          'Voce pode acompanhar o status do pedido sem interromper seu uso do app.',
      maxContentWidth: 960,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatusNoticeBanner(
                  message: request == null
                      ? 'Nenhuma solicitacao ativa agora. Se quiser, voce pode voltar ao chat e pedir acolhimento humano.'
                      : 'Status atual: ${request.queueStatusLabel}.',
                  icon: request?.isActive == true
                      ? Icons.record_voice_over_outlined
                      : Icons.hourglass_top_rounded,
                ),
                if (request != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Risco ${request.riskLevel.label} • ${request.situationType.replaceAll('_', ' ')}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  Text(request.safeSummary.summaryText),
                  if (request.sessionId != null) ...[
                    const SizedBox(height: 18),
                    AppButton.primary(
                      label: 'Abrir conversa humana',
                      icon: Icons.forum_outlined,
                      onPressed: () =>
                          context.go('/human-chat/${request.sessionId}'),
                    ),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          AdaptiveTwoPane(
            primary: AppButton.secondary(
              label: 'Atualizar status',
              icon: Icons.refresh_rounded,
              onPressed: () => ref
                  .read(supportControllerProvider.notifier)
                  .refreshUserSupport(),
            ),
            secondary: Column(
              children: [
                AppButton.secondary(
                  label: 'Continuar com a IA',
                  onPressed: () => context.go('/chat'),
                ),
                const SizedBox(height: 12),
                AppButton.primary(
                  label: 'Sair da fila',
                  onPressed: request == null
                      ? null
                      : () async {
                          final cancelled = await ref
                              .read(supportControllerProvider.notifier)
                              .cancelCurrentRequest();
                          if (!context.mounted || !cancelled) {
                            return;
                          }
                          context.go('/chat');
                        },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HumanChatScreen extends ConsumerStatefulWidget {
  const HumanChatScreen({
    required this.sessionId,
    super.key,
  });

  final String sessionId;

  @override
  ConsumerState<HumanChatScreen> createState() => _HumanChatScreenState();
}

class _HumanChatScreenState extends ConsumerState<HumanChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _composerFocusNode = FocusNode();
  String _lastScrollSignature = '';
  double _lastKeyboardInset = 0;

  @override
  void initState() {
    super.initState();
    _composerFocusNode.addListener(_handleComposerFocusChanged);
    Future.microtask(
      () => ref.read(supportControllerProvider.notifier).openUserSession(
            widget.sessionId,
          ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _composerFocusNode
      ..removeListener(_handleComposerFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _handleComposerFocusChanged() {
    if (_composerFocusNode.hasFocus) {
      _scheduleScrollToBottom(animated: true);
    }
  }

  void _scheduleScrollToBottom({bool animated = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      final position = _scrollController.position.maxScrollExtent + 20;
      if (animated) {
        _scrollController.animateTo(
          position,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scrollController.jumpTo(position);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final support = ref.watch(supportControllerProvider);
    final session = support.activeSession;
    final supporter = session?.supporterProfile;
    final summary = session?.safeSummary;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final scrollSignature =
        '${session?.id ?? 'none'}:${session?.messages.length ?? 0}:${support.isSubmitting}:${support.errorMessage ?? ''}';

    if (_lastScrollSignature != scrollSignature) {
      _lastScrollSignature = scrollSignature;
      _scheduleScrollToBottom(animated: true);
    }
    if ((_lastKeyboardInset - keyboardInset).abs() > 1 &&
        (session?.messages.isNotEmpty ??
            false || _composerFocusNode.hasFocus)) {
      _lastKeyboardInset = keyboardInset;
      _scheduleScrollToBottom(animated: true);
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            _SupportTopBar(
              title: supporter?.isVerifiedSpecialist == true
                  ? 'Especialista verificado'
                  : 'Rede Acolhe',
              subtitle: supporter == null
                  ? 'Conectando conversa humana...'
                  : supporter.isVerifiedSpecialist
                      ? '${supporter.displayName} • ${supporter.specialties.join(', ')}'
                      : 'Voce esta conversando com ${supporter.displayName}.',
            ),
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  keyboardInset > 0 ? 24 : 20,
                ),
                children: [
                  if (summary != null)
                    const StatusNoticeBanner(
                      message:
                          'A Rede Acolhe oferece acolhimento inicial e orientacao segura. Em risco imediato, priorize emergencia e rede de confianca.',
                      icon: Icons.info_outline_rounded,
                    ),
                  if (support.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    StatusNoticeBanner(
                      message: support.errorMessage!,
                      icon: Icons.cloud_off_outlined,
                      tone: Theme.of(context).colorScheme.error,
                    ),
                  ],
                  if (support.connectionLabel != 'Conectado') ...[
                    const SizedBox(height: 12),
                    StatusNoticeBanner(
                      message: support.connectionLabel,
                      icon: Icons.sync_problem_outlined,
                    ),
                  ],
                  const SizedBox(height: 12),
                  for (final message in session?.messages ?? const [])
                    _HumanMessageBubble(message: message),
                  if (support.isOtherParticipantTyping) ...[
                    const SizedBox(height: 4),
                    Text(
                      'A outra pessoa esta digitando...',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.fromLTRB(16, 12, 16, keyboardInset + 16),
                child: Column(
                  children: [
                    if (support.statusMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: StatusNoticeBanner(
                          message: support.statusMessage!,
                          icon: Icons.shield_outlined,
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            focusNode: _composerFocusNode,
                            minLines: 1,
                            maxLines: 5,
                            textInputAction: TextInputAction.newline,
                            decoration: const InputDecoration(
                              hintText:
                                  'Escreva no seu ritmo. Voce pode encerrar a qualquer momento.',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton.filled(
                          onPressed: support.isSubmitting
                              ? null
                              : () async {
                                  final text = _messageController.text.trim();
                                  if (text.isEmpty) {
                                    return;
                                  }
                                  _messageController.clear();
                                  await ref
                                      .read(supportControllerProvider.notifier)
                                      .sendUserMessage(text);
                                },
                          icon: const Icon(Icons.arrow_upward_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton.secondary(
                            label: 'Denunciar apoiador',
                            onPressed: session == null
                                ? null
                                : () => context
                                    .push('/report-supporter/${session.id}'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppButton.primary(
                            label: 'Encerrar atendimento',
                            onPressed: session == null
                                ? null
                                : () async {
                                    final closed = await ref
                                        .read(
                                            supportControllerProvider.notifier)
                                        .closeUserSession();
                                    if (!context.mounted || !closed) {
                                      return;
                                    }
                                    context.go('/chat');
                                  },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SupporterDashboardScreen extends ConsumerStatefulWidget {
  const SupporterDashboardScreen({super.key});

  @override
  ConsumerState<SupporterDashboardScreen> createState() =>
      _SupporterDashboardScreenState();
}

class _SupporterDashboardScreenState
    extends ConsumerState<SupporterDashboardScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () =>
          ref.read(supportControllerProvider.notifier).loadSupporterDashboard(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final support = ref.watch(supportControllerProvider);
    final profile = support.supporterProfile;
    return AppShell(
      title: 'Painel da Rede Acolhe',
      subtitle:
          'Fila, sessoes ativas e status de disponibilidade para acolhimento humano.',
      maxContentWidth: 1180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdaptiveTwoPane(
            primary: GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile == null
                        ? 'Perfil de apoiador'
                        : '${profile.displayName} • ${profile.roleType.label}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    support.connectionLabel,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  StatusNoticeBanner(
                    message: support.statusMessage ??
                        'Antes de atender, confirme as diretrizes e mantenha a disponibilidade atualizada.',
                    icon: Icons.shield_outlined,
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    value: profile?.isAvailable ?? false,
                    onChanged: (value) => ref
                        .read(supportControllerProvider.notifier)
                        .updateAvailability(value),
                    title: const Text('Disponivel para acolhimento'),
                    subtitle: Text(
                      profile?.trainingCompleted == true
                          ? 'A fila vai considerar voce para novos atendimentos.'
                          : 'Aceite as diretrizes antes de ficar disponivel.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  AdaptiveTwoPane(
                    breakpoint: 720,
                    primary: AppButton.secondary(
                      label: 'Diretrizes do apoiador',
                      onPressed: () => context.push('/supporter-guidelines'),
                    ),
                    secondary: AppButton.secondary(
                      label: 'Ver fila',
                      onPressed: () => context.push('/supporter-queue'),
                    ),
                  ),
                ],
              ),
            ),
            secondary: GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resumo rapido',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Text('Aguardando: ${support.queue.length}'),
                  const SizedBox(height: 8),
                  Text(
                      'Em andamento: ${support.activeSupporterSessions.length}'),
                  if (support.supporterDashboard != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Primeira atribuicao media: ${support.supporterDashboard!.metrics.averageFirstAssignmentMinutes.toStringAsFixed(1)} min',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Alertas de moderacao abertos: ${support.supporterDashboard!.openModerationAlerts}',
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (support.errorMessage != null)
                    StatusNoticeBanner(
                      message: support.errorMessage!,
                      icon: Icons.info_outline_rounded,
                      tone: Theme.of(context).colorScheme.error,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Atendimentos em andamento',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (support.activeSupporterSessions.isEmpty)
            const GlassCard(
              child: Text(
                'Nenhum atendimento ativo agora. A fila continua disponivel para novos acolhimentos.',
              ),
            )
          else
            AdaptiveCardGrid(
              minItemWidth: 300,
              children: [
                for (final session in support.activeSupporterSessions)
                  HomeFeatureCard(
                    title: session.supporterProfile?.displayName ??
                        'Sessao em andamento',
                    subtitle: session.safeSummary?.summaryText ??
                        'Acolhimento humano em andamento.',
                    icon: Icons.forum_outlined,
                    onTap: () => context.push('/support-session/${session.id}'),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class SupporterQueueScreen extends ConsumerStatefulWidget {
  const SupporterQueueScreen({super.key});

  @override
  ConsumerState<SupporterQueueScreen> createState() =>
      _SupporterQueueScreenState();
}

class _SupporterQueueScreenState extends ConsumerState<SupporterQueueScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () =>
          ref.read(supportControllerProvider.notifier).loadSupporterDashboard(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final support = ref.watch(supportControllerProvider);
    return AppShell(
      title: 'Fila da Rede Acolhe',
      subtitle:
          'Resumo seguro, risco, prioridade e tempo de espera para cada solicitacao.',
      maxContentWidth: 1120,
      child: Column(
        children: [
          for (final item in support.queue) ...[
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${item.request.requesterAlias} • ${item.priorityBucket}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Text('${item.waitingMinutes} min'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Risco ${item.request.riskLevel.label} • ${item.request.situationType.replaceAll('_', ' ')}',
                  ),
                  const SizedBox(height: 10),
                  Text(item.request.safeSummary.summaryText),
                  if (item.distributionScore > 0) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Compatibilidade sugerida: ${(item.distributionScore * 100).toStringAsFixed(0)}%',
                    ),
                  ],
                  if (item.matchingReasons.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    for (final reason in item.matchingReasons.take(3))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('• $reason'),
                      ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      AppButton.primary(
                        label: 'Aceitar atendimento',
                        onPressed: support.isSubmitting
                            ? null
                            : () async {
                                final selected = await ref
                                    .read(supportControllerProvider.notifier)
                                    .acceptRequest(item.request.id);
                                if (!context.mounted || selected == null) {
                                  return;
                                }
                                context.push('/support-session/${selected.id}');
                              },
                      ),
                      AppButton.secondary(
                        label: 'Atualizar fila',
                        onPressed: () => ref
                            .read(supportControllerProvider.notifier)
                            .loadSupporterDashboard(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (support.queue.isEmpty)
            const GlassCard(
              child: Text('Nenhuma solicitacao aguardando no momento.'),
            ),
        ],
      ),
    );
  }
}

class SupportSessionDetailScreen extends ConsumerStatefulWidget {
  const SupportSessionDetailScreen({
    required this.sessionId,
    super.key,
  });

  final String sessionId;

  @override
  ConsumerState<SupportSessionDetailScreen> createState() =>
      _SupportSessionDetailScreenState();
}

class _SupportSessionDetailScreenState
    extends ConsumerState<SupportSessionDetailScreen> {
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(supportControllerProvider.notifier).openSupporterSession(
            widget.sessionId,
          ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final support = ref.watch(supportControllerProvider);
    final session = support.selectedSupporterSession;
    final summary = session?.safeSummary;
    return AppShell(
      title: 'Sessao de acolhimento',
      subtitle:
          'Escuta inicial, resumo seguro, copiloto privado e encaminhamento responsavel.',
      maxContentWidth: 1180,
      child: AdaptiveTwoPane(
        breakpoint: 960,
        primary: GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                session?.supporterProfile?.displayName ??
                    'Atendimento em andamento',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                support.connectionLabel,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              for (final message in session?.messages ?? const [])
                _HumanMessageBubble(message: message),
              if (support.isOtherParticipantTyping) ...[
                const SizedBox(height: 8),
                Text(
                  'A pessoa atendida esta digitando...',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _messageController,
                minLines: 1,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText:
                      'Responder com acolhimento inicial, clareza e sem julgamento.',
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  AppButton.primary(
                    label: 'Enviar',
                    onPressed: support.isSubmitting
                        ? null
                        : () async {
                            final text = _messageController.text.trim();
                            if (text.isEmpty) {
                              return;
                            }
                            _messageController.clear();
                            await ref
                                .read(supportControllerProvider.notifier)
                                .sendSupporterMessage(text);
                          },
                  ),
                  AppButton.secondary(
                    label: 'Transferir',
                    onPressed: session == null
                        ? null
                        : () async {
                            final transferred = await ref
                                .read(supportControllerProvider.notifier)
                                .transferSupporterSession(
                                  sessionId: session.id,
                                  reason:
                                      'Transferencia solicitada pelo apoiador',
                                  targetSpecialty: 'psicologia',
                                );
                            if (!context.mounted || !transferred) {
                              return;
                            }
                            context.go('/supporter-queue');
                          },
                  ),
                  AppButton.secondary(
                    label: 'Encerrar',
                    onPressed: session == null
                        ? null
                        : () async {
                            final closed = await ref
                                .read(supportControllerProvider.notifier)
                                .closeSupporterSession(
                                  sessionId: session.id,
                                  reason: 'Encerrado pelo apoiador',
                                );
                            if (!context.mounted || !closed) {
                              return;
                            }
                            context.go('/supporter-dashboard');
                          },
                  ),
                ],
              ),
            ],
          ),
        ),
        secondary: GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle(
                title: 'Copiloto privado',
                subtitle:
                    'Estas sugestoes sao apenas para apoiar sua conduta. Nada e enviado automaticamente.',
              ),
              if (support.latestModerationAlert != null) ...[
                const SizedBox(height: 12),
                StatusNoticeBanner(
                  message:
                      'Alerta recente de moderacao: ${support.latestModerationAlert!.rationale}',
                  icon: Icons.flag_outlined,
                  tone: Theme.of(context).colorScheme.error,
                ),
              ],
              const SizedBox(height: 12),
              if (summary != null) ...[
                Text('Resumo seguro',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(summary.summaryText),
                const SizedBox(height: 14),
                for (final reminder in summary.supporterReminders)
                  _GuidelineBullet(text: reminder),
                const SizedBox(height: 14),
                Text('Sugestoes de resposta',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final tip in summary.supporterCopilotSuggestions)
                  _GuidelineBullet(text: tip),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class SupporterGuidelinesScreen extends ConsumerWidget {
  const SupporterGuidelinesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final support = ref.watch(supportControllerProvider);
    return AppShell(
      title: 'Diretrizes do apoiador',
      subtitle:
          'Antes de acolher alguem, confirme seu compromisso com seguranca, etica e clareza.',
      maxContentWidth: 840,
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _GuidelineBullet(text: 'Escute sem julgamento.'),
            const _GuidelineBullet(text: 'Nao pressione decisoes ou denuncia.'),
            const _GuidelineBullet(
                text: 'Nao peca detalhes intimos desnecessarios.'),
            const _GuidelineBullet(
                text: 'Nao prometa solucao ou sigilo absoluto.'),
            const _GuidelineBullet(
                text: 'Respeite o tempo e a ambivalencia da pessoa.'),
            const _GuidelineBullet(
              text:
                  'Em risco imediato, oriente busca de ajuda real e local seguro.',
            ),
            const SizedBox(height: 18),
            if (support.statusMessage != null)
              StatusNoticeBanner(
                message: support.statusMessage!,
                icon: Icons.verified_user_outlined,
              ),
            const SizedBox(height: 18),
            AppButton.primary(
              label: support.isSubmitting
                  ? 'Registrando aceite...'
                  : 'Aceito as diretrizes',
              onPressed: support.isSubmitting
                  ? null
                  : () async {
                      final acknowledged = await ref
                          .read(supportControllerProvider.notifier)
                          .acknowledgeGuidelines();
                      if (!context.mounted || !acknowledged) {
                        return;
                      }
                      context.go('/supporter-dashboard');
                    },
            ),
          ],
        ),
      ),
    );
  }
}

class ReportSupporterScreen extends ConsumerStatefulWidget {
  const ReportSupporterScreen({
    required this.sessionId,
    super.key,
  });

  final String sessionId;

  @override
  ConsumerState<ReportSupporterScreen> createState() =>
      _ReportSupporterScreenState();
}

class _ReportSupporterScreenState extends ConsumerState<ReportSupporterScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  String _reason = 'safety_concern';

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final support = ref.watch(supportControllerProvider);
    return AppShell(
      title: 'Denunciar apoiador',
      subtitle:
          'Se algo na conversa humana foi inadequado, voce pode registrar isso para revisao segura.',
      maxContentWidth: 760,
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _reason,
              decoration: const InputDecoration(labelText: 'Motivo'),
              items: const [
                DropdownMenuItem(
                  value: 'safety_concern',
                  child: Text('Preocupacao com seguranca'),
                ),
                DropdownMenuItem(
                  value: 'pressure_or_judgment',
                  child: Text('Pressao ou julgamento'),
                ),
                DropdownMenuItem(
                  value: 'inadequate_language',
                  child: Text('Linguagem inadequada'),
                ),
                DropdownMenuItem(
                  value: 'identity_misrepresentation',
                  child: Text('Representacao inadequada'),
                ),
                DropdownMenuItem(
                  value: 'other',
                  child: Text('Outro'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _reason = value);
                }
              },
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _descriptionController,
              label: 'Descricao opcional',
              maxLines: 5,
              hint: 'Descreva apenas o que for importante para revisao segura.',
            ),
            const SizedBox(height: 18),
            if (support.errorMessage != null)
              StatusNoticeBanner(
                message: support.errorMessage!,
                icon: Icons.info_outline_rounded,
                tone: Theme.of(context).colorScheme.error,
              ),
            const SizedBox(height: 18),
            AppButton.primary(
              label: support.isSubmitting ? 'Enviando...' : 'Enviar denuncia',
              onPressed: support.isSubmitting
                  ? null
                  : () async {
                      final reported = await ref
                          .read(supportControllerProvider.notifier)
                          .reportSupporter(
                            sessionId: widget.sessionId,
                            reason: _reason,
                            description: _descriptionController.text.trim(),
                          );
                      if (!context.mounted || !reported) {
                        return;
                      }
                      context.pop();
                    },
            ),
          ],
        ),
      ),
    );
  }
}

class _GuidelineBullet extends StatelessWidget {
  const _GuidelineBullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Icon(Icons.circle, size: 8),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _SupportTopBar extends StatelessWidget {
  const _SupportTopBar({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF10171D)
            : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _HumanMessageBubble extends StatelessWidget {
  const _HumanMessageBubble({required this.message});

  final HumanSupportMessageModel message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.senderRole == SupportRoleType.user;
    final theme = Theme.of(context);
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: isUser
              ? theme.colorScheme.primary
              : (theme.brightness == Brightness.dark
                  ? const Color(0xFF17212A)
                  : Colors.white),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: message.isFlagged
                ? theme.colorScheme.error
                : theme.dividerColor,
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.content,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: isUser
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message.senderRole.label,
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}
