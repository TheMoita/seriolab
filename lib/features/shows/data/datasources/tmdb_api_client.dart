import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../../core/config/app_config.dart';

/// Base exception for all TMDB API client errors.
sealed class TmdbException implements Exception {
  const TmdbException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Thrown when `TMDB_API_KEY` is empty, unset, or still has the placeholder value.
class TmdbApiKeyMissingException extends TmdbException {
  const TmdbApiKeyMissingException([
    super.message =
        'A chave de API do TMDB (TMDB_API_KEY) não está configurada.\n'
        'Adiciona a tua chave no ficheiro .env para aceder ao catálogo real.',
  ]) : super(statusCode: 401);
}

/// Thrown when TMDB rejects the credential (401 Unauthorized).
class TmdbAuthException extends TmdbException {
  const TmdbAuthException([
    super.message =
        'Chave de API do TMDB inválida ou não autorizada (401). Verifica o ficheiro .env.',
  ]) : super(statusCode: 401);
}

/// Thrown when a show or season was not found (404 Not Found).
class TmdbNotFoundException extends TmdbException {
  const TmdbNotFoundException([
    super.message = 'Conteúdo ou série não encontrado no TMDB (404).',
  ]) : super(statusCode: 404);
}

/// Thrown on request timeout.
class TmdbTimeoutException extends TmdbException {
  const TmdbTimeoutException([
    super.message = 'O pedido ao TMDB demorou demasiado tempo (tempo limite esgotado).',
  ]);
}

/// Thrown on network/socket connection failures.
class TmdbNetworkException extends TmdbException {
  const TmdbNetworkException([
    super.message = 'Sem ligação à internet ou falha ao contactar os servidores do TMDB.',
  ]);
}

/// Generic TMDB HTTP status exception.
class TmdbApiException extends TmdbException {
  const TmdbApiException(super.message, {super.statusCode});
}

/// Robust HTTP client for the The Movie Database (TMDB) v3 API.
///
/// Handles:
/// - Authentication via v3 API Key (`api_key` param) or v4 Bearer Token
/// - Timeout enforcement (default: 15s)
/// - Error parsing from TMDB's `status_message`
/// - Safe UTF-8 decoding & JSON deserialization
class TmdbApiClient {
  TmdbApiClient({
    required http.Client client,
    String? apiKey,
    String? baseUrl,
    this.timeout = const Duration(seconds: 15),
    String? defaultLanguage,
  })  : _client = client,
        _apiKey = apiKey ?? AppConfig.tmdbApiKey,
        baseUrl = baseUrl ?? AppConfig.tmdbBaseUrl,
        defaultLanguage = defaultLanguage ?? AppConfig.tmdbLanguage;

  final http.Client _client;
  final String _apiKey;
  final String baseUrl;
  final Duration timeout;
  final String defaultLanguage;

  bool get hasApiKey => _apiKey.trim().isNotEmpty && !_apiKey.contains('your_tmdb_api_key');
  bool get _isBearerToken => _apiKey.length > 40 || _apiKey.startsWith('ey');

  /// Executes an HTTP GET request to TMDB and decodes the JSON response map.
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? queryParameters,
    String? language,
  }) async {
    if (!hasApiKey) {
      throw const TmdbApiKeyMissingException();
    }

    final query = <String, String>{
      'language': language ?? defaultLanguage,
      if (!_isBearerToken) 'api_key': _apiKey,
      if (queryParameters != null) ...queryParameters,
    };

    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);

    try {
      final headers = <String, String>{
        HttpHeaders.acceptHeader: 'application/json',
        if (_isBearerToken) HttpHeaders.authorizationHeader: 'Bearer $_apiKey',
      };

      final response = await _client.get(uri, headers: headers).timeout(timeout);

      final bodyString = utf8.decode(response.bodyBytes);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(bodyString);
        if (decoded is Map) {
          return decoded.cast<String, dynamic>();
        }
        throw TmdbApiException(
          'Resposta inesperada do TMDB (esperado objecto JSON)',
          statusCode: response.statusCode,
        );
      }

      // Handle non-200 responses
      String errorMessage = 'Erro ao comunicar com o TMDB (${response.statusCode})';
      try {
        final decoded = jsonDecode(bodyString);
        if (decoded is Map && decoded['status_message'] is String) {
          errorMessage = decoded['status_message'] as String;
        }
      } catch (_) {
        // Fallback to generic message
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw TmdbAuthException(errorMessage);
      } else if (response.statusCode == 404) {
        throw TmdbNotFoundException(errorMessage);
      } else {
        throw TmdbApiException(errorMessage, statusCode: response.statusCode);
      }
    } on TmdbException {
      rethrow;
    } on TimeoutException {
      throw const TmdbTimeoutException();
    } on SocketException {
      throw const TmdbNetworkException();
    } on http.ClientException catch (e) {
      throw TmdbNetworkException('Erro de ligação HTTP: ${e.message}');
    } on FormatException catch (e) {
      throw TmdbApiException('Falha ao processar resposta JSON do TMDB: ${e.message}');
    } catch (e) {
      throw TmdbApiException('Erro inesperado: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Essential TV Shows Endpoints
  // ---------------------------------------------------------------------------

  /// 1. Popular This Week: GET /trending/tv/week
  Future<Map<String, dynamic>> getTrendingTv({
    String timeWindow = 'week',
    int page = 1,
  }) async {
    return get(
      '/trending/tv/$timeWindow',
      queryParameters: {
        if (page > 1) 'page': '$page',
      },
    );
  }

  /// 2. Search TV Shows: GET /search/tv?query={query}
  Future<Map<String, dynamic>> searchTv(
    String query, {
    int page = 1,
    bool includeAdult = false,
  }) async {
    return get(
      '/search/tv',
      queryParameters: {
        'query': query,
        'include_adult': '$includeAdult',
        if (page > 1) 'page': '$page',
      },
    );
  }

  /// 3. Show Details: GET /tv/{series_id}
  Future<Map<String, dynamic>> getTvDetails(
    int seriesId, {
    String? appendToResponse = 'aggregate_credits',
  }) async {
    return get(
      '/tv/$seriesId',
      queryParameters: {
        if (appendToResponse != null && appendToResponse.isNotEmpty)
          'append_to_response': appendToResponse,
      },
    );
  }

  /// 4. Season & Episodes: GET /tv/{series_id}/season/{season_number}
  Future<Map<String, dynamic>> getSeasonDetails(
    int seriesId,
    int seasonNumber,
  ) async {
    return get('/tv/$seriesId/season/$seasonNumber');
  }

  /// Top Rated TV Shows: GET /tv/top_rated
  Future<Map<String, dynamic>> getTopRatedTv({int page = 1}) async {
    return get(
      '/tv/top_rated',
      queryParameters: {
        if (page > 1) 'page': '$page',
      },
    );
  }

  /// Discover TV Shows: GET /discover/tv
  Future<Map<String, dynamic>> discoverTv(
    Map<String, String> queryParameters,
  ) async {
    return get('/discover/tv', queryParameters: queryParameters);
  }
}
