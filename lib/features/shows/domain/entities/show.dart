import 'package:flutter/foundation.dart';

import '../../data/models/tmdb_mapper.dart';
import 'episode.dart';
import 'genre.dart';

/// Lightweight show representation used in lists, search results, grids.
@immutable
class ShowSummary {
  const ShowSummary({
    required this.id,
    required this.name,
    this.originalName = '',
    this.overview = '',
    this.posterUrl,
    this.backdropUrl,
    this.rating = 0,
    this.voteCount = 0,
    this.popularity = 0,
    this.firstAirDate,
    this.genreIds = const [],
    this.originalLanguage = '',
  });

  factory ShowSummary.fromTmdbJson(Map<String, dynamic> json) =>
      TmdbMapper.summary(json);

  Map<String, dynamic> toJson() => TmdbMapper.summaryToJson(this);

  final int id;
  final String name;
  final String originalName;
  final String overview;
  final String? posterUrl;
  final String? backdropUrl;
  final double rating;
  final int voteCount;
  final double popularity;
  final DateTime? firstAirDate;
  final List<int> genreIds;
  final String originalLanguage;

  /// Localized title fallback to [name].
  String get title => name;

  /// Original series title (from original_name/original_title).
  String get originalTitle => originalName.isNotEmpty ? originalName : name;

  /// Helper to decide which title to render based on user preference.
  String displayTitle({bool showOriginal = false}) =>
      showOriginal && originalTitle.isNotEmpty
          ? originalTitle
          : (title.isNotEmpty ? title : originalTitle);

  int? get year => firstAirDate?.year;

  bool get isAnime =>
      genreIds.contains(Genre.animationId) && originalLanguage == 'ja';

  bool matchesGenre(Genre genre) =>
      genre.id == Genre.animeId ? isAnime : genreIds.contains(genre.id);
}

@immutable
class SeasonSummary {
  const SeasonSummary({
    required this.seasonNumber,
    required this.name,
    required this.episodeCount,
    this.airDate,
    this.posterUrl,
    this.overview = '',
  });

  factory SeasonSummary.fromTmdbJson(Map<String, dynamic> json) {
    return SeasonSummary(
      seasonNumber: json['season_number'] is num
          ? (json['season_number'] as num).toInt()
          : 0,
      name: json['name'] as String? ?? '',
      episodeCount: json['episode_count'] is num
          ? (json['episode_count'] as num).toInt()
          : 0,
      airDate: TmdbMapper.date(json['air_date']),
      posterUrl: TmdbMapper.image(json['poster_path'], size: 'w342'),
      overview: json['overview'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'season_number': seasonNumber,
        'name': name,
        'episode_count': episodeCount,
        'air_date': airDate?.toIso8601String().substring(0, 10),
        'poster_path': posterUrl,
        'overview': overview,
      };

  final int seasonNumber;
  final String name;
  final int episodeCount;
  final DateTime? airDate;
  final String? posterUrl;
  final String overview;

  bool get isSpecials => seasonNumber == 0;
}

@immutable
class SeasonDetails {
  const SeasonDetails({
    required this.showId,
    required this.seasonNumber,
    required this.name,
    required this.episodes,
    this.overview = '',
    this.posterUrl,
    this.airDate,
  });

  final int showId;
  final int seasonNumber;
  final String name;
  final String overview;
  final String? posterUrl;
  final DateTime? airDate;
  final List<Episode> episodes;

  List<Episode> airedEpisodes(DateTime now) =>
      episodes.where((e) => e.isAiredAt(now)).toList();

  /// Average rating given by the user to rated episodes in this season.
  /// Returns null if no episodes in this season have been rated.
  double? get averageUserRating {
    final rated = episodes.where((e) => e.userRating != null && e.userRating! > 0);
    if (rated.isEmpty) return null;
    final sum = rated.fold<double>(0.0, (acc, e) => acc + e.userRating!);
    return sum / rated.length;
  }

  /// Total number of rated episodes in this season.
  int get ratedEpisodeCount =>
      episodes.where((e) => e.userRating != null && e.userRating! > 0).length;

  factory SeasonDetails.fromTmdbJson(Map<String, dynamic> json, {required int showId}) =>
      TmdbMapper.season(json, showId: showId);

  Map<String, dynamic> toJson() => TmdbMapper.seasonToJson(this);

  SeasonDetails copyWith({
    int? showId,
    int? seasonNumber,
    String? name,
    List<Episode>? episodes,
    String? overview,
    String? posterUrl,
    DateTime? airDate,
  }) =>
      SeasonDetails(
        showId: showId ?? this.showId,
        seasonNumber: seasonNumber ?? this.seasonNumber,
        name: name ?? this.name,
        episodes: episodes ?? this.episodes,
        overview: overview ?? this.overview,
        posterUrl: posterUrl ?? this.posterUrl,
        airDate: airDate ?? this.airDate,
      );
}

typedef SeasonModel = SeasonDetails;
typedef Season = SeasonDetails;

/// Full technical sheet of a show.
@immutable
class ShowDetails {
  const ShowDetails({
    required this.id,
    required this.name,
    this.originalName,
    this.overview = '',
    this.tagline = '',
    this.posterUrl,
    this.backdropUrl,
    this.genres = const [],
    this.rating = 0,
    this.voteCount = 0,
    this.popularity = 0,
    this.status = ShowStatus.unknown,
    this.networks = const [],
    this.firstAirDate,
    this.lastAirDate,
    this.episodeRuntime = 0,
    this.seasons = const [],
    this.cast = const [],
    this.originalLanguage = '',
    this.originCountries = const [],
    this.lastEpisodeToAir,
    this.nextEpisodeToAir,
    this.overallUserRating,
    this.reviewText,
    this.hasSpoilers = false,
    this.loggedAt,
    this.isFavorite = false,
  });

  final int id;
  final String name;
  final String? originalName;
  final String overview;
  final String tagline;
  final String? posterUrl;
  final String? backdropUrl;
  final List<Genre> genres;
  final double rating;
  final int voteCount;
  final double popularity;
  final ShowStatus status;
  final List<String> networks;
  final DateTime? firstAirDate;
  final DateTime? lastAirDate;

  /// Typical episode runtime in minutes (used for watch-time statistics).
  final int episodeRuntime;
  final List<SeasonSummary> seasons;
  final List<CastMember> cast;
  final String originalLanguage;
  final List<String> originCountries;
  final Episode? lastEpisodeToAir;
  final Episode? nextEpisodeToAir;

  /// Independent overall user rating for the entire series (1.0 to 10.0 or 0.5 to 5.0 stars).
  final double? overallUserRating;

  /// Optional user written review/notes for the show.
  final String? reviewText;

  /// Whether the review contains spoilers.
  final bool hasSpoilers;

  /// Date the log was recorded.
  final DateTime? loggedAt;

  /// Whether the show is marked as favorite by the user.
  final bool isFavorite;

  /// Localized title fallback to [name].
  String get title => name;

  /// Original series title (from original_name/original_title).
  String get originalTitle =>
      (originalName != null && originalName!.trim().isNotEmpty)
          ? originalName!.trim()
          : name;

  /// Helper to decide which title to render based on user preference.
  String displayTitle({bool showOriginal = false}) =>
      showOriginal && originalTitle.isNotEmpty
          ? originalTitle
          : (title.isNotEmpty ? title : originalTitle);

  int? get year => firstAirDate?.year;

  bool get isAnime =>
      genres.any((g) => g.id == Genre.animationId) && originalLanguage == 'ja';

  List<SeasonSummary> get regularSeasons =>
      seasons.where((s) => !s.isSpecials).toList();

  int get totalEpisodeCount =>
      regularSeasons.fold(0, (sum, s) => sum + s.episodeCount);

  /// Number of regular-season episodes already aired, derived from
  /// [lastEpisodeToAir] so it does not require loading every season.
  int get airedEpisodeCount {
    final last = lastEpisodeToAir;
    if (last == null) return 0;
    var count = 0;
    for (final s in regularSeasons) {
      if (s.seasonNumber < last.seasonNumber) count += s.episodeCount;
    }
    return count + last.episodeNumber;
  }

  String? get primaryNetwork => networks.isEmpty ? null : networks.first;

  ShowSummary toSummary() => ShowSummary(
        id: id,
        name: name,
        originalName: originalName ?? '',
        overview: overview,
        posterUrl: posterUrl,
        backdropUrl: backdropUrl,
        rating: rating,
        voteCount: voteCount,
        popularity: popularity,
        firstAirDate: firstAirDate,
        genreIds: genres.map((g) => g.id).toList(),
        originalLanguage: originalLanguage,
      );

  factory ShowDetails.fromTmdbJson(Map<String, dynamic> json) =>
      TmdbMapper.details(json);

  Map<String, dynamic> toJson() => TmdbMapper.detailsToJson(this);

  ShowDetails copyWith({
    int? id,
    String? name,
    String? originalName,
    String? overview,
    String? tagline,
    String? posterUrl,
    String? backdropUrl,
    List<Genre>? genres,
    double? rating,
    int? voteCount,
    double? popularity,
    ShowStatus? status,
    List<String>? networks,
    DateTime? firstAirDate,
    DateTime? lastAirDate,
    int? episodeRuntime,
    List<SeasonSummary>? seasons,
    List<CastMember>? cast,
    String? originalLanguage,
    List<String>? originCountries,
    Episode? lastEpisodeToAir,
    Episode? nextEpisodeToAir,
    double? overallUserRating,
    bool clearOverallUserRating = false,
    String? reviewText,
    bool clearReviewText = false,
    bool? hasSpoilers,
    DateTime? loggedAt,
    bool clearLoggedAt = false,
    bool? isFavorite,
  }) =>
      ShowDetails(
        id: id ?? this.id,
        name: name ?? this.name,
        originalName: originalName ?? this.originalName,
        overview: overview ?? this.overview,
        tagline: tagline ?? this.tagline,
        posterUrl: posterUrl ?? this.posterUrl,
        backdropUrl: backdropUrl ?? this.backdropUrl,
        genres: genres ?? this.genres,
        rating: rating ?? this.rating,
        voteCount: voteCount ?? this.voteCount,
        popularity: popularity ?? this.popularity,
        status: status ?? this.status,
        networks: networks ?? this.networks,
        firstAirDate: firstAirDate ?? this.firstAirDate,
        lastAirDate: lastAirDate ?? this.lastAirDate,
        episodeRuntime: episodeRuntime ?? this.episodeRuntime,
        seasons: seasons ?? this.seasons,
        cast: cast ?? this.cast,
        originalLanguage: originalLanguage ?? this.originalLanguage,
        originCountries: originCountries ?? this.originCountries,
        lastEpisodeToAir: lastEpisodeToAir ?? this.lastEpisodeToAir,
        nextEpisodeToAir: nextEpisodeToAir ?? this.nextEpisodeToAir,
        overallUserRating: clearOverallUserRating
            ? null
            : (overallUserRating ?? this.overallUserRating),
        reviewText:
            clearReviewText ? null : (reviewText ?? this.reviewText),
        hasSpoilers: hasSpoilers ?? this.hasSpoilers,
        loggedAt: clearLoggedAt ? null : (loggedAt ?? this.loggedAt),
        isFavorite: isFavorite ?? this.isFavorite,
      );
}

typedef SeriesModel = ShowDetails;
typedef Series = ShowDetails;
typedef SeriesSummary = ShowSummary;

/// An episode airing soon for a show the user follows.
@immutable
class UpcomingEpisode {
  const UpcomingEpisode({
    required this.showId,
    required this.showName,
    required this.episode,
    this.posterUrl,
    this.backdropUrl,
    this.network,
  });

  final int showId;
  final String showName;
  final String? posterUrl;
  final String? backdropUrl;
  final String? network;
  final Episode episode;

  bool get isSeasonPremiere => episode.episodeNumber == 1;
}

/// A show plus every regular-season episode (used to compute "next episode").
@immutable
class ShowWithEpisodes {
  const ShowWithEpisodes({required this.show, required this.episodes});

  final ShowDetails show;

  /// Regular-season episodes ordered by season/episode.
  final List<Episode> episodes;
}

/// Orders shows according to [sort] (returns a new list).
List<ShowSummary> sortShows(List<ShowSummary> shows, ShowSort sort) {
  final sorted = [...shows];
  switch (sort) {
    case ShowSort.popularity:
      sorted.sort((a, b) => b.popularity.compareTo(a.popularity));
    case ShowSort.rating:
      sorted.sort((a, b) => b.rating.compareTo(a.rating));
    case ShowSort.newest:
      sorted.sort((a, b) => (b.firstAirDate ?? DateTime(1900))
          .compareTo(a.firstAirDate ?? DateTime(1900)));
  }
  return sorted;
}
