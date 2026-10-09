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

  @override
  Future<UserSettings> getSettings() async {
    try {
      final raw = await _trackingRepo.readMeta(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          return UserSettings.fromJson(decoded);
        }
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
    } catch (e) {
      debugPrint('Falha ao guardar definições: $e');
    }
  }
}
