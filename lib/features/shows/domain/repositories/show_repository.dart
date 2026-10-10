import '../entities/episode.dart';
import '../entities/genre.dart';
import '../entities/show.dart';

/// Contract for the TV-show catalogue (TMDB or mock). TV shows only.
abstract interface class ShowRepository {
  /// `true` when backed by the offline demo catalogue.
  bool get isUsingMockData;

  Future<List<ShowSummary>> getTrending({String? language});

  /// Popular shows this week (curated / trending)
  Future<List<ShowSummary>> getPopularThisWeek({String? language});

  /// Recently premiered or new seasons currently airing
  Future<List<ShowSummary>> getJustPremiered({String? language});

  /// Highest rated TV shows of all time
  Future<List<ShowSummary>> getTopRated({String? language});

  /// Discover shows, optionally filtered by [genre], ordered by [sort].
  Future<List<ShowSummary>> discover({
    Genre? genre,
    ShowSort sort,
    String? language,
  });

  /// Search by title, optionally refined by [genre] and re-ordered by [sort]
  /// (`null` keeps the API relevance order).
  Future<List<ShowSummary>> search(
    String query, {
    Genre? genre,
    ShowSort? sort,
    String? language,
  });

  Future<ShowDetails> getShowDetails(int showId, {String? language});

  Future<SeasonDetails> getSeason(int showId, int seasonNumber,
      {String? language});

  Future<EpisodeDetails> getEpisodeDetails(
    int showId,
    int seasonNumber,
    int episodeNumber, {
    String? language,
  });

  /// Show details plus all regular-season episodes.
  Future<ShowWithEpisodes> getShowWithEpisodes(int showId, {String? language});

  /// Episodes airing from today up to [days] ahead for the given shows,
  /// ordered chronologically.
  Future<List<UpcomingEpisode>> getUpcomingEpisodes(
    List<int> showIds, {
    int days,
  });

  /// Clears cached data (all, or for a single show).
  void invalidate({int? showId});

  /// High-resolution backdrops/wallpapers for the show.
  Future<List<String>> getShowBackdrops(int showId);

  /// Official YouTube trailer video key for the show (or null if unavailable).
  Future<String?> getSeriesTrailer(int seriesId, {String? language});
}
