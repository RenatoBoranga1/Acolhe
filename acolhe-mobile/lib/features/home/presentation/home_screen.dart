import 'package:acolhe_mobile/features/auth/application/auth_controller.dart';
import 'package:acolhe_mobile/features/chat/application/chat_controller.dart';
import 'package:acolhe_mobile/shared/widgets/app_shell.dart';
import 'package:acolhe_mobile/shared/widgets/design_system.dart';
import 'package:acolhe_mobile/shared/widgets/responsive_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final chat = ref.watch(chatControllerProvider);
    final appName = auth.currentAppName;
    final recentConversations = chat.conversations.take(3).toList(growable: false);
    return AppShell(
      title: appName,
      subtitle: auth.discreetMode
          ? 'Seu espaco protegido para conversar, registrar e se organizar.'
          : 'Acolhimento inicial, organizacao segura e apoio no seu ritmo.',
      showBack: false,
      maxContentWidth: 1200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdaptiveTwoPane(
            breakpoint: 940,
            primaryFlex: 6,
            secondaryFlex: 5,
            primary: GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle(
                    title: 'Chat como centro do cuidado',
                    subtitle:
                        'O Acolhe agora prioriza a conversa como experiencia principal, mantendo registro, plano de seguranca e rede de apoio ao alcance.',
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'A assistente oferece acolhimento inicial e orientacao geral. Nao substitui apoio psicologico, juridico, medico ou policial.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  AppButton.primary(
                    label: 'Abrir chat principal',
                    icon: Icons.chat_bubble_outline_rounded,
                    onPressed: () => context.go('/chat'),
                  ),
                  const SizedBox(height: 12),
                  AppButton.secondary(
                    label: 'Nova conversa protegida',
                    icon: Icons.add_comment_outlined,
                    onPressed: () async {
                      await ref.read(chatControllerProvider.notifier).newConversation();
                      if (!context.mounted) {
                        return;
                      }
                      context.go('/chat');
                    },
                  ),
                ],
              ),
            ),
            secondary: GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Conversas recentes', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  Text(
                    'Historico salvo localmente no aparelho para retomada mais facil.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 14),
                  if (recentConversations.isEmpty)
                    const Text('Nenhuma conversa salva ainda.')
                  else
                    for (var index = 0; index < recentConversations.length; index++) ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.forum_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: Text(recentConversations[index].title),
                        subtitle: Text(
                          recentConversations[index].previewText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () async {
                          await ref
                              .read(chatControllerProvider.notifier)
                              .switchConversation(recentConversations[index].id);
                          if (!context.mounted) {
                            return;
                          }
                          context.go('/chat');
                        },
                      ),
                      if (index < recentConversations.length - 1)
                        const Divider(height: 12),
                    ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          AdaptiveCardGrid(
            minItemWidth: 320,
            spacing: 14,
            children: [
              HomeFeatureCard(
                title: 'Conversar agora',
                subtitle: 'Abrir o chat acolhedor com respostas curtas, seguras e responsaveis.',
                icon: Icons.chat_bubble_outline_rounded,
                onTap: () => context.push('/chat'),
              ),
              HomeFeatureCard(
                title: 'Preciso de ajuda urgente',
                subtitle: 'Atalhos para seguranca imediata, rede de apoio e plano rapido.',
                icon: Icons.warning_amber_rounded,
                tone: Theme.of(context).colorScheme.error,
                onTap: () => context.push('/urgent-help'),
              ),
              HomeFeatureCard(
                title: 'Registrar o que aconteceu',
                subtitle: 'Guardar fatos importantes em um rascunho pessoal privado.',
                icon: Icons.event_note_outlined,
                onTap: () => context.push('/incident-record'),
              ),
              HomeFeatureCard(
                title: 'Plano de seguranca',
                subtitle: 'Locais seguros, sinais de alerta, passos imediatos e checklist.',
                icon: Icons.shield_outlined,
                onTap: () => context.push('/safety-plan'),
              ),
              HomeFeatureCard(
                title: 'Rede de apoio',
                subtitle: 'Contatos confiaveis e mensagem pronta para pedir ajuda.',
                icon: Icons.people_outline_rounded,
                onTap: () => context.push('/support-network'),
              ),
              HomeFeatureCard(
                title: 'Informacoes e direitos',
                subtitle: 'Conteudo educativo em linguagem clara e facil de atualizar.',
                icon: Icons.menu_book_outlined,
                onTap: () => context.push('/resources'),
              ),
              HomeFeatureCard(
                title: 'Configuracoes e privacidade',
                subtitle: 'Modo discreto, biometria, auto-bloqueio e limpeza rapida.',
                icon: Icons.lock_outline_rounded,
                onTap: () => context.push('/settings'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class UrgentHelpScreen extends ConsumerWidget {
  const UrgentHelpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppShell(
      title: 'Ajuda urgente',
      subtitle: 'Se houver risco imediato, priorize sua seguranca agora.',
      child: AdaptiveTwoPane(
        primary: const GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(
                title: 'Mensagem curta de seguranca',
                subtitle:
                    'Se voce estiver em perigo imediato, tente ir para um local seguro e acione emergencia local ou uma pessoa de confianca.',
              ),
              SizedBox(height: 16),
              Text(
                'Se falar estiver dificil, use apenas a acao mais rapida disponivel para este momento.',
              ),
            ],
          ),
        ),
        secondary: Column(
          children: [
            AppButton.primary(
              label: 'Ligar para emergencia',
              icon: Icons.call_rounded,
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Integre aqui o discador seguro do dispositivo.')),
                );
              },
            ),
            const SizedBox(height: 12),
            AppButton.secondary(
              label: 'Abrir contatos de confianca',
              icon: Icons.people_outline_rounded,
              onPressed: () => context.push('/support-network'),
            ),
            const SizedBox(height: 12),
            AppButton.secondary(
              label: 'Abrir plano de seguranca',
              icon: Icons.shield_outlined,
              onPressed: () => context.push('/safety-plan'),
            ),
            const SizedBox(height: 12),
            AppButton.secondary(
              label: 'Sair rapido',
              icon: Icons.visibility_off_outlined,
              onPressed: () => context.go('/privacy'),
            ),
          ],
        ),
      ),
    );
  }
}
