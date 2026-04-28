import 'dart:async';

import 'package:acolhe_mobile/features/auth/application/auth_controller.dart';
import 'package:acolhe_mobile/shared/widgets/app_shell.dart';
import 'package:acolhe_mobile/shared/widgets/brand_logo.dart';
import 'package:acolhe_mobile/shared/widgets/design_system.dart';
import 'package:acolhe_mobile/shared/widgets/responsive_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _navigated = false;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    if (!_navigated && !auth.isLoading) {
      _navigated = true;
      unawaited(Future<void>.delayed(const Duration(milliseconds: 900), () {
        if (!mounted) {
          return;
        }
        if (!auth.onboardingCompleted) {
          context.go('/onboarding');
        } else if (!auth.hasPin) {
          context.go('/pin-setup');
        } else if (!auth.isUnlocked) {
          context.go('/login');
        } else {
          context.go('/chat');
        }
      }));
    }

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AcolheBrandLockup(
                orientation: AcolheLockupOrientation.vertical,
                markSize: 106,
                center: true,
              ),
              const SizedBox(height: 18),
              Text(
                auth.discreetMode
                    ? 'Espaco privado protegido'
                    : 'Acolhimento inicial com privacidade, escuta e seguranca',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  bool _discreetMode = true;
  bool _biometrics = true;

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Boas-vindas',
      subtitle:
          'Privacidade, acolhimento e clareza sobre limites desde o inicio.',
      showBack: false,
      maxContentWidth: 1020,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdaptiveTwoPane(
            breakpoint: 900,
            primary: const GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AcolheBrandLockup(markSize: 70),
                  SizedBox(height: 18),
                  SectionTitle(
                    title: 'Como o Acolhe pode apoiar',
                    subtitle:
                        'Conversas acolhedoras, registro privado, plano de seguranca e organizacao de proximos passos.',
                  ),
                  SizedBox(height: 16),
                  Text(
                      'A assistente virtual oferece acolhimento inicial e orientacao geral.'),
                  SizedBox(height: 8),
                  Text(
                      'Ela nao substitui psicologo, advogado, medico, assistente social ou policia.'),
                  SizedBox(height: 8),
                  Text(
                      'Se houver risco imediato, procure emergencia local ou uma pessoa de confianca.'),
                ],
              ),
            ),
            secondary: GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle(
                    title: 'Protecao por padrao',
                    subtitle:
                        'Voce pode ajustar agora e mudar depois nas configuracoes.',
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: _discreetMode,
                    onChanged: (value) => setState(() => _discreetMode = value),
                    title: const Text('Ativar modo discreto'),
                    subtitle: const Text(
                        'Mantem a interface mais neutra e discreta.'),
                  ),
                  SwitchListTile(
                    value: _biometrics,
                    onChanged: (value) => setState(() => _biometrics = value),
                    title: const Text('Preparar desbloqueio por biometria'),
                    subtitle:
                        const Text('Disponivel quando o aparelho suportar.'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          AppButton.primary(
            label: 'Continuar com seguranca',
            onPressed: () async {
              await ref
                  .read(authControllerProvider.notifier)
                  .completeOnboarding(
                    discreetMode: _discreetMode,
                    biometricsEnabled: _biometrics,
                  );
              if (!mounted) {
                return;
              }
              context.go('/pin-setup');
            },
          ),
        ],
      ),
    );
  }
}

class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Criar PIN',
      subtitle: 'Seu PIN protege o acesso local ao conteudo sensivel.',
      showBack: false,
      maxContentWidth: 560,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 18),
            child: AcolheBrandMark(size: 54, withContainer: true),
          ),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField(
                  controller: _pinController,
                  label: 'PIN',
                  hint: 'Use 4 a 8 numeros',
                  keyboardType: TextInputType.number,
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _confirmController,
                  label: 'Confirmar PIN',
                  keyboardType: TextInputType.number,
                  obscureText: true,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          AppButton.primary(
            label: 'Salvar PIN',
            onPressed: () async {
              final pin = _pinController.text.trim();
              final confirm = _confirmController.text.trim();
              if (pin.length < 4 || pin != confirm) {
                setState(() => _error =
                    'Use um PIN de 4 a 8 numeros e confirme corretamente.');
                return;
              }
              await ref.read(authControllerProvider.notifier).setupPin(pin);
              if (!mounted) {
                return;
              }
              context.go('/chat');
            },
          ),
        ],
      ),
    );
  }
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _pinController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    return AppShell(
      title: auth.currentAppName,
      subtitle: auth.discreetMode
          ? 'Acesso protegido ao seu espaco privado.'
          : 'Desbloqueie para acessar conversas e registros protegidos.',
      showBack: false,
      maxContentWidth: 560,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 18),
            child: AcolheBrandMark(size: 54, withContainer: true),
          ),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle(
                  title: 'Entrar',
                  subtitle:
                      'Seu conteudo fica salvo apenas neste aparelho, com protecao local.',
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _pinController,
                  label: 'PIN',
                  keyboardType: TextInputType.number,
                  obscureText: true,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 20),
                AppButton.primary(
                  label: 'Desbloquear',
                  onPressed: () async {
                    final ok = await ref
                        .read(authControllerProvider.notifier)
                        .unlockWithPin(
                          _pinController.text.trim(),
                        );
                    if (!mounted) {
                      return;
                    }
                    if (ok) {
                      context.go('/chat');
                    } else {
                      setState(() => _error = 'PIN invalido. Tente novamente.');
                    }
                  },
                ),
                if (auth.biometricsEnabled) ...[
                  const SizedBox(height: 12),
                  AppButton.secondary(
                    label: 'Entrar com biometria',
                    icon: Icons.fingerprint_rounded,
                    onPressed: () async {
                      final ok = await ref
                          .read(authControllerProvider.notifier)
                          .unlockWithBiometrics();
                      if (!mounted) {
                        return;
                      }
                      if (ok) {
                        context.go('/chat');
                      } else {
                        setState(() => _error =
                            'Biometria indisponivel ou nao confirmada.');
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
