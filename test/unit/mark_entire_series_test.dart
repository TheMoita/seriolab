import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seriolab/core/di/providers.dart';
import 'package:seriolab/features/shows/data/datasources/mock/mock_show_remote_data_source.dart';
import 'package:seriolab/features/shows/data/repositories/show_repository_impl.dart';
import 'package:seriolab/features/shows/domain/entities/episode.dart';
import 'package:seriolab/features/shows/domain/entities/show.dart';
import 'package:seriolab/features/shows/presentation/screens/show_detail_screen.dart';
import 'package:seriolab/features/tracking/data/repositories/in_memory_tracking_repository.dart';
import 'package:seriolab/features/tracking/domain/entities/tracking_entities.dart';
import 'package:seriolab/features/tracking/presentation/providers/tracking_providers.dart';

void main() {
  group('TrackingController - markEntireSeriesWatched and unwatched', () {
    late InMemoryTrackingRepository inMemoryRepo;
    late ShowRepositoryImpl testRepo;
    late ProviderContainer container;

    setUp(() async {
      inMemoryRepo = InMemoryTrackingRepository();
      testRepo = ShowRepositoryImpl(
        remote: MockShowRemoteDataSource(latency: Duration.zero),
        isUsingMockData: true,
      );
      container = ProviderContainer(
        overrides: [
          trackingRepositoryProvider.overrideWithValue(inMemoryRepo),
          showRepositoryProvider.overrideWithValue(testRepo),
          demoSeedingEnabledProvider.overrideWithValue(false),
        ],
      );
      await container.read(trackingControllerProvider.future);
    });

    tearDown(() {
      container.dispose();
    });

    test('markEntireSeriesWatched marks all episodes as watched and sets status to completed for ended series', () async {
      final controller = container.read(trackingControllerProvider.notifier);
      final showDetails = await testRepo.getShowDetails(1396); // Breaking Bad (Ended)
      expect(showDetails.status, ShowStatus.ended);
      expect(showDetails.totalEpisodeCount, greaterThan(0));

      // Initially no episodes watched
      expect(container.read(trackingControllerProvider).value!.watchedFor(1396), isEmpty);

      // Call with String seriesId as requested in spec
      await controller.markEntireSeriesWatched('1396', showDetails: showDetails);

      final state = container.read(trackingControllerProvider).value!;
      final watchedEpisodes = state.watchedFor(1396);
      expect(watchedEpisodes.length, showDetails.totalEpisodeCount);
      expect(state.watchedRegularCount(1396), showDetails.totalEpisodeCount);
      expect(state.progress(1396), 1.0);
      expect(state.show(1396)?.status, TrackingStatus.completed);

      // Verify stats
      expect(state.stats.episodesWatched, showDetails.totalEpisodeCount);
    });

    test('markEntireSeriesWatched sets status to watching (up-to-date) and NOT completed for returning series', () async {
      final controller = container.read(trackingControllerProvider.notifier);
      final showDetails = await testRepo.getShowDetails(95396); // Severance (Returning)
      expect(showDetails.status, ShowStatus.returning);
      expect(showDetails.status.isFinished, isFalse);

      // Call with int seriesId
      await controller.markEntireSeriesWatched(95396, showDetails: showDetails);

      final state = container.read(trackingControllerProvider).value!;
      expect(state.watchedFor(95396).length, greaterThan(0));
      expect(state.progress(95396), 1.0);
      // Status must be Watching, NOT Completed
      expect(state.show(95396)?.status, TrackingStatus.watching);
    });

    test('markEntireSeriesWatched excludes unaired future episodes', () async {
      final controller = container.read(trackingControllerProvider.notifier);
      final now = DateTime.now();
      const customShow = ShowDetails(
        id: 99999,
        name: 'Future Test Show',
        status: ShowStatus.returning,
        seasons: [
          SeasonSummary(
            seasonNumber: 1,
            name: 'Season 1',
            episodeCount: 2,
          ),
        ],
      );

      final episodes = [
        Episode(
          id: 1,
          showId: 99999,
          seasonNumber: 1,
          episodeNumber: 1,
          name: 'Aired Episode',
          airDate: now.subtract(const Duration(days: 7)),
        ),
        Episode(
          id: 2,
          showId: 99999,
          seasonNumber: 1,
          episodeNumber: 2,
          name: 'Unaired Episode',
          airDate: now.add(const Duration(days: 7)),
        ),
      ];

      await controller.markEntireSeriesWatched(
        99999,
        showDetails: customShow,
        episodes: episodes,
      );

      final state = container.read(trackingControllerProvider).value!;
      final watched = state.watchedFor(99999);
      expect(watched.length, 1);
      expect(watched.containsKey(const EpisodeKey(1, 1)), isTrue);
      expect(watched.containsKey(const EpisodeKey(1, 2)), isFalse);
    });

    test('markEntireSeriesUnwatched unmarks all episodes and resets progress and counters to 0', () async {
      final controller = container.read(trackingControllerProvider.notifier);
      final showDetails = await testRepo.getShowDetails(1396); // Breaking Bad

      // First mark all watched
      await controller.markEntireSeriesWatched('1396', showDetails: showDetails);
      expect(container.read(trackingControllerProvider).value!.watchedRegularCount(1396), greaterThan(0));
      expect(container.read(trackingControllerProvider).value!.show(1396)?.status, TrackingStatus.completed);

      // Now unmark entire series
      await controller.markEntireSeriesUnwatched('1396', showDetails: showDetails);

      final state = container.read(trackingControllerProvider).value!;
      expect(state.watchedFor(1396), isEmpty);
      expect(state.watchedRegularCount(1396), 0);
      expect(state.progress(1396), 0.0);
      // Status reverted from completed to watching
      expect(state.show(1396)?.status, TrackingStatus.watching);
      expect(state.stats.episodesWatched, 0);
    });
  });

  group('ShowDetailScreen - UI options and confirmation dialog', () {
    testWidgets('shows confirmation dialog and marks entire series watched from options menu', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final inMemoryRepo = InMemoryTrackingRepository();
      final testRepo = ShowRepositoryImpl(
        remote: MockShowRemoteDataSource(latency: Duration.zero),
        isUsingMockData: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trackingRepositoryProvider.overrideWithValue(inMemoryRepo),
            showRepositoryProvider.overrideWithValue(testRepo),
            demoSeedingEnabledProvider.overrideWithValue(false),
          ],
          child: const MaterialApp(
            home: ShowDetailScreen(showId: 1396),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Open top app bar PopupMenuButton
      final moreOptionsFinder = find.byIcon(Icons.more_vert_rounded);
      expect(moreOptionsFinder, findsOneWidget);
      await tester.tap(moreOptionsFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Menu should contain "Mark all as watched"
      final markAllWatchedItem = find.widgetWithText(PopupMenuItem<String>, 'Mark all as watched');
      expect(markAllWatchedItem, findsOneWidget);

      // Tap "Mark all as watched" in the popup menu
      await tester.tap(markAllWatchedItem);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Confirmation AlertDialog must appear
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Mark all as watched?'), findsOneWidget);
      // Should mention episode and season counts
      expect(find.textContaining('episodes across'), findsOneWidget);

      // Tap confirm button
      final confirmButton = find.widgetWithText(FilledButton, 'Mark as watched');
      expect(confirmButton, findsOneWidget);
      await tester.tap(confirmButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Dialog should close, SnackBar should appear
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.textContaining('as watched.'), findsOneWidget);

      // Dismiss snackbar or advance time
      await tester.pump(const Duration(seconds: 3));

      // Header progress bar button also updated reactively to "Mark all as unwatched"
      expect(find.widgetWithText(TextButton, 'Mark all as unwatched'), findsOneWidget);

      // Now open PopupMenuButton again
      await tester.tap(moreOptionsFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Since all episodes are watched, menu must now display "Mark all as unwatched"
      final markAllUnwatchedItem = find.widgetWithText(PopupMenuItem<String>, 'Mark all as unwatched');
      expect(markAllUnwatchedItem, findsOneWidget);

      // Tap "Mark all as unwatched"
      await tester.tap(markAllUnwatchedItem);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Confirmation AlertDialog must appear
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Mark all as unwatched?'), findsOneWidget);
      expect(find.textContaining('reset your progress to 0%'), findsOneWidget);

      // Tap confirm button
      final unmarkConfirmButton = find.widgetWithText(FilledButton, 'Unmark all');
      expect(unmarkConfirmButton, findsOneWidget);
      await tester.tap(unmarkConfirmButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // SnackBar shows unmark confirmation
      expect(find.textContaining('Progress reset.'), findsOneWidget);
    });
  });
}
