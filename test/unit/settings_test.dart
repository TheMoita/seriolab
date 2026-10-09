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
      expect(settings.hideSpoilersForUnwatched, isTrue);
      expect(settings.groupSpecialEpisodes, isTrue);
      expect(settings.episodeReleaseReminders, isTrue);
      expect(settings.formattedReminderTime, '20:00');
      expect(settings.favoriteShowIds.length, 5);
      expect(settings.ratingDistribution.length, 19);
      expect(settings.totalRatingsCount, greaterThan(0));
      expect(settings.averageRating, greaterThan(0.0));
    });

    test('toJson and fromJson preserves all fields', () {
      const original = UserSettings(
        displayName: 'Test User',
        username: 'tester',
        bio: 'Binge watcher',
        avatarId: 'cyan',
        language: 'en',
        streamingRegion: 'US',
        hideSpoilersForUnwatched: false,
        groupSpecialEpisodes: false,
        episodeReleaseReminders: false,
        reminderHour: 9,
        reminderMinute: 30,
      );

      final json = original.toJson();
      final reconstructed = UserSettings.fromJson(json);

      expect(reconstructed.displayName, original.displayName);
      expect(reconstructed.username, original.username);
      expect(reconstructed.bio, original.bio);
      expect(reconstructed.avatarId, original.avatarId);
      expect(reconstructed.language, original.language);
      expect(reconstructed.streamingRegion, original.streamingRegion);
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
        hideSpoilersForUnwatched: false,
      );

      expect(updated.displayName, 'Novo Nome');
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

      // Test favorites management
      await notifier.removeFavoriteShow(1396);
      expect(directContainer.read(settingsControllerProvider).favoriteShowIds.contains(1396), isFalse);

      await notifier.addFavoriteShow(1396);
      expect(directContainer.read(settingsControllerProvider).favoriteShowIds.contains(1396), isTrue);

      await notifier.reorderFavoriteShows(0, 1);
      expect(directContainer.read(settingsControllerProvider).favoriteShowIds.length, 5);
    });
  });
}
