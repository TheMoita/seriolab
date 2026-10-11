import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Seriolab's signature animated loading indicator: a minimalist laboratory
/// beaker / Erlenmeyer flask with flowing liquid, rising micro-bubbles,
/// and a gentle breathing pulse.
class SeriolabLoader extends StatefulWidget {
  const SeriolabLoader({
    super.key,
    this.size = 48.0,
    this.strokeWidth,
    this.primaryColor,
    this.secondaryColor,
  });

  /// The width and height of the loader widget.
  final double size;

  /// Custom stroke width for the flask outline.
  final double? strokeWidth;

  /// Primary accent color (defaults to [AppColors.primary] - Electric Violet).
  final Color? primaryColor;

  /// Secondary accent color (defaults to [AppColors.secondary] - Vibrant Cyan).
  final Color? secondaryColor;

  @override
  State<SeriolabLoader> createState() => _SeriolabLoaderState();
}

class _SeriolabLoaderState extends State<SeriolabLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = widget.primaryColor ?? AppColors.primary;
    final secondary = widget.secondaryColor ?? AppColors.secondary;
    final strokeW = widget.strokeWidth ?? (widget.size * 0.055).clamp(2.0, 3.5);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        // Smooth breathing scale between 0.95 and 1.05
        final pulse = 0.95 + 0.10 * (0.5 - 0.5 * math.cos(t * 2 * math.pi));

        return Transform.scale(
          scale: pulse,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _BeakerPainter(
                progress: t,
                primaryColor: primary,
                secondaryColor: secondary,
                strokeWidth: strokeW,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BeakerPainter extends CustomPainter {
  _BeakerPainter({
    required this.progress,
    required this.primaryColor,
    required this.secondaryColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color primaryColor;
  final Color secondaryColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Padding to ensure thick strokes and glow fit inside canvas
    final pad = strokeWidth * 1.5;
    final left = pad;
    final right = w - pad;
    final top = pad + h * 0.04;
    final bottom = h - pad;

    final contentW = right - left;
    final contentH = bottom - top;

    final neckWidth = contentW * 0.32;
    final neckLeft = left + (contentW - neckWidth) / 2;
    final neckRight = neckLeft + neckWidth;
    final neckHeight = contentH * 0.30;
    final neckBottom = top + neckHeight;

    final baseCornerRadius = contentW * 0.14;
    final baseLeft = left + contentW * 0.04;
    final baseRight = right - contentW * 0.04;
    final baseBottom = bottom;

    // Build the closed Erlenmeyer flask path
    final beakerPath = Path()
      ..moveTo(neckLeft, top)
      ..lineTo(neckLeft, neckBottom)
      ..lineTo(baseLeft, baseBottom - baseCornerRadius)
      ..quadraticBezierTo(baseLeft, baseBottom, baseLeft + baseCornerRadius, baseBottom)
      ..lineTo(baseRight - baseCornerRadius, baseBottom)
      ..quadraticBezierTo(baseRight, baseBottom, baseRight, baseBottom - baseCornerRadius)
      ..lineTo(neckRight, neckBottom)
      ..lineTo(neckRight, top)
      ..close();

    // 1. Draw Liquid Fill & Waves Inside
    canvas.save();
    canvas.clipPath(beakerPath);

    // Liquid fill level oscillates between 28% and 65% height of the conical body
    final liquidHeightFactor =
        0.28 + 0.37 * (0.5 - 0.5 * math.cos(progress * 2 * math.pi));
    final bodyHeight = baseBottom - neckBottom;
    final liquidY = baseBottom - bodyHeight * liquidHeightFactor;
    final wavePhase = progress * 2 * math.pi;
    final waveAmplitude = contentH * 0.025;

    final liquidPath = Path()..moveTo(left - 10, baseBottom + 10);
    liquidPath.lineTo(left - 10, liquidY);
    for (double x = left - 10; x <= right + 10; x += 3) {
      final y = liquidY +
          math.sin(((x - left) / contentW) * 2 * math.pi + wavePhase) *
              waveAmplitude;
      liquidPath.lineTo(x, y);
    }
    liquidPath.lineTo(right + 10, baseBottom + 10);
    liquidPath.close();

    final liquidRect = Rect.fromLTRB(baseLeft, liquidY - waveAmplitude, baseRight, baseBottom);
    final liquidPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          primaryColor.withValues(alpha: 0.70),
          secondaryColor.withValues(alpha: 0.85),
        ],
      ).createShader(liquidRect)
      ..style = PaintingStyle.fill;

    canvas.drawPath(liquidPath, liquidPaint);

    // Subtle internal liquid glow line on the wave crest
    final waveSurfacePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    final waveLine = Path()..moveTo(left - 5, liquidY);
    for (double x = left - 5; x <= right + 5; x += 3) {
      final y = liquidY +
          math.sin(((x - left) / contentW) * 2 * math.pi + wavePhase) *
              waveAmplitude;
      waveLine.lineTo(x, y);
    }
    canvas.drawPath(waveLine, waveSurfacePaint);

    // Rising micro bubbles
    final bubbleProgress1 = (progress * 1.5) % 1.0;
    final bubbleY1 = baseBottom - (baseBottom - neckBottom) * bubbleProgress1;
    if (bubbleY1 < baseBottom && bubbleY1 > neckBottom) {
      final bubbleAlpha = math.sin(bubbleProgress1 * math.pi).clamp(0.0, 1.0);
      final bubblePaint1 = Paint()
        ..color = Colors.white.withValues(alpha: 0.5 * bubbleAlpha)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(neckLeft + neckWidth * 0.35, bubbleY1),
        contentW * 0.025,
        bubblePaint1,
      );
    }

    final bubbleProgress2 = (progress * 1.5 + 0.5) % 1.0;
    final bubbleY2 = baseBottom - (baseBottom - neckBottom) * bubbleProgress2;
    if (bubbleY2 < baseBottom && bubbleY2 > neckBottom) {
      final bubbleAlpha = math.sin(bubbleProgress2 * math.pi).clamp(0.0, 1.0);
      final bubblePaint2 = Paint()
        ..color = Colors.white.withValues(alpha: 0.4 * bubbleAlpha)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(neckLeft + neckWidth * 0.65, bubbleY2),
        contentW * 0.02,
        bubblePaint2,
      );
    }

    canvas.restore();

    // 2. Measurement / Graduation Marks
    final tickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    // Ticks at 45% and 65% height of the body
    final tick1Y = baseBottom - bodyHeight * 0.40;
    final tick1StartX = baseLeft + (neckLeft - baseLeft) * 0.60;
    canvas.drawLine(Offset(tick1StartX, tick1Y), Offset(tick1StartX + contentW * 0.12, tick1Y), tickPaint);

    final tick2Y = baseBottom - bodyHeight * 0.60;
    final tick2StartX = baseLeft + (neckLeft - baseLeft) * 0.40;
    canvas.drawLine(Offset(tick2StartX, tick2Y), Offset(tick2StartX + contentW * 0.09, tick2Y), tickPaint);

    // 3. Beaker Outer Contour with Electric Violet to Cyan Gradient
    final contourRect = Rect.fromLTRB(left, top, right, bottom);
    final contourPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [primaryColor, secondaryColor],
      ).createShader(contourRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(beakerPath, contourPaint);

    // Top rim lip line (extended slightly beyond the neck for a classic flask look)
    final lipOverhang = neckWidth * 0.16;
    final rimPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(neckLeft - lipOverhang, top),
      Offset(neckRight + lipOverhang, top),
      rimPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _BeakerPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.primaryColor != primaryColor ||
      oldDelegate.secondaryColor != secondaryColor ||
      oldDelegate.strokeWidth != strokeWidth;
}
