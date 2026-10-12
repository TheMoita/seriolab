import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../shows/presentation/providers/show_providers.dart';
import '../../../shows/presentation/screens/episode_detail_screen.dart';
import '../../domain/entities/tracking_entities.dart';
import '../providers/tracking_providers.dart';

/// Formats the watch date into a relative presentation string.
String formatRelativeWatchedAt(DateTime watchedAt, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final today = Formatters.dateOnly(current);
  final date = Formatters.dateOnly(watchedAt);
  final diffDays = today.difference(date).inDays;

  if (diffDays == 0) return 'Today';
  if (diffDays == 1) return 'Yesterday';
  if (diffDays > 1 && diffDays < 7) return '$diffDays days ago';
  if (diffDays >= 7 && diffDays < 30) {
    final weeks = (diffDays / 7).floor();
    return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
  }
  return Formatters.shortDate(watchedAt);
}

/// Displays the user's most recently watched episodes in a sleek horizontal
/// scrollable list directly below the Top 5 Favorites on the profile screen.
class RecentActivitySection extends ConsumerWidget {
  const RecentActivitySection({
    super.key,
    this.customEpisodes,
  });

  /// Optional override for testing or visiting users.
  final List<WatchedEpisode>? customEpisodes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackingAsync = ref.watch(trackingControllerProvider);
    final trackingState = trackingAsync.value;

    final List<WatchedEpisode> episodes;
    if (customEpisodes != null) {
      episodes = List.of(customEpisodes!)
        ..sort(WatchedEpisode.compareForRecentActivity);
    } else if (trackingState != null) {
      episodes = trackingState.recentWatchedEpisodes();
    } else {
      episodes = const [];
    }

    final recentEpisodes = episodes.take(10).toList();

    if (recentEpisodes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'RECENT ACTIVITY',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.outline, width: 0.8),
              ),
              child: const Center(
                child: Text(
                  'No recent activity yet',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'RECENT ACTIVITY',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: AppColors.textMuted,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 196,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: recentEpisodes.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final episode = recentEpisodes[index];
              final trackedShow = trackingState?.show(episode.showId);
              return _RecentEpisodeCard(
                episode: episode,
                trackedShow: trackedShow,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RecentEpisodeCard extends ConsumerWidget {
  const _RecentEpisodeCard({
    required this.episode,
    this.trackedShow,
  });

  final WatchedEpisode episode;
  final TrackedShow? trackedShow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final epDetailsAsync = ref.watch(
      episodeDetailsProvider((
        showId: episode.showId,
        seasonNumber: episode.key.season,
        episodeNumber: episode.key.episode,
      )),
    );

    final epDetails = epDetailsAsync.value;
    final showName = trackedShow?.name ?? 'Show';
    final stillUrl = epDetails?.stillHighResUrl ??
        epDetails?.episode.stillUrl ??
        trackedShow?.posterUrl;
    final episodeName = epDetails?.episode.displayTitle();
    final relativeTime = formatRelativeWatchedAt(episode.watchedAt);

    const cardWidth = 200.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => EpisodeDetailScreen(
                seriesId: episode.showId,
                seasonNumber: episode.key.season,
                episodeNumber: episode.key.episode,
                initialEpisode: epDetails?.episode,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: cardWidth,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.outline, width: 0.8),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 16:9 Thumbnail with Overlay Badges
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AppNetworkImage(
                      imageUrl: stillUrl,
                      fit: BoxFit.cover,
                      placeholderIcon: Icons.tv_rounded,
                      title: showName,
                    ),
                    // Gradient overlay at bottom
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.65),
                            ],
                            stops: const [0.5, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // Personal Rating Badge (top-right) if user rated the episode
                    if (episode.userRating != null)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFF38BDF8)
                                  .withValues(alpha: 0.5),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 12,
                                color: Color(0xFF38BDF8),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                episode.userRating!.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // Season & Episode Code Badge (bottom-left)
                    Positioned(
                      bottom: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'S${episode.key.season} • E${episode.key.episode}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Episode Info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            showName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            episodeName != null && episodeName.isNotEmpty
                                ? episodeName
                                : 'Episode ${episode.key.episode}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 11,
                            color: Color(0xFF10B981),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              relativeTime,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
