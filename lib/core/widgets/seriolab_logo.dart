import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Reusable Seriolab logo widget featuring the official app icon and typography.
class SeriolabLogo extends StatelessWidget {
  const SeriolabLogo({
    super.key,
    this.iconSize = 28,
    this.fontSize = 20,
    this.showText = true,
    this.subtitle,
    this.orientation = Axis.horizontal,
  });

  /// The dimensions of the app icon (width and height).
  final double iconSize;

  /// The font size for the "Seriolab" text.
  final double fontSize;

  /// Whether to display the brand name beside/below the icon.
  final bool showText;

  /// Optional subtitle (e.g. "Your TV Series Log").
  final String? subtitle;

  /// Orientation: [Axis.horizontal] for AppBars, [Axis.vertical] for Splash/Welcome.
  final Axis orientation;

  @override
  Widget build(BuildContext context) {
    final iconWidget = Container(
      width: iconSize,
      height: iconSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(iconSize * 0.22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(iconSize * 0.22),
        child: Image.asset(
          'assets/icons/app_icon.png',
          width: iconSize,
          height: iconSize,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: AppColors.primary,
            alignment: Alignment.center,
            child: Icon(
              Icons.tv_rounded,
              color: Colors.white,
              size: iconSize * 0.6,
            ),
          ),
        ),
      ),
    );

    if (!showText) {
      return iconWidget;
    }

    final textWidget = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: orientation == Axis.horizontal
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              'Serio',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              'lab',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: (fontSize * 0.55).clamp(11.0, 14.0),
              fontWeight: FontWeight.w500,
              letterSpacing: 1.2,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );

    if (orientation == Axis.vertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          iconWidget,
          SizedBox(height: iconSize * 0.4),
          textWidget,
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        iconWidget,
        const SizedBox(width: 10),
        textWidget,
      ],
    );
  }
}
