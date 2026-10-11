import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:seriolab/features/shows/data/datasources/tmdb_api_client.dart';
import 'package:seriolab/features/shows/data/datasources/tmdb_remote_data_source.dart';
import 'package:seriolab/features/shows/domain/entities/episode.dart';
import 'package:seriolab/features/shows/domain/entities/show.dart';

void main() {
  group('TmdbApiClient', () {
    test('throws TmdbApiKeyMissingException when API key is empty', () async {
      final client = TmdbApiClient(
        client: http.Client(),
        apiKey: '',
      );

      expect(
        () => client.getTrendingTv(),
        throwsA(isA<TmdbApiKeyMissingException>()),
      );
    });

    test('throws TmdbApiKeyMissingException when API key contains placeholder',
        () async {
      final client = TmdbApiClient(
        client: http.Client(),
        apiKey: 'your_tmdb_api_key_here',
      );

      expect(
        () => client.searchTv('Breaking Bad'),
        throwsA(isA<TmdbApiKeyMissingException>()),
      );
    });

    test('attaches api_key as query param for v3 api keys', () async {
      late Uri requestedUri;
      final mockHttp = MockClient((request) async {
        requestedUri = request.url;
        return http.Response(
          jsonEncode({'results': []}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final client = TmdbApiClient(
        client: mockHttp,
        apiKey: 'test_api_key_32_characters_1234',
        defaultLanguage: 'pt-PT',
      );

      await client.getTrendingTv();
      expect(requestedUri.path, '/3/trending/tv/week');
      expect(requestedUri.queryParameters['api_key'],
          'test_api_key_32_characters_1234');
      expect(requestedUri.queryParameters['language'], 'pt-PT');
    });

    test('supports dynamic language override in requests', () async {
      late Uri requestedUri;
      final mockHttp = MockClient((request) async {
        requestedUri = request.url;
        return http.Response(
          jsonEncode({'results': []}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final client = TmdbApiClient(
        client: mockHttp,
        apiKey: 'test_api_key_32_characters_1234',
        defaultLanguage: 'pt-PT',
      );

      await client.getTrendingTv(language: 'en-US');
      expect(requestedUri.queryParameters['language'], 'en-US');

      await client.searchTv('Dark', language: 'pt-BR');
      expect(requestedUri.queryParameters['language'], 'pt-BR');
    });

    test('attaches Authorization Bearer header for v4 token', () async {
      late http.Request sentRequest;
      final mockHttp = MockClient((request) async {
        sentRequest = request;
        return http.Response(
          jsonEncode({'results': []}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final v4Token =
          'eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiJ0ZXN0X3Rva2VuX3ZlcnlfbG9uZ19zdHJpbmdfZXhhbXBsZSIu.signature';
      final client = TmdbApiClient(
        client: mockHttp,
        apiKey: v4Token,
      );

      await client.searchTv('Severance');
      expect(sentRequest.url.path, '/3/search/tv');
      expect(sentRequest.url.queryParameters['query'], 'Severance');
      expect(sentRequest.headers['authorization'], 'Bearer $v4Token');
      expect(sentRequest.url.queryParameters.containsKey('api_key'), isFalse);
    });

    test('throws TmdbAuthException on 401 status', () async {
      final mockHttp = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'status_code': 7,
            'status_message': 'Invalid API key: You must be granted a valid key.',
          }),
          401,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = TmdbApiClient(
        client: mockHttp,
        apiKey: 'invalid_key',
      );

      expect(
        () => client.getTrendingTv(),
        throwsA(isA<TmdbAuthException>()),
      );
    });

    test('throws TmdbNotFoundException on 404 status', () async {
      final mockHttp = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'status_code': 34,
            'status_message': 'The resource you requested could not be found.',
          }),
          404,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = TmdbApiClient(
        client: mockHttp,
        apiKey: 'valid_test_key_12345',
      );

      expect(
        () => client.getTvDetails(999999),
        throwsA(isA<TmdbNotFoundException>()),
      );
    });
  });

  group('TMDB Model Serialization & Deserialization', () {
    test('ShowSummary fromTmdbJson and toJson', () {
      final raw = {
        'id': 100088,
        'name': 'The Last of Us',
        'overview': 'Post-apocalyptic drama',
        'poster_path': '/uKwX94d1F6U1.jpg',
        'backdrop_path': '/uDgy6hyPd82k.jpg',
        'vote_average': 8.6,
        'vote_count': 5400,
        'popularity': 240.5,
        'first_air_date': '2023-01-15',
        'genre_ids': [18, 10759],
        'original_language': 'en',
      };

      final summary = ShowSummary.fromTmdbJson(raw);
      expect(summary.id, 100088);
      expect(summary.name, 'The Last of Us');
      expect(summary.posterUrl,
          'https://image.tmdb.org/t/p/w500/uKwX94d1F6U1.jpg');
      expect(summary.backdropUrl,
          'https://image.tmdb.org/t/p/w780/uDgy6hyPd82k.jpg');
      expect(summary.rating, 8.6);
      expect(summary.year, 2023);

      final json = summary.toJson();
      expect(json['id'], 100088);
      expect(json['name'], 'The Last of Us');
    });

    test('ShowSummary extracts localized and original titles and displayTitle works', () {
      final raw = {
        'id': 100088,
        'name': 'O Último de Nós',
        'original_name': 'The Last of Us',
        'overview': 'Drama pós-apocalíptico',
        'poster_path': '/uKwX94d1F6U1.jpg',
      };

      final summary = ShowSummary.fromTmdbJson(raw);
      expect(summary.name, 'O Último de Nós');
      expect(summary.title, 'O Último de Nós');
      expect(summary.originalName, 'The Last of Us');
      expect(summary.originalTitle, 'The Last of Us');
      expect(summary.displayTitle(showOriginal: false), 'O Último de Nós');
      expect(summary.displayTitle(showOriginal: true), 'The Last of Us');
    });

    test('ShowDetails / SeriesModel extracts localized and original titles', () {
      final raw = {
        'id': 70523,
        'name': 'Matrioska',
        'original_name': 'Russian Doll',
        'overview': 'Nádia morre repetidamente...',
        'poster_path': '/poster.jpg',
      };

      final details = ShowDetails.fromTmdbJson(raw);
      expect(details.name, 'Matrioska');
      expect(details.title, 'Matrioska');
      expect(details.originalName, 'Russian Doll');
      expect(details.originalTitle, 'Russian Doll');
      expect(details.displayTitle(showOriginal: false), 'Matrioska');
      expect(details.displayTitle(showOriginal: true), 'Russian Doll');
    });

    test('Episode / EpisodeModel extracts localized and original titles and displayTitle works', () {
      final raw = {
        'id': 2001,
        'season_number': 1,
        'episode_number': 1,
        'name': 'Quando Estás Perdido na Escuridão',
        'original_name': 'When You\'re Lost in the Darkness',
        'overview': 'Vinte anos após o surto...',
      };

      final episode = Episode.fromTmdbJson(raw, showId: 100088);
      expect(episode.name, 'Quando Estás Perdido na Escuridão');
      expect(episode.title, 'Quando Estás Perdido na Escuridão');
      expect(episode.originalName, 'When You\'re Lost in the Darkness');
      expect(episode.originalTitle, 'When You\'re Lost in the Darkness');
      expect(episode.displayTitle(showOriginal: false), 'Quando Estás Perdido na Escuridão');
      expect(episode.displayTitle(showOriginal: true), 'When You\'re Lost in the Darkness');
    });

    test('Episode fromTmdbJson and toJson', () {
      final raw = {
        'id': 2001,
        'season_number': 1,
        'episode_number': 1,
        'name': 'When You\'re Lost in the Darkness',
        'overview': 'Twenty years after a fungal outbreak...',
        'air_date': '2023-01-15',
        'runtime': 81,
        'still_path': '/still1.jpg',
        'vote_average': 8.8,
      };

      final episode = Episode.fromTmdbJson(raw, showId: 100088);
      expect(episode.showId, 100088);
      expect(episode.seasonNumber, 1);
      expect(episode.episodeNumber, 1);
      expect(episode.code, 'S01E01');
      expect(episode.name, 'When You\'re Lost in the Darkness');
      expect(episode.stillUrl, 'https://image.tmdb.org/t/p/w300/still1.jpg');

      final json = episode.toJson();
      expect(json['show_id'], 100088);
      expect(json['episode_number'], 1);
    });

    test('SeasonDetails fromTmdbJson and toJson', () {
      final raw = {
        'season_number': 1,
        'name': 'Season 1',
        'overview': 'The journey begins',
        'poster_path': '/s1_poster.jpg',
        'air_date': '2023-01-15',
        'episodes': [
          {
            'id': 2001,
            'season_number': 1,
            'episode_number': 1,
            'name': 'Ep 1',
            'overview': 'Intro',
            'air_date': '2023-01-15',
            'runtime': 81,
            'still_path': '/still1.jpg',
            'vote_average': 8.8,
          }
        ],
      };

      final season = SeasonDetails.fromTmdbJson(raw, showId: 100088);
      expect(season.showId, 100088);
      expect(season.seasonNumber, 1);
      expect(season.episodes.length, 1);
      expect(season.episodes.first.code, 'S01E01');

      final json = season.toJson();
      expect(json['season_number'], 1);
      expect((json['episodes'] as List).length, 1);
    });
  });

  group('TmdbRemoteDataSource with TmdbApiClient', () {
    test('trending() parses popular shows successfully', () async {
      final mockHttp = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'results': [
              {
                'id': 94997,
                'name': 'House of the Dragon',
                'overview': 'The Targaryen civil war begins',
                'poster_path': '/hotd.jpg',
                'vote_average': 8.4,
                'vote_count': 4200,
                'popularity': 350.0,
                'first_air_date': '2022-08-21',
                'genre_ids': [18, 10765],
                'original_language': 'en',
              }
            ]
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final apiClient = TmdbApiClient(
        client: mockHttp,
        apiKey: 'mock_valid_key_12345',
      );
      final remote = TmdbRemoteDataSource(apiClient: apiClient);

      final popular = await remote.popularThisWeek();
      expect(popular.length, 1);
      expect(popular.first.id, 94997);
      expect(popular.first.name, 'House of the Dragon');
      expect(popular.first.posterUrl,
          'https://image.tmdb.org/t/p/w500/hotd.jpg');
    });

    test('seriesTrailer returns official YouTube trailer key', () async {
      final mockHttp = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'id': 1399,
            'results': [
              {
                'id': 'clip1',
                'iso_639_1': 'pt',
                'key': 'clip_key',
                'name': 'Clip',
                'site': 'YouTube',
                'type': 'Clip',
                'official': false,
              },
              {
                'id': 'trailer1',
                'iso_639_1': 'pt',
                'key': 'pt_official_trailer',
                'name': 'Trailer Oficial',
                'site': 'YouTube',
                'type': 'Trailer',
                'official': true,
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final apiClient = TmdbApiClient(
        client: mockHttp,
        apiKey: 'mock_valid_key_12345',
        defaultLanguage: 'pt-PT',
      );
      final remote = TmdbRemoteDataSource(apiClient: apiClient);

      final key = await remote.seriesTrailer(1399);
      expect(key, 'pt_official_trailer');
    });

    test('seriesTrailer falls back to en-US if localized results are empty', () async {
      final requestedLangs = <String?>[];
      final mockHttp = MockClient((request) async {
        final lang = request.url.queryParameters['language'];
        requestedLangs.add(lang);
        if (lang == 'pt-PT') {
          return http.Response(
            jsonEncode({'id': 1399, 'results': []}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response(
          jsonEncode({
            'id': 1399,
            'results': [
              {
                'id': 'en_trailer',
                'iso_639_1': 'en',
                'key': 'en_youtube_trailer_key',
                'name': 'Official Trailer',
                'site': 'YouTube',
                'type': 'Trailer',
                'official': true,
              }
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final apiClient = TmdbApiClient(
        client: mockHttp,
        apiKey: 'mock_valid_key_12345',
        defaultLanguage: 'pt-PT',
      );
      final remote = TmdbRemoteDataSource(apiClient: apiClient);

      final key = await remote.seriesTrailer(1399);
      expect(key, 'en_youtube_trailer_key');
      expect(requestedLangs, contains('pt-PT'));
      expect(requestedLangs, contains('en-US'));
    });
  });
}
