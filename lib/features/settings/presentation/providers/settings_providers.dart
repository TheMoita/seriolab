import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../data/repositories/settings_repository_impl.dart';
import '../../domain/entities/user_settings.dart';
import '../../domain/repositories/settings_repository.dart';

/// Provider for the settings repository.
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final trackingRepo = ref.watch(trackingRepositoryProvider);
  return SettingsRepositoryImpl(trackingRepo);
});

/// Riverpod controller that manages and persists app & user settings.
final settingsControllerProvider =
    NotifierProvider<SettingsNotifier, UserSettings>(SettingsNotifier.new);

class SettingsNotifier extends Notifier<UserSettings> {
  SettingsRepository get _repo => ref.read(settingsRepositoryProvider);
  bool _initialized = false;

  @override
  UserSettings build() {
    final repo = ref.watch(settingsRepositoryProvider);
    _initialized = false;
    _loadFromStorage(repo);
    return UserSettings.defaultSettings;
  }

  Future<void> _loadFromStorage(SettingsRepository repo) async {
    final saved = await repo.getSettings();
    if (!_initialized) {
      _initialized = true;
      state = saved;
    }
  }

  Future<void> update(UserSettings Function(UserSettings current) updater) async {
    _initialized = true;
    final updated = updater(state);
    state = updated;
    await _repo.saveSettings(updated);
  }

  Future<void> updateProfile({
    required String displayName,
    required String username,
    required String bio,
    required String avatarId,
  }) async {
    await update((current) => current.copyWith(
          displayName: displayName,
          username: username,
          bio: bio,
          avatarId: avatarId,
        ));
  }

  Future<void> setLanguage(String language) async {
    await update((current) => current.copyWith(language: language));
  }

  Future<void> setStreamingRegion(String region) async {
    await update((current) => current.copyWith(streamingRegion: region));
  }

  Future<void> setHideSpoilers(bool value) async {
    await update((current) => current.copyWith(hideSpoilersForUnwatched: value));
  }

  Future<void> setGroupSpecialEpisodes(bool value) async {
    await update((current) => current.copyWith(groupSpecialEpisodes: value));
  }

  Future<void> setEpisodeReleaseReminders(bool value) async {
    await update((current) => current.copyWith(episodeReleaseReminders: value));
  }

  Future<void> setReminderTime(int hour, int minute) async {
    await update((current) => current.copyWith(
          reminderHour: hour,
          reminderMinute: minute,
        ));
  }

  Future<void> setAvatar(String avatarId) async {
    await update((current) => current.copyWith(avatarId: avatarId));
  }

  Future<void> setFavoriteShows(List<int> showIds) async {
    await update((current) => current.copyWith(favoriteShowIds: showIds));
  }

  Future<void> addFavoriteShow(int showId) async {
    final list = List<int>.from(state.favoriteShowIds);
    if (!list.contains(showId) && list.length < 5) {
      list.add(showId);
      await setFavoriteShows(list);
    }
  }

  Future<void> removeFavoriteShow(int showId) async {
    final list = List<int>.from(state.favoriteShowIds)..remove(showId);
    await setFavoriteShows(list);
  }

  Future<void> reorderFavoriteShows(int oldIndex, int newIndex) async {
    final list = List<int>.from(state.favoriteShowIds);
    if (oldIndex < list.length && newIndex <= list.length) {
      final item = list.removeAt(oldIndex);
      final insertIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
      list.insert(insertIndex, item);
      await setFavoriteShows(list);
    }
  }

  Future<void> recordRating(double newScore, {double? oldScore}) async {
    final key = newScore.toStringAsFixed(1);
    final map = Map<String, int>.from(state.ratingDistribution);
    if (oldScore != null) {
      final oldKey = oldScore.toStringAsFixed(1);
      final prev = map[oldKey] ?? 0;
      if (prev > 0) map[oldKey] = prev - 1;
    }
    map[key] = (map[key] ?? 0) + 1;
    await update((current) => current.copyWith(ratingDistribution: map));
  }

  Future<void> removeRating(double oldScore) async {
    final oldKey = oldScore.toStringAsFixed(1);
    final map = Map<String, int>.from(state.ratingDistribution);
    final prev = map[oldKey] ?? 0;
    if (prev > 0) {
      map[oldKey] = prev - 1;
      await update((current) => current.copyWith(ratingDistribution: map));
    }
  }
}
