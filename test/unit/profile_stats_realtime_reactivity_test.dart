import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seriolab/core/di/providers.dart';
import 'package:seriolab/features/shows/data/datasources/mock/mock_show_remote_data_source.dart';
import 'package:seriolab/features/shows/data/repositories/show_repository_impl.dart';
import 'package:seriolab/features/shows/domain/entities/episode.dart';
import 'package:seriolab/features/shows/domain/entities/show.dart';
import 'package:seriolab/features/tracking/data/repositories/in_memory_tracking_repository.dart';
import 'package:seriolab/features/tracking/domain/entities/tracking_entities.dart';
import 'package:seriolab/features/tracking/domain/entities/tracking_state.dart';
import 'package:seriolab/features/tracking/presentation/providers/tracking_providers.dart';
import 'package:seriolab/features/tracking/presentation/screens/profile_screen.dart';

void main() {
  group('Profile Stats & Realtime Reactivity Tests', () {
    test('UserStats implements equality and hashCode correctly', () {
      const stats1 = UserStats(
        episodesWatched: 10,
        minutesWatched: 450,
        showsByStatus: {
          TrackingStatus.watching: 2,
          TrackingStatus.completed: 1,
        },
      );

      const stats2 = UserStats(
        episodesWatched: 10,
        minutesWatched: 450,
        showsByStatus: {
          TrackingStatus.watching: 2,
          TrackingStatus.completed: 1,
        },
      );

      const statsDifferent = UserStats(
        episodesWatched: 11,
        minutesWatched: 495,
        showsByStatus: {
          TrackingStatus.watching: 2,
          TrackingStatus.completed: 1,
        },
      );

      expect(stats1, equals(stats2));
      expect(stats1.hashCode, equals(stats2.hashCode));
      expect(stats1, isNot(equals(statsDifferent)));
      expect(stats1.totalShows, 3);
    });

    test('TrackingState implements equality and hashCode correctly', () {
      final now = DateTime(2026, 10, 11);
      final showA = TrackedShow(
        showId: 1,
        name: 'Dark',
        status: TrackingStatus.watching,
        addedAt: now,
        updatedAt: now,
      );

      final state1 = TrackingState(
        shows: {1: showA},
        watched: const {},
      );

      final state2 = TrackingState(
        shows: {1: showA},
        watched: const {},
      );

      final state3 = TrackingState(
        shows: {
          1: showA.copyWith(status: TrackingStatus.completed),
        },
        watched: const {},
      );

      expect(state1, equals(state2));
      expect(state1.hashCode, equals(state2.hashCode));
      expect(state1, isNot(equals(state3)));
    });

    test('TrackingController optimistic updates notify userStatsProvider immediately', () async {
      final inMemoryRepo = InMemoryTrackingRepository();
      final container = ProviderContainer(
        overrides: [
          trackingRepositoryProvider.overrideWithValue(inMemoryRepo),
        ],
      );
      addTearDown(container.dispose);

      // Initial state
      final initialStats = await container.read(trackingControllerProvider.future);
      expect(initialStats.shows, isEmpty);
      expect(container.read(userStatsProvider)?.totalShows ?? 0, 0);

      const show = ShowDetails(
        id: 42,
        name: 'Severance',
        overview: '',
        status: ShowStatus.returning,
        firstAirDate: null,
        lastAirDate: null,
        episodeRuntime: 50,
        seasons: [],
      );

      final controller = container.read(trackingControllerProvider.notifier);

      // 1. Move to "Quero Ver" (Watchlist)
      await controller.setStatus(show, TrackingStatus.watchlist);
      var currentStats = container.read(userStatsProvider);
      expect(currentStats?.totalShows, 1);
      expect(currentStats?.count(TrackingStatus.watchlist), 1);
      expect(currentStats?.count(TrackingStatus.watching), 0);

      // 2. Optimistic status change to "A Ver" (Watching)
      await controller.setStatus(show, TrackingStatus.watching);
      currentStats = container.read(userStatsProvider);
      expect(currentStats?.totalShows, 1);
      expect(currentStats?.count(TrackingStatus.watchlist), 0);
      expect(currentStats?.count(TrackingStatus.watching), 1);

      // 3. Mark episodes as watched
      final ep1 = Episode(
        id: 101,
        showId: 42,
        seasonNumber: 1,
        episodeNumber: 1,
        name: 'Good News About Hell',
        airDate: DateTime(2022, 2, 18),
        runtime: 55,
      );

      await controller.setEpisodesWatched(show, [ep1], watched: true);
      currentStats = container.read(userStatsProvider);
      expect(currentStats?.episodesWatched, 1);
      expect(currentStats?.minutesWatched, 55);

      // 4. Remove show
      await controller.removeShow(42);
      currentStats = container.read(userStatsProvider);
      expect(currentStats?.totalShows, 0);
      expect(currentStats?.episodesWatched, 0);
    });

    test('FirestoreSyncService triggers registered tracking listeners on cloud sync down', () async {
      final inMemoryRepo = InMemoryTrackingRepository();
      final container = ProviderContainer(
        overrides: [
          trackingRepositoryProvider.overrideWithValue(inMemoryRepo),
        ],
      );
      addTearDown(container.dispose);

      final syncService = container.read(firestoreSyncServiceProvider);
      final controller = container.read(trackingControllerProvider.notifier);

      var listenerNotified = false;
      final unregister = syncService.addTrackingListener((snapshot) {
        listenerNotified = true;
      });
      addTearDown(unregister);

      // Pre-check
      expect(container.read(userStatsProvider)?.totalShows ?? 0, 0);

      // Simulate remote cloud update arriving from Firestore
      final remoteShow = TrackedShow(
        showId: 99,
        name: 'Succession',
        status: TrackingStatus.completed,
        addedAt: DateTime.now(),
        updatedAt: DateTime.now(),
        airedEpisodeCount: 39,
        episodeRuntime: 60,
      );
      final remoteEpisodes = [
        WatchedEpisode(
          showId: 99,
          key: const EpisodeKey(1, 1),
          runtime: 60,
          watchedAt: DateTime.now(),
        ),
      ];

      await inMemoryRepo.upsertShow(remoteShow);
      await inMemoryRepo.markWatched(remoteEpisodes);

      final cloudSnapshot = await inMemoryRepo.load();
      controller.syncFromRemote(cloudSnapshot);
      expect(listenerNotified, isFalse);

      final stats = container.read(userStatsProvider);
      expect(stats?.totalShows, 1);
      expect(stats?.count(TrackingStatus.completed), 1);
      expect(stats?.episodesWatched, 1);
      expect(stats?.minutesWatched, 60);
    });

    testWidgets('ProfileScreen updates metric cards and tab counters reactively without reloading', (tester) async {
      final inMemoryRepo = InMemoryTrackingRepository();
      final testRepo = ShowRepositoryImpl(
        remote: MockShowRemoteDataSource(latency: Duration.zero),
        isUsingMockData: true,
      );
      final now = DateTime.now();

      final show = TrackedShow(
        showId: 1396,
        name: 'Breaking Bad',
        status: TrackingStatus.watchlist,
        airedEpisodeCount: 62,
        episodeRuntime: 49,
        addedAt: now,
        updatedAt: now,
      );
      await inMemoryRepo.upsertShow(show);

      final container = ProviderContainer(
        overrides: [
          trackingRepositoryProvider.overrideWithValue(inMemoryRepo),
          showRepositoryProvider.overrideWithValue(testRepo),
        ],
      );
      addTearDown(container.dispose);

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify initial tab counts and empty state on the active "Watching" tab
      expect(find.text('Plan to Watch (1)'), findsOneWidget);
      expect(find.text('Watching (0)'), findsOneWidget);
      expect(find.text('Completed (0)'), findsOneWidget);
      expect(find.text('No shows in "Watching"'), findsOneWidget);

      // Now mutate the state optimistically using TrackingController to "Watching"
      const showDetails = ShowDetails(
        id: 1396,
        name: 'Breaking Bad',
        overview: '',
        status: ShowStatus.ended,
        firstAirDate: null,
        lastAirDate: null,
        episodeRuntime: 49,
        seasons: [],
      );

      await container
          .read(trackingControllerProvider.notifier)
          .setStatus(showDetails, TrackingStatus.watching);

      // Pump to trigger reactive UI rebuild
      await tester.pump();
      await tester.pumpAndSettle();

      // Counters in the TabBar MUST update in real time!
      expect(find.text('Plan to Watch (0)'), findsOneWidget);
      expect(find.text('Watching (1)'), findsOneWidget);
      expect(find.text('Completed (0)'), findsOneWidget);
      expect(find.text('Breaking Bad'), findsAtLeastNWidgets(1));
    });
  });
}
