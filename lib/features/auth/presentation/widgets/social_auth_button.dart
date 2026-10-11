import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/seriolab_loader.dart';

/// Distinctive social sign-in button matching Seriolab's Midnight Indigo theme.
class SocialAuthButton extends StatelessWidget {
  const SocialAuthButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surfaceHigh,
          side: const BorderSide(color: AppColors.outline, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: isLoading
            ? const SeriolabLoader(
                size: 22,
                primaryColor: AppColors.secondary,
                secondaryColor: AppColors.primary,
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _GoogleGLogo(size: 22),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Custom-painted vector Google "G" logo for zero external asset dependencies.
class _GoogleGLogo extends StatelessWidget {
  const _GoogleGLogo({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);
    final radius = w / 2;

    // Draw the 4 distinct Google color segments:
    // Red (top), Yellow (left/bottom-left), Green (bottom), Blue (right bar)
    final redPaint = Paint()..color = const Color(0xFFEA4335);
    final yellowPaint = Paint()..color = const Color(0xFFFBBC05);
    final greenPaint = Paint()..color = const Color(0xFF34A853);
    final bluePaint = Paint()..color = const Color(0xFF4285F4);

    final rect = Rect.fromCircle(center: center, radius: radius);

    // Blue horizontal bar
    final barRect = Rect.fromLTWH(w * 0.45, h * 0.38, w * 0.52, h * 0.24);
    canvas.drawRRect(
      RRect.fromRectAndRadius(barRect, const Radius.circular(2)),
      bluePaint,
    );

    // Outer arcs
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.22;

    // Red arc (top)
    strokePaint.color = redPaint.color;
    canvas.drawArc(rect.deflate(w * 0.11), -2.6, 1.8, false, strokePaint);

    // Yellow arc (left)
    strokePaint.color = yellowPaint.color;
    canvas.drawArc(rect.deflate(w * 0.11), 2.1, 1.6, false, strokePaint);

    // Green arc (bottom)
    strokePaint.color = greenPaint.color;
    canvas.drawArc(rect.deflate(w * 0.11), 0.5, 1.6, false, strokePaint);

    // Blue arc (right curve)
    strokePaint.color = bluePaint.color;
    canvas.drawArc(rect.deflate(w * 0.11), -0.8, 1.3, false, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
