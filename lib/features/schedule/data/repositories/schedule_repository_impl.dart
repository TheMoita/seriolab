import 'package:seriolab/core/utils/formatters.dart';
import 'package:seriolab/features/shows/domain/repositories/show_repository.dart';
import 'package:seriolab/features/tracking/domain/entities/tracking_entities.dart';
import 'package:seriolab/features/tracking/domain/entities/tracking_state.dart';
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
  ) =>
      getUpNext(trackingState);

  @override
  Future<List<CurrentlyWatchingItem>> getUpNext(
    TrackingState trackingState,
  ) async {
    final now = _clock();
    final watchingShows = trackingState.byStatus(TrackingStatus.watching);
    if (watchingShows.isEmpty) return const [];

    final results = await Future.wait(
      watchingShows.map((tracked) async {
        try {
          final showWithEpisodes =
              await showRepository.getShowWithEpisodes(tracked.showId);
          final show = showWithEpisodes.show;
          final episodes = showWithEpisodes.episodes;

          // 1. Calculate already aired/available episodes (air_date <= now)
          final airedEpisodes =
              episodes.where((ep) => ep.isAiredAt(now)).toList();

          // 2. Compare with episodes marked as watched by user
          final unwatchedAired = airedEpisodes
              .where((ep) => !trackingState.isWatched(tracked.showId, ep.key))
              .toList();

          // 3. Strict Inclusion Criterion:
          // A série SÓ é incluída se existir pelo menos 1 episódio já transmitido
          // que ainda NÃO foi visto pelo utilizador.
          if (unwatchedAired.isEmpty) {
            return null;
          }

          final nextEp = unwatchedAired.first;
          return CurrentlyWatchingItem(
            trackedShow: tracked,
            showDetails: show,
            nextEpisode: nextEp,
            isAired: true,
            isCaughtUp: false,
          );
        } catch (_) {
          return null;
        }
      }),
    );

    final items = results.whereType<CurrentlyWatchingItem>().toList();
    items.sort(
        (a, b) => b.trackedShow.updatedAt.compareTo(a.trackedShow.updatedAt));

    return items;
  }

  @override
  Future<List<CurrentlyWatchingItem>> getStartWatching(
    TrackingState trackingState,
  ) async {
    final now = _clock();
    // Séries em 'plan_to_watch' ('watchlist') que ainda não têm nenhum episódio visto
    final watchlistShows = trackingState
        .byStatus(TrackingStatus.watchlist)
        .where((tracked) => trackingState.watchedRegularCount(tracked.showId) == 0)
        .toList();

    if (watchlistShows.isEmpty) return const [];

    final results = await Future.wait(
      watchlistShows.map((tracked) async {
        try {
          final showWithEpisodes =
              await showRepository.getShowWithEpisodes(tracked.showId);
          final show = showWithEpisodes.show;
          final episodes = showWithEpisodes.episodes;

          // Selecionar 1º episódio (preferencialmente temporada 1, excluindo especiais)
          final regularEpisodes =
              episodes.where((e) => e.seasonNumber > 0).toList();
          final firstEpisode = regularEpisodes.isNotEmpty
              ? regularEpisodes.first
              : (episodes.isNotEmpty ? episodes.first : null);

          final isAired =
              firstEpisode != null ? firstEpisode.isAiredAt(now) : true;

          return CurrentlyWatchingItem(
            trackedShow: tracked,
            showDetails: show,
            nextEpisode: firstEpisode,
            isAired: isAired,
            isCaughtUp: false,
          );
        } catch (_) {
          return CurrentlyWatchingItem(
            trackedShow: tracked,
            isAired: true,
            isCaughtUp: false,
          );
        }
      }),
    );

    final items = results.whereType<CurrentlyWatchingItem>().toList();
    items.sort(
        (a, b) => b.trackedShow.addedAt.compareTo(a.trackedShow.addedAt));

    return items;
  }

  @override
  Future<List<CurrentlyWatchingItem>> getResume(
    TrackingState trackingState,
  ) async {
    final now = _clock();
    // Séries marcadas como 'dropped' ('Abandonadas')
    final droppedShows = trackingState.byStatus(TrackingStatus.dropped);
    if (droppedShows.isEmpty) return const [];

    final results = await Future.wait(
      droppedShows.map((tracked) async {
        try {
          final showWithEpisodes =
              await showRepository.getShowWithEpisodes(tracked.showId);
          final show = showWithEpisodes.show;
          final episodes = showWithEpisodes.episodes;

          final regularEpisodes =
              episodes.where((e) => e.seasonNumber > 0).toList();
          final candidateEpisodes =
              regularEpisodes.isNotEmpty ? regularEpisodes : episodes;

          // Próximo episódio por assistir
          final unwatched = candidateEpisodes
              .where((ep) => !trackingState.isWatched(tracked.showId, ep.key))
              .toList();

          final nextEp = unwatched.isNotEmpty ? unwatched.first : null;
          final isAired = nextEp != null ? nextEp.isAiredAt(now) : true;

          return CurrentlyWatchingItem(
            trackedShow: tracked,
            showDetails: show,
            nextEpisode: nextEp,
            isAired: isAired,
            isCaughtUp: unwatched.isEmpty,
          );
        } catch (_) {
          return CurrentlyWatchingItem(
            trackedShow: tracked,
            isAired: true,
            isCaughtUp: false,
          );
        }
      }),
    );

    final items = results.whereType<CurrentlyWatchingItem>().toList();
    items.sort(
        (a, b) => b.trackedShow.updatedAt.compareTo(a.trackedShow.updatedAt));

    return items;
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

        final key =
            '${up.showId}_${up.episode.seasonNumber}_${up.episode.episodeNumber}';
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
        if (!cleanDate.isBefore(today)) {
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
          if (!cleanDate.isBefore(today)) {
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
        if (!cleanDate.isBefore(today)) {
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

    // 3. Specifically for watching shows that are caught up, check if they have scheduled future episodes
    final watchingShows = trackingState.byStatus(TrackingStatus.watching);
    for (final tracked in watchingShows) {
      try {
        final showWithEpisodes =
            await showRepository.getShowWithEpisodes(tracked.showId);
        final show = showWithEpisodes.show;
        for (final ep in showWithEpisodes.episodes) {
          final epDate = ep.airDate;
          if (epDate == null) continue;
          final cleanDate = Formatters.dateOnly(epDate);
          if (!cleanDate.isBefore(today)) {
            final key =
                '${tracked.showId}_${ep.seasonNumber}_${ep.episodeNumber}';
            if (seenKeys.add(key)) {
              items.add(
                ComingSoonItem(
                  showId: tracked.showId,
                  showName: show.name,
                  airDate: epDate,
                  seasonNumber: ep.seasonNumber,
                  episodeNumber: ep.episodeNumber,
                  episodeTitle: ep.name,
                  posterUrl: show.posterUrl ?? tracked.posterUrl,
                  backdropUrl: show.backdropUrl,
                  network: show.primaryNetwork ?? tracked.network,
                  episode: ep,
                  isSeasonPremiere: ep.episodeNumber == 1,
                  showDetails: show,
                ),
              );
            }
          }
        }
      } catch (_) {}
    }

    // Sort chronologically: closest to today first
    items.sort((a, b) => a.airDate.compareTo(b.airDate));
    return items;
  }
}
