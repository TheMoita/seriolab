import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../tracking/domain/entities/tracking_entities.dart';
import '../../../tracking/presentation/providers/tracking_providers.dart';
import '../../domain/entities/show.dart';
import '../screens/show_detail_screen.dart';

/// Minimalist, visual-first show card inspired by Letterboxd's poster grid.
///
/// Features:
/// - 2:3 vertical poster proportions with subtle 1px border
/// - Dark background with clean typography below
/// - Year and star rating badge
/// - Smooth hover and tap animation
/// - Quick tracking action via tap on bookmark icon or long press
class LetterboxdShowCard extends ConsumerStatefulWidget {
  const LetterboxdShowCard({
    super.key,
    required this.show,
    this.width,
    this.showRating = true,
    this.compact = false,
  });

  final ShowSummary show;
  final double? width;
  final bool showRating;
  final bool compact;

  @override
  ConsumerState<LetterboxdShowCard> createState() => _LetterboxdShowCardState();
}

class _LetterboxdShowCardState extends ConsumerState<LetterboxdShowCard> {
  bool _isHovered = false;

  void _openDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ShowDetailScreen(showId: widget.show.id),
      ),
    );
  }

  void _showQuickStatusSheet(BuildContext context, TrackedShow? current) {
    final theme = Theme.of(context);
    final tracking = ref.read(trackingControllerProvider.notifier);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.outline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (widget.show.posterUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: AppNetworkImage(
                          imageUrl: widget.show.posterUrl,
                          width: 36,
                          height: 54,
                        ),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.show.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Estado na tua lista',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: AppColors.outline),
                const SizedBox(height: 8),
                for (final status in TrackingStatus.values)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      status.icon,
                      color: current?.status == status
                          ? status.color
                          : AppColors.textSecondary,
                    ),
                    title: Text(
                      status.label,
                      style: TextStyle(
                        fontWeight: current?.status == status
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: current?.status == status
                            ? Colors.white
                            : AppColors.textPrimary,
                      ),
                    ),
                    trailing: current?.status == status
                        ? Icon(Icons.check_rounded, color: status.color, size: 20)
                        : null,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      tracking.setSummaryStatus(widget.show, status);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${widget.show.name} marcada como "${status.label}"',
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                if (current != null) ...[
                  const Divider(height: 1, color: AppColors.outline),
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.danger,
                    ),
                    title: const Text(
                      'Remover da lista',
                      style: TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      tracking.removeShow(widget.show.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${widget.show.name} removida da lista',
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tracked = ref.watch(trackedShowProvider(widget.show.id));
    final hasStatus = tracked != null;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 2:3 Vertical Poster with Letterboxd Hairline Border
        AspectRatio(
          aspectRatio: 2 / 3,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _isHovered
                    ? AppColors.primary.withValues(alpha: 0.70)
                    : AppColors.outline,
                width: 1.0,
              ),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppNetworkImage(
                    imageUrl: widget.show.posterUrl,
                    fit: BoxFit.cover,
                  ),

                  // Subtle gradient overlay at top & bottom for readability
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.35),
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.45),
                          ],
                          stops: const [0.0, 0.25, 0.75, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Active tracking status pill on top-right
                  if (hasStatus)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: tracked.status.color.withValues(alpha: 0.7),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              tracked.status.icon,
                              size: 11,
                              color: tracked.status.color,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              tracked.status.label,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: tracked.status.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Anime tag on top-left if applicable
                  if (widget.show.isAnime)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.90),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text(
                          'ANIME',
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),

                  // Quick Action button (Bookmark/add to tracking)
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _showQuickStatusSheet(context, tracked),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.70),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.20),
                              width: 0.6,
                            ),
                          ),
                          child: Icon(
                            hasStatus
                                ? Icons.bookmark_added_rounded
                                : Icons.bookmark_add_outlined,
                            size: 14,
                            color: hasStatus
                                ? tracked.status.color
                                : Colors.white70,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 6),

        // Show Title (Clean, sober Letterboxd typography)
        Text(
          widget.show.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: widget.compact ? 12 : 13,
            fontWeight: FontWeight.w600,
            color: _isHovered ? Colors.white : AppColors.textPrimary,
            letterSpacing: 0.1,
          ),
        ),

        const SizedBox(height: 2),

        // Sub-row: Release year and Rating
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (widget.show.year != null)
              Text(
                '${widget.show.year}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              )
            else
              const SizedBox.shrink(),
            if (widget.showRating && widget.show.rating > 0)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.star_rounded,
                    size: 13,
                    color: AppColors.secondary,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    Formatters.rating(widget.show.rating),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => _openDetail(context),
        onLongPress: () => _showQuickStatusSheet(context, tracked),
        child: widget.width != null
            ? SizedBox(width: widget.width, child: content)
            : content,
      ),
    );
  }
}
