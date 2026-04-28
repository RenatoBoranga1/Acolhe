import 'package:acolhe_mobile/core/config/app_identity.dart';
import 'package:acolhe_mobile/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

enum AcolheLockupOrientation { horizontal, vertical }

class AcolheBrandMark extends StatelessWidget {
  const AcolheBrandMark({
    super.key,
    this.size = 72,
    this.monochrome = false,
    this.onDark = false,
    this.withContainer = false,
  });

  final double size;
  final bool monochrome;
  final bool onDark;
  final bool withContainer;

  @override
  Widget build(BuildContext context) {
    final mark = SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _AcolheBrandMarkPainter(
          monochrome: monochrome,
          onDark: onDark,
        ),
      ),
    );

    if (!withContainer) {
      return mark;
    }

    final background = onDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.84);

    return Container(
      width: size + 18,
      height: size + 18,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size * 0.34),
        boxShadow: onDark
            ? null
            : [
                BoxShadow(
                  color: AcolheTheme.graphite.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      alignment: Alignment.center,
      child: mark,
    );
  }
}

class AcolheBrandLockup extends StatelessWidget {
  const AcolheBrandLockup({
    super.key,
    this.orientation = AcolheLockupOrientation.horizontal,
    this.markSize = 72,
    this.showTagline = true,
    this.onDark = false,
    this.monochrome = false,
    this.center = false,
  });

  final AcolheLockupOrientation orientation;
  final double markSize;
  final bool showTagline;
  final bool onDark;
  final bool monochrome;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final wordmarkColor = monochrome
        ? (onDark ? Colors.white : AcolheTheme.graphite)
        : AcolheTheme.graphite;
    final neutralTagColor = onDark
        ? Colors.white.withValues(alpha: 0.86)
        : AcolheTheme.graphite.withValues(alpha: 0.74);
    final taglineBaseStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: neutralTagColor,
        );

    final label = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          AppIdentity.appName,
          style: TextStyle(
            fontSize: markSize * 0.68,
            height: 1,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.6,
            color: wordmarkColor,
          ),
        ),
        if (showTagline) ...[
          const SizedBox(height: 6),
          Wrap(
            alignment: center ? WrapAlignment.center : WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                'RESPEITO',
                style: taglineBaseStyle?.copyWith(color: AcolheTheme.calmGreen),
              ),
              _BrandTagDot(color: neutralTagColor),
              Text(
                'APOIO',
                style: taglineBaseStyle?.copyWith(color: AcolheTheme.lavender),
              ),
              _BrandTagDot(color: neutralTagColor),
              Text(
                'ESCUTA',
                style: taglineBaseStyle?.copyWith(color: AcolheTheme.trustBlue),
              ),
            ],
          ),
        ],
      ],
    );

    if (orientation == AcolheLockupOrientation.vertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          AcolheBrandMark(
            size: markSize,
            monochrome: monochrome,
            onDark: onDark,
          ),
          const SizedBox(height: 18),
          label,
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AcolheBrandMark(
          size: markSize,
          monochrome: monochrome,
          onDark: onDark,
        ),
        const SizedBox(width: 18),
        label,
      ],
    );
  }
}

class AcolheBrandPill extends StatelessWidget {
  const AcolheBrandPill({
    super.key,
    this.onDark = false,
  });

  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final borderColor = onDark
        ? Colors.white.withValues(alpha: 0.08)
        : AcolheTheme.trustBlue.withValues(alpha: 0.14);
    final background = onDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.white.withValues(alpha: 0.72);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AcolheBrandMark(size: 26, onDark: onDark),
          const SizedBox(width: 10),
          Text(
            AppIdentity.appName,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: onDark ? Colors.white : AcolheTheme.graphite,
                ),
          ),
        ],
      ),
    );
  }
}

class _BrandTagDot extends StatelessWidget {
  const _BrandTagDot({
    required this.color,
  });

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _AcolheBrandMarkPainter extends CustomPainter {
  const _AcolheBrandMarkPainter({
    required this.monochrome,
    required this.onDark,
  });

  final bool monochrome;
  final bool onDark;

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.14;
    final leftColor = monochrome
        ? (onDark ? Colors.white : AcolheTheme.graphite)
        : AcolheTheme.calmGreen;
    final rightColor = monochrome
        ? (onDark ? Colors.white : AcolheTheme.graphite)
        : AcolheTheme.lavender;
    final heartColor = monochrome
        ? (onDark ? Colors.white : AcolheTheme.graphite)
        : AcolheTheme.lavender;

    final leftPaint = Paint()
      ..color = leftColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = strokeWidth;
    final rightPaint = Paint()
      ..color = rightColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = strokeWidth;

    final headRadius = size.width * 0.095;
    final leftHeadCenter = Offset(size.width * 0.28, size.height * 0.17);
    final rightHeadCenter = Offset(size.width * 0.72, size.height * 0.20);
    canvas.drawCircle(leftHeadCenter, headRadius, Paint()..color = leftColor);
    canvas.drawCircle(rightHeadCenter, headRadius, Paint()..color = rightColor);

    final leftPath = Path()
      ..moveTo(size.width * 0.43, size.height * 0.34)
      ..cubicTo(
        size.width * 0.19,
        size.height * 0.30,
        size.width * 0.10,
        size.height * 0.58,
        size.width * 0.31,
        size.height * 0.79,
      );
    final rightPath = Path()
      ..moveTo(size.width * 0.57, size.height * 0.34)
      ..cubicTo(
        size.width * 0.81,
        size.height * 0.30,
        size.width * 0.90,
        size.height * 0.58,
        size.width * 0.69,
        size.height * 0.79,
      );

    canvas.drawPath(leftPath, leftPaint);
    canvas.drawPath(rightPath, rightPaint);
    canvas.drawPath(_heartPath(size), Paint()..color = heartColor);
  }

  Path _heartPath(Size size) {
    final left = size.width * 0.37;
    final top = size.height * 0.37;
    final width = size.width * 0.26;
    final height = size.height * 0.24;
    final cx = left + width / 2;
    final bottom = top + height;

    return Path()
      ..moveTo(cx, bottom)
      ..cubicTo(
        cx - width * 0.14,
        bottom - height * 0.12,
        left,
        bottom - height * 0.34,
        left,
        top + height * 0.26,
      )
      ..cubicTo(
        left,
        top,
        left + width * 0.16,
        top - height * 0.08,
        left + width * 0.32,
        top - height * 0.08,
      )
      ..cubicTo(
        left + width * 0.44,
        top - height * 0.08,
        cx - width * 0.06,
        top - height * 0.01,
        cx,
        top + height * 0.11,
      )
      ..cubicTo(
        cx + width * 0.06,
        top - height * 0.01,
        left + width * 0.56,
        top - height * 0.08,
        left + width * 0.68,
        top - height * 0.08,
      )
      ..cubicTo(
        left + width * 0.84,
        top - height * 0.08,
        left + width,
        top,
        left + width,
        top + height * 0.26,
      )
      ..cubicTo(
        left + width,
        bottom - height * 0.34,
        cx + width * 0.14,
        bottom - height * 0.12,
        cx,
        bottom,
      )
      ..close();
  }

  @override
  bool shouldRepaint(covariant _AcolheBrandMarkPainter oldDelegate) {
    return monochrome != oldDelegate.monochrome || onDark != oldDelegate.onDark;
  }
}
