import 'package:acolhe_mobile/core/router/app_router.dart';
import 'package:acolhe_mobile/core/theme/app_theme.dart';
import 'package:acolhe_mobile/features/auth/application/auth_controller.dart';
import 'package:acolhe_mobile/shared/widgets/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: AcolheApp()));
}

class AcolheApp extends ConsumerStatefulWidget {
  const AcolheApp({super.key});

  @override
  ConsumerState<AcolheApp> createState() => _AcolheAppState();
}

class _AcolheAppState extends ConsumerState<AcolheApp> with WidgetsBindingObserver {
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = ref.read(authControllerProvider.notifier);
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _backgroundedAt = DateTime.now();
      controller.showPrivacyShield();
      return;
    }
    if (state == AppLifecycleState.resumed) {
      final auth = ref.read(authControllerProvider);
      final backgroundGap = _backgroundedAt == null
          ? Duration.zero
          : DateTime.now().difference(_backgroundedAt!);
      if (backgroundGap.inMinutes >= auth.autoLockMinutes && auth.hasPin) {
        controller.lock();
      }
      controller.hidePrivacyShield();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final auth = ref.watch(authControllerProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: auth.currentAppName,
      theme: AcolheTheme.lightTheme,
      darkTheme: AcolheTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
      builder: (context, child) {
        return Stack(
          children: [
            child ?? const SizedBox.shrink(),
            if (auth.privacyShield) const PrivacyShieldOverlay(),
          ],
        );
      },
    );
  }
}
