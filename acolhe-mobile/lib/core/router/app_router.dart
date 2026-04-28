import 'package:acolhe_mobile/features/auth/presentation/auth_screens.dart';
import 'package:acolhe_mobile/features/chat/presentation/chat_screen.dart';
import 'package:acolhe_mobile/features/home/presentation/home_screen.dart';
import 'package:acolhe_mobile/features/journal/presentation/journal_screens.dart';
import 'package:acolhe_mobile/features/resources/presentation/resources_screen.dart';
import 'package:acolhe_mobile/features/safety_plan/presentation/safety_plan_screen.dart';
import 'package:acolhe_mobile/features/settings/presentation/settings_screens.dart';
import 'package:acolhe_mobile/features/support_network/presentation/support_network_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingScreen()),
      GoRoute(
          path: '/pin-setup',
          builder: (context, state) => const PinSetupScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(path: '/chat', builder: (context, state) => const ChatScreen()),
      GoRoute(
          path: '/urgent-help',
          builder: (context, state) => const UrgentHelpScreen()),
      GoRoute(
          path: '/incident-record',
          builder: (context, state) => const IncidentRecordScreen()),
      GoRoute(
          path: '/incident-summary',
          builder: (context, state) => const IncidentSummaryScreen()),
      GoRoute(
          path: '/safety-plan',
          builder: (context, state) => const SafetyPlanScreen()),
      GoRoute(
          path: '/support-network',
          builder: (context, state) => const SupportNetworkScreen()),
      GoRoute(
          path: '/resources',
          builder: (context, state) => const ResourcesScreen()),
      GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen()),
      GoRoute(
          path: '/backend-connection',
          builder: (context, state) => const BackendConnectionScreen()),
      GoRoute(
          path: '/privacy', builder: (context, state) => const PrivacyScreen()),
    ],
  );
});
