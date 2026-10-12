import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/modal_drag_handle.dart';
import '../../../../core/widgets/seriolab_loader.dart';
import '../../../../core/widgets/seriolab_refresh_indicator.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../tracking/domain/entities/tracking_entities.dart';
import '../../../tracking/presentation/providers/tracking_providers.dart';
import '../../domain/entities/episode.dart';
import '../../domain/entities/show.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../providers/show_providers.dart';
import '../widgets/episode_review_bottom_sheet.dart';
import '../widgets/rating_modal.dart';
import '../widgets/trailer_dialog.dart';
import 'episode_detail_screen.dart';

class ShowDetailScreen extends ConsumerStatefulWidget {
  const ShowDetailScreen({super.key, required this.showId});

  final int showId;

  @override
  ConsumerState<ShowDetailScreen> createState() => _ShowDetailScreenState();
}

class _ShowDetailScreenState extends ConsumerState<ShowDetailScreen> {
  int _selectedSeasonNumber = 1;
  final Set<EpisodeKey> _revealedSpoilers = {};

  @override
  Widget build(BuildContext context) {
    final showAsync = ref.watch(showDetailsProvider(widget.showId));

    return Scaffold(
      body: showAsync.when(
        loading: () => const Center(
          child: SeriolabLoader(),
        ),
        error: (err, stack) => Scaffold(
          appBar: AppBar(),
          body: EmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Error loading details',
            message: err.toString(),
            actionLabel: 'Try again',
            onAction: () => ref.refresh(showDetailsProvider(widget.showId)),
          ),
        ),
        data: (show) => _buildContent(context, show),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ShowDetails show) {
    final trackingState = ref.watch(trackingControllerProvider).value;
    final tracked = trackingState?.show(show.id);
    final settings = ref.watch(settingsControllerProvider);
    final displayedSeasons = settings.groupSpecialEpisodes
        ? show.regularSeasons
        : show.seasons;

    // Ensure selected season is valid
    final seasonNumbers = displayedSeasons.map((s) => s.seasonNumber).toList();
    if (!seasonNumbers.contains(_selectedSeasonNumber) &&
        seasonNumbers.isNotEmpty) {
      _selectedSeasonNumber = seasonNumbers.first;
    }

    final seasonAsync = ref.watch(
      seasonDetailsProvider((
        showId: show.id,
        seasonNumber: _selectedSeasonNumber,
      )),
    );

    return SeriolabRefreshIndicator(
      onRefresh: () async {
        ref.invalidate(showDetailsProvider(show.id));
        ref.invalidate(seasonDetailsProvider((
          showId: show.id,
          seasonNumber: _selectedSeasonNumber,
        )));
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // Collapsible App Bar with Backdrop
        SliverAppBar(
          expandedHeight: 280,
          pinned: true,
          backgroundColor: AppColors.background,
          actions: [
            _FavoriteHeartButton(show: show),
            _ShowDetailOptionsMenu(show: show),
            const SizedBox(width: 8),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                AppNetworkImage(
                  imageUrl: show.backdropUrl ?? show.posterUrl,
                  fallbackImageUrl: show.posterUrl,
                  title: show.displayTitle(showOriginal: settings.showOriginalTitles),
                  fit: BoxFit.cover,
                  placeholderIcon: Icons.tv_rounded,
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.3),
                        Colors.transparent,
                        AppColors.background.withValues(alpha: 0.8),
                        AppColors.background,
                      ],
                      stops: const [0.0, 0.3, 0.75, 1.0],
                    ),
                  ),
                ),
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: _BackdropTrailerButton(show: show),
                ),
              ],
            ),
          ),
        ),

        // Header details: Poster, Title, Meta, Tracking button
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Poster
                    AppNetworkImage(
                      imageUrl: show.posterUrl ?? show.backdropUrl,
                      fallbackImageUrl: show.backdropUrl,
                      title: show.displayTitle(showOriginal: settings.showOriginalTitles),
                      width: 100,
                      height: 150,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    const SizedBox(width: 16),
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            show.displayTitle(showOriginal: settings.showOriginalTitles),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              height: 1.2,
                            ),
                          ),
                          if (settings.showOriginalTitles &&
                              show.title.isNotEmpty &&
                              show.title != show.displayTitle(showOriginal: true)) ...[
                            const SizedBox(height: 2),
                            Text(
                              show.title,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ] else if (!settings.showOriginalTitles &&
                              show.originalTitle.isNotEmpty &&
                              show.originalTitle != show.displayTitle(showOriginal: false)) ...[
                            const SizedBox(height: 2),
                            Text(
                              show.originalTitle,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          // Rating & year & runtime
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (show.rating > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.star_rounded,
                                        size: 14,
                                        color: AppColors.secondary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        Formatters.rating(show.rating),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.secondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (show.year != null)
                                Text(
                                  '${show.year}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              if (show.episodeRuntime > 0)
                                Text(
                                  Formatters.runtime(show.episodeRuntime),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              if (show.primaryNetwork != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceHigh,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: AppColors.outline,
                                      width: 0.6,
                                    ),
                                  ),
                                  child: Text(
                                    show.primaryNetwork!,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Status chip
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: show.status.isFinished
                                      ? AppColors.surfaceHigh
                                      : AppColors.success.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: show.status.isFinished
                                        ? AppColors.outline
                                        : AppColors.success.withValues(alpha: 0.4),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  show.status.label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: show.status.isFinished
                                        ? AppColors.textSecondary
                                        : AppColors.success,
                                  ),
                                ),
                              ),
                              if (tracked != null) ...[
                                const SizedBox(width: 8),
                                StatusChip(status: tracked.status, compact: true),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Overall Show Rating Card (Community vs Your Overall Rating)
                _buildOverallRatingCard(
                  context,
                  show,
                  tracked,
                ),

                const SizedBox(height: 12),

                // Tracking Action Button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      if (tracked == null) {
                        await ref
                            .read(trackingControllerProvider.notifier)
                            .setStatus(show, TrackingStatus.watchlist);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Show added to Watchlist.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      } else {
                        _showSeriesMoreOptionsSheet(context, show, tracked);
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: tracked != null
                          ? AppColors.surfaceHigh
                          : AppColors.primary,
                      foregroundColor: tracked != null
                          ? AppColors.textPrimary
                          : AppColors.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: tracked != null
                            ? const BorderSide(color: AppColors.outline)
                            : BorderSide.none,
                      ),
                    ),
                    icon: Icon(
                      tracked != null ? tracked.status.icon : Icons.bookmark_add_outlined,
                      size: 20,
                      color: tracked != null ? tracked.status.color : AppColors.onPrimary,
                    ),
                    label: Text(
                      tracked != null
                          ? switch (tracked.status) {
                              TrackingStatus.watchlist =>
                                'In My Watchlist',
                              TrackingStatus.watching => (show.airedEpisodeCount > 0 &&
                                      (trackingState?.watchedRegularCount(show.id) ?? 0) >=
                                          show.airedEpisodeCount &&
                                      !show.status.isFinished)
                                  ? 'Up to Date (Watching)'
                                  : 'Currently Watching',
                              TrackingStatus.completed => 'Completed',
                              TrackingStatus.dropped => 'Dropped',
                            }
                          : 'Add to Watchlist',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

                // Episode Progress Indicator for tracked shows
                if (tracked != null && show.totalEpisodeCount > 0) ...[
                  () {
                    final watchedCount =
                        trackingState?.watchedRegularCount(show.id) ?? 0;
                    final progressRatio = (show.totalEpisodeCount > 0
                            ? watchedCount / show.totalEpisodeCount
                            : 0.0)
                        .clamp(0.0, 1.0);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceHigh,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.outline,
                              width: 0.6,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    (show.airedEpisodeCount > 0 &&
                                            watchedCount >=
                                                show.airedEpisodeCount &&
                                            !show.status.isFinished)
                                        ? '$watchedCount of ${show.totalEpisodeCount} episodes watched • Up to date'
                                        : '$watchedCount of ${show.totalEpisodeCount} episodes watched',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    Formatters.percent(progressRatio),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.secondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progressRatio,
                                  minHeight: 6,
                                  backgroundColor: AppColors.surface,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    watchedCount >= show.totalEpisodeCount
                                        ? AppColors.success
                                        : AppColors.secondary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    onPressed: () {
                                      final effectiveAired =
                                          show.airedEpisodeCount > 0
                                              ? show.airedEpisodeCount
                                              : show.totalEpisodeCount;
                                      final allWatched = (effectiveAired > 0 &&
                                              watchedCount >= effectiveAired) ||
                                          (tracked.status ==
                                              TrackingStatus.completed);
                                      _confirmMarkEntireSeries(
                                        context,
                                        ref,
                                        show,
                                        markWatched: !allWatched,
                                      );
                                    },
                                    style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      foregroundColor: (show.airedEpisodeCount > 0 &&
                                                  watchedCount >=
                                                      show.airedEpisodeCount) ||
                                              (tracked.status ==
                                                  TrackingStatus.completed)
                                          ? AppColors.danger
                                          : AppColors.secondary,
                                    ),
                                    icon: Icon(
                                      (show.airedEpisodeCount > 0 &&
                                                  watchedCount >=
                                                      show.airedEpisodeCount) ||
                                              (tracked.status ==
                                                  TrackingStatus.completed)
                                          ? Icons.remove_done_rounded
                                          : Icons.done_all_rounded,
                                      size: 14,
                                    ),
                                    label: Text(
                                      (show.airedEpisodeCount > 0 &&
                                                  watchedCount >=
                                                      show.airedEpisodeCount) ||
                                              (tracked.status ==
                                                  TrackingStatus.completed)
                                          ? 'Mark all as unwatched'
                                          : 'Mark all as watched',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }(),
                ],

                // Genres list
                if (show.genres.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: show.genres.map((g) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceHigh,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.outline, width: 0.6),
                        ),
                        child: Text(
                          g.name,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                // Overview
                if (show.overview.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text(
                    'Overview',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    show.overview,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],

                // Cast section
                if (show.cast.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'Top Cast',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 130,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: show.cast.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, i) {
                        final castMember = show.cast[i];
                        return SizedBox(
                          width: 80,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              AppNetworkImage(
                                imageUrl: castMember.profileUrl,
                                width: 64,
                                height: 64,
                                borderRadius: BorderRadius.circular(32),
                                placeholderIcon: Icons.person_rounded,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                castMember.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                castMember.character,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],

                // Seasons & Episodes Section
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Episodes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (displayedSeasons.isNotEmpty)
                      Text(
                        '${show.totalEpisodeCount} episodes',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Season Selector Horizontal Chips
                if (displayedSeasons.isNotEmpty)
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: displayedSeasons.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, idx) {
                        final s = displayedSeasons[idx];
                        final isSelected = s.seasonNumber == _selectedSeasonNumber;
                        return ChoiceChip(
                          label: Text(
                            s.isSpecials
                                ? 'Specials (${s.episodeCount})'
                                : 'S${s.seasonNumber} (${s.episodeCount})',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight:
                                  isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected
                                  ? AppColors.onPrimary
                                  : AppColors.textPrimary,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (val) {
                            if (val) {
                              setState(() {
                                _selectedSeasonNumber = s.seasonNumber;
                              });
                            }
                          },
                          selectedColor: AppColors.primary,
                          backgroundColor: AppColors.surfaceHigh,
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.outline,
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),

        // Episodes List for currently selected season
        seasonAsync.when(
          loading: () => const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: SeriolabLoader(size: 36),
              ),
            ),
          ),
          error: (err, _) => SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Error loading episodes: $err',
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
          ),
          data: (seasonDetails) {
            final episodesWithRatings = seasonDetails.episodes.map((ep) {
              final watched = trackingState?.watchedFor(show.id)[ep.key];
              if (watched != null) {
                return ep.copyWith(
                  userRating: watched.userRating,
                  reviewText: watched.reviewText,
                  hasSpoilers: watched.hasSpoilers,
                  loggedAt: watched.loggedAt ?? watched.watchedAt,
                );
              }
              return ep;
            }).toList();
            final activeSeason =
                seasonDetails.copyWith(episodes: episodesWithRatings);
            final episodes = activeSeason.episodes;
            if (episodes.isEmpty) {
              return const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'No episodes available.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ),
              );
            }

            final now = DateTime.now();
            final airedEpisodes = activeSeason.airedEpisodes(now);
            final allAiredWatched = airedEpisodes.isNotEmpty &&
                airedEpisodes.every(
                  (e) => trackingState?.isWatched(show.id, e.key) ?? false,
                );

            final seasonAvg = activeSeason.averageUserRating;
            final ratedCount = activeSeason.ratedEpisodeCount;

            return SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index == 0) {
                    // Quick Season Action Bar with Average Rating Badge
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Season $_selectedSeasonNumber',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: seasonAvg != null
                                        ? AppColors.primary.withValues(alpha: 0.15)
                                        : AppColors.surfaceHigh,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: seasonAvg != null
                                          ? AppColors.primary.withValues(alpha: 0.5)
                                          : AppColors.outline,
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        seasonAvg != null
                                            ? Icons.star_rounded
                                            : Icons.star_outline_rounded,
                                        size: 13,
                                        color: seasonAvg != null
                                            ? AppColors.secondary
                                            : AppColors.textMuted,
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          seasonAvg != null
                                              ? 'Season Average: ${seasonAvg.toStringAsFixed(1)} ★ ($ratedCount ${ratedCount == 1 ? 'rated episode' : 'rated episodes'})'
                                              : 'Season Average: — / 10',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: seasonAvg != null
                                                ? AppColors.textPrimary
                                                : AppColors.textSecondary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (airedEpisodes.isNotEmpty)
                            TextButton.icon(
                              onPressed: () {
                                ref
                                    .read(trackingControllerProvider.notifier)
                                    .setEpisodesWatched(
                                      show,
                                      airedEpisodes,
                                      watched: !allAiredWatched,
                                    );
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: allAiredWatched
                                    ? AppColors.danger
                                    : AppColors.secondary,
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: Icon(
                                allAiredWatched
                                    ? Icons.remove_done_rounded
                                    : Icons.done_all_rounded,
                                size: 16,
                              ),
                              label: Text(
                                allAiredWatched
                                    ? 'Unmark season'
                                    : 'Mark season watched',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    );
                  }

                  final episode = episodes[index - 1];
                  final isWatched =
                      trackingState?.isWatched(show.id, episode.key) ?? false;
                  final isAired = episode.isAiredAt(now);

                  return _buildEpisodeItem(
                    context: context,
                    show: show,
                    episode: episode,
                    isWatched: isWatched,
                    isAired: isAired,
                    hideSpoilers: settings.hideSpoilersForUnwatched,
                  );
                },
                childCount: episodes.length + 1,
              ),
            );
          },
        ),

        const SliverToBoxAdapter(
          child: SizedBox(height: 48),
        ),
      ],
    ),
  );
  }

  Widget _buildEpisodeItem({
    required BuildContext context,
    required ShowDetails show,
    required Episode episode,
    required bool isWatched,
    required bool isAired,
    required bool hideSpoilers,
  }) {
    final showOriginal =
        ref.watch(settingsControllerProvider.select((s) => s.showOriginalTitles));
    final episodeTitle = episode.displayTitle(showOriginal: showOriginal);
    final isSpoilerProtected =
        hideSpoilers && !isWatched && !_revealedSpoilers.contains(episode.key);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isWatched
            ? AppColors.surface.withValues(alpha: 0.6)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isWatched
              ? AppColors.secondary.withValues(alpha: 0.35)
              : AppColors.outline,
          width: 0.6,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            type: MaterialType.transparency,
            child: ListTile(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => EpisodeDetailScreen(
                    seriesId: show.id,
                    seasonNumber: episode.seasonNumber,
                    episodeNumber: episode.episodeNumber,
                    initialShow: show,
                    initialEpisode: episode,
                  ),
                ),
              );
            },
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isWatched
                    ? AppColors.secondary.withValues(alpha: 0.15)
                    : AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                'E${episode.episodeNumber}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isWatched
                      ? AppColors.secondary
                      : AppColors.textSecondary,
                ),
              ),
            ),
            title: Text(
              episodeTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isWatched
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
                decoration: isWatched ? TextDecoration.lineThrough : null,
              ),
            ),
            subtitle: Row(
              children: [
                if (episode.airDate != null)
                  Text(
                    Formatters.shortDate(episode.airDate),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                if (episode.runtime != null) ...[
                  const Text(' • ',
                      style: TextStyle(color: AppColors.textSecondary)),
                  Text(
                    '${episode.runtime}m',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (!isAired) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'BREVEMENTE',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Episode User Rating Badge or Subtle "★ Rate" Button
                if (episode.userRating != null || episode.reviewText != null)
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => _openEpisodeRatingModal(show, episode),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E054).withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFF00E054).withValues(alpha: 0.5),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 13,
                            color: Color(0xFF00E054),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            episode.userRating != null
                                ? episode.userRating!.toStringAsFixed(1)
                                : 'Registo',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF00E054),
                            ),
                          ),
                          if (episode.reviewText != null &&
                              episode.reviewText!.isNotEmpty) ...[
                            const SizedBox(width: 3),
                            const Icon(
                              Icons.notes_rounded,
                              size: 11,
                              color: Color(0xFF00E054),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                else
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => _openEpisodeRatingModal(show, episode),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHigh,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.outline,
                          width: 0.6,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star_outline_rounded,
                            size: 13,
                            color: AppColors.textMuted,
                          ),
                          SizedBox(width: 3),
                          Text(
                            'Rate',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(
                    isWatched
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked,
                    color: isWatched
                        ? AppColors.secondary
                        : AppColors.textSecondary,
                    size: 24,
                  ),
                  tooltip:
                      isWatched ? 'Mark as unwatched' : 'Mark as watched',
                  onPressed: isAired
                      ? () async {
                          final wasWatched = isWatched;
                          await ref
                              .read(trackingControllerProvider.notifier)
                              .toggleEpisode(show, episode);
                          if (!wasWatched && context.mounted) {
                            final showOriginal = ref
                                .read(settingsControllerProvider)
                                .showOriginalTitles;
                            showEpisodeRatingAndReviewSheet(
                              context,
                              show.id,
                              episode.seasonNumber,
                              episode.episodeNumber,
                              episode.displayTitle(
                                showOriginal: showOriginal,
                              ),
                              show: show,
                              episode: episode,
                            );
                          }
                        }
                      : () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('This episode has not aired yet!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                ),
              ],
            ),
          ),
          ),
          if (episode.overview.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: isSpoilerProtected
                  ? InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        setState(() {
                          _revealedSpoilers.add(episode.key);
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceHigh,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.outline,
                            width: 0.8,
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.visibility_off_rounded,
                              size: 13,
                              color: AppColors.warning,
                            ),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Spoiler hidden • Tap to reveal',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Text(
                      episode.overview,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
            ),
        ],
      ),
    );
  }

  void _showSeriesMoreOptionsSheet(
    BuildContext context,
    ShowDetails show,
    TrackedShow tracked,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: false,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalCtx) {
        final trackingState = ref.read(trackingControllerProvider).value;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ModalDragHandle(topPadding: 0, bottomPadding: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              show.displayTitle(
                                showOriginal: ref
                                    .read(settingsControllerProvider)
                                    .showOriginalTitles,
                              ),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            StatusChip(
                              status: tracked.status,
                              compact: true,
                              customLabel: (tracked.status ==
                                          TrackingStatus.watching &&
                                      show.airedEpisodeCount > 0 &&
                                      (trackingState?.watchedRegularCount(show.id) ?? 0) >=
                                          show.airedEpisodeCount &&
                                      !show.status.isFinished)
                                  ? 'Up to date'
                                  : null,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(modalCtx),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(),

                // Option 0: Mark entire series watched / unwatched
                () {
                  final watchedCount =
                      trackingState?.watchedRegularCount(show.id) ?? 0;
                  final effectiveAiredCount = show.airedEpisodeCount > 0
                      ? show.airedEpisodeCount
                      : show.totalEpisodeCount;
                  final allAiredWatched = (effectiveAiredCount > 0 &&
                          watchedCount >= effectiveAiredCount) ||
                      (tracked.status == TrackingStatus.completed);

                  return ListTile(
                    leading: Icon(
                      allAiredWatched
                          ? Icons.remove_done_rounded
                          : Icons.done_all_rounded,
                      color: allAiredWatched
                          ? AppColors.danger
                          : AppColors.secondary,
                    ),
                    title: Text(
                      allAiredWatched
                          ? 'Mark all as unwatched'
                          : 'Mark all as watched',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: allAiredWatched
                            ? AppColors.danger
                            : AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      allAiredWatched
                          ? 'Unmarks all episodes and resets progress'
                          : 'Marks all available episodes as watched',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(modalCtx);
                      _confirmMarkEntireSeries(
                        context,
                        ref,
                        show,
                        markWatched: !allAiredWatched,
                      );
                    },
                  );
                }(),

                // Option 1: Drop or Resume
                if (tracked.status != TrackingStatus.dropped)
                  ListTile(
                    leading: const Icon(
                      Icons.pause_circle_outline_rounded,
                      color: Color(0xFFF59E0B),
                    ),
                    title: const Text(
                      'Mark as Dropped / On Hold',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: const Text(
                      'Archives the show and moves it to the "Resume" section',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    onTap: () async {
                      Navigator.pop(modalCtx);
                      await ref
                          .read(trackingControllerProvider.notifier)
                          .setStatus(show, TrackingStatus.dropped);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Show marked as Dropped.'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  )
                else
                  ListTile(
                    leading: const Icon(
                      Icons.play_circle_outline_rounded,
                      color: AppColors.primary,
                    ),
                    title: const Text(
                      'Resume Show ("Watching")',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: const Text(
                      'Reactivates the show in your watching list',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    onTap: () async {
                      Navigator.pop(modalCtx);
                      await ref
                          .read(trackingControllerProvider.notifier)
                          .setStatus(show, TrackingStatus.watching);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Show resumed ("Watching").'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),

                // Option 2: Remove from library
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.danger,
                  ),
                  title: const Text(
                    'Remove from My List',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.danger,
                    ),
                  ),
                  subtitle: const Text(
                    'Removes the show from your library and clears progress',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(modalCtx);
                    _confirmRemoveShow(context, ref, show);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Future<void> _confirmMarkEntireSeries(
    BuildContext context,
    WidgetRef ref,
    ShowDetails show, {
    required bool markWatched,
  }) async {
    final showOriginal =
        ref.read(settingsControllerProvider).showOriginalTitles;
    final title = show.displayTitle(showOriginal: showOriginal);

    final showWithEpisodes = ref.read(showWithEpisodesProvider(show.id)).value;
    List<Episode>? episodes = showWithEpisodes?.episodes;
    if (episodes == null || episodes.isEmpty) {
      try {
        final fetched =
            await ref.read(showWithEpisodesProvider(show.id).future);
        episodes = fetched.episodes;
      } catch (_) {}
    }

    if (!context.mounted) return;

    final now = DateTime.now();
    final airedEpisodes = episodes != null
        ? episodes.where((e) => e.isAiredAt(now)).toList()
        : <Episode>[];

    final effectiveAiredCount = show.airedEpisodeCount > 0
        ? show.airedEpisodeCount
        : show.totalEpisodeCount;
    final totalAiredCount = airedEpisodes.isNotEmpty
        ? airedEpisodes.length
        : effectiveAiredCount;

    final seasons = show.regularSeasons.isNotEmpty
        ? show.regularSeasons
        : show.seasons.where((s) => s.seasonNumber > 0).toList();
    final seasonCount = seasons.isNotEmpty ? seasons.length : 1;

    final trackingState = ref.read(trackingControllerProvider).value;
    final watchedCount = trackingState?.watchedRegularCount(show.id) ?? 0;

    final affectedEpisodes = markWatched
        ? ((totalAiredCount - watchedCount) > 0
            ? (totalAiredCount - watchedCount)
            : totalAiredCount)
        : (watchedCount > 0 ? watchedCount : totalAiredCount);

    final epLabel =
        '$affectedEpisodes ${affectedEpisodes == 1 ? 'episode' : 'episodes'}';
    final seasonLabel =
        '$seasonCount ${seasonCount == 1 ? 'season' : 'seasons'}';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.outline),
        ),
        title: Text(
          markWatched ? 'Mark all as watched?' : 'Mark all as unwatched?',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          markWatched
              ? 'Are you sure you want to mark $epLabel across $seasonLabel of "$title" as watched?'
              : 'Are you sure you want to unmark $epLabel across $seasonLabel of "$title" and reset your progress to 0%?',
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor:
                  markWatched ? AppColors.primary : AppColors.danger,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              markWatched ? 'Mark as watched' : 'Unmark all',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      if (markWatched) {
        await ref
            .read(trackingControllerProvider.notifier)
            .markEntireSeriesWatched(
              show.id.toString(),
              showDetails: show,
              episodes: airedEpisodes.isNotEmpty ? airedEpisodes : episodes,
            );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Marked $epLabel across $seasonLabel as watched.'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        await ref
            .read(trackingControllerProvider.notifier)
            .markEntireSeriesUnwatched(
              show.id.toString(),
              showDetails: show,
            );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unmarked all episodes for "$title". Progress reset.'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  static Future<void> _confirmRemoveShow(
    BuildContext context,
    WidgetRef ref,
    ShowDetails show,
  ) async {
    final showOriginal =
        ref.read(settingsControllerProvider).showOriginalTitles;
    final title = show.displayTitle(showOriginal: showOriginal);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.outline),
        ),
        title: const Text(
          'Remove from My List?',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to remove "$title" from your library? Your progress and watched episodes for this show will be deleted.',
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Remove',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(trackingControllerProvider.notifier).removeShow(show.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Show removed from your library.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Widget _buildOverallRatingCard(
    BuildContext context,
    ShowDetails show,
    TrackedShow? tracked,
  ) {
    final userRating = tracked?.overallUserRating;
    final reviewText = tracked?.reviewText;
    final hasReview = reviewText != null && reviewText.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: userRating != null
              ? const Color(0xFF00E054).withValues(alpha: 0.5)
              : AppColors.outline,
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Community Rating
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'COMMUNITY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 18,
                          color: Color(0xFF38BDF8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          show.rating > 0
                              ? show.rating.toStringAsFixed(1)
                              : '—',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (show.voteCount > 0) ...[
                          const SizedBox(width: 4),
                          Text(
                            '(${show.voteCount})',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 38,
                color: AppColors.outline,
              ),
              const SizedBox(width: 14),
              // User's Overall Rating
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _openShowRatingModal(show, tracked),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'YOUR RATING',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: Color(0xFF38BDF8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            userRating != null
                                ? Icons.star_rounded
                                : Icons.star_border,
                            size: 18,
                            color: const Color(0xFF38BDF8),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              userRating != null
                                  ? userRating.toStringAsFixed(1)
                                  : 'Rate Show',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: userRating != null ? 16 : 14,
                                fontWeight: FontWeight.w800,
                                color: userRating != null
                                    ? AppColors.textPrimary
                                    : const Color(0xFF38BDF8),
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
          if (hasReview) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.outline, width: 0.6),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.format_quote_rounded,
                    size: 14,
                    color: Color(0xFF00E054),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      reviewText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openShowRatingModal(
    ShowDetails show,
    TrackedShow? tracked,
  ) async {
    final showOriginal =
        ref.read(settingsControllerProvider).showOriginalTitles;
    final result = await RatingModal.show(
      context,
      title: 'Rate & Log Show',
      itemName: show.displayTitle(showOriginal: showOriginal),
      badgeText: 'SHOW',
      initialRating: tracked?.overallUserRating,
      initialReview: tracked?.reviewText,
      initialHasSpoilers: tracked?.hasSpoilers ?? false,
      initialLoggedAt: tracked?.loggedAt,
    );
    if (!mounted || result == null) return;

    if (result is RatingSelected) {
      await ref
          .read(trackingControllerProvider.notifier)
          .setOverallShowRating(
            show,
            result.rating,
            reviewText: result.reviewText,
            hasSpoilers: result.hasSpoilers,
            loggedAt: result.loggedAt,
          );
      if (mounted) {
        final scoreText = result.rating != null
            ? '${result.rating!.toStringAsFixed(1)} ★'
            : 'log saved';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Show updated: $scoreText!',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else if (result is RatingRemoved) {
      await ref
          .read(trackingControllerProvider.notifier)
          .setOverallShowRating(show, null, clearReview: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Show rating and log removed.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _openEpisodeRatingModal(
    ShowDetails show,
    Episode episode,
  ) async {
    final watched = ref
        .read(trackingControllerProvider)
        .asData
        ?.value
        .watchedFor(show.id)[episode.key];
    final showOriginal =
        ref.read(settingsControllerProvider).showOriginalTitles;

    final result = await RatingModal.show(
      context,
      title: 'Rate Episode',
      itemName:
          '${episode.code} • ${episode.displayTitle(showOriginal: showOriginal)}',
      badgeText: episode.code,
      initialRating: watched?.userRating ?? episode.userRating,
      initialReview: watched?.reviewText ?? episode.reviewText,
      initialHasSpoilers: watched?.hasSpoilers ?? episode.hasSpoilers,
      initialLoggedAt: watched?.loggedAt ?? episode.loggedAt,
    );
    if (!mounted || result == null) return;

    if (result is RatingSelected) {
      await ref
          .read(trackingControllerProvider.notifier)
          .rateEpisode(
            show,
            episode,
            result.rating,
            reviewText: result.reviewText,
            hasSpoilers: result.hasSpoilers,
            loggedAt: result.loggedAt,
          );
      if (mounted) {
        final scoreMsg = result.rating != null
            ? 'rated ${result.rating!.toStringAsFixed(1)} ★'
            : 'logged';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Episode ${episode.code} $scoreMsg (marked as watched)!',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else if (result is RatingRemoved) {
      await ref
          .read(trackingControllerProvider.notifier)
          .rateEpisode(show, episode, null, clearReview: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Episode ${episode.code} rating removed.'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}

/// Animated heart icon button for marking series as favorite.
class _FavoriteHeartButton extends ConsumerStatefulWidget {
  const _FavoriteHeartButton({required this.show});

  final ShowDetails show;

  @override
  ConsumerState<_FavoriteHeartButton> createState() =>
      _FavoriteHeartButtonState();
}

class _FavoriteHeartButtonState extends ConsumerState<_FavoriteHeartButton> {
  double _scale = 1.0;

  void _triggerBounce() {
    setState(() => _scale = 1.35);
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _scale = 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider);
    final tracking = ref.watch(trackingControllerProvider).value;
    final tracked = tracking?.show(widget.show.id);
    final isFavorite =
        settings.isFavorite(widget.show.id) || (tracked?.isFavorite ?? false);

    return AnimatedScale(
      scale: _scale,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutBack,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: Icon(
            isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: isFavorite ? const Color(0xFFEF4444) : Colors.white,
            size: 22,
          ),
          tooltip:
              isFavorite ? 'Remove from favorites' : 'Add to favorites',
          onPressed: () async {
            _triggerBounce();
            final nowFav = await ref
                .read(settingsControllerProvider.notifier)
                .toggleFavorite(widget.show);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  nowFav
                      ? 'Added "${widget.show.title}" to favorites ❤️'
                      : 'Removed "${widget.show.title}" from favorites.',
                ),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Options menu on top bar providing Top 5 selection.
class _ShowDetailOptionsMenu extends ConsumerWidget {
  const _ShowDetailOptionsMenu({required this.show});

  final ShowDetails show;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final isInTopFive = settings.favoriteShowIds.contains(show.id);
    final tracked = ref.watch(trackedShowProvider(show.id));
    final trackingState = ref.watch(trackingControllerProvider).value;
    final watchedCount = trackingState?.watchedRegularCount(show.id) ?? 0;
    final effectiveAiredCount = show.airedEpisodeCount > 0
        ? show.airedEpisodeCount
        : show.totalEpisodeCount;
    final allAiredWatched = (effectiveAiredCount > 0 &&
            watchedCount >= effectiveAiredCount) ||
        (tracked?.status == TrackingStatus.completed);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        shape: BoxShape.circle,
      ),
      child: PopupMenuButton<String>(
        icon:
            const Icon(Icons.more_vert_rounded, color: Colors.white, size: 22),
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.outline),
        ),
        onSelected: (value) async {
          if (value == 'mark_all_watched') {
            _ShowDetailScreenState._confirmMarkEntireSeries(
              context,
              ref,
              show,
              markWatched: true,
            );
          } else if (value == 'mark_all_unwatched') {
            _ShowDetailScreenState._confirmMarkEntireSeries(
              context,
              ref,
              show,
              markWatched: false,
            );
          } else if (value == 'top5') {
            _showTopFiveSlotPicker(context, ref, show);
          } else if (value == 'drop') {
            await ref
                .read(trackingControllerProvider.notifier)
                .setStatus(show, TrackingStatus.dropped);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Show marked as Dropped.'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          } else if (value == 'resume') {
            await ref
                .read(trackingControllerProvider.notifier)
                .setStatus(show, TrackingStatus.watching);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Show resumed ("Watching").'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          } else if (value == 'remove') {
            _ShowDetailScreenState._confirmRemoveShow(context, ref, show);
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem<String>(
            value: allAiredWatched ? 'mark_all_unwatched' : 'mark_all_watched',
            child: Row(
              children: [
                Icon(
                  allAiredWatched
                      ? Icons.remove_done_rounded
                      : Icons.done_all_rounded,
                  color: allAiredWatched
                      ? AppColors.danger
                      : AppColors.secondary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    allAiredWatched
                        ? 'Mark all as unwatched'
                        : 'Mark all as watched',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: allAiredWatched
                          ? AppColors.danger
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const PopupMenuDivider(),
          if (tracked != null) ...[
            if (tracked.status != TrackingStatus.dropped)
              const PopupMenuItem<String>(
                value: 'drop',
                child: Row(
                  children: [
                    Icon(
                      Icons.pause_circle_outline_rounded,
                      color: Color(0xFFF59E0B),
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Mark as Dropped',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              const PopupMenuItem<String>(
                value: 'resume',
                child: Row(
                  children: [
                    Icon(
                      Icons.play_circle_outline_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Resume Show ("Watching")',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const PopupMenuItem<String>(
              value: 'remove',
              child: Row(
                children: [
                  Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.danger,
                    size: 20,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Remove from My List',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const PopupMenuDivider(),
          ],
          PopupMenuItem<String>(
            value: 'top5',
            child: Row(
              children: [
                Icon(
                  isInTopFive ? Icons.star_rounded : Icons.star_border_rounded,
                  color: AppColors.secondary,
                  size: 20,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isInTopFive ? 'Manage in Top 5' : 'Add to Top 5',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
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

/// Modal bottom sheet allowing selection of a Top 5 slot (1 to 5).
void _showTopFiveSlotPicker(
  BuildContext context,
  WidgetRef ref,
  ShowDetails show,
) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: false,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (modalCtx) {
      return Consumer(
        builder: (ctx, ref, _) {
          final settings = ref.watch(settingsControllerProvider);
          final favoriteIds = settings.favoriteShowIds;
          final currentSlotIndex = favoriteIds.indexOf(show.id);

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ModalDragHandle(topPadding: 0, bottomPadding: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Select Top 5 Slot',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            currentSlotIndex != -1
                                ? 'Currently at #${currentSlotIndex + 1}'
                                : 'Choose a slot for this show',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(modalCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 5 Slots List
                  Column(
                    children: List.generate(5, (index) {
                      final isOccupied = index < favoriteIds.length;
                      final occupiedId = isOccupied ? favoriteIds[index] : null;
                      final isCurrentShow = occupiedId == show.id;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            Navigator.pop(modalCtx);
                            await ref
                                .read(settingsControllerProvider.notifier)
                                .setTopFiveSlot(index, show);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Show "${show.title}" placed at slot #${index + 1} in Top 5.',
                                ),
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isCurrentShow
                                  ? AppColors.primary.withValues(alpha: 0.15)
                                  : AppColors.surfaceHigh,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isCurrentShow
                                    ? AppColors.primary
                                    : AppColors.outline,
                                width: isCurrentShow ? 1.5 : 0.8,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isCurrentShow
                                        ? AppColors.primary
                                        : AppColors.surface,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '#${index + 1}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: isCurrentShow
                                          ? Colors.white
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: isOccupied
                                      ? (isCurrentShow
                                          ? Text(
                                              '${show.title} (Current Slot)',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.primary,
                                              ),
                                            )
                                          : _OccupiedSlotTitle(
                                              showId: occupiedId!,
                                            ))
                                      : const Text(
                                          'Empty Slot (+)',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                ),
                                if (isCurrentShow)
                                  TextButton(
                                    onPressed: () async {
                                      Navigator.pop(modalCtx);
                                      await ref
                                          .read(settingsControllerProvider
                                              .notifier)
                                          .removeTopFiveSlot(index);
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text('Removed from Top 5.'),
                                          duration: Duration(seconds: 2),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    },
                                    child: const Text(
                                      'Remove',
                                      style: TextStyle(
                                        color: AppColors.danger,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  )
                                else
                                  Text(
                                    isOccupied ? 'Replace' : 'Assign',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isOccupied
                                          ? AppColors.textSecondary
                                          : AppColors.primary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class _OccupiedSlotTitle extends ConsumerWidget {
  const _OccupiedSlotTitle({required this.showId});

  final int showId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showAsync = ref.watch(showDetailsProvider(showId));
    return showAsync.when(
      data: (s) => Text(
        '${s.title} (Replace)',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
      loading: () => const Text(
        'Loading...',
        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
      ),
      error: (_, _) => Text(
        'Show #$showId',
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
    );
  }
}

class _BackdropTrailerButton extends ConsumerWidget {
  const _BackdropTrailerButton({required this.show});

  final ShowDetails show;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trailerAsync = ref.watch(showTrailerProvider(show.id));

    return trailerAsync.maybeWhen(
      data: (trailerKey) {
        if (trailerKey == null || trailerKey.isEmpty) {
          return const SizedBox.shrink();
        }

        final settings = ref.watch(settingsControllerProvider);
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              TrailerDialog.show(
                context,
                youtubeVideoKey: trailerKey,
                title: show.displayTitle(
                  showOriginal: settings.showOriginalTitles,
                ),
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0F17).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF7C5CFC),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.play_arrow_rounded,
                    color: Color(0xFF7C5CFC),
                    size: 18,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Watch Trailer',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

