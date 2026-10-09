import 'package:flutter_test/flutter_test.dart';
import 'package:series_app/features/shows/data/datasources/mock/mock_show_remote_data_source.dart';
import 'package:series_app/features/shows/data/repositories/show_repository_impl.dart';
import 'package:series_app/core/widgets/app_network_image.dart';
import 'package:series_app/features/shows/data/models/tmdb_mapper.dart';
import 'package:series_app/features/shows/domain/entities/episode.dart';
import 'package:series_app/features/shows/domain/entities/genre.dart';

void main() {
  group('ShowRepository & Mock DataSource', () {
    late ShowRepositoryImpl repository;
    final fixedDate = DateTime(2026, 10, 9);

    setUp(() {
      repository = ShowRepositoryImpl(
        remote: MockShowRemoteDataSource(
          latency: Duration.zero,
          clock: () => fixedDate,
        ),
        isUsingMockData: true,
        clock: () => fixedDate,
      );
    });

    test('getTrending returns curated popular series', () async {
      final trending = await repository.getTrending();
      expect(trending, isNotEmpty);
      expect(trending.length, lessThanOrEqualTo(10));
    });

    test('getPopularThisWeek returns popular series with posters', () async {
      final popular = await repository.getPopularThisWeek();
      expect(popular, isNotEmpty);
      expect(popular.length, greaterThanOrEqualTo(5));
      expect(popular.first.posterUrl, isNotNull);
      expect(popular.first.posterUrl, startsWith('https://image.tmdb.org'));

      // The Last of Us and Severance should be present
      final names = popular.map((s) => s.name).toList();
      expect(names, contains('The Last of Us'));
      expect(names, contains('Severance'));
    });

    test('getJustPremiered returns recent and returning seasons', () async {
      final premiered = await repository.getJustPremiered();
      expect(premiered, isNotEmpty);
      expect(premiered.first.posterUrl, isNotNull);
    });

    test('getTopRated returns series sorted by rating descending', () async {
      final topRated = await repository.getTopRated();
      expect(topRated, isNotEmpty);
      for (var i = 0; i < topRated.length - 1; i++) {
        expect(topRated[i].rating, greaterThanOrEqualTo(topRated[i + 1].rating));
      }
    });

    test('discover filters by Anime genre properly', () async {
      final animeShows = await repository.discover(
        genre: Genre.anime,
        sort: ShowSort.popularity,
      );

      expect(animeShows, isNotEmpty);
      for (final show in animeShows) {
        expect(show.isAnime, isTrue);
        expect(show.originalLanguage, 'ja');
      }
    });

    test('search finds shows matching query with diacritic insensitivity',
        () async {
      // "shogun" without macron should find "Shōgun"
      final results1 = await repository.search('shogun');
      expect(results1.any((s) => s.name.contains('Shōgun')), isTrue);

      // "breaking" finds Breaking Bad
      final results2 = await repository.search('breaking');
      expect(results2.any((s) => s.name == 'Breaking Bad'), isTrue);
    });

    test('getShowDetails loads technical details and seasons', () async {
      // Breaking Bad ID 1396
      final details = await repository.getShowDetails(1396);
      expect(details.name, 'Breaking Bad');
      expect(details.status, ShowStatus.ended);
      expect(details.regularSeasons.length, 5);
      expect(details.cast, isNotEmpty);
      expect(details.networks, contains('AMC'));
      expect(details.posterUrl, isNotNull);
      expect(details.backdropUrl, isNotNull);
    });

    test('getSeason loads episodes with air dates', () async {
      final season = await repository.getSeason(1396, 1);
      expect(season.seasonNumber, 1);
      expect(season.episodes.length, 7);
      expect(season.episodes.first.name, 'Pilot');
      expect(season.episodes.first.isAiredAt(fixedDate), isTrue);
    });

    test('getUpcomingEpisodes retrieves future episodes for followed shows',
        () async {
      // Severance (95396) has a relative season with upcoming air dates
      final upcoming = await repository.getUpcomingEpisodes([95396], days: 60);

      expect(upcoming, isNotEmpty);
      for (final item in upcoming) {
        expect(item.showId, 95396);
        expect(item.episode.airDate!.isAfter(fixedDate), isTrue);
      }
    });

    test('TmdbMapper.image rejects invalid, null and incomplete paths', () {
      expect(TmdbMapper.image(null), isNull);
      expect(TmdbMapper.image(''), isNull);
      expect(TmdbMapper.image('   '), isNull);
      expect(TmdbMapper.image('null'), isNull);
      expect(TmdbMapper.image('/null'), isNull);
      expect(TmdbMapper.image('/undefined'), isNull);

      final valid = TmdbMapper.image('/poster.jpg');
      expect(valid, isNotNull);
      expect(valid, contains('/w500/poster.jpg'));
      expect(valid, isNot(endsWith('/null')));
    });

    test('TmdbMapper.summary falls back to backdrop when poster is null or invalid', () {
      final summary = TmdbMapper.summary({
        'id': 12345,
        'name': 'Carrie',
        'poster_path': null,
        'backdrop_path': '/backdrop.jpg',
      });

      expect(summary.posterUrl, isNotNull);
      expect(summary.posterUrl, contains('/backdrop.jpg'));
      expect(summary.backdropUrl, contains('/backdrop.jpg'));
    });

    test('AppNetworkImage.isValidUrl correctly validates image URLs', () {
      expect(AppNetworkImage.isValidUrl(null), isFalse);
      expect(AppNetworkImage.isValidUrl(''), isFalse);
      expect(AppNetworkImage.isValidUrl('   '), isFalse);
      expect(AppNetworkImage.isValidUrl('not-a-url'), isFalse);
      expect(AppNetworkImage.isValidUrl('https://image.tmdb.org/t/p/w500/null'), isFalse);
      expect(AppNetworkImage.isValidUrl('https://image.tmdb.org/t/p/w500null'), isFalse);
      expect(AppNetworkImage.isValidUrl('https://image.tmdb.org/t/p/w500/undefined'), isFalse);
      expect(AppNetworkImage.isValidUrl('https://image.tmdb.org/t/p/w500'), isFalse);
      expect(AppNetworkImage.isValidUrl('https://image.tmdb.org/t/p/w500/'), isFalse);

      expect(AppNetworkImage.isValidUrl('https://image.tmdb.org/t/p/w500/abc.jpg'), isTrue);
    });
  });
}
