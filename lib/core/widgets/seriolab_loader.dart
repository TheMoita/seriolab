import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Seriolab's signature vector animated loading indicator: a minimalist laboratory
/// beaker / Erlenmeyer flask with flowing liquid, rising bubbles,
/// and a gentle dynamic breathing pulse.
class SeriolabLoader extends StatefulWidget {
  const SeriolabLoader({
    super.key,
    this.size = 60.0,
    this.strokeWidth,
    this.primaryColor,
    this.secondaryColor,
  });

  /// The width and height of the loader widget (defaults to 60.0).
  final double size;

  /// Custom stroke width for the flask outline.
  final double? strokeWidth;

  /// Primary contour color (defaults to #7C5CFC - Electric Violet).
  final Color? primaryColor;

  /// Secondary liquid & bubble color (defaults to #38BDF8 - Vibrant Cyan).
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

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        // Smooth breathing scale pulse between 0.95 and 1.05
        final pulse = 0.95 + 0.10 * (0.5 - 0.5 * math.cos(t * 2 * math.pi));

        return Transform.scale(
          scale: pulse,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              size: Size(widget.size, widget.size),
              painter: BeakerPainter(
                t,
                primaryColor: primary,
                secondaryColor: secondary,
                strokeWidth: widget.strokeWidth,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// CustomPainter that renders the geometric beaker flask silhouette,
/// internal sinusoidal liquid wave, and rising animated bubbles.
class BeakerPainter extends CustomPainter {
  BeakerPainter(
    this.animationValue, {
    this.primaryColor = const Color(0xFF7C5CFC),
    this.secondaryColor = const Color(0xFF38BDF8),
    this.strokeWidth,
  });

  final double animationValue;
  final Color primaryColor;
  final Color secondaryColor;
  final double? strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    // Proportional stroke width with safe bounds for small loaders
    final effectiveStrokeWidth =
        strokeWidth ?? (size.width * 0.05).clamp(1.5, 3.2);

    final paint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = effectiveStrokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    // 1. Desenhar a silhueta do copo de laboratório (Erlenmeyer / Beaker)
    path.moveTo(size.width * 0.4, size.height * 0.2); // topo esquerdo do gargalo
    path.lineTo(size.width * 0.6, size.height * 0.2); // topo direito
    path.lineTo(size.width * 0.6, size.height * 0.45); // descida do gargalo direita
    path.lineTo(size.width * 0.85, size.height * 0.85); // inclinação do balão à direita
    path.quadraticBezierTo(
      size.width * 0.9,
      size.height * 0.9,
      size.width * 0.8,
      size.height * 0.9,
    ); // canto inferior direito arredondado
    path.lineTo(size.width * 0.2, size.height * 0.9); // base
    path.quadraticBezierTo(
      size.width * 0.1,
      size.height * 0.9,
      size.width * 0.15,
      size.height * 0.85,
    ); // canto inferior esquerdo arredondado
    path.lineTo(size.width * 0.4, size.height * 0.45); // subida da inclinação esquerda
    path.close();

    canvas.drawPath(path, paint);

    // 2. Desenhar o líquido com efeito de onda usando o animationValue
    final liquidPaint = Paint()
      ..color = secondaryColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    final liquidPath = Path();
    final waveAmplitude = (size.height * 0.025).clamp(1.0, 3.0);
    final waveHeight = math.sin(animationValue * 2 * math.pi) * waveAmplitude;

    liquidPath.moveTo(size.width * 0.26, size.height * 0.72);
    liquidPath.quadraticBezierTo(
      size.width * 0.5,
      size.height * 0.7 + waveHeight,
      size.width * 0.74,
      size.height * 0.72,
    );
    liquidPath.lineTo(size.width * 0.82, size.height * 0.84);
    liquidPath.quadraticBezierTo(
      size.width * 0.85,
      size.height * 0.88,
      size.width * 0.8,
      size.height * 0.88,
    );
    liquidPath.lineTo(size.width * 0.2, size.height * 0.88);
    liquidPath.quadraticBezierTo(
      size.width * 0.15,
      size.height * 0.88,
      size.width * 0.18,
      size.height * 0.84,
    );
    liquidPath.close();

    canvas.drawPath(liquidPath, liquidPaint);

    // Fallback para tamanhos pequenos: omite bolhas se tamanho reduzido
    if (size.width < 28 || size.height < 28) {
      return;
    }

    // 3. Desenhar bolhas circulares a subir com fade-in, subida e fade-out
    void drawBubble({
      required double xRatio,
      required double startYRatio,
      required double travelRatio,
      required double offsetProgress,
      required double radiusRatio,
    }) {
      final p = (animationValue + offsetProgress) % 1.0;
      final bubbleY = (size.height * startYRatio) - (p * size.height * travelRatio);
      if (bubbleY > size.height * 0.25 && bubbleY < size.height * startYRatio) {
        // Fade in during first half of ascent, fade out towards the neck
        final alpha = math.sin(p * math.pi).clamp(0.0, 1.0);
        final bubblePaint = Paint()
          ..color = secondaryColor.withValues(alpha: alpha * 0.95)
          ..style = PaintingStyle.fill;
        final radius = (size.width * radiusRatio).clamp(1.2, 3.0);
        canvas.drawCircle(Offset(size.width * xRatio, bubbleY), radius, bubblePaint);
      }
    }

    // Bolha 1
    drawBubble(
      xRatio: 0.45,
      startYRatio: 0.72,
      travelRatio: 0.45,
      offsetProgress: 0.0,
      radiusRatio: 0.042,
    );
    // Bolha 2
    drawBubble(
      xRatio: 0.53,
      startYRatio: 0.70,
      travelRatio: 0.42,
      offsetProgress: 0.28,
      radiusRatio: 0.032,
    );
    // Bolha 3
    drawBubble(
      xRatio: 0.48,
      startYRatio: 0.74,
      travelRatio: 0.46,
      offsetProgress: 0.58,
      radiusRatio: 0.038,
    );
    // Bolha 4
    drawBubble(
      xRatio: 0.38,
      startYRatio: 0.71,
      travelRatio: 0.38,
      offsetProgress: 0.82,
      radiusRatio: 0.028,
    );
  }

  @override
  bool shouldRepaint(covariant BeakerPainter oldDelegate) => true;
}
