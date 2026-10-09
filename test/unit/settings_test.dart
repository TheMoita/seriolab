import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:series_app/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:series_app/features/settings/domain/entities/user_settings.dart';
import 'package:series_app/features/settings/presentation/providers/settings_providers.dart';
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
      expect(settings.favoriteShowIds.length, 5);
      expect(settings.ratingDistribution.length, 19);
      expect(settings.totalRatingsCount, greaterThan(0));
      expect(settings.averageRating, greaterThan(0.0));
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
      await notifier.removeFavoriteShow(1396);
      expect(directContainer.read(settingsControllerProvider).favoriteShowIds.contains(1396), isFalse);

      await notifier.addFavoriteShow(1396);
      expect(directContainer.read(settingsControllerProvider).favoriteShowIds.contains(1396), isTrue);

      await notifier.reorderFavoriteShows(0, 1);
      expect(directContainer.read(settingsControllerProvider).favoriteShowIds.length, 5);

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
}
