import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../../tracking/domain/repositories/tracking_repository.dart';
import '../../domain/entities/user_settings.dart';
import '../../domain/repositories/settings_repository.dart';

/// Implementation of [SettingsRepository] leveraging the app's existing
/// persistent key-value metadata store (`app_meta` in SQLite / in-memory).
class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(this._trackingRepo);

  final TrackingRepository _trackingRepo;
  static const String _storageKey = 'seriolab_user_settings';
  static const String _languageKey = 'selected_language_code';

  @override
  Future<UserSettings> getSettings() async {
    try {
      final raw = await _trackingRepo.readMeta(_storageKey);
      final savedLang = await _trackingRepo.readMeta(_languageKey);

      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          var settings = UserSettings.fromJson(decoded);
          if (savedLang != null && savedLang.isNotEmpty) {
            settings = settings.copyWith(language: savedLang);
          }
          return settings;
        }
      } else if (savedLang != null && savedLang.isNotEmpty) {
        return UserSettings.defaultSettings.copyWith(language: savedLang);
      }
    } catch (e) {
      debugPrint('Falha ao carregar definições: $e');
    }
    return UserSettings.defaultSettings;
  }

  @override
  Future<void> saveSettings(UserSettings settings) async {
    try {
      final raw = jsonEncode(settings.toJson());
      await _trackingRepo.writeMeta(_storageKey, raw);
      await _trackingRepo.writeMeta(_languageKey, settings.language);
    } catch (e) {
      debugPrint('Falha ao guardar definições: $e');
    }
  }
}
