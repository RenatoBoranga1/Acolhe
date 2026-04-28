import 'package:acolhe_mobile/core/storage/secure_storage_service.dart';
import 'package:acolhe_mobile/shared/widgets/app_shell.dart';
import 'package:acolhe_mobile/shared/widgets/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('back button falls back safely when there is no route stack',
      (tester) async {
    final router = _buildRouter(initialLocation: '/settings');

    await tester.pumpWidget(_TestApp(router: router));
    await tester.pumpAndSettle();

    expect(find.text('Settings content'), findsOneWidget);

    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();

    expect(find.text('Home content'), findsOneWidget);
  });

  testWidgets('back button pops when the page was opened with push',
      (tester) async {
    final router = _buildRouter(initialLocation: '/home');

    await tester.pumpWidget(_TestApp(router: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    expect(find.text('Settings content'), findsOneWidget);

    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();

    expect(find.text('Home content'), findsOneWidget);
  });
}

GoRouter _buildRouter({required String initialLocation}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/home',
        builder: (context, state) => AppShell(
          title: 'Home',
          showBack: false,
          child: GlassCard(
            child: Column(
              children: [
                const Text('Home content'),
                TextButton(
                  onPressed: () => context.push('/settings'),
                  child: const Text('Open settings'),
                ),
              ],
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const AppShell(
          title: 'Settings',
          backFallbackRoute: '/home',
          child: GlassCard(child: Text('Settings content')),
        ),
      ),
    ],
  );
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        secureStorageProvider.overrideWithValue(_FakeSecureStorageService()),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: ThemeData(useMaterial3: true),
      ),
    );
  }
}

class _FakeSecureStorageService extends SecureStorageService {
  _FakeSecureStorageService();

  final Map<String, String> _values = {};

  @override
  Future<void> writeString(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<String?> readString(String key) async => _values[key] ?? 'pin-hash';

  @override
  Future<void> writeMap(String key, Map<String, dynamic> value) async {
    _values[key] = value.toString();
  }

  @override
  Future<Map<String, dynamic>?> readMap(String key) async => {
        'onboardingCompleted': true,
        'hasPin': true,
        'isUnlocked': true,
        'biometricsEnabled': false,
        'discreetMode': false,
        'autoLockMinutes': 5,
        'aliasName': 'Acolhe',
        'notificationsHidden': true,
        'quickExitEnabled': true,
      };

  @override
  Future<void> writeList(String key, List<Map<String, dynamic>> value) async {}

  @override
  Future<List<Map<String, dynamic>>> readList(String key) async => [];

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    _values.clear();
  }
}
