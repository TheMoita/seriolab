import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../shows/domain/entities/show.dart';
import '../../../tracking/presentation/providers/tracking_providers.dart';
import '../../data/repositories/settings_repository_impl.dart';
import '../../data/repositories/user_profile_repository_impl.dart';
import '../../domain/entities/user_settings.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/repositories/user_profile_repository.dart';

/// Provider for the settings repository.
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final trackingRepo = ref.watch(trackingRepositoryProvider);
  return SettingsRepositoryImpl(trackingRepo);
});

/// Provider for the user profile repository (favorites and Top 5).
final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  return UserProfileRepositoryImpl(settingsRepo);
});

/// Loads the user's top 5 favorite shows with full details.
/// Safely validates user authentication and logs full error and stack trace on failure.
final topFiveFavoritesProvider = FutureProvider<List<ShowDetails>>((ref) async {
  try {
    // Explicit authentication verification without forcing currentUser!
    if (Firebase.apps.isNotEmpty) {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        debugPrint('Top 5: User not authenticated in Firebase Auth. Returning empty list.');
        return const [];
      }
    }

    final settings = ref.watch(settingsControllerProvider);
    final ids = settings.favoriteShowIds;
    if (ids.isEmpty) return const [];

    final showRepo = ref.watch(showRepositoryProvider);
    final results = <ShowDetails>[];
    for (final id in ids) {
      try {
        final show = await showRepo.getShowDetails(id);
        results.add(show);
      } catch (e, stackTrace) {
        debugPrint('Error loading Top 5 ($id): $e');
        debugPrint('Stack: $stackTrace');
      }
    }
    return results;
  } catch (e, stackTrace) {
    debugPrint('Error loading Top 5: $e');
    debugPrint('Stack: $stackTrace');
    return const [];
  }
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
    var saved = await repo.getSettings();
    try {
      final trackingRepo = ref.read(trackingRepositoryProvider);
      final snapshot = await trackingRepo.load();
      final hasRealRatings = snapshot.shows.any(
        (s) => s.overallUserRating != null && s.overallUserRating! > 0,
      ) || snapshot.episodes.any(
        (e) => e.userRating != null && e.userRating! > 0,
      );
      if (!hasRealRatings && saved.totalRatingsCount > 0) {
        saved = saved.copyWith(
          ratingDistribution: UserSettings.defaultRatingDistribution,
        );
        await repo.saveSettings(saved);
      } else if (hasRealRatings) {
        final actualDist =
            Map<String, int>.from(UserSettings.defaultRatingDistribution);
        for (final show in snapshot.shows) {
          if (show.overallUserRating != null && show.overallUserRating! > 0) {
            final clamped = show.overallUserRating!.clamp(0.5, 10.0);
            final key = ((clamped * 2).round() / 2).toStringAsFixed(1);
            if (actualDist.containsKey(key)) {
              actualDist[key] = (actualDist[key] ?? 0) + 1;
            }
          }
        }
        for (final ep in snapshot.episodes) {
          if (ep.userRating != null && ep.userRating! > 0) {
            final clamped = ep.userRating!.clamp(0.5, 10.0);
            final key = ((clamped * 2).round() / 2).toStringAsFixed(1);
            if (actualDist.containsKey(key)) {
              actualDist[key] = (actualDist[key] ?? 0) + 1;
            }
          }
        }
        saved = saved.copyWith(ratingDistribution: actualDist);
        await repo.saveSettings(saved);
      }
    } catch (_) {}

    if (!_initialized) {
      _initialized = true;
      state = saved;
    }
  }

  Future<void> syncFromRemote(UserSettings remote) async {
    _initialized = true;
    state = remote;
    await _repo.saveSettings(remote);
  }

  Future<void> syncFavoritesFromRemote(
    List<int> topFive,
    List<int> allFavorites,
  ) async {
    _initialized = true;
    final updated = state.copyWith(
      favoriteShowIds: topFive,
      favoritedShowIds: allFavorites,
    );
    state = updated;
    await _repo.saveSettings(updated);
  }

  Future<void> update(UserSettings Function(UserSettings current) updater) async {
    _initialized = true;
    final updated = updater(state);
    state = updated;
    await _repo.saveSettings(updated);
    try {
      final sync = ref.read(firestoreSyncServiceProvider);
      sync.syncUserProfile(updated);
      sync.syncFavorites(updated);
    } catch (_) {}
  }

  Future<void> updateProfile({
    required String displayName,
    required String username,
    required String bio,
    required String avatarId,
    AvatarType? avatarType,
    String? avatarValue,
  }) async {
    await update((current) => current.copyWith(
          displayName: displayName,
          username: username,
          bio: bio,
          avatarId: avatarId,
          avatarType: avatarType ?? current.avatarType,
          avatarValue: avatarValue ?? current.avatarValue,
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

  Future<void> setShowOriginalTitles(bool value) async {
    await update((current) => current.copyWith(showOriginalTitles: value));
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
    await update((current) => current.copyWith(
          avatarId: avatarId,
          avatarType: AvatarType.preset,
          avatarValue: avatarId,
        ));
  }

  Future<void> setAvatarPreset(String avatarId) async {
    await update((current) => current.copyWith(
          avatarId: avatarId,
          avatarType: AvatarType.preset,
          avatarValue: avatarId,
        ));
  }

  Future<void> setAvatarLocalFile(String filePath) async {
    await update((current) => current.copyWith(
          avatarType: AvatarType.localFile,
          avatarValue: filePath,
        ));
  }

  Future<void> setAvatarNetworkUrl(String url) async {
    await update((current) => current.copyWith(
          avatarType: AvatarType.networkUrl,
          avatarValue: url,
        ));
  }

  Future<void> setProfileBannerUrl(String url) async {
    await update((current) => current.copyWith(
          profileBannerUrl: url,
          clearProfileBannerPath: true,
        ));
  }

  Future<void> setProfileBannerPath(String path) async {
    await update((current) => current.copyWith(
          profileBannerPath: path,
          clearProfileBannerUrl: true,
        ));
  }

  Future<void> clearProfileBanner() async {
    await update((current) => current.copyWith(
          clearProfileBanner: true,
        ));
  }

  Future<void> setFavoriteShows(List<int> showIds) async {
    await update((current) => current.copyWith(favoriteShowIds: showIds));
  }

  /// Toggles whether [series] is marked as a favorite.
  /// Also updates tracking storage offline SQLite data.
  Future<bool> toggleFavorite(SeriesModel series) async {
    final list = List<int>.from(state.favoritedShowIds);
    final isFav = list.contains(series.id);
    final nextFav = !isFav;
    if (nextFav) {
      if (!list.contains(series.id)) {
        list.add(series.id);
      }
    } else {
      list.remove(series.id);
    }
    await update((current) => current.copyWith(favoritedShowIds: list));

    try {
      final tracking = ref.read(trackingControllerProvider.notifier);
      await tracking.setIsFavorite(series, nextFav);
    } catch (_) {}

    return nextFav;
  }

  /// Sets [series] (or showId) into a specific slot [index] (0 to 4) of the Top 5.
  /// If the series was already in another slot, it is moved to [index].
  Future<void> setTopFiveSlot(int index, dynamic series) async {
    if (index < 0 || index >= 5) return;
    final int showId = series is int
        ? series
        : (series is ShowSummary ? series.id : (series as ShowDetails).id);
    final list = List<int>.from(state.favoriteShowIds);
    list.remove(showId);
    if (index < list.length) {
      list[index] = showId;
    } else {
      list.add(showId);
    }
    final clamped = list.length > 5 ? list.sublist(0, 5) : list;
    await setFavoriteShows(clamped);
  }

  /// Removes the series located at Top 5 slot [index].
  Future<void> removeTopFiveSlot(int index) async {
    final list = List<int>.from(state.favoriteShowIds);
    if (index >= 0 && index < list.length) {
      list.removeAt(index);
      await setFavoriteShows(list);
    }
  }

  /// Reorders the Top 5 from [oldIndex] to [newIndex].
  Future<void> reorderTopFive(int oldIndex, int newIndex) async {
    final list = List<int>.from(state.favoriteShowIds);
    if (oldIndex >= 0 && oldIndex < list.length) {
      final item = list.removeAt(oldIndex);
      final targetIndex = newIndex.clamp(0, list.length);
      list.insert(targetIndex, item);
      final clamped = list.length > 5 ? list.sublist(0, 5) : list;
      await setFavoriteShows(clamped);
    }
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
    await reorderTopFive(oldIndex, newIndex);
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

  Future<void> resetRatingDistribution() async {
    await update((current) => current.copyWith(
          ratingDistribution: UserSettings.defaultRatingDistribution,
        ));
  }

  Future<void> followUser(String userId) async {
    final list = List<String>.from(state.following);
    if (!list.contains(userId)) {
      list.add(userId);
      await update((current) => current.copyWith(following: list));
    }
  }

  Future<void> unfollowUser(String userId) async {
    final list = List<String>.from(state.following);
    if (list.contains(userId)) {
      list.remove(userId);
      await update((current) => current.copyWith(following: list));
    }
  }

  Future<void> toggleFollowUser(String userId) async {
    if (state.following.contains(userId)) {
      await unfollowUser(userId);
    } else {
      await followUser(userId);
    }
  }
}
