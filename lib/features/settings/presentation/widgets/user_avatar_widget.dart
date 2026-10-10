import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/local_storage_utils.dart';
import '../../domain/entities/user_settings.dart';
import 'seriolab_avatar_view.dart';

/// Modular avatar widget supporting presets, local uploaded files, and TMDB network images.
///
/// Automatically handles fallback to the default preset avatar on load or network errors.
class UserAvatarWidget extends StatelessWidget {
  const UserAvatarWidget({
    super.key,
    this.avatarType,
    this.avatarValue,
    this.avatarId,
    this.settings,
    this.size = 54,
    this.borderWidth = 2,
    this.showGlow = false,
    this.borderColor,
  });

  /// Convenience factory from [UserSettings].
  factory UserAvatarWidget.fromSettings({
    Key? key,
    required UserSettings settings,
    double size = 54,
    double borderWidth = 2,
    bool showGlow = false,
    Color? borderColor,
  }) =>
      UserAvatarWidget(
        key: key,
        avatarType: settings.avatarType,
        avatarValue: settings.avatarValue,
        avatarId: settings.avatarId,
        size: size,
        borderWidth: borderWidth,
        showGlow: showGlow,
        borderColor: borderColor,
      );

  final AvatarType? avatarType;
  final String? avatarValue;
  final String? avatarId;
  final UserSettings? settings;
  final double size;
  final double borderWidth;
  final bool showGlow;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final effectiveType = avatarType ?? settings?.avatarType ?? AvatarType.preset;
    final effectiveValue = avatarValue ?? settings?.avatarValue ?? avatarId ?? settings?.avatarId;
    final fallbackId = avatarId ?? settings?.avatarId ?? 'tv_retro';

    final effectiveBorderColor = borderColor ??
        (effectiveType == AvatarType.networkUrl
            ? const Color(0xFF38BDF8)
            : const Color(0xFF7C5CFC));

    switch (effectiveType) {
      case AvatarType.preset:
        return SeriolabAvatarView(
          avatarId: (effectiveValue != null && effectiveValue.isNotEmpty)
              ? effectiveValue
              : fallbackId,
          size: size,
          borderWidth: borderWidth,
          showGlow: showGlow,
        );

      case AvatarType.localFile:
        return _buildLocalFileAvatar(
          context,
          effectiveValue,
          fallbackId,
          effectiveBorderColor,
        );

      case AvatarType.networkUrl:
        return _buildNetworkUrlAvatar(
          context,
          effectiveValue,
          fallbackId,
          effectiveBorderColor,
        );
    }
  }

  Widget _buildLocalFileAvatar(
    BuildContext context,
    String? path,
    String fallbackId,
    Color activeBorderColor,
  ) {
    if (kIsWeb || path == null || path.isEmpty) {
      return SeriolabAvatarView(
        avatarId: fallbackId,
        size: size,
        borderWidth: borderWidth,
        showGlow: showGlow,
      );
    }

    if (path.startsWith('http://') || path.startsWith('https://')) {
      return _buildNetworkUrlAvatar(context, path, fallbackId, activeBorderColor);
    }

    final file = LocalStorageUtils.resolveFile(path);
    if (file != null && file.existsSync()) {
      return _buildImageCircle(file, fallbackId, activeBorderColor);
    }

    return FutureBuilder<File?>(
      future: LocalStorageUtils.resolveFileAsync(path),
      builder: (context, snapshot) {
        final resolved = snapshot.data;
        if (resolved != null && resolved.existsSync()) {
          return _buildImageCircle(resolved, fallbackId, activeBorderColor);
        }
        return SeriolabAvatarView(
          avatarId: fallbackId,
          size: size,
          borderWidth: borderWidth,
          showGlow: showGlow,
        );
      },
    );
  }

  Widget _buildImageCircle(
    File file,
    String fallbackId,
    Color activeBorderColor,
  ) {

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: activeBorderColor,
          width: borderWidth,
        ),
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: activeBorderColor.withValues(alpha: 0.35),
                  blurRadius: 12,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: ClipOval(
        child: Image.file(
          file,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => SeriolabAvatarView(
            avatarId: fallbackId,
            size: size,
            borderWidth: 0,
            showGlow: false,
          ),
        ),
      ),
    );
  }

  Widget _buildNetworkUrlAvatar(
    BuildContext context,
    String? url,
    String fallbackId,
    Color activeBorderColor,
  ) {
    if (url == null || url.trim().isEmpty) {
      return SeriolabAvatarView(
        avatarId: fallbackId,
        size: size,
        borderWidth: borderWidth,
        showGlow: showGlow,
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: activeBorderColor,
          width: borderWidth,
        ),
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: activeBorderColor.withValues(alpha: 0.35),
                  blurRadius: 12,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: url.trim(),
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: AppColors.surface,
            alignment: Alignment.center,
            child: SizedBox(
              width: size * 0.32,
              height: size * 0.32,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          ),
          errorWidget: (context, url, error) => SeriolabAvatarView(
            avatarId: fallbackId,
            size: size,
            borderWidth: 0,
            showGlow: false,
          ),
        ),
      ),
    );
  }
}
