import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../tracking/domain/entities/tracking_entities.dart';
import '../../../tracking/presentation/providers/tracking_providers.dart';
import '../../domain/entities/episode.dart';
import '../../domain/entities/show.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../providers/show_providers.dart';
import '../widgets/rating_modal.dart';

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
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, stack) => Scaffold(
          appBar: AppBar(),
          body: EmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Erro ao carregar detalhes',
            message: err.toString(),
            actionLabel: 'Tentar novamente',
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

    return CustomScrollView(
      slivers: [
        // Collapsible App Bar with Backdrop
        SliverAppBar(
          expandedHeight: 280,
          pinned: true,
          backgroundColor: AppColors.background,
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                AppNetworkImage(
                  imageUrl: show.backdropUrl ?? show.posterUrl,
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
                      imageUrl: show.posterUrl,
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
                            show.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              height: 1.2,
                            ),
                          ),
                          if (show.originalName != null &&
                              show.originalName != show.name) ...[
                            const SizedBox(height: 2),
                            Text(
                              show.originalName!,
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
                    onPressed: () => _showTrackingOptionsModal(context, show, tracked),
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
                      tracked != null ? tracked.status.icon : Icons.add_rounded,
                      size: 20,
                      color: tracked != null ? tracked.status.color : AppColors.onPrimary,
                    ),
                    label: Text(
                      tracked != null
                          ? 'Lista: ${tracked.status.label} (Alterar)'
                          : 'Seguir / Adicionar à Lista',
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
                                    '$watchedCount de ${show.totalEpisodeCount} episódios vistos',
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
                    'Sinopse',
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
                    'Elenco Principal',
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
                      'Episódios',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (displayedSeasons.isNotEmpty)
                      Text(
                        '${show.totalEpisodeCount} episódios',
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
                                ? 'Especiais (${s.episodeCount})'
                                : 'T${s.seasonNumber} (${s.episodeCount})',
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
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
          ),
          error: (err, _) => SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Erro ao carregar episódios: $err',
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
                      'Sem episódios disponíveis.',
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
                                  'Temporada $_selectedSeasonNumber',
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
                                      Text(
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
                                    ? 'Desmarcar temporada'
                                    : 'Marcar toda vista',
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
          ListTile(
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
              episode.name,
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
                                ? '${episode.userRating!.toStringAsFixed(1)} ★'
                                : '★ Registo',
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
                            '★ Rate',
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
                      isWatched ? 'Marcar como não visto' : 'Marcar como visto',
                  onPressed: isAired
                      ? () {
                          ref
                              .read(trackingControllerProvider.notifier)
                              .toggleEpisode(show, episode);
                        }
                      : () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Este episódio ainda não estreou!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                ),
              ],
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
                                'Sinopse oculta (anti-spoiler) • Toca para ver',
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

  void _showTrackingOptionsModal(
    BuildContext context,
    ShowDetails show,
    TrackedShow? current,
  ) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      const Text(
                        'Estado da Série',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(modalCtx),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                ...TrackingStatus.values.map((status) {
                  final isCurrent = current?.status == status;
                  return ListTile(
                    leading: Icon(
                      status.icon,
                      color: isCurrent ? status.color : AppColors.textSecondary,
                    ),
                    title: Text(
                      status.label,
                      style: TextStyle(
                        fontWeight:
                            isCurrent ? FontWeight.w800 : FontWeight.w600,
                        color:
                            isCurrent ? status.color : AppColors.textPrimary,
                      ),
                    ),
                    trailing: isCurrent
                        ? Icon(Icons.check_rounded, color: status.color)
                        : null,
                    onTap: () {
                      Navigator.pop(modalCtx);
                      ref
                          .read(trackingControllerProvider.notifier)
                          .setStatus(show, status);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Série marcada como "${status.label}"',
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  );
                }),
                if (current != null) ...[
                  const Divider(),
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.danger,
                    ),
                    title: const Text(
                      'Remover da minha lista',
                      style: TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(modalCtx);
                      ref
                          .read(trackingControllerProvider.notifier)
                          .removeShow(show.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Série removida do teu perfil.'),
                          duration: Duration(seconds: 2),
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
                      'COMUNIDADE',
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
                          color: AppColors.secondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          show.rating > 0
                              ? '${show.rating.toStringAsFixed(1)} ★'
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
                              color: AppColors.textSecondary,
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
                        'A TUA AVALIAÇÃO',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: Color(0xFF00E054),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            userRating != null
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 18,
                            color: userRating != null
                                ? const Color(0xFF00E054)
                                : AppColors.secondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              userRating != null
                                  ? '${userRating.toStringAsFixed(1)} ★'
                                  : '★ Rate Show',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: userRating != null
                                    ? const Color(0xFF00E054)
                                    : AppColors.secondary,
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
    final result = await RatingModal.show(
      context,
      title: 'Classificar & Registar Série',
      itemName: show.name,
      badgeText: 'SÉRIE',
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
            : 'registo guardado';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Série atualizada: $scoreText!',
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
            content: Text('Avaliação e registo da série removidos.'),
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

    final result = await RatingModal.show(
      context,
      title: 'Classificar Episódio',
      itemName: '${episode.code} • ${episode.name}',
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
            ? 'avaliado com ${result.rating!.toStringAsFixed(1)} ★'
            : 'registado';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Episódio ${episode.code} $scoreMsg (marcado como visto)!',
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
            content: Text('Avaliação do episódio ${episode.code} removida.'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}
