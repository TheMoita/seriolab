import 'package:http/http.dart' as http;

import '../../domain/entities/genre.dart';
import '../../domain/entities/show.dart';
import '../models/tmdb_mapper.dart';
import 'show_remote_data_source.dart';
import 'tmdb_api_client.dart';

/// TMDB v3 implementation — only `/tv` endpoints are used (no movies).
///
/// Delegates all HTTP requests and error handling to [TmdbApiClient].
class TmdbRemoteDataSource implements ShowRemoteDataSource {
  TmdbRemoteDataSource({
    required this.apiClient,
  });

  factory TmdbRemoteDataSource.withClient({
    required http.Client client,
    required String apiKey,
    String? language,
  }) {
    return TmdbRemoteDataSource(
      apiClient: TmdbApiClient(
        client: client,
        apiKey: apiKey,
        defaultLanguage: language,
      ),
    );
  }

  final TmdbApiClient apiClient;

  @override
  Future<List<ShowSummary>> trending() async {
    try {
      final json = await apiClient.getTrendingTv(timeWindow: 'week');
      return TmdbMapper.summaries(json);
    } on TmdbException catch (e) {
      throw CatalogException(e.message, statusCode: e.statusCode);
    }
  }

  @override
  Future<List<ShowSummary>> popularThisWeek() async => trending();

  @override
  Future<List<ShowSummary>> justPremiered() async {
    final nowStr = DateTime.now().toIso8601String().substring(0, 10);
    final pastStr = DateTime.now()
        .subtract(const Duration(days: 90))
        .toIso8601String()
        .substring(0, 10);
    try {
      final json = await apiClient.discoverTv({
        'include_adult': 'false',
        'sort_by': 'first_air_date.desc',
        'first_air_date.lte': nowStr,
        'first_air_date.gte': pastStr,
        'vote_count.gte': '20',
      });
      return TmdbMapper.summaries(json);
    } on TmdbException catch (e) {
      throw CatalogException(e.message, statusCode: e.statusCode);
    }
  }

  @override
  Future<List<ShowSummary>> topRated() async {
    try {
      final json = await apiClient.getTopRatedTv();
      return TmdbMapper.summaries(json);
    } on TmdbException catch (e) {
      throw CatalogException(e.message, statusCode: e.statusCode);
    }
  }

  @override
  Future<List<ShowSummary>> discover({
    Genre? genre,
    required ShowSort sort,
  }) async {
    final query = <String, String>{
      'include_adult': 'false',
      'sort_by': switch (sort) {
        ShowSort.popularity => 'popularity.desc',
        ShowSort.rating => 'vote_average.desc',
        ShowSort.newest => 'first_air_date.desc',
      },
      if (sort == ShowSort.rating) 'vote_count.gte': '300',
      if (sort == ShowSort.newest) ...{
        'first_air_date.lte': DateTime.now().toIso8601String().substring(0, 10),
        'vote_count.gte': '20',
      },
    };
    if (genre != null) {
      if (genre.id == Genre.animeId) {
        query['with_genres'] = '${Genre.animationId}';
        query['with_original_language'] = 'ja';
      } else {
        query['with_genres'] = '${genre.id}';
      }
    }
    try {
      final json = await apiClient.discoverTv(query);
      return TmdbMapper.summaries(json);
    } on TmdbException catch (e) {
      throw CatalogException(e.message, statusCode: e.statusCode);
    }
  }

  @override
  Future<List<ShowSummary>> search(String query) async {
    try {
      final json = await apiClient.searchTv(query);
      return TmdbMapper.summaries(json);
    } on TmdbException catch (e) {
      throw CatalogException(e.message, statusCode: e.statusCode);
    }
  }

  @override
  Future<ShowDetails> showDetails(int showId) async {
    try {
      final json = await apiClient.getTvDetails(
        showId,
        appendToResponse: 'aggregate_credits',
      );
      return TmdbMapper.details(json);
    } on TmdbException catch (e) {
      throw CatalogException(e.message, statusCode: e.statusCode);
    }
  }

  @override
  Future<SeasonDetails> season(int showId, int seasonNumber) async {
    try {
      final json = await apiClient.getSeasonDetails(showId, seasonNumber);
      return TmdbMapper.season(json, showId: showId);
    } on TmdbException catch (e) {
      throw CatalogException(e.message, statusCode: e.statusCode);
    }
  }
}
