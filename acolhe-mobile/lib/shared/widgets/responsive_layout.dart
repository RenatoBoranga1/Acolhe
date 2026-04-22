import 'dart:math' as math;

import 'package:flutter/material.dart';

class AppResponsive {
  static bool isTabletWidth(double width) => width >= 720;

  static bool isTwoPaneWidth(double width) => width >= 960;

  static bool isExpandedWidth(double width) => width >= 1280;

  static double horizontalPadding(double width) {
    if (isExpandedWidth(width)) {
      return 48;
    }
    if (isTabletWidth(width)) {
      return 32;
    }
    return 20;
  }

  static double shellMaxWidth(double width) {
    if (isExpandedWidth(width)) {
      return 1320;
    }
    if (isTabletWidth(width)) {
      return 1080;
    }
    return width;
  }
}

class AdaptiveTwoPane extends StatelessWidget {
  const AdaptiveTwoPane({
    required this.primary,
    required this.secondary,
    super.key,
    this.breakpoint = 960,
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
