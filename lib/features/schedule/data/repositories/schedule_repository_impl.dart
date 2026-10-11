import 'package:series_app/core/utils/formatters.dart';
import 'package:series_app/features/shows/domain/entities/episode.dart';
import 'package:series_app/features/shows/domain/repositories/show_repository.dart';
import 'package:series_app/features/tracking/domain/entities/tracking_entities.dart';
import 'package:series_app/features/tracking/domain/entities/tracking_state.dart';
import '../../domain/entities/schedule_item.dart';
import '../../domain/repositories/schedule_repository.dart';

class ScheduleRepositoryImpl implements ScheduleRepository {
  ScheduleRepositoryImpl({
    required this.showRepository,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final ShowRepository showRepository;
  final DateTime Function() _clock;

  @override
  Future<List<CurrentlyWatchingItem>> getCurrentlyWatching(
    TrackingState trackingState,
  ) async {
    final now = _clock();
    final watchingShows = trackingState.byStatus(TrackingStatus.watching);
    if (watchingShows.isEmpty) return const [];

    final items = await Future.wait(
      watchingShows.map((tracked) async {
        try {
          final showWithEpisodes =
              await showRepository.getShowWithEpisodes(tracked.showId);
          final show = showWithEpisodes.show;
          final episodes = showWithEpisodes.episodes;

          Episode? nextEp;
          var isAired = false;
          var isCaughtUp = false;

          // 1. Look for first unwatched regular episode
          for (final ep in episodes) {
            if (!trackingState.isWatched(tracked.showId, ep.key)) {
              nextEp = ep;
              isAired = ep.isAiredAt(now);
              break;
            }
          }

          // 2. If all loaded episodes are watched, check nextEpisodeToAir
          if (nextEp == null) {
            final nextToAir = show.nextEpisodeToAir;
            if (nextToAir != null) {
              nextEp = nextToAir;
              isAired = nextToAir.isAiredAt(now);
            } else {
              isCaughtUp = true;
            }
          }

          return CurrentlyWatchingItem(
            trackedShow: tracked,
            showDetails: show,
            nextEpisode: nextEp,
            isAired: isAired,
            isCaughtUp: isCaughtUp,
          );
        } catch (_) {
          return CurrentlyWatchingItem(
            trackedShow: tracked,
          );
        }
      }),
    );

    final sorted = List.of(items);
    sorted.sort((a, b) {
      int rank(CurrentlyWatchingItem item) {
        if (item.nextEpisode != null && item.isAired) return 0;
        if (item.nextEpisode != null && !item.isAired) return 1;
        if (item.isCaughtUp) return 2;
        return 3;
      }

      final rankDiff = rank(a).compareTo(rank(b));
      if (rankDiff != 0) return rankDiff;
      return b.trackedShow.updatedAt.compareTo(a.trackedShow.updatedAt);
    });

    return sorted;
  }

  @override
  Future<List<ComingSoonItem>> getComingSoon(
    TrackingState trackingState, {
    int windowDays = 60,
  }) async {
    final now = _clock();
    final today = Formatters.dateOnly(now);
    final until = today.add(Duration(days: windowDays));

    final showIds = trackingState.calendarShowIds;
    if (showIds.isEmpty) return const [];

    final items = <ComingSoonItem>[];
    final seenKeys = <String>{};

    // 1. Fetch upcoming episodes for followed shows
    try {
      final upcomingList = await showRepository.getUpcomingEpisodes(
        showIds,
        days: windowDays,
      );

      for (final up in upcomingList) {
        final airDate = up.episode.airDate;
        if (airDate == null) continue;
        final cleanDate = Formatters.dateOnly(airDate);
        if (cleanDate.isBefore(today) || cleanDate.isAfter(until)) continue;

        final key = '${up.showId}_${up.episode.seasonNumber}_${up.episode.episodeNumber}';
        if (seenKeys.add(key)) {
          items.add(ComingSoonItem.fromUpcomingEpisode(up));
        }
      }
    } catch (_) {
      // Continue to check individual shows
    }

    // 2. Also check show details for future premieres or seasons
    final shows = await Future.wait(
      showIds.map((id) async {
        try {
          return await showRepository.getShowDetails(id);
        } catch (_) {
          return null;
        }
      }),
    );

    for (final show in shows) {
      if (show == null) continue;

      // Check nextEpisodeToAir
      final next = show.nextEpisodeToAir;
      if (next != null && next.airDate != null) {
        final cleanDate = Formatters.dateOnly(next.airDate!);
        if (!cleanDate.isBefore(today) && !cleanDate.isAfter(until)) {
          final key = '${show.id}_${next.seasonNumber}_${next.episodeNumber}';
          if (seenKeys.add(key)) {
            items.add(
              ComingSoonItem(
                showId: show.id,
                showName: show.name,
                airDate: next.airDate!,
                seasonNumber: next.seasonNumber,
                episodeNumber: next.episodeNumber,
                episodeTitle: next.name,
                posterUrl: show.posterUrl,
                backdropUrl: show.backdropUrl,
                network: show.primaryNetwork,
                episode: next,
                isSeasonPremiere: next.episodeNumber == 1,
                showDetails: show,
              ),
            );
          }
        }
      }

      // Check regular seasons with future premiere dates
      for (final season in show.regularSeasons) {
        final sDate = season.airDate;
        if (sDate != null) {
          final cleanDate = Formatters.dateOnly(sDate);
          if (!cleanDate.isBefore(today) && !cleanDate.isAfter(until)) {
            final key = '${show.id}_${season.seasonNumber}_1';
            if (seenKeys.add(key)) {
              items.add(
                ComingSoonItem(
                  showId: show.id,
                  showName: show.name,
                  airDate: sDate,
                  seasonNumber: season.seasonNumber,
                  episodeNumber: 1,
                  episodeTitle: season.name.isNotEmpty
                      ? season.name
                      : 'Estreia da Temporada ${season.seasonNumber}',
                  posterUrl: season.posterUrl ?? show.posterUrl,
                  backdropUrl: show.backdropUrl,
                  network: show.primaryNetwork,
                  isSeasonPremiere: true,
                  showDetails: show,
                ),
              );
            }
          }
        }
      }

      // Check series firstAirDate if it hasn't aired yet
      final firstAir = show.firstAirDate;
      if (firstAir != null) {
        final cleanDate = Formatters.dateOnly(firstAir);
        if (!cleanDate.isBefore(today) && !cleanDate.isAfter(until)) {
          final key = '${show.id}_1_1';
          if (seenKeys.add(key)) {
            items.add(
              ComingSoonItem(
                showId: show.id,
                showName: show.name,
                airDate: firstAir,
                seasonNumber: 1,
                episodeNumber: 1,
                episodeTitle: 'Estreia da Série',
                posterUrl: show.posterUrl,
                backdropUrl: show.backdropUrl,
                network: show.primaryNetwork,
                isSeasonPremiere: true,
                showDetails: show,
              ),
            );
          }
        }
      }
    }

    // Sort chronologically: closest to today first
    items.sort((a, b) => a.airDate.compareTo(b.airDate));
    return items;
  }
}
