import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/seriolab_loader.dart';
import '../../../../core/widgets/seriolab_refresh_indicator.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../../shows/domain/entities/episode.dart';
import '../../../shows/domain/entities/show.dart';
import '../../../shows/presentation/screens/show_detail_screen.dart';
import '../../../shows/presentation/widgets/episode_review_bottom_sheet.dart';
import '../controllers/schedule_controller.dart';
import '../../domain/entities/schedule_item.dart';

class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key, this.onExploreTap});

  final VoidCallback? onExploreTap;

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleMarkWatched(
    ShowDetails show,
    Episode episode,
  ) async {
    try {
      await ref
          .read(scheduleControllerProvider.notifier)
          .markEpisodeWatched(show: show, episode: episode);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${show.name} ${episode.code} marcado como visto!',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: AppColors.surfaceHigh,
          behavior: SnackBarBehavior.floating,
        ),
      );

      final showOriginal =
          ref.read(settingsControllerProvider).showOriginalTitles;
      showEpisodeRatingAndReviewSheet(
        context,
        show.id,
        episode.seasonNumber,
        episode.episodeNumber,
        episode.displayTitle(showOriginal: showOriginal),
        show: show,
        episode: episode,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao atualizar episódio: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheduleAsync = ref.watch(scheduleControllerProvider);
    final settings = ref.watch(settingsControllerProvider);
    final l10n =
        AppLocalizations.of(context, settingsLanguage: settings.language);

    final watchlistCount =
        scheduleAsync.value?.watchlistTotalCount ?? 0;
    final comingSoonCount =
        scheduleAsync.value?.comingSoon.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Atualizar agenda',
            onPressed: () =>
                ref.read(scheduleControllerProvider.notifier).refresh(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            letterSpacing: 0.3,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            letterSpacing: 0.3,
          ),
          dividerColor: AppColors.outline,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(l10n.watchlistTab),
                  if (watchlistCount > 0) ...[
                    const SizedBox(width: 6),
                    _CountBadge(count: watchlistCount),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(l10n.comingSoonTab),
                  if (comingSoonCount > 0) ...[
                    const SizedBox(width: 6),
                    _CountBadge(count: comingSoonCount),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: scheduleAsync.when(
        loading: () => const Center(
          child: SeriolabLoader(),
        ),
        error: (err, _) => EmptyState(
          icon: Icons.calendar_today_rounded,
          title: 'Erro ao carregar agenda',
          message: err.toString(),
          actionLabel: 'Tentar novamente',
          onAction: () =>
              ref.read(scheduleControllerProvider.notifier).refresh(),
        ),
        data: (state) => TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: "Lista para Assistir" / Watchlist
            _WatchingListView(
              upNext: state.upNext,
              startWatching: state.startWatching,
              resume: state.resume,
              onExploreTap: widget.onExploreTap,
              onMarkWatched: _handleMarkWatched,
              onRefresh: () =>
                  ref.read(scheduleControllerProvider.notifier).refresh(),
            ),

            // Tab 2: "Brevemente"
            _ComingSoonListView(
              items: state.comingSoon,
              onExploreTap: widget.onExploreTap,
              onMarkWatched: _handleMarkWatched,
              onRefresh: () =>
                  ref.read(scheduleControllerProvider.notifier).refresh(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Backwards compatibility alias for CalendarScreen
typedef CalendarScreen = ScheduleScreen;

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

enum _WatchlistSectionType {
  upNext,
  startWatching,
  resume,
}

class _WatchlistSectionHeader extends StatelessWidget {
  const _WatchlistSectionHeader({
    required this.title,
    required this.icon,
    required this.count,
  });

  final String title;
  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          _CountBadge(count: count),
        ],
      ),
    );
  }
}

class _WatchingListView extends ConsumerWidget {
  const _WatchingListView({
    List<CurrentlyWatchingItem>? upNext,
    this.startWatching = const [],
    this.resume = const [],
    List<CurrentlyWatchingItem>? items,
    required this.onExploreTap,
    required this.onMarkWatched,
    required this.onRefresh,
  }) : upNext = upNext ?? items ?? const [];

  final List<CurrentlyWatchingItem> upNext;
  final List<CurrentlyWatchingItem> startWatching;
  final List<CurrentlyWatchingItem> resume;
  final VoidCallback? onExploreTap;
  final void Function(ShowDetails, Episode) onMarkWatched;
  final RefreshCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEmpty = upNext.isEmpty && startWatching.isEmpty && resume.isEmpty;
    if (isEmpty) {
      return EmptyState(
        icon: Icons.check_circle_outline_rounded,
        title: 'Estás em dia!',
        message: 'Nenhuma série com episódios pendentes para ver.',
        actionLabel: 'Explorar séries',
        onAction: onExploreTap,
      );
    }

    final settings = ref.watch(settingsControllerProvider);
    final l10n =
        AppLocalizations.of(context, settingsLanguage: settings.language);

    return SeriolabRefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          // Secção 1: "Ver a Seguir" (Up Next)
          if (upNext.isNotEmpty) ...[
            _WatchlistSectionHeader(
              title: l10n.upNextSection,
              icon: Icons.play_circle_outline_rounded,
              count: upNext.length,
            ),
            ...upNext.map(
              (item) => _CurrentlyWatchingCard(
                item: item,
                onMarkWatched: onMarkWatched,
                sectionType: _WatchlistSectionType.upNext,
              ),
            ),
          ],

          // Secção 2: "Começar a Ver" (Start Watching)
          if (startWatching.isNotEmpty) ...[
            _WatchlistSectionHeader(
              title: l10n.startWatchingSection,
              icon: Icons.bookmark_added_outlined,
              count: startWatching.length,
            ),
            ...startWatching.map(
              (item) => _CurrentlyWatchingCard(
                item: item,
                onMarkWatched: onMarkWatched,
                sectionType: _WatchlistSectionType.startWatching,
              ),
            ),
          ],

          // Secção 3: "Retomar" (Resume Watching)
          if (resume.isNotEmpty) ...[
            _WatchlistSectionHeader(
              title: l10n.resumeWatchingSection,
              icon: Icons.replay_rounded,
              count: resume.length,
            ),
            ...resume.map(
              (item) => _CurrentlyWatchingCard(
                item: item,
                onMarkWatched: onMarkWatched,
                sectionType: _WatchlistSectionType.resume,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CurrentlyWatchingCard extends ConsumerWidget {
  const _CurrentlyWatchingCard({
    required this.item,
    required this.onMarkWatched,
    this.sectionType = _WatchlistSectionType.upNext,
  });

  final CurrentlyWatchingItem item;
  final void Function(ShowDetails, Episode) onMarkWatched;
  final _WatchlistSectionType sectionType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showOriginal = ref.watch(
      settingsControllerProvider.select((s) => s.showOriginalTitles),
    );
    final ep = item.nextEpisode;
    final epTitle = ep != null
        ? ep.displayTitle(showOriginal: showOriginal)
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline, width: 0.6),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ShowDetailScreen(showId: item.showId),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Poster / Backdrop
              AppNetworkImage(
                imageUrl: item.posterUrl ?? item.backdropUrl,
                title: item.showName,
                width: 58,
                height: 86,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(width: 14),

              // Show & Episode Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Show name + Network
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.showName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (item.network != null &&
                            item.network!.trim().isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
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
                              item.network!,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    if (item.isCaughtUp) ...[
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            item.trackedShow.showStatus.isFinished
                                ? 'Série terminada!'
                                : 'Em dia com os episódios',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'A aguardar novos episódios',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ] else if (ep != null) ...[
                      // Episode identifier + Temporal badge or Section badge
                      Row(
                        children: [
                          Text(
                            item.episodeIdentifier, // e.g. T2 • E4
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: sectionType == _WatchlistSectionType.resume
                                  ? AppColors.danger
                                  : (sectionType ==
                                          _WatchlistSectionType.startWatching
                                      ? AppColors.primary
                                      : AppColors.secondary),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (sectionType == _WatchlistSectionType.resume)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.danger.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Pausada',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.danger,
                                ),
                              ),
                            )
                          else if (sectionType ==
                              _WatchlistSectionType.startWatching)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Começar',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            )
                          else
                            _TemporalBadge(
                              isAired: item.isAired,
                              airDate: ep.airDate,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        epTitle.isNotEmpty
                            ? epTitle
                            : 'Episódio ${ep.episodeNumber}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ] else ...[
                      Text(
                        sectionType == _WatchlistSectionType.startWatching
                            ? 'Começar a ver (Episódio 1)'
                            : (sectionType == _WatchlistSectionType.resume
                                ? 'Retomar série'
                                : 'Em andamento'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Quick action: mark as watched
              if (item.nextEpisode != null &&
                  item.showDetails != null &&
                  (item.isAired ||
                      sectionType != _WatchlistSectionType.upNext))
                IconButton(
                  icon: const Icon(
                    Icons.check_circle_outline_rounded,
                    color: AppColors.primary,
                    size: 26,
                  ),
                  tooltip: 'Marcar como visto',
                  onPressed: () => onMarkWatched(
                    item.showDetails!,
                    item.nextEpisode!,
                  ),
                )
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComingSoonListView extends StatelessWidget {
  const _ComingSoonListView({
    required this.items,
    required this.onExploreTap,
    required this.onMarkWatched,
    required this.onRefresh,
  });

  final List<ComingSoonItem> items;
  final VoidCallback? onExploreTap;
  final void Function(ShowDetails, Episode) onMarkWatched;
  final RefreshCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return EmptyState(
        icon: Icons.event_busy_rounded,
        title: 'Sem estreias agendadas',
        message: 'Nenhuma estreia agendada para breve nas tuas séries.',
        actionLabel: 'Explorar séries',
        onAction: onExploreTap,
      );
    }

    return SeriolabRefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return _ComingSoonCard(
            item: item,
            onMarkWatched: onMarkWatched,
          );
        },
      ),
    );
  }
}

class _ComingSoonCard extends StatelessWidget {
  const _ComingSoonCard({
    required this.item,
    required this.onMarkWatched,
  });

  final ComingSoonItem item;
  final void Function(ShowDetails, Episode) onMarkWatched;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline, width: 0.6),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ShowDetailScreen(showId: item.showId),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Poster / Backdrop
              AppNetworkImage(
                imageUrl: item.posterUrl ?? item.backdropUrl,
                title: item.showName,
                width: 58,
                height: 86,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(width: 14),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Show name + Network
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.showName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (item.network != null &&
                            item.network!.trim().isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
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
                              item.network!,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Episode code + Prominent Premiere Badge
                    Row(
                      children: [
                        Text(
                          item.episodeIdentifier, // e.g. T2 • E4
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.secondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _PremiereBadge(item: item),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Episode title or date description
                    Text(
                      item.episodeTitle.isNotEmpty
                          ? item.episodeTitle
                          : Formatters.fullDate(item.airDate),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // If already aired today, quick action; otherwise chevron
              if (item.isAiredToday &&
                  item.episode != null &&
                  item.showDetails != null)
                IconButton(
                  icon: const Icon(
                    Icons.check_circle_outline_rounded,
                    color: AppColors.primary,
                    size: 26,
                  ),
                  tooltip: 'Marcar como visto',
                  onPressed: () => onMarkWatched(
                    item.showDetails!,
                    item.episode!,
                  ),
                )
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Temporal badge for "A Ver Atualmente"
class _TemporalBadge extends StatelessWidget {
  const _TemporalBadge({required this.isAired, this.airDate});

  final bool isAired;
  final DateTime? airDate;

  @override
  Widget build(BuildContext context) {
    if (isAired) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: AppColors.success.withValues(alpha: 0.35),
            width: 0.8,
          ),
        ),
        child: const Text(
          'Disponível',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.success,
          ),
        ),
      );
    }

    if (airDate == null) {
      return const SizedBox.shrink();
    }

    final now = DateTime.now();
    final today = Formatters.dateOnly(now);
    final target = Formatters.dateOnly(airDate!);
    final diff = target.difference(today).inDays;

    final String label;
    if (diff <= 0) {
      label = 'Hoje';
    } else if (diff == 1) {
      label = 'Amanhã';
    } else {
      label = 'Em $diff dias';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppColors.secondary.withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.secondary,
        ),
      ),
    );
  }
}

/// Prominent premiere badge for "Brevemente" (e.g. "Estreia hoje", "Amanhã", "Daqui a 5 dias", "18 Out", "T3 Estreia em 2 semanas")
class _PremiereBadge extends StatelessWidget {
  const _PremiereBadge({required this.item});

  final ComingSoonItem item;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = Formatters.dateOnly(now);
    final airDate = Formatters.dateOnly(item.airDate);
    final diff = airDate.difference(today).inDays;

    final String text;
    final bool isHighlight;

    if (diff <= 0) {
      text = 'Estreia hoje';
      isHighlight = true;
    } else if (diff == 1) {
      text = 'Amanhã';
      isHighlight = true;
    } else if (diff < 7) {
      text = 'Daqui a $diff dias';
      isHighlight = false;
    } else {
      final weeks = (diff / 7).round();
      if (weeks <= 4 && item.isSeasonPremiere && item.seasonNumber > 1) {
        text = 'T${item.seasonNumber} Estreia em $weeks semanas';
        isHighlight = true;
      } else {
        text = Formatters.dayMonth(item.airDate);
        isHighlight = false;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isHighlight
            ? AppColors.warning.withValues(alpha: 0.18)
            : AppColors.secondary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isHighlight
              ? AppColors.warning.withValues(alpha: 0.4)
              : AppColors.secondary.withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isHighlight ? AppColors.warning : AppColors.secondary,
        ),
      ),
    );
  }
}
