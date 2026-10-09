import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuration for Seriolab, reading credentials from `.env` via `flutter_dotenv`
/// with fallback to `--dart-define`.
class AppConfig {
  const AppConfig._();

  /// Fallback TMDB v3 key used when neither `.env` nor `--dart-define`
  /// provide one (e.g. the `.env` asset was not bundled in a release build).
  static const String _fallbackTmdbApiKey = '***REMOVED***';

  /// TMDB credential read from `.env` or `--dart-define`.
  /// Accepts either a v3 API key or a v4 "Read Access Token".
  static String get tmdbApiKey {
    try {
      final key = dotenv.isInitialized ? dotenv.env['TMDB_API_KEY'] : null;
      if (key != null &&
          key.trim().isNotEmpty &&
          !key.contains('your_tmdb_api_key')) {
        return key.trim();
      }
    } catch (_) {}
    const envVal = String.fromEnvironment('TMDB_API_KEY');
    if (envVal.isNotEmpty && !envVal.contains('your_tmdb_api_key')) {
      return envVal.trim();
    }
    debugPrint('[AppConfig] TMDB_API_KEY ausente no .env/dart-define — a usar chave de fallback.');
    return _fallbackTmdbApiKey;
  }

  /// Whether a non-empty TMDB API key is configured.
  static bool get hasTmdbApiKey => tmdbApiKey.isNotEmpty;

  /// Base URL for TMDB REST API endpoints.
  static String get tmdbBaseUrl {
    try {
      final url = dotenv.isInitialized ? dotenv.env['TMDB_BASE_URL'] : null;
      if (url != null && url.trim().isNotEmpty) {
        return url.trim().replaceAll(RegExp(r'/$'), '');
      }
    } catch (_) {}
    return 'https://api.themoviedb.org/3';
  }

  /// Base URL for TMDB image CDN.
  static String get tmdbImageBaseUrl {
    try {
      final url = dotenv.isInitialized ? dotenv.env['TMDB_IMAGE_BASE_URL'] : null;
      if (url != null && url.trim().isNotEmpty) {
        // Strip trailing size segment (/w500, /original, etc.) so size can be parameterized
        return url
            .trim()
            .replaceAll(RegExp(r'/(?:w\d+|original)$'), '')
            .replaceAll(RegExp(r'/$'), '');
      }
    } catch (_) {}
    return 'https://image.tmdb.org/t/p';
  }

  /// Language used for TMDB metadata (synopses, titles, ...).
  static String get tmdbLanguage {
    try {
      final lang = dotenv.isInitialized ? dotenv.env['TMDB_LANGUAGE'] : null;
      if (lang != null && lang.trim().isNotEmpty) {
        return lang.trim();
      }
    } catch (_) {}
    return const String.fromEnvironment('TMDB_LANGUAGE', defaultValue: 'pt-PT');
  }

  /// Forces the mock catalogue even if a key is configured.
  static const bool forceMockData = bool.fromEnvironment('USE_MOCK_DATA');

  /// When `forceMockData` is true, use mock data.
  static bool get useMockData => forceMockData;

  /// How many days ahead the release calendar looks.
  static const int calendarWindowDays = 60;
}
