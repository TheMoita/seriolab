import 'package:flutter_test/flutter_test.dart';
import 'package:series_app/features/settings/domain/entities/user_settings.dart';
import 'package:series_app/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:series_app/features/shows/domain/entities/episode.dart';
import 'package:series_app/features/tracking/data/repositories/in_memory_tracking_repository.dart';
import 'package:series_app/features/tracking/data/services/firestore_sync_service.dart';
import 'package:series_app/features/tracking/domain/entities/tracking_entities.dart';

void main() {
  group('FirestoreSyncService serialization tests', () {
    test('serializes and deserializes TrackedShow and WatchedEpisodes correctly', () {
      final now = DateTime.now();
      final show = TrackedShow(
        showId: 1396,
        name: 'Breaking Bad',
        posterUrl: 'https://image.tmdb.org/t/p/w500/breaking_bad.jpg',
        status: TrackingStatus.completed,
        airedEpisodeCount: 62,
        episodeRuntime: 49,
        showStatus: ShowStatus.ended,
        network: 'AMC',
        addedAt: now.subtract(const Duration(days: 30)),
        updatedAt: now,
        overallUserRating: 10.0,
        reviewText: 'Masterpiece from start to finish.',
        hasSpoilers: false,
        loggedAt: now,
        isFavorite: true,
      );

      final episodes = [
        WatchedEpisode(
          showId: 1396,
          key: const EpisodeKey(1, 1),
          runtime: 58,
          watchedAt: now.subtract(const Duration(days: 29)),
          userRating: 9.5,
          reviewText: 'Incredible pilot',
          hasSpoilers: false,
          loggedAt: now.subtract(const Duration(days: 29)),
        ),
        WatchedEpisode(
          showId: 1396,
          key: const EpisodeKey(5, 14),
          runtime: 47,
          watchedAt: now,
          userRating: 10.0,
          reviewText: 'Ozymandias is perfection',
          hasSpoilers: true,
          loggedAt: now,
        ),
      ];

      final map = FirestoreSyncService.trackedShowToMap(show, watchedEpisodes: episodes);

      expect(map['showId'], 1396);
      expect(map['name'], 'Breaking Bad');
      expect(map['status'], 'completed');
      expect(map['airedEpisodeCount'], 62);
      expect(map['overallUserRating'], 10.0);
      expect(map['reviewText'], 'Masterpiece from start to finish.');
      expect(map['isFavorite'], true);

      final watchedList = map['watchedEpisodes'] as List<dynamic>;
      expect(watchedList.length, 2);
      expect(watchedList[0]['seasonNumber'], 1);
      expect(watchedList[0]['episodeNumber'], 1);
      expect(watchedList[0]['userRating'], 9.5);
      expect(watchedList[1]['seasonNumber'], 5);
      expect(watchedList[1]['episodeNumber'], 14);
      expect(watchedList[1]['hasSpoilers'], true);

      // Deserialization
      final restoredShow = FirestoreSyncService.trackedShowFromMap(map);
      expect(restoredShow.showId, show.showId);
      expect(restoredShow.name, show.name);
      expect(restoredShow.status, TrackingStatus.completed);
      expect(restoredShow.overallUserRating, 10.0);
      expect(restoredShow.reviewText, 'Masterpiece from start to finish.');
      expect(restoredShow.isFavorite, true);

      final restoredEpisodes = FirestoreSyncService.watchedEpisodesFromMap(1396, map);
      expect(restoredEpisodes.length, 2);
      expect(restoredEpisodes[0].key.season, 1);
      expect(restoredEpisodes[0].key.episode, 1);
      expect(restoredEpisodes[0].userRating, 9.5);
      expect(restoredEpisodes[0].reviewText, 'Incredible pilot');
      expect(restoredEpisodes[1].key.season, 5);
      expect(restoredEpisodes[1].key.episode, 14);
      expect(restoredEpisodes[1].hasSpoilers, true);
    });

    test('serializes and deserializes UserSettings profile info', () {
      const settings = UserSettings(
        displayName: 'Afonso Dias',
        username: 'afonsod',
        bio: 'Passionate about cinema & quality television.',
        avatarId: 'tv_retro',
        avatarType: AvatarType.preset,
        profileBannerUrl: 'https://example.com/banner.jpg',
        language: 'pt-PT',
        streamingRegion: 'PT',
        hideSpoilersForUnwatched: true,
        groupSpecialEpisodes: false,
        episodeReleaseReminders: true,
        reminderHour: 20,
        reminderMinute: 30,
        following: ['user_1', 'user_2'],
        followers: ['user_3'],
        favoriteShowIds: [1396, 95396],
        favoritedShowIds: [1396, 95396, 70523],
        ratingDistribution: {'10.0': 5, '9.0': 3},
      );

      final map = FirestoreSyncService.userSettingsToMap(settings);
      expect(map['displayName'], 'Afonso Dias');
      expect(map['username'], 'afonsod');
      expect(map['bio'], 'Passionate about cinema & quality television.');
      expect(map['avatarId'], 'tv_retro');
      expect(map['avatarType'], 'preset');
      expect(map['profileBannerUrl'], 'https://example.com/banner.jpg');
      expect(map['following'], ['user_1', 'user_2']);
      expect(map['followers'], ['user_3']);
      expect(map['ratingDistribution'], {'10.0': 5, '9.0': 3});

      final restored = FirestoreSyncService.profileFromMap(map);
      expect(restored.displayName, 'Afonso Dias');
      expect(restored.username, 'afonsod');
      expect(restored.bio, 'Passionate about cinema & quality television.');
      expect(restored.avatarId, 'tv_retro');
      expect(restored.avatarType, AvatarType.preset);
      expect(restored.profileBannerUrl, 'https://example.com/banner.jpg');
      expect(restored.following, ['user_1', 'user_2']);
      expect(restored.followers, ['user_3']);
      expect(restored.ratingDistribution['10.0'], 5);
      expect(restored.ratingDistribution['9.0'], 3);
    });

    test('serializes and deserializes favorites and Top 5', () {
      const settings = UserSettings(
        displayName: 'Test',
        username: 'test',
        bio: '',
        avatarId: 'sparkles',
        language: 'pt-PT',
        streamingRegion: 'PT',
        hideSpoilersForUnwatched: true,
        groupSpecialEpisodes: false,
        episodeReleaseReminders: false,
        reminderHour: 20,
        reminderMinute: 0,
        favoriteShowIds: [1396, 76479, 95396, 1399, 94605],
        favoritedShowIds: [1396, 76479, 95396, 1399, 94605, 87108],
      );

      final map = FirestoreSyncService.favoritesToMap(settings);
      expect(map['topFiveFavorites'], [1396, 76479, 95396, 1399, 94605]);
      expect(map['favoritedShowIds'], [1396, 76479, 95396, 1399, 94605, 87108]);

      final (topFive, allFavs) = FirestoreSyncService.favoritesFromMap(map);
      expect(topFive, [1396, 76479, 95396, 1399, 94605]);
      expect(allFavs, [1396, 76479, 95396, 1399, 94605, 87108]);
    });

    test('handles uninitialized Firebase gracefully without crashing', () async {
      final trackingRepo = InMemoryTrackingRepository();
      final settingsRepo = SettingsRepositoryImpl(trackingRepo);
      final syncService = FirestoreSyncService(
        trackingRepo: trackingRepo,
        settingsRepo: settingsRepo,
      );

      // Safe no-ops when Firebase is not initialized
      await syncService.syncUser('test_uid');
      await syncService.syncTrackedShow(
        TrackedShow(
          showId: 1,
          name: 'Show',
          status: TrackingStatus.watching,
          addedAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await syncService.deleteTrackedShow(1);
      await syncService.syncUserProfile(UserSettings.defaultSettings);
      await syncService.syncFavorites(UserSettings.defaultSettings);
      syncService.stopSync();

      expect(syncService.activeUid, isNull);
    });
  });
}
