import '../entities/user_settings.dart';

/// Contract for persisting and retrieving user preferences and profile.
abstract interface class SettingsRepository {
  /// Loads saved settings or returns [UserSettings.defaultSettings].
  Future<UserSettings> getSettings();

  /// Persists the updated settings locally.
  Future<void> saveSettings(UserSettings settings);
}
