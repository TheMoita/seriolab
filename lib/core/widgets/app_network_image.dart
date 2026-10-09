import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Seriolab cached network image with automatic fallback, shimmer loading,
/// and a stylish branded placeholder when no image is available.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.imageUrl,
    this.fallbackImageUrl,
    this.title,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = BorderRadius.zero,
    this.placeholderIcon = Icons.movie_filter_rounded,
    this.showTitleOnPlaceholder = true,
  });

  /// Primary image URL (e.g. show poster).
  final String? imageUrl;

  /// Optional fallback image URL (e.g. show backdrop) used if [imageUrl] is missing or fails.
  final String? fallbackImageUrl;

  /// Optional item or show title displayed centered on the fallback placeholder.
  final String? title;

  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius borderRadius;
  final IconData placeholderIcon;
  final bool showTitleOnPlaceholder;

  /// Validates whether a URL is a legitimate image resource.
  /// Rejects null, empty, incomplete TMDB URLs like '.../null', and non-http(s) strings.
  static bool isValidUrl(String? url) {
    if (url == null) return false;
    final trimmed = url.trim();
    if (trimmed.isEmpty) return false;
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return false;
    }
    final lower = trimmed.toLowerCase();
    if (lower.endsWith('/null') ||
        lower.endsWith('/undefined') ||
        lower == 'null') {
      return false;
    }
    if (lower.contains('/t/p/w500null') ||
        lower.contains('/t/p/w342null') ||
        lower.contains('/t/p/w780null') ||
        lower.contains('/t/p/w1280null') ||
        lower.contains('/t/p/originalnull')) {
      return false;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.host.isEmpty) return false;
    if (uri.path.isEmpty || uri.path == '/' || uri.path.endsWith('/null')) {
      return false;
    }
    if (uri.host.contains('image.tmdb.org')) {
      final segments = uri.pathSegments;
      if (segments.length < 4) return false;
      final fileSegment = segments.last.toLowerCase();
      if (fileSegment == 'null' || fileSegment.isEmpty) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final validPrimary = isValidUrl(imageUrl);
    final validFallback =
        isValidUrl(fallbackImageUrl) && fallbackImageUrl != imageUrl;

    final primaryUrl =
        validPrimary ? imageUrl! : (validFallback ? fallbackImageUrl! : null);
    final secondaryUrl =
        (validPrimary && validFallback) ? fallbackImageUrl : null;

    if (primaryUrl == null) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: _SeriolabPlaceholder(
          title: title,
          width: width,
          height: height,
          borderRadius: borderRadius,
          placeholderIcon: placeholderIcon,
          showTitle: showTitleOnPlaceholder,
        ),
      );
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: CachedNetworkImage(
        imageUrl: primaryUrl,
        width: width,
        height: height,
        fit: fit,
        fadeInDuration: const Duration(milliseconds: 220),
        fadeOutDuration: const Duration(milliseconds: 150),
        placeholder: (context, url) => _SeriolabShimmer(
          width: width,
          height: height,
          borderRadius: borderRadius,
          placeholderIcon: placeholderIcon,
        ),
        errorWidget: (context, url, error) {
          if (secondaryUrl != null) {
            return CachedNetworkImage(
              imageUrl: secondaryUrl,
              width: width,
              height: height,
              fit: fit,
              fadeInDuration: const Duration(milliseconds: 220),
              placeholder: (context, url) => _SeriolabShimmer(
                width: width,
                height: height,
                borderRadius: borderRadius,
                placeholderIcon: placeholderIcon,
              ),
              errorWidget: (context, url, error) => _SeriolabPlaceholder(
                title: title,
                width: width,
                height: height,
                borderRadius: borderRadius,
                placeholderIcon: placeholderIcon,
                showTitle: showTitleOnPlaceholder,
              ),
            );
          }
          return _SeriolabPlaceholder(
            title: title,
            width: width,
            height: height,
            borderRadius: borderRadius,
            placeholderIcon: placeholderIcon,
            showTitle: showTitleOnPlaceholder,
          );
        },
      ),
    );
  }
}

class _SeriolabPlaceholder extends StatelessWidget {
  const _SeriolabPlaceholder({
    this.title,
    this.width,
    this.height,
    required this.borderRadius,
    required this.placeholderIcon,
    required this.showTitle,
  });

  final String? title;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final IconData placeholderIcon;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxW = width ?? constraints.maxWidth;
        final boxH = height ?? constraints.maxHeight;

        final isCompact = (boxW < 75) || (boxH < 100);
        final isTiny = (boxW < 50) || (boxH < 65);
        final iconSize = isTiny ? 14.0 : (isCompact ? 18.0 : 26.0);

        final cleanTitle = title?.trim();
        final hasTitle =
            showTitle && cleanTitle != null && cleanTitle.isNotEmpty && !isTiny;

        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF171B26),
                Color(0xFF232938),
              ],
            ),
            border: Border.all(
              color: AppColors.outline.withValues(alpha: 0.5),
              width: 0.8,
            ),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 6 : 10,
            vertical: isCompact ? 6 : 8,
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(isTiny ? 3 : (isCompact ? 5 : 8)),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.15),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    width: 0.8,
                  ),
                ),
                child: Icon(
                  placeholderIcon,
                  size: iconSize,
                  color: AppColors.secondary,
                ),
              ),
              if (hasTitle) ...[
                SizedBox(height: isCompact ? 4 : 8),
                Text(
                  cleanTitle,
                  textAlign: TextAlign.center,
                  maxLines: isCompact ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isCompact ? 10 : 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.2,
                    letterSpacing: -0.2,
                    shadows: const [
                      Shadow(
                        color: Colors.black,
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                if (!isCompact && boxH > 130) ...[
                  const SizedBox(height: 5),
                  Text(
                    'SERIOLAB',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: AppColors.textMuted.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SeriolabShimmer extends StatefulWidget {
  const _SeriolabShimmer({
    this.width,
    this.height,
    required this.borderRadius,
    required this.placeholderIcon,
  });

  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final IconData placeholderIcon;

  @override
  State<_SeriolabShimmer> createState() => _SeriolabShimmerState();
}

class _SeriolabShimmerState extends State<_SeriolabShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(
              begin: Alignment(-2.0 + 4.0 * progress, -0.3),
              end: Alignment(0.0 + 4.0 * progress, 0.3),
              colors: const [
                Color(0xFF171B26),
                Color(0xFF232938),
                Color(0xFF2E384D),
                Color(0xFF232938),
                Color(0xFF171B26),
              ],
              stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
            ),
          ),
          alignment: Alignment.center,
          child: Opacity(
            opacity: 0.3 + 0.3 * math.sin(progress * math.pi),
            child: Icon(
              widget.placeholderIcon,
              size: (widget.width != null && widget.width! < 60) ? 18 : 26,
              color: AppColors.secondary.withValues(alpha: 0.6),
            ),
          ),
        );
      },
    );
  }
}
