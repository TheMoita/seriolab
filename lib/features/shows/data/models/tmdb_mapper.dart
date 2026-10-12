import '../../../../core/config/app_config.dart';
import '../../domain/entities/episode.dart';
import '../../domain/entities/genre.dart';
import '../../domain/entities/show.dart';

/// Helper to build TMDB image URLs with custom sizes.
String? buildTmdbImageUrl(Object? path, {String size = 'w500'}) =>
    TmdbMapper.image(path, size: size);

/// Maps raw TMDB TV JSON payloads to clean domain entities and vice-versa.
abstract final class TmdbMapper {
  /// Builds a fully-qualified image URL from a TMDB path (e.g. `/w500/abc.jpg`).
  /// If the path is already an absolute HTTP URL, it is returned unchanged.
  /// Rejects null, empty, or incomplete paths like `/null`.
  static String? image(Object? path, {String size = 'w500'}) {
    if (path is! String) return null;
    final trimmed = path.trim();
    if (trimmed.isEmpty) return null;

    final lower = trimmed.toLowerCase();
    if (lower == 'null' ||
        lower == '/null' ||
        lower.endsWith('/null') ||
        lower.endsWith('/undefined')) {
      return null;
    }

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    final cleanPath = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    if (cleanPath == '/null' || cleanPath.endsWith('/null')) return null;

    final base = AppConfig.tmdbImageBaseUrl;
    if (base.isEmpty) return null;
    return '$base/$size$cleanPath';
  }

  static DateTime? date(Object? value) {
    if (value is! String || value.isEmpty) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  static double _double(Object? v) => v is num ? v.toDouble() : 0;
  static int _int(Object? v) => v is num ? v.toInt() : 0;
  static String _string(Object? v) => v is String ? v : '';

  static List<Map<String, dynamic>> _list(Object? v) => v is List
      ? v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
      : const [];

  static ShowSummary summary(Map<String, dynamic> json) {
    final poster = image(json['poster_path']);
    final backdrop = image(json['backdrop_path'], size: 'w780');
    final rawName = json['name'] ?? json['title'];
    final rawOriginal = json['original_name'] ?? json['original_title'];
    final nameStr = rawName is String ? rawName.trim() : '';
    final originalStr = rawOriginal is String ? rawOriginal.trim() : '';
    final title = nameStr.isNotEmpty ? nameStr : originalStr;

    return ShowSummary(
      id: _int(json['id']),
      name: title,
      originalName: originalStr,
      overview: _string(json['overview']),
      posterUrl: poster ?? backdrop,
      backdropUrl: backdrop ?? poster,
      rating: _double(json['vote_average']),
      voteCount: _int(json['vote_count']),
      popularity: _double(json['popularity']),
      firstAirDate: date(json['first_air_date']),
      genreIds: (json['genre_ids'] as List?)?.whereType<int>().toList() ??
          const [],
      originalLanguage: _string(json['original_language']),
    );
  }

  static Map<String, dynamic> summaryToJson(ShowSummary summary) => {
        'id': summary.id,
        'name': summary.name,
        'original_name': summary.originalName,
        'overview': summary.overview,
        'poster_path': summary.posterUrl,
        'backdrop_path': summary.backdropUrl,
        'vote_average': summary.rating,
        'vote_count': summary.voteCount,
        'popularity': summary.popularity,
        'first_air_date': summary.firstAirDate?.toIso8601String().substring(0, 10),
        'genre_ids': summary.genreIds,
        'original_language': summary.originalLanguage,
      };

  static List<ShowSummary> summaries(Map<String, dynamic> page) =>
      _list(page['results']).map(summary).where((s) => s.id != 0).toList();

  static Episode episode(Map<String, dynamic> json, {required int showId}) {
    final rawName = json['name'] ?? json['title'];
    final rawOriginal = json['original_name'] ?? json['original_title'];
    final nameStr = rawName is String ? rawName.trim() : '';
    final originalStr = rawOriginal is String ? rawOriginal.trim() : '';
    final epNum = _int(json['episode_number']);
    final fallbackName = 'Episode $epNum';
    final title = nameStr.isNotEmpty
        ? nameStr
        : (originalStr.isNotEmpty ? originalStr : fallbackName);
    final origTitle = originalStr.isNotEmpty ? originalStr : title;

    return Episode(
      id: _int(json['id']),
      showId: showId,
      seasonNumber: _int(json['season_number']),
      episodeNumber: epNum,
      name: title,
      originalName: origTitle,
      overview: _string(json['overview']),
      airDate: date(json['air_date']),
      runtime: json['runtime'] is num ? _int(json['runtime']) : null,
      stillUrl: image(json['still_path'], size: 'w300'),
      rating: _double(json['vote_average']),
    );
  }

  static Map<String, dynamic> episodeToJson(Episode ep) => {
        'id': ep.id,
        'show_id': ep.showId,
        'season_number': ep.seasonNumber,
        'episode_number': ep.episodeNumber,
        'name': ep.name,
        if (ep.originalName.isNotEmpty) 'original_name': ep.originalName,
        'overview': ep.overview,
        'air_date': ep.airDate?.toIso8601String().substring(0, 10),
        'runtime': ep.runtime,
        'still_path': ep.stillUrl,
        'vote_average': ep.rating,
        if (ep.userRating != null) 'user_rating': ep.userRating,
      };

  static ShowDetails details(Map<String, dynamic> json) {
    final id = _int(json['id']);
    final rawName = json['name'] ?? json['title'];
    final rawOriginal = json['original_name'] ?? json['original_title'];
    final nameStr = rawName is String ? rawName.trim() : '';
    final originalStr = rawOriginal is String ? rawOriginal.trim() : '';
    final title = nameStr.isNotEmpty ? nameStr : originalStr;

    final runtimes =
        (json['episode_run_time'] as List?)?.whereType<num>().toList() ??
            const <num>[];
    final last = json['last_episode_to_air'];
    final next = json['next_episode_to_air'];
    final credits = json['aggregate_credits'] ?? json['credits'];

    var runtime = runtimes.isNotEmpty ? runtimes.first.toInt() : 0;
    if (runtime == 0 && last is Map && last['runtime'] is num) {
      runtime = (last['runtime'] as num).toInt();
    }

    final poster = image(json['poster_path']);
    final backdrop = image(json['backdrop_path'], size: 'w1280');

    return ShowDetails(
      id: id,
      name: title,
      originalName: originalStr.isNotEmpty ? originalStr : null,
      overview: _string(json['overview']),
      tagline: _string(json['tagline']),
      posterUrl: poster ?? backdrop,
      backdropUrl: backdrop ?? poster,
      genres: _list(json['genres'])
          .map((g) => Genre.byId(_int(g['id'])) ??
              Genre(id: _int(g['id']), name: _string(g['name'])))
          .toList(),
      rating: _double(json['vote_average']),
      voteCount: _int(json['vote_count']),
      popularity: _double(json['popularity']),
      status: ShowStatus.fromTmdb(json['status'] as String?),
      networks: _list(json['networks']).map((n) => _string(n['name'])).toList(),
      firstAirDate: date(json['first_air_date']),
      lastAirDate: date(json['last_air_date']),
      episodeRuntime: runtime,
      originalLanguage: _string(json['original_language']),
      originCountries:
          (json['origin_country'] as List?)?.whereType<String>().toList() ??
              const [],
      seasons: _list(json['seasons'])
          .map((s) => SeasonSummary(
                seasonNumber: _int(s['season_number']),
                name: _string(s['name']),
                episodeCount: _int(s['episode_count']),
                airDate: date(s['air_date']),
                posterUrl: image(s['poster_path'], size: 'w342') ?? poster ?? backdrop,
                overview: _string(s['overview']),
              ))
          .toList(),
      cast: credits is Map
          ? _list(credits['cast']).take(20).map((c) {
              final roles = _list(c['roles']);
              final character = roles.isNotEmpty
                  ? _string(roles.first['character'])
                  : _string(c['character']);
              return CastMember(
                id: _int(c['id']),
                name: _string(c['name']),
                character: character,
                profileUrl: image(c['profile_path'], size: 'w185'),
              );
            }).toList()
          : const [],
      lastEpisodeToAir:
          last is Map ? episode(last.cast<String, dynamic>(), showId: id) : null,
      nextEpisodeToAir:
          next is Map ? episode(next.cast<String, dynamic>(), showId: id) : null,
    );
  }

  static Map<String, dynamic> detailsToJson(ShowDetails d) => {
        'id': d.id,
        'name': d.name,
        'original_name': d.originalName,
        'overview': d.overview,
        'tagline': d.tagline,
        'poster_path': d.posterUrl,
        'backdrop_path': d.backdropUrl,
        'genres': d.genres.map((g) => {'id': g.id, 'name': g.name}).toList(),
        'vote_average': d.rating,
        'vote_count': d.voteCount,
        'popularity': d.popularity,
        'status': d.status.tmdbValue,
        'networks': d.networks.map((n) => {'name': n}).toList(),
        'first_air_date': d.firstAirDate?.toIso8601String().substring(0, 10),
        'last_air_date': d.lastAirDate?.toIso8601String().substring(0, 10),
        'episode_run_time': [d.episodeRuntime],
        'original_language': d.originalLanguage,
        'origin_country': d.originCountries,
        'seasons': d.seasons
            .map((s) => {
                  'season_number': s.seasonNumber,
                  'name': s.name,
                  'episode_count': s.episodeCount,
                  'air_date': s.airDate?.toIso8601String().substring(0, 10),
                  'poster_path': s.posterUrl,
                  'overview': s.overview,
                })
            .toList(),
        'aggregate_credits': {
          'cast': d.cast
              .map((c) => {
                    'id': c.id,
                    'name': c.name,
                    'roles': [
                      {'character': c.character}
                    ],
                    'profile_path': c.profileUrl,
                  })
              .toList(),
        },
        if (d.lastEpisodeToAir != null)
          'last_episode_to_air': episodeToJson(d.lastEpisodeToAir!),
        if (d.nextEpisodeToAir != null)
          'next_episode_to_air': episodeToJson(d.nextEpisodeToAir!),
      };

  static SeasonDetails season(Map<String, dynamic> json,
          {required int showId}) =>
      SeasonDetails(
        showId: showId,
        seasonNumber: _int(json['season_number']),
        name: _string(json['name']),
        overview: _string(json['overview']),
        posterUrl: image(json['poster_path'], size: 'w342'),
        airDate: date(json['air_date']),
        episodes: _list(json['episodes'])
            .map((e) => episode(e, showId: showId))
            .toList(),
      );

  static Map<String, dynamic> seasonToJson(SeasonDetails s) => {
        'id': s.seasonNumber,
        'season_number': s.seasonNumber,
        'name': s.name,
        'overview': s.overview,
        'poster_path': s.posterUrl,
        'air_date': s.airDate?.toIso8601String().substring(0, 10),
        'episodes': s.episodes.map(episodeToJson).toList(),
      };
}
