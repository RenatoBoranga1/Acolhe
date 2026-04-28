import 'dart:math' as math;

import 'package:flutter/material.dart';

class AppBreakpoints {
  const AppBreakpoints._();

  static const double mobileMax = 600;
  static const double tabletMax = 1024;
  static const double compactTwoPaneMin = 760;
  static const double inlineSidebarMin = 860;
  static const double desktopMin = 1025;
  static const double expandedMin = 1440;
}

enum AppViewport { mobile, tablet, desktop }

class AppResponsive {
  const AppResponsive._();

  static AppViewport viewportFor(double width) {
    if (width <= AppBreakpoints.mobileMax) {
      return AppViewport.mobile;
    }
    if (width <= AppBreakpoints.tabletMax) {
      return AppViewport.tablet;
    }
    return AppViewport.desktop;
  }

  static bool isMobileWidth(double width) =>
      viewportFor(width) == AppViewport.mobile;

  static bool isTabletWidth(double width) =>
      viewportFor(width) == AppViewport.tablet;

  static bool isDesktopWidth(double width) =>
      viewportFor(width) == AppViewport.desktop;

  static bool isTwoPaneWidth(double width) =>
      width >= AppBreakpoints.compactTwoPaneMin;

  static bool showsInlineSidebar(double width) =>
      width >= AppBreakpoints.inlineSidebarMin;

  static double horizontalPadding(double width) {
    return switch (viewportFor(width)) {
      AppViewport.mobile => 16,
      AppViewport.tablet => 28,
      AppViewport.desktop => width >= AppBreakpoints.expandedMin ? 48 : 36,
    };
  }

  static double shellMaxWidth(double width) {
    return switch (viewportFor(width)) {
      AppViewport.mobile => width,
      AppViewport.tablet => 1080,
      AppViewport.desktop => 1320,
    };
  }

  static double chatMaxWidth(double width) {
    return switch (viewportFor(width)) {
      AppViewport.mobile => width,
      AppViewport.tablet => 920,
      AppViewport.desktop => 980,
    };
  }

  static double chatSidebarWidth(double width) {
    if (width >= AppBreakpoints.desktopMin) {
      return 344;
    }
    return 292;
  }
}

class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    required this.builder,
    super.key,
  });

  final Widget Function(BuildContext context, AppViewport viewport) builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return builder(
          context,
          AppResponsive.viewportFor(constraints.maxWidth),
        );
      },
    );
  }
}

class AdaptiveTwoPane extends StatelessWidget {
  const AdaptiveTwoPane({
    required this.primary,
    required this.secondary,
    super.key,
    this.breakpoint = AppBreakpoints.compactTwoPaneMin,
    this.spacing = 20,
    this.primaryFlex = 6,
    this.secondaryFlex = 5,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  final Widget primary;
  final Widget secondary;
  final double breakpoint;
  final double spacing;
  final int primaryFlex;
  final int secondaryFlex;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= breakpoint) {
          return Row(
            crossAxisAlignment: crossAxisAlignment,
            children: [
              Expanded(flex: primaryFlex, child: primary),
              SizedBox(width: spacing),
              Expanded(flex: secondaryFlex, child: secondary),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            primary,
            SizedBox(height: spacing),
            secondary,
          ],
        );
      },
    );
  }
}

class AdaptiveCardGrid extends StatelessWidget {
  const AdaptiveCardGrid({
    required this.children,
    super.key,
    this.minItemWidth = 280,
    this.spacing = 16,
  });

  final List<Widget> children;
  final double minItemWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final columns = math.max(
          1,
          ((availableWidth + spacing) / (minItemWidth + spacing)).floor(),
        );
        final itemWidth = columns == 1
            ? availableWidth
            : (availableWidth - ((columns - 1) * spacing)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children)
              SizedBox(
                width: itemWidth,
                child: child,
              ),
          ],
        );
      },
    );
  }
}
