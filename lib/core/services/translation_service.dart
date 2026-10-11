import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Service for translating user comments / reviews into the app's active language.
class TranslationService {
  TranslationService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final Map<String, String> _cache = {};

  /// Translates [text] to [targetLanguageCode] (e.g. 'pt', 'en', 'es').
  ///
  /// Uses an in-memory cache to avoid duplicate network requests for the same comment.
  /// Returns the translated text, or `null` if the translation fails.
  Future<String?> translateComment(String text, String targetLanguageCode) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return cleanText;

    final target = targetLanguageCode.split('-').first.toLowerCase();
    final cacheKey = '$cleanText::$target';

    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    // 1. Try MyMemory API (free, reliable public translation service)
    try {
      final uri = Uri.parse(
        'https://api.mymemory.translated.net/get?q=${Uri.encodeComponent(cleanText)}&langpair=autodetect|$target',
      );
      final response = await _client.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          final responseData = data['responseData'];
          if (responseData is Map<String, dynamic>) {
            final translated = responseData['translatedText'] as String?;
            if (translated != null &&
                translated.trim().isNotEmpty &&
                !translated.toUpperCase().startsWith('MYMEMORY WARNING:')) {
              final result = translated.trim();
              _cache[cacheKey] = result;
              return result;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[TranslationService] MyMemory request failed: $e');
    }

    // 2. Fallback: Google Translate public single endpoint
    try {
      final gUri = Uri.parse(
        'https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=$target&dt=t&q=${Uri.encodeComponent(cleanText)}',
      );
      final gResponse = await _client.get(
        gUri,
        headers: {'User-Agent': 'Mozilla/5.0 (Seriolab-App)'},
      );
      if (gResponse.statusCode == 200) {
        final dynamic decoded = jsonDecode(gResponse.body);
        if (decoded is List && decoded.isNotEmpty && decoded[0] is List) {
          final buffer = StringBuffer();
          for (final segment in decoded[0]) {
            if (segment is List && segment.isNotEmpty && segment[0] is String) {
              buffer.write(segment[0]);
            }
          }
          final res = buffer.toString().trim();
          if (res.isNotEmpty) {
            _cache[cacheKey] = res;
            return res;
          }
        }
      }
    } catch (e) {
      debugPrint('[TranslationService] Google Translate fallback failed: $e');
    }

    return null;
  }

  /// Clears cache (useful for testing).
  void clearCache() => _cache.clear();

  /// Inspect cache size (useful for testing).
  int get cacheSize => _cache.length;
}

final translationServiceProvider = Provider<TranslationService>((ref) {
  return TranslationService();
});
