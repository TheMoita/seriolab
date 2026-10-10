import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:series_app/core/di/providers.dart';
import 'package:series_app/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:series_app/features/settings/data/repositories/user_profile_repository_impl.dart';
import 'package:series_app/features/settings/domain/entities/user_settings.dart';
import 'package:series_app/features/settings/presentation/providers/settings_providers.dart';
import 'package:series_app/features/shows/domain/entities/episode.dart';
import 'package:series_app/features/shows/domain/entities/show.dart';
import 'package:series_app/features/tracking/data/repositories/in_memory_tracking_repository.dart';

void main() {
  group('UserSettings Entity', () {
    test('defaultSettings has expected defaults', () {
      const settings = UserSettings.defaultSettings;
      expect(settings.displayName, 'Afonso Dias');
      expect(settings.username, 'afonsodias');
      expect(settings.language, 'pt');
      expect(settings.streamingRegion, 'PT');
      expect(settings.showOriginalTitles, isFalse);
      expect(settings.tmdbLanguageCode, 'pt-PT');
      expect(settings.hideSpoilersForUnwatched, isTrue);
      expect(settings.groupSpecialEpisodes, isTrue);
      expect(settings.episodeReleaseReminders, isTrue);
      expect(settings.formattedReminderTime, '20:00');
      expect(settings.favoriteShowIds, isEmpty);
      expect(settings.ratingDistribution.length, 20);
      expect(settings.totalRatingsCount, 0);
      expect(settings.averageRating, 0.0);
    });

    test('tmdbLanguageCode maps properly for regions and languages', () {
      final ptBr = UserSettings.defaultSettings.copyWith(
        language: 'pt',
        streamingRegion: 'BR',
      );
      expect(ptBr.tmdbLanguageCode, 'pt-BR');

      final en = UserSettings.defaultSettings.copyWith(
        language: 'en',
      );
      expect(en.tmdbLanguageCode, 'en-US');

      final es = UserSettings.defaultSettings.copyWith(
        language: 'es',
      );
      expect(es.tmdbLanguageCode, 'es-ES');
    });

    test('toJson and fromJson preserves all fields', () {
      const original = UserSettings(
        displayName: 'Test User',
        username: 'tester',
        bio: 'Binge watcher',
        avatarId: 'cyan',
        language: 'en',
        streamingRegion: 'US',
        showOriginalTitles: true,
        hideSpoilersForUnwatched: false,
        groupSpecialEpisodes: false,
        episodeReleaseReminders: false,
        reminderHour: 9,
        reminderMinute: 30,
        profileBannerUrl: 'https://image.tmdb.org/t/p/w1280/wallpaper.jpg',
        profileBannerPath: '/storage/banner.jpg',
      );

      final json = original.toJson();
      final reconstructed = UserSettings.fromJson(json);

      expect(reconstructed.displayName, original.displayName);
      expect(reconstructed.username, original.username);
      expect(reconstructed.bio, original.bio);
      expect(reconstructed.avatarId, original.avatarId);
      expect(reconstructed.profileBannerUrl, 'https://image.tmdb.org/t/p/w1280/wallpaper.jpg');
      expect(reconstructed.profileBannerPath, '/storage/banner.jpg');
      expect(reconstructed.language, original.language);
      expect(reconstructed.streamingRegion, original.streamingRegion);
      expect(reconstructed.showOriginalTitles, isTrue);
      expect(reconstructed.hideSpoilersForUnwatched, isFalse);
      expect(reconstructed.groupSpecialEpisodes, isFalse);
      expect(reconstructed.episodeReleaseReminders, isFalse);
      expect(reconstructed.reminderHour, 9);
      expect(reconstructed.reminderMinute, 30);
      expect(reconstructed.formattedReminderTime, '09:30');
    });

    test('copyWith updates specified fields only', () {
      const initial = UserSettings.defaultSettings;
      final updated = initial.copyWith(
        displayName: 'Novo Nome',
        showOriginalTitles: true,
        hideSpoilersForUnwatched: false,
      );

      expect(updated.displayName, 'Novo Nome');
      expect(updated.showOriginalTitles, isTrue);
      expect(updated.hideSpoilersForUnwatched, isFalse);
      expect(updated.username, initial.username);
      expect(updated.language, initial.language);
    });

    test('SeriolabAvatar.getById falls back gracefully', () {
      final avatar = SeriolabAvatar.getById('non_existent');
      expect(avatar.id, SeriolabAvatar.presets.first.id);

      final iris = SeriolabAvatar.getById('iris');
      expect(iris.id, 'iris');
    });

    test('AvatarType fromString and serialization work properly', () {
      expect(AvatarType.fromString('preset'), AvatarType.preset);
      expect(AvatarType.fromString('localFile'), AvatarType.localFile);
      expect(AvatarType.fromString('networkUrl'), AvatarType.networkUrl);
      expect(AvatarType.fromString(null), AvatarType.preset);
      expect(AvatarType.fromString('invalid'), AvatarType.preset);

      // Serialization with networkUrl
      final networkSettings = UserSettings.defaultSettings.copyWith(
        avatarType: AvatarType.networkUrl,
        avatarValue: 'https://image.tmdb.org/t/p/w500/test.jpg',
      );
      final jsonNet = networkSettings.toJson();
      expect(jsonNet['avatarType'], 'networkUrl');
      expect(jsonNet['avatarValue'], 'https://image.tmdb.org/t/p/w500/test.jpg');

      final reloadedNet = UserSettings.fromJson(jsonNet);
      expect(reloadedNet.avatarType, AvatarType.networkUrl);
      expect(reloadedNet.avatarValue, 'https://image.tmdb.org/t/p/w500/test.jpg');
      expect(reloadedNet.effectiveAvatarValue, 'https://image.tmdb.org/t/p/w500/test.jpg');

      // Serialization with localFile
      final localSettings = UserSettings.defaultSettings.copyWith(
        avatarType: AvatarType.localFile,
        avatarValue: '/data/user/0/avatar.jpg',
      );
      final jsonLocal = localSettings.toJson();
      final reloadedLocal = UserSettings.fromJson(jsonLocal);
      expect(reloadedLocal.avatarType, AvatarType.localFile);
      expect(reloadedLocal.avatarValue, '/data/user/0/avatar.jpg');
    });
  });

  group('SettingsRepositoryImpl', () {
    test('persists and retrieves settings via TrackingRepository metadata',
        () async {
      final trackingRepo = InMemoryTrackingRepository();
      final settingsRepo = SettingsRepositoryImpl(trackingRepo);

      // Default before save
      final initial = await settingsRepo.getSettings();
      expect(initial.displayName, UserSettings.defaultSettings.displayName);

      // Save custom settings
      const custom = UserSettings(
        displayName: 'Maria Santos',
        username: 'mariastv',
        bio: 'Adoro drama e comédia.',
        avatarId: 'rose',
        language: 'es',
        streamingRegion: 'BR',
        hideSpoilersForUnwatched: false,
        groupSpecialEpisodes: true,
        episodeReleaseReminders: true,
        reminderHour: 21,
        reminderMinute: 15,
      );
      await settingsRepo.saveSettings(custom);

      // Retrieve again
      final reloaded = await settingsRepo.getSettings();
      expect(reloaded.displayName, 'Maria Santos');
      expect(reloaded.username, 'mariastv');
      expect(reloaded.language, 'es');
      expect(reloaded.streamingRegion, 'BR');
      expect(reloaded.formattedReminderTime, '21:15');
    });
  });

  group('SettingsNotifier in Riverpod container', () {
    test('notifies state updates and persists them', () async {
      final trackingRepo = InMemoryTrackingRepository();
      final directContainer = ProviderContainer(
        overrides: [
          settingsRepositoryProvider
              .overrideWithValue(SettingsRepositoryImpl(trackingRepo)),
        ],
      );
      addTearDown(directContainer.dispose);

      final notifier = directContainer.read(settingsControllerProvider.notifier);
      await notifier.setLanguage('en');
      expect(directContainer.read(settingsControllerProvider).language, 'en');

      await notifier.setHideSpoilers(false);
      expect(
        directContainer.read(settingsControllerProvider).hideSpoilersForUnwatched,
        isFalse,
      );

      await notifier.setShowOriginalTitles(true);
      expect(
        directContainer.read(settingsControllerProvider).showOriginalTitles,
        isTrue,
      );

      await notifier.updateProfile(
        displayName: 'Carlos Silva',
        username: 'carlos',
        bio: 'Sci-fi only',
        avatarId: 'cosmic',
      );
      final current = directContainer.read(settingsControllerProvider);
      expect(current.displayName, 'Carlos Silva');
      expect(current.username, 'carlos');
      expect(current.avatarId, 'cosmic');

      // Test avatar change
      await notifier.setAvatar('retro_tv');
      expect(directContainer.read(settingsControllerProvider).avatarId, 'retro_tv');
      expect(directContainer.read(settingsControllerProvider).avatarType, AvatarType.preset);

      await notifier.setAvatarPreset('iris');
      expect(directContainer.read(settingsControllerProvider).avatarId, 'iris');
      expect(directContainer.read(settingsControllerProvider).avatarType, AvatarType.preset);

      await notifier.setAvatarNetworkUrl('https://image.tmdb.org/t/p/w500/series.jpg');
      expect(directContainer.read(settingsControllerProvider).avatarType, AvatarType.networkUrl);
      expect(directContainer.read(settingsControllerProvider).avatarValue, 'https://image.tmdb.org/t/p/w500/series.jpg');

      await notifier.setAvatarLocalFile('/path/to/my_photo.jpg');
      expect(directContainer.read(settingsControllerProvider).avatarType, AvatarType.localFile);
      expect(directContainer.read(settingsControllerProvider).avatarValue, '/path/to/my_photo.jpg');

      // Test favorites management
      expect(directContainer.read(settingsControllerProvider).favoriteShowIds, isEmpty);
      await notifier.addFavoriteShow(1396);
      expect(directContainer.read(settingsControllerProvider).favoriteShowIds.contains(1396), isTrue);
      expect(directContainer.read(settingsControllerProvider).favoriteShowIds.length, 1);

      await notifier.removeFavoriteShow(1396);
      expect(directContainer.read(settingsControllerProvider).favoriteShowIds.contains(1396), isFalse);
      expect(directContainer.read(settingsControllerProvider).favoriteShowIds, isEmpty);

      // Test banner management
      await notifier.setProfileBannerUrl('https://image.tmdb.org/t/p/w1280/backdrop.jpg');
      expect(
        directContainer.read(settingsControllerProvider).profileBannerUrl,
        'https://image.tmdb.org/t/p/w1280/backdrop.jpg',
      );
      expect(
        directContainer.read(settingsControllerProvider).profileBannerPath,
        isNull,
      );
      expect(
        directContainer.read(settingsControllerProvider).hasCustomBanner,
        isTrue,
      );

      await notifier.setProfileBannerPath('/local/storage/my_banner.png');
      expect(
        directContainer.read(settingsControllerProvider).profileBannerPath,
        '/local/storage/my_banner.png',
      );
      expect(
        directContainer.read(settingsControllerProvider).profileBannerUrl,
        isNull,
      );

      await notifier.clearProfileBanner();
      expect(
        directContainer.read(settingsControllerProvider).profileBannerUrl,
        isNull,
      );
      expect(
        directContainer.read(settingsControllerProvider).profileBannerPath,
        isNull,
      );
      expect(
        directContainer.read(settingsControllerProvider).hasCustomBanner,
        isFalse,
      );
    });
  });

  group('UserProfileRepository and Top 5 selection', () {
    const show1 = ShowDetails(
      id: 1399,
      name: 'Game of Thrones',
      overview: 'Winter is coming',
      tagline: 'You win or you die',
      genres: [],
      rating: 8.4,
      voteCount: 20000,
      popularity: 100.0,
      status: ShowStatus.ended,
      networks: ['HBO'],
      firstAirDate: null,
      lastAirDate: null,
      episodeRuntime: 60,
      seasons: [],
      cast: [],
      originalLanguage: 'en',
      originCountries: ['US'],
    );

    const show2 = ShowDetails(
      id: 1396,
      name: 'Breaking Bad',
      overview: 'Chemistry teacher',
      tagline: 'Change the equation',
      genres: [],
      rating: 8.9,
      voteCount: 25000,
      popularity: 120.0,
      status: ShowStatus.ended,
      networks: ['AMC'],
      firstAirDate: null,
      lastAirDate: null,
      episodeRuntime: 47,
      seasons: [],
      cast: [],
      originalLanguage: 'en',
      originCountries: ['US'],
    );

    const show3 = ShowDetails(
      id: 66732,
      name: 'Stranger Things',
      overview: 'Upside Down',
      tagline: 'Every ending has a beginning',
      genres: [],
      rating: 8.6,
      voteCount: 18000,
      popularity: 95.0,
      status: ShowStatus.returning,
      networks: ['Netflix'],
      firstAirDate: null,
      lastAirDate: null,
      episodeRuntime: 50,
      seasons: [],
      cast: [],
      originalLanguage: 'en',
      originCountries: ['US'],
    );

    test('UserProfileRepositoryImpl manages favorites and Top 5 slots', () async {
      final trackingRepo = InMemoryTrackingRepository();
      final settingsRepo = SettingsRepositoryImpl(trackingRepo);
      final profileRepo = UserProfileRepositoryImpl(settingsRepo);

      // Initially empty
      var settings = await settingsRepo.getSettings();
      expect(settings.favoritedShowIds, isEmpty);
      expect(settings.favoriteShowIds, isEmpty);
      expect(settings.topFiveFavorites, isEmpty);

      // Toggle favorite
      await profileRepo.toggleFavorite(show1);
      settings = await settingsRepo.getSettings();
      expect(settings.isFavorite(show1.id), isTrue);
      expect(settings.favoritedShowIds.contains(show1.id), isTrue);

      await profileRepo.toggleFavorite(show1);
      settings = await settingsRepo.getSettings();
      expect(settings.isFavorite(show1.id), isFalse);
      expect(settings.favoritedShowIds, isEmpty);

      // Set Top 5 slots
      await profileRepo.setTopFiveSlot(0, show1);
      await profileRepo.setTopFiveSlot(1, show2);
      await profileRepo.setTopFiveSlot(2, show3);
      settings = await settingsRepo.getSettings();
      expect(settings.favoriteShowIds, [1399, 1396, 66732]);

      // Reorder Top 5
      await profileRepo.reorderTopFive(0, 2);
      settings = await settingsRepo.getSettings();
      expect(settings.favoriteShowIds, [1396, 66732, 1399]);

      // Remove slot
      await profileRepo.removeTopFiveSlot(1);
      settings = await settingsRepo.getSettings();
      expect(settings.favoriteShowIds, [1396, 1399]);
    });

    test('SettingsNotifier toggleFavorite and Top 5 slot methods work in Riverpod', () async {
      final trackingRepo = InMemoryTrackingRepository();
      final container = ProviderContainer(
        overrides: [
          trackingRepositoryProvider.overrideWithValue(trackingRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(settingsControllerProvider.notifier);

      // Toggle favorite
      final res1 = await notifier.toggleFavorite(show1);
      expect(res1, isTrue);
      expect(container.read(settingsControllerProvider).isFavorite(show1.id), isTrue);

      final res2 = await notifier.toggleFavorite(show1);
      expect(res2, isFalse);
      expect(container.read(settingsControllerProvider).isFavorite(show1.id), isFalse);

      // Set Top 5 slot
      await notifier.setTopFiveSlot(0, show1);
      await notifier.setTopFiveSlot(1, show2);
      expect(container.read(settingsControllerProvider).favoriteShowIds, [1399, 1396]);

      // Move show1 from slot 0 to slot 1 (replacement / move)
      await notifier.setTopFiveSlot(1, show1);
      expect(container.read(settingsControllerProvider).favoriteShowIds.contains(1399), isTrue);

      // Remove slot
      await notifier.removeTopFiveSlot(0);
      expect(container.read(settingsControllerProvider).favoriteShowIds.length, lessThanOrEqualTo(1));
    });
  });
}
