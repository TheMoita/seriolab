import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seriolab/core/di/providers.dart';
import 'package:seriolab/features/shows/domain/entities/episode.dart';
import 'package:seriolab/features/shows/domain/entities/show.dart';
import 'package:seriolab/features/tracking/data/repositories/in_memory_tracking_repository.dart';
import 'package:seriolab/features/tracking/domain/entities/tracking_entities.dart';
import 'package:seriolab/features/tracking/domain/entities/tracking_state.dart';
import 'package:seriolab/features/tracking/presentation/providers/tracking_providers.dart';
import 'package:seriolab/features/tracking/presentation/widgets/recent_activity_section.dart';

void main() {
  group('WatchedEpisode Recent Activity Ordering and Tie-Breaker', () {
    final fixedTime = DateTime(2026, 10, 11, 12, 0, 0);

    test('orders by watchedAt descending when timestamps differ', () {
      final ep1 = WatchedEpisode(
        showId: 1,
        key: const EpisodeKey(1, 1),
        runtime: 45,
        watchedAt: fixedTime,
      );
      final ep2 = WatchedEpisode(
        showId: 1,
        key: const EpisodeKey(1, 2),
        runtime: 45,
        watchedAt: fixedTime.add(const Duration(hours: 1)),
      );

      final list = [ep1, ep2]..sort(WatchedEpisode.compareForRecentActivity);
      expect(list.first.key.episode, 2);
      expect(list.last.key.episode, 1);
    });

    test(
        'tie-breaker: when watchedAt is identical, orders by seasonNumber descending',
        () {
      final s1e5 = WatchedEpisode(
        showId: 1,
        key: const EpisodeKey(1, 5),
        runtime: 45,
        watchedAt: fixedTime,
      );
      final s2e1 = WatchedEpisode(
        showId: 1,
        key: const EpisodeKey(2, 1),
        runtime: 45,
        watchedAt: fixedTime,
      );

      final list = [s1e5, s2e1]..sort(WatchedEpisode.compareForRecentActivity);
      expect(list.first.key.season, 2);
      expect(list.first.key.episode, 1);
      expect(list.last.key.season, 1);
      expect(list.last.key.episode, 5);
    });

    test(
        'tie-breaker: when watchedAt and seasonNumber are identical, orders by episodeNumber descending',
        () {
      // User marks whole Season 2 (Episodes 1 to 10) at identical timestamp
      final season2Episodes = List.generate(
        10,
        (i) => WatchedEpisode(
          showId: 100,
          key: EpisodeKey(2, i + 1),
          runtime: 50,
          watchedAt: fixedTime,
        ),
      );

      final sorted = List.of(season2Episodes)
        ..sort(WatchedEpisode.compareForRecentActivity);

      // T2E10 must be the first, followed by T2E9 down to T2E1
      expect(sorted.first.key.season, 2);
      expect(sorted.first.key.episode, 10);
      expect(sorted[1].key.episode, 9);
      expect(sorted[2].key.episode, 8);
      expect(sorted.last.key.episode, 1);

      for (var i = 0; i < sorted.length; i++) {
        expect(sorted[i].key.episode, 10 - i);
      }
    });

    test('TrackingState.recentWatchedEpisodes respects 3-level ordering', () {
      final state = TrackingState(
        shows: const {},
        watched: {
          10: {
            const EpisodeKey(1, 1): WatchedEpisode(
              showId: 10,
              key: const EpisodeKey(1, 1),
              runtime: 45,
              watchedAt: fixedTime,
            ),
            const EpisodeKey(1, 2): WatchedEpisode(
              showId: 10,
              key: const EpisodeKey(1, 2),
              runtime: 45,
              watchedAt: fixedTime,
            ),
            const EpisodeKey(2, 1): WatchedEpisode(
              showId: 10,
              key: const EpisodeKey(2, 1),
              runtime: 45,
              watchedAt: fixedTime,
            ),
            const EpisodeKey(2, 2): WatchedEpisode(
              showId: 10,
              key: const EpisodeKey(2, 2),
              runtime: 45,
              watchedAt: fixedTime,
            ),
          },
        },
      );

      final recent = state.recentWatchedEpisodes();
      expect(recent.map((e) => '${e.key.season}x${e.key.episode}').toList(), [
        '2x2',
        '2x1',
        '1x2',
        '1x1',
      ]);
    });
  });

  group('Batch Watch Operations in TrackingController', () {
    late InMemoryTrackingRepository repo;
    late ProviderContainer container;

    setUp(() {
      repo = InMemoryTrackingRepository();
      container = ProviderContainer(
        overrides: [
          trackingRepositoryProvider.overrideWithValue(repo),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test(
        'setEpisodesWatched increments timestamps so latest episode in season is first',
        () async {
      final controller = container.read(trackingControllerProvider.notifier);
      await container.read(trackingControllerProvider.future);

      const dummyShow = ShowDetails(
        id: 42,
        name: 'Breaking Bad',
        episodeRuntime: 47,
      );

      final episodes = List.generate(
        7,
        (i) => Episode(
          id: 1000 + i,
          showId: 42,
          seasonNumber: 1,
          episodeNumber: i + 1,
          name: 'Episode ${i + 1}',
          runtime: 47,
          airDate: DateTime(2008, 1, 20),
        ),
      );

      // Mark whole season 1 as watched in batch
      await controller.setEpisodesWatched(dummyShow, episodes, watched: true);

      final state = container.read(trackingControllerProvider).value!;
      final recent = state.recentWatchedEpisodes();

      // Ensure 7 episodes marked
      expect(recent.length, 7);

      // S1E7 (finale) must strictly be the first episode!
      expect(recent.first.key.season, 1);
      expect(recent.first.key.episode, 7);
      expect(recent[1].key.episode, 6);
      expect(recent.last.key.episode, 1);

      // Verify that timestamps have sequential millisecond offsets
      final ep1 = state.watched[42]![const EpisodeKey(1, 1)]!;
      final ep7 = state.watched[42]![const EpisodeKey(1, 7)]!;
      expect(ep7.watchedAt.isAfter(ep1.watchedAt), isTrue);
    });

    testWidgets(
        'RecentActivitySection displays T2E10 as first card when Season 2 is watched',
        (tester) async {
      final season2Episodes = List.generate(
        10,
        (i) => WatchedEpisode(
          showId: 999,
          key: EpisodeKey(2, i + 1),
          runtime: 50,
          watchedAt: DateTime(2026, 10, 11, 10, 0),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: RecentActivitySection(customEpisodes: season2Episodes),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Recent Activity header is present
      expect(find.text('ATIVIDADE RECENTE'), findsOneWidget);
      expect(find.text('10 recentes'), findsNothing);

      // First badge should be T2 • E10
      final firstBadgeFinder = find.text('T2 • E10');
      expect(firstBadgeFinder, findsOneWidget);
    });
  });
}
