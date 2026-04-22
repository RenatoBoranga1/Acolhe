import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

class AcolheNavigation {
  const AcolheNavigation._();

  static void goBackOrFallback(
    BuildContext context, {
    required String fallbackLocation,
  }) {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      context.pop();
      return;
    }
    context.go(fallbackLocation);
  }
}
