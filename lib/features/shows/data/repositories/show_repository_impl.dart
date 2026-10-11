import '../../../../core/config/app_config.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/episode.dart';
import '../../domain/entities/genre.dart';
import '../../domain/entities/show.dart';
import '../../domain/repositories/show_repository.dart';
import '../datasources/show_remote_data_source.dart';

/// Single source of truth for catalogue data, with an in-memory cache so
/// navigating back and forth does not refetch details/seasons.
class ShowRepositoryImpl implements ShowRepository {
  ShowRepositoryImpl({
    required this.remote,
    required this.isUsingMockData,
    DateTime Function()? clock,
  })  : _clock = clock ?? DateTime.now;

  final ShowRemoteDataSource remote;
  final DateTime Function() _clock;

  @override
  final bool isUsingMockData;

  final Map<int, Future<ShowDetails>> _details = {};
  final Map<(int, int), Future<SeasonDetails>> _seasons = {};
  final Map<(int, int, int), Future<EpisodeDetails>> _episodes = {};

  /// Caches the in-flight future; evicts it on failure so retries work.
  Future<T> _cached<K, T>(
    Map<K, Future<T>> cache,
    K key,
    Future<T> Function() load,
  ) {
    final existing = cache[key];
    if (existing != null) return existing;
    final future = load();
    cache[key] = future;
    future.then<void>((_) {}, onError: (Object _, StackTrace _) {
      if (identical(cache[key], future)) cache.remove(key);
    });
    return future;
  }

  @override
  Future<List<ShowSummary>> getTrending({String? language}) =>
      remote.trending(language: language);

  @override
  Future<List<ShowSummary>> getPopularThisWeek({String? language}) =>
      remote.popularThisWeek(language: language);

  @override
  Future<List<ShowSummary>> getJustPremiered({String? language}) =>
      remote.justPremiered(language: language);

  @override
  Future<List<ShowSummary>> getTopRated({String? language}) =>
      remote.topRated(language: language);

  @override
  Future<List<ShowSummary>> discover({
    Genre? genre,
    ShowSort sort = ShowSort.popularity,
    String? language,
  }) =>
      remote.discover(genre: genre, sort: sort, language: language);

  @override
  Future<List<ShowSummary>> search(
    String query, {
    Genre? genre,
    ShowSort? sort,
    String? language,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    final results = await remote.search(trimmed, language: language);
    final filtered = genre == null
        ? results
        : results.where((s) => s.matchesGenre(genre)).toList();
    return sort == null ? filtered : sortShows(filtered, sort);
  }

  @override
  Future<ShowDetails> getShowDetails(int showId, {String? language}) =>
      _cached(_details, showId,
          () => remote.showDetails(showId, language: language));

  @override
  Future<SeasonDetails> getSeason(int showId, int seasonNumber,
          {String? language}) =>
      _cached(
        _seasons,
        (showId, seasonNumber),
        () => remote.season(showId, seasonNumber, language: language),
      );

  @override
  Future<EpisodeDetails> getEpisodeDetails(
    int showId,
    int seasonNumber,
    int episodeNumber, {
    String? language,
  }) =>
      _cached(
        _episodes,
        (showId, seasonNumber, episodeNumber),
        () => remote.episode(showId, seasonNumber, episodeNumber,
            language: language),
      );

  @override
  Future<ShowWithEpisodes> getShowWithEpisodes(int showId,
      {String? language}) async {
    final show = await getShowDetails(showId, language: language);
    final seasons = await Future.wait(
      show.regularSeasons
          .where((s) => s.episodeCount > 0)
          .map((s) => getSeason(showId, s.seasonNumber, language: language)),
    );
    final episodes = [for (final s in seasons) ...s.episodes]
      ..sort((a, b) => a.key.compareTo(b.key));
    return ShowWithEpisodes(show: show, episodes: episodes);
  }

  @override
  Future<List<UpcomingEpisode>> getUpcomingEpisodes(
    List<int> showIds, {
    int days = AppConfig.calendarWindowDays,
  }) async {
    final today = Formatters.dateOnly(_clock());
    final until = today.add(Duration(days: days));

    Future<List<UpcomingEpisode>> forShow(int id) async {
      try {
        final show = await getShowDetails(id);
        final next = show.nextEpisodeToAir;
        if (next == null) return const [];
        try {
          final season = await getSeason(id, next.seasonNumber);
          final episodes = season.episodes
              .where((e) {
                final d = e.airDate;
                return d != null && !d.isBefore(today) && !d.isAfter(until);
              })
              .map((e) => UpcomingEpisode(
                    showId: id,
                    showName: show.name,
                    posterUrl: show.posterUrl,
                    backdropUrl: show.backdropUrl,
                    network: show.primaryNetwork,
                    episode: e,
                  ))
              .toList();
          if (episodes.isNotEmpty) return episodes;
        } catch (_) {
          // If individual season cannot be loaded, fallback to nextEpisodeToAir
        }

        final nextDate = next.airDate;
        if (nextDate != null && !nextDate.isBefore(today) && !nextDate.isAfter(until)) {
          return [
            UpcomingEpisode(
              showId: id,
              showName: show.name,
              posterUrl: show.posterUrl,
              backdropUrl: show.backdropUrl,
              network: show.primaryNetwork,
              episode: next,
            ),
          ];
        }
        return const [];
      } on CatalogException {
        // A single failing show must not break the whole calendar.
        return const [];
      }
    }

    final perShow = await Future.wait(showIds.map(forShow));
    return [for (final list in perShow) ...list]..sort((a, b) {
        final byDate = a.episode.airDate!.compareTo(b.episode.airDate!);
        if (byDate != 0) return byDate;
        final byShow = a.showName.compareTo(b.showName);
        return byShow != 0 ? byShow : a.episode.key.compareTo(b.episode.key);
      });
  }

  @override
  void invalidate({int? showId}) {
    if (showId == null) {
      _details.clear();
      _seasons.clear();
      _episodes.clear();
    } else {
      _details.remove(showId);
      _seasons.removeWhere((key, _) => key.$1 == showId);
      _episodes.removeWhere((key, _) => key.$1 == showId);
    }
  }

  @override
  Future<List<String>> getShowBackdrops(int showId) =>
      remote.showBackdrops(showId);

  @override
  Future<String?> getSeriesTrailer(int seriesId, {String? language}) =>
      remote.seriesTrailer(seriesId, language: language);
}
