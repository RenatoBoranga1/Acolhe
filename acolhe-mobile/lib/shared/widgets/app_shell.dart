import 'package:acolhe_mobile/core/navigation/safe_navigation.dart';
import 'package:acolhe_mobile/features/auth/application/auth_controller.dart';
import 'package:acolhe_mobile/shared/widgets/responsive_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AppShell extends ConsumerWidget {
  const AppShell({
    required this.title,
    required this.child,
    super.key,
    this.subtitle,
    this.showBack = true,
    this.padding = const EdgeInsets.symmetric(vertical: 24),
    this.actions,
    this.maxContentWidth,
    this.backFallbackRoute = '/chat',
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final bool showBack;
  final EdgeInsets padding;
  final List<Widget>? actions;
  final double? maxContentWidth;
  final String backFallbackRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final horizontalPadding = AppResponsive.horizontalPadding(viewportWidth);
    final resolvedMaxWidth =
        maxContentWidth ?? AppResponsive.shellMaxWidth(viewportWidth);

    final shell = Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [
                    Color(0xFF10171D),
                    Color(0xFF17212A),
                    Color(0xFF10171D)
                  ]
                : const [
                    Color(0xFFF5EFE9),
                    Color(0xFFF2F5F6),
                    Color(0xFFF7F1EC)
                  ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              padding.top,
              horizontalPadding,
              padding.bottom,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: resolvedMaxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (showBack)
                          IconButton(
                            tooltip: 'Voltar',
                            onPressed: () => AcolheNavigation.goBackOrFallback(
                              context,
                              fallbackLocation: backFallbackRoute,
                            ),
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: theme.textTheme.headlineSmall),
                              if (subtitle != null) ...[
                                const SizedBox(height: 4),
                                Text(subtitle!,
                                    style: theme.textTheme.bodyMedium),
                              ],
                            ],
                          ),
                        ),
                        if (actions != null) ...actions!,
                        if (auth.quickExitEnabled)
                          IconButton(
                            tooltip: 'Saida rapida',
                            onPressed: () {
                              ref
                                  .read(authControllerProvider.notifier)
                                  .showPrivacyShield();
                              context.go('/privacy');
                            },
                            icon: const Icon(Icons.visibility_off_outlined),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    child,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return PopScope(
      canPop: !showBack || GoRouter.of(context).canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || !showBack) {
          return;
        }
        context.go(backFallbackRoute);
      },
      child: shell,
    );
  }
}
