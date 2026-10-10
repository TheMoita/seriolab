import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:series_app/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:series_app/features/settings/domain/entities/user_settings.dart';
import 'package:series_app/features/settings/presentation/providers/settings_providers.dart';
import 'package:series_app/features/shows/domain/entities/show.dart';
import 'package:series_app/features/shows/presentation/providers/show_providers.dart';
import 'package:series_app/features/social/data/repositories/social_repository_impl.dart';
import 'package:series_app/features/social/presentation/providers/social_providers.dart';
import 'package:series_app/features/social/presentation/screens/user_profile_screen.dart';
import 'package:series_app/features/social/presentation/widgets/follow_list_sheet.dart';
import 'package:series_app/features/tracking/data/repositories/in_memory_tracking_repository.dart';
import 'package:series_app/features/tracking/presentation/widgets/top_favorites_section.dart';

void main() {
  group('UserSettings Social Fields', () {
    test('following and followers default to empty lists', () {
      const settings = UserSettings.defaultSettings;
      expect(settings.following, isEmpty);
      expect(settings.followers, isEmpty);
      expect(settings.followingCount, 0);
      expect(settings.followersCount, 0);
      expect(settings.isFollowing('user_marta'), isFalse);
    });

    test('copyWith updates following and followers', () {
      final updated = UserSettings.defaultSettings.copyWith(
        following: ['user_marta', 'user_diogo'],
        followers: ['user_beatriz'],
      );
      expect(updated.followingCount, 2);
      expect(updated.followersCount, 1);
      expect(updated.isFollowing('user_marta'), isTrue);
      expect(updated.isFollowing('user_beatriz'), isFalse);
    });

    test('toJson and fromJson preserves social fields', () {
      final initial = UserSettings.defaultSettings.copyWith(
        following: ['user_1', 'user_2'],
        followers: ['user_3'],
      );
      final json = initial.toJson();
      final reconstructed = UserSettings.fromJson(json);

      expect(reconstructed.following, ['user_1', 'user_2']);
      expect(reconstructed.followers, ['user_3']);
      expect(reconstructed.followingCount, 2);
      expect(reconstructed.followersCount, 1);
    });
  });

  group('SocialRepositoryImpl', () {
    late InMemoryTrackingRepository trackingRepo;
    late SettingsRepositoryImpl settingsRepo;
    late SocialRepositoryImpl socialRepo;

    setUp(() {
      trackingRepo = InMemoryTrackingRepository();
      settingsRepo = SettingsRepositoryImpl(trackingRepo);
      socialRepo = SocialRepositoryImpl(
        settingsRepo: settingsRepo,
        trackingRepo: trackingRepo,
      );
    });

    test('getSuggestedUsers returns community profiles when following is empty', () async {
      final suggestions = await socialRepo.getSuggestedUsers();
      expect(suggestions, isNotEmpty);
      expect(suggestions.any((u) => u.username == 'martas'), isTrue);
      expect(suggestions.any((u) => u.username == 'diogof'), isTrue);
    });

    test('followUser and unfollowUser toggle following status and count', () async {
      const targetId = 'user_marta';

      expect(await socialRepo.isFollowing(targetId), isFalse);

      final initialProfile = await socialRepo.getUserProfile(targetId);
      final initialFollowers = initialProfile!.followersCount;

      // Follow
      await socialRepo.followUser(targetId);
      expect(await socialRepo.isFollowing(targetId), isTrue);

      final followedProfile = await socialRepo.getUserProfile(targetId);
      expect(followedProfile!.followersCount, initialFollowers + 1);

      // Verify in settings repo
      final settings = await settingsRepo.getSettings();
      expect(settings.following.contains(targetId), isTrue);

      // Verify following list contains Marta
      final followingList = await socialRepo.getFollowing('me');
      expect(followingList.any((u) => u.id == targetId), isTrue);

      // Unfollow
      await socialRepo.unfollowUser(targetId);
      expect(await socialRepo.isFollowing(targetId), isFalse);

      final unfollowedProfile = await socialRepo.getUserProfile(targetId);
      expect(unfollowedProfile!.followersCount, initialFollowers);

      final settingsAfter = await settingsRepo.getSettings();
      expect(settingsAfter.following.contains(targetId), isFalse);
    });

    test('searchUsers finds matching community members by username or name', () async {
      final byUsername = await socialRepo.searchUsers('diogo');
      expect(byUsername.any((u) => u.username == 'diogof'), isTrue);

      final byName = await socialRepo.searchUsers('Marta');
      expect(byName.any((u) => u.displayName == 'Marta Silva'), isTrue);

      final byAtHandle = await socialRepo.searchUsers('@bealima');
      expect(byAtHandle.any((u) => u.username == 'bealima'), isTrue);

      final empty = await socialRepo.searchUsers('non_existing_xyz_123');
      expect(empty, isEmpty);
    });
  });

  group('Top 5 Clean Posters UI (No Numbering)', () {
    testWidgets('TopFavoritesSection does not display any rank numbers or # badges',
        (tester) async {
      const testShow = ShowDetails(
        id: 1396,
        name: 'Breaking Bad',
        originalName: 'Breaking Bad',
        overview: 'A chemistry teacher diagnosed with cancer...',
        posterUrl: '/breaking_bad.jpg',
        backdropUrl: '/bb_backdrop.jpg',
      );

      final trackingRepo = InMemoryTrackingRepository();
      final settingsRepo = SettingsRepositoryImpl(trackingRepo);
      await settingsRepo.saveSettings(UserSettings.defaultSettings.copyWith(
        favoriteShowIds: [1396],
      ));

      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepo),
          showDetailsProvider(1396).overrideWith((ref) => Future.value(testShow)),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: TopFavoritesSection(favoriteIds: [1396], isEditable: false),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Numbering badges like '#1', '#2', '1', '2' must NOT exist in the Top 5
      expect(find.text('#1'), findsNothing);
      expect(find.text('#2'), findsNothing);
      expect(find.text('#3'), findsNothing);
      expect(find.text('#4'), findsNothing);
      expect(find.text('#5'), findsNothing);

      // Verify header and empty slots
      expect(find.text('TOP 5 FAVORITES'), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsNWidgets(4)); // 4 empty slots
    });
  });

  group('UserProfileScreen and Follow Button Interactions', () {
    testWidgets('UserProfileScreen renders user details, counters, and toggles follow button',
        (tester) async {
      final trackingRepo = InMemoryTrackingRepository();
      final settingsRepo = SettingsRepositoryImpl(trackingRepo);
      final socialRepo = SocialRepositoryImpl(
        settingsRepo: settingsRepo,
        trackingRepo: trackingRepo,
      );

      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepo),
          socialRepositoryProvider.overrideWithValue(socialRepo),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: UserProfileScreen(userId: 'user_marta'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify profile info
      expect(find.text('Marta Silva'), findsOneWidget);
      expect(find.text('@martas'), findsOneWidget);
      expect(find.text('A Seguir'), findsWidgets);
      expect(find.text('Seguidores'), findsWidgets);

      // Initially not following -> Button says "Seguir"
      expect(find.widgetWithText(FilledButton, 'Seguir'), findsOneWidget);

      // Tap "Seguir"
      await tester.tap(find.widgetWithText(FilledButton, 'Seguir'));
      await tester.pumpAndSettle();

      // Button now changes to "A Seguir"
      expect(find.widgetWithText(OutlinedButton, 'A Seguir'), findsOneWidget);
    });

    testWidgets('FollowListSheet displays followers and following tabs',
        (tester) async {
      final trackingRepo = InMemoryTrackingRepository();
      final settingsRepo = SettingsRepositoryImpl(trackingRepo);
      final socialRepo = SocialRepositoryImpl(
        settingsRepo: settingsRepo,
        trackingRepo: trackingRepo,
      );

      // Pre-follow Marta so she appears in the following list
      await socialRepo.followUser('user_marta');

      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepo),
          socialRepositoryProvider.overrideWithValue(socialRepo),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: FollowListSheet(
                userId: 'me',
                username: 'afonsodias',
                initialIndex: 0,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tab bar text
      expect(find.text('A Seguir (1)'), findsOneWidget);
      expect(find.text('Seguidores (0)'), findsOneWidget);

      // Followed user item
      expect(find.text('Marta Silva'), findsOneWidget);
      expect(find.text('@martas'), findsOneWidget);
    });
  });
}
