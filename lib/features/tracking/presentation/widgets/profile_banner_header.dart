import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/local_storage_utils.dart';
import '../../../settings/domain/entities/user_settings.dart';
import '../../../settings/presentation/widgets/avatar_selection_sheet.dart';
import '../../../settings/presentation/widgets/user_avatar_widget.dart';
import 'profile_banner_modal.dart';

/// Top customizable banner & avatar header for the Profile screen (Twitter / Letterboxd Patron style).
///
/// Features:
/// - Full-width 200px container displaying a TMDB backdrop, gallery image, or default Seriolab gradient (#7C5CFC -> #0D0F17)
/// - Smooth dark gradient overlay transitioning to [AppColors.background] (#0D0F17)
/// - Discrete semi-transparent edit button in the top corner
/// - Circular avatar partially overlapping the bottom edge of the banner
class ProfileBannerHeader extends StatelessWidget {
  const ProfileBannerHeader({
    super.key,
    required this.settings,
    this.bannerHeight = 200.0,
    this.avatarSize = 86.0,
  });

  final UserSettings settings;
  final double bannerHeight;
  final double avatarSize;

  Widget _buildBannerImage() {
    final bannerUrl = settings.profileBannerUrl;
    final bannerPath = settings.profileBannerPath;

    if (bannerUrl != null && bannerUrl.trim().isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: bannerUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: bannerHeight,
        placeholder: (context, url) => Container(
          color: AppColors.surfaceHigh,
          child: const Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        errorWidget: (context, url, error) => _buildDefaultGradient(),
      );
    }

    if (bannerPath != null && bannerPath.trim().isNotEmpty) {
      try {
        if (kIsWeb) {
          return Image.network(
            bannerPath,
            fit: BoxFit.cover,
            width: double.infinity,
            height: bannerHeight,
            errorBuilder: (context, error, stackTrace) => _buildDefaultGradient(),
          );
        } else {
          final file = LocalStorageUtils.resolveFile(bannerPath);
          if (file != null && file.existsSync()) {
            return Image.file(
              file,
              fit: BoxFit.cover,
              width: double.infinity,
              height: bannerHeight,
              errorBuilder: (context, error, stackTrace) => _buildDefaultGradient(),
            );
          }

          return FutureBuilder<File?>(
            future: LocalStorageUtils.resolveFileAsync(bannerPath),
            builder: (context, snapshot) {
              final resolved = snapshot.data;
              if (resolved != null && resolved.existsSync()) {
                return Image.file(
                  resolved,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: bannerHeight,
                  errorBuilder: (context, error, stackTrace) => _buildDefaultGradient(),
                );
              }
              return _buildDefaultGradient();
            },
          );
        }
      } catch (_) {
        return _buildDefaultGradient();
      }
    }

    return _buildDefaultGradient();
  }

  Widget _buildDefaultGradient() {
    return Container(
      width: double.infinity,
      height: bannerHeight,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF7C5CFC), // Seriolab Electric Violet
            Color(0xFF0D0F17), // Midnight Indigo Background
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.movie_filter_rounded,
          size: 64,
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Total height of the Stack accommodates the banner plus the bottom half of the overlapping avatar
    final totalHeight = bannerHeight + (avatarSize / 2);

    return SizedBox(
      height: totalHeight,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // 1. Banner Image Container
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: bannerHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildBannerImage(),

                // 2. Smooth Dark Gradient Overlay for seamless transition to AppColors.background (#0D0F17)
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.22),
                        Colors.transparent,
                        AppColors.background.withValues(alpha: 0.72),
                        AppColors.background,
                      ],
                      stops: const [0.0, 0.35, 0.8, 1.0],
                    ),
                  ),
                ),

                // 3. Discrete Edit Banner Button in the top corner
                Positioned(
                  top: 14,
                  right: 14,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => ProfileBannerModal.show(context),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.52),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.camera_alt_rounded,
                              size: 15,
                              color: Colors.white,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Banner',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 4. Circular Avatar partially overlapping the bottom edge of the banner
          Positioned(
            bottom: 0,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(avatarSize),
                  onTap: () => AvatarSelectionSheet.show(context),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.background,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: UserAvatarWidget.fromSettings(
                      settings: settings,
                      size: avatarSize,
                      showGlow: true,
                      borderWidth: 2.5,
                    ),
                  ),
                ),
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: InkWell(
                    onTap: () => AvatarSelectionSheet.show(context),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.background,
                          width: 2.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.45),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        size: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
