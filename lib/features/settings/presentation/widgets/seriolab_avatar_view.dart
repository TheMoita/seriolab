import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/user_settings.dart';

/// Renders a distinctive gradient avatar for Seriolab users.
class SeriolabAvatarView extends StatelessWidget {
  const SeriolabAvatarView({
    super.key,
    required this.avatarId,
    this.size = 54,
    this.borderWidth = 2,
    this.showGlow = false,
  });

  final String avatarId;
  final double size;
  final double borderWidth;
  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    final avatar = SeriolabAvatar.getById(avatarId);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: avatar.gradientColors,
        ),
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: avatar.gradientColors.first.withValues(alpha: 0.35),
                  blurRadius: 12,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
        border: Border.all(
          color: AppColors.outline.withValues(alpha: 0.8),
          width: borderWidth,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        avatar.icon,
        color: Colors.white,
        size: size * 0.52,
      ),
    );
  }
}
