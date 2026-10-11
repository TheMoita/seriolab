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

void main() {
  group('TrackingState and UserStats', () {
    test('Calculates watch time, episode counts and progress accurately', () {
      final now = DateTime(2026, 10, 9);
      final show1 = TrackedShow(
        showId: 101,
        name: 'Show One',
        status: TrackingStatus.watching,
        airedEpisodeCount: 10,
        episodeRuntime: 50,
        addedAt: now,
        updatedAt: now,
      );

      final episodes = [
        WatchedEpisode(
          showId: 101,
          key: const EpisodeKey(1, 1),
          runtime: 50,
          watchedAt: now,
        ),
        WatchedEpisode(
          showId: 101,
          key: const EpisodeKey(1, 2),
          runtime: 50,
          watchedAt: now,
        ),
      ];

      final snapshot = TrackingSnapshot(
        shows: [show1],
        episodes: episodes,
      );

      final state = TrackingState.fromSnapshot(snapshot);

      expect(state.watchedRegularCount(101), 2);
      expect(state.progress(101), 0.2); // 2 / 10 = 20%
      expect(state.isWatched(101, const EpisodeKey(1, 1)), isTrue);
      expect(state.isWatched(101, const EpisodeKey(1, 3)), isFalse);

      final stats = state.stats;
      expect(stats.episodesWatched, 2);
      expect(stats.minutesWatched, 100);
      expect(stats.hoursWatched, closeTo(1.666, 0.01));
      expect(stats.totalShows, 1);
      expect(stats.count(TrackingStatus.watching), 1);
    });

    test('TrackingController.nextStatusFor computes transitions correctly', () {
      // 1. Marking episode as watched on a watchlist show moves it to watching
      final status1 = TrackingController.nextStatusFor(
        current: TrackingStatus.watchlist,
        markedWatched: true,
        watchedRegular: 1,
        airedEpisodes: 10,
        showFinished: false,
      );
      expect(status1, TrackingStatus.watching);

      // 2. Catching up with an ended show moves it to completed
      final status2 = TrackingController.nextStatusFor(
        current: TrackingStatus.watching,
        markedWatched: true,
        watchedRegular: 10,
        airedEpisodes: 10,
        showFinished: true,
      );
      expect(status2, TrackingStatus.completed);

      // 3. Unmarking an episode on a completed show moves it back to watching
      final status3 = TrackingController.nextStatusFor(
        current: TrackingStatus.completed,
        markedWatched: false,
        watchedRegular: 9,
        airedEpisodes: 10,
        showFinished: true,
      );
      expect(status3, TrackingStatus.watching);
    });

    test('SeasonDetails.averageUserRating computes arithmetic mean of rated episodes', () {
      final ep1 = Episode(
        id: 1,
        showId: 100,
        seasonNumber: 1,
        episodeNumber: 1,
        name: 'Ep 1',
        userRating: 8.0,
      );
      final ep2 = Episode(
        id: 2,
        showId: 100,
        seasonNumber: 1,
        episodeNumber: 2,
        name: 'Ep 2',
        userRating: 9.0,
      );
      final ep3 = Episode(
        id: 3,
        showId: 100,
        seasonNumber: 1,
        episodeNumber: 3,
        name: 'Ep 3',
        userRating: 8.5,
      );
      final ep4 = Episode(
        id: 4,
        showId: 100,
        seasonNumber: 1,
        episodeNumber: 4,
        name: 'Ep 4',
        userRating: null, // Unrated
      );

      final season = SeasonDetails(
        showId: 100,
        seasonNumber: 1,
        name: 'Season 1',
        episodes: [ep1, ep2, ep3, ep4],
      );

      // (8.0 + 9.0 + 8.5) / 3 = 25.5 / 3 = 8.5
      expect(season.averageUserRating, 8.5);
      expect(season.ratedEpisodeCount, 3);

      // Season with 0 rated episodes returns null
      final unratedSeason = SeasonDetails(
        showId: 100,
        seasonNumber: 2,
        name: 'Season 2',
        episodes: [ep4],
      );
      expect(unratedSeason.averageUserRating, isNull);
      expect(unratedSeason.ratedEpisodeCount, 0);
    });

    test('Letterboxd review and 10-star rating fields on WatchedEpisode and TrackedShow', () {
      final logDate = DateTime(2026, 10, 9);
      final episode = WatchedEpisode(
        showId: 100,
        key: const EpisodeKey(1, 1),
        runtime: 45,
        watchedAt: logDate,
        userRating: 8.5,
        reviewText: 'Incrível episódio, reviravolta brilhante!',
        hasSpoilers: true,
        loggedAt: logDate,
      );

      expect(episode.userRating, 8.5);
      expect(episode.reviewText, 'Incrível episódio, reviravolta brilhante!');
      expect(episode.hasSpoilers, isTrue);
      expect(episode.loggedAt, logDate);

      final show = TrackedShow(
        showId: 100,
        name: 'Succession',
        status: TrackingStatus.watching,
        addedAt: logDate,
        updatedAt: logDate,
        overallUserRating: 9.5,
        reviewText: 'Uma obra-prima contemporânea.',
        hasSpoilers: false,
        loggedAt: logDate,
      );

      expect(show.overallUserRating, 9.5);
      expect(show.reviewText, 'Uma obra-prima contemporânea.');
      expect(show.hasSpoilers, isFalse);
      expect(show.loggedAt, logDate);
    });
  });

  group('TrackingController batch episode marking on completed status', () {
    test('marking status as completed marks all episodes watched, updates stats and progress', () async {
      final inMemoryRepo = InMemoryTrackingRepository();
      final testRepo = ShowRepositoryImpl(
        remote: MockShowRemoteDataSource(latency: Duration.zero),
        isUsingMockData: true,
      );

      final container = ProviderContainer(
        overrides: [
          trackingRepositoryProvider.overrideWithValue(inMemoryRepo),
          showRepositoryProvider.overrideWithValue(testRepo),
          demoSeedingEnabledProvider.overrideWithValue(false),
        ],
      );
      addTearDown(container.dispose);

      // Wait for trackingController to build
      await container.read(trackingControllerProvider.future);

      final notifier = container.read(trackingControllerProvider.notifier);
      final showDetails = await testRepo.getShowDetails(1396); // Breaking Bad
      expect(showDetails.totalEpisodeCount, greaterThan(0));

      // Initially no episodes are watched
      expect(container.read(trackingControllerProvider).value!.watchedFor(1396), isEmpty);
      expect(container.read(trackingControllerProvider).value!.stats.episodesWatched, 0);

      // 1. Mark as completed
      final hadUnwatched = await notifier.setStatus(showDetails, TrackingStatus.completed);
      expect(hadUnwatched, isTrue);

      final stateAfter = container.read(trackingControllerProvider).value!;
      final watchedEpisodes = stateAfter.watchedFor(1396);
      expect(watchedEpisodes.length, showDetails.totalEpisodeCount);
      expect(stateAfter.watchedRegularCount(1396), showDetails.totalEpisodeCount);
      expect(stateAfter.progress(1396), 1.0);
      expect(stateAfter.show(1396)?.status, TrackingStatus.completed);

      // Stats should reflect all watched episodes
      final stats = stateAfter.stats;
      expect(stats.episodesWatched, showDetails.totalEpisodeCount);
      expect(stats.minutesWatched, greaterThan(0));
      expect(stats.hoursWatched, greaterThan(0));

      // 2. Marking as completed again returns false (all were already watched)
      final hadUnwatchedSecond = await notifier.setStatus(showDetails, TrackingStatus.completed);
      expect(hadUnwatchedSecond, isFalse);

      // 3. Changing to watching keeps all episodes watched
      await notifier.setStatus(showDetails, TrackingStatus.watching);
      final stateWatching = container.read(trackingControllerProvider).value!;
      expect(stateWatching.show(1396)?.status, TrackingStatus.watching);
      expect(stateWatching.watchedFor(1396).length, showDetails.totalEpisodeCount);
      expect(stateWatching.stats.episodesWatched, showDetails.totalEpisodeCount);

      // 4. Changing to watchlist keeps all episodes watched
      await notifier.setStatus(showDetails, TrackingStatus.watchlist);
      final stateWatchlist = container.read(trackingControllerProvider).value!;
      expect(stateWatchlist.show(1396)?.status, TrackingStatus.watchlist);
      expect(stateWatchlist.watchedFor(1396).length, showDetails.totalEpisodeCount);
    });

    test('setSummaryStatus with completed marks all episodes watched', () async {
      final inMemoryRepo = InMemoryTrackingRepository();
      final testRepo = ShowRepositoryImpl(
        remote: MockShowRemoteDataSource(latency: Duration.zero),
        isUsingMockData: true,
      );

      final container = ProviderContainer(
        overrides: [
          trackingRepositoryProvider.overrideWithValue(inMemoryRepo),
          showRepositoryProvider.overrideWithValue(testRepo),
          demoSeedingEnabledProvider.overrideWithValue(false),
        ],
      );
      addTearDown(container.dispose);

      await container.read(trackingControllerProvider.future);
      final notifier = container.read(trackingControllerProvider.notifier);

      final showWithEpisodes = await testRepo.getShowWithEpisodes(95396); // Severance
      final summary = showWithEpisodes.show.toSummary();

      final hadUnwatched = await notifier.setSummaryStatus(summary, TrackingStatus.completed);
      expect(hadUnwatched, isTrue);

      final state = container.read(trackingControllerProvider).value!;
      expect(state.watchedFor(95396).length, showWithEpisodes.episodes.length);
      expect(state.watchedRegularCount(95396), showWithEpisodes.episodes.length);
      expect(state.progress(95396), 1.0);
      expect(state.show(95396)?.status, TrackingStatus.completed);
    });
  });

  group('Streamlined series status automation and management', () {
    test('nextStatusFor: untracked or watchlist transitions to watching on episode watched', () {
      // 1. Untracked show (current == null) becomes watching when an episode is watched
      expect(
        TrackingController.nextStatusFor(
          current: null,
          markedWatched: true,
          watchedRegular: 1,
          airedEpisodes: 10,
          showFinished: false,
        ),
        TrackingStatus.watching,
      );

      // 2. Watchlist show becomes watching when an episode is watched
      expect(
        TrackingController.nextStatusFor(
          current: TrackingStatus.watchlist,
          markedWatched: true,
          watchedRegular: 1,
          airedEpisodes: 10,
          showFinished: false,
        ),
        TrackingStatus.watching,
      );

      // 3. Watchlist show that finishes all episodes on ended show becomes completed
      expect(
        TrackingController.nextStatusFor(
          current: TrackingStatus.watchlist,
          markedWatched: true,
          watchedRegular: 10,
          airedEpisodes: 10,
          showFinished: true,
          totalEpisodes: 10,
        ),
        TrackingStatus.completed,
      );
    });

    test('End-to-end: 1-tap add to watchlist, auto-watching on episode watched, drop, and remove', () async {
      final inMemoryRepo = InMemoryTrackingRepository();
      final testRepo = ShowRepositoryImpl(
        remote: MockShowRemoteDataSource(latency: Duration.zero),
        isUsingMockData: true,
      );

      final container = ProviderContainer(
        overrides: [
          trackingRepositoryProvider.overrideWithValue(inMemoryRepo),
          showRepositoryProvider.overrideWithValue(testRepo),
          demoSeedingEnabledProvider.overrideWithValue(false),
        ],
      );
      addTearDown(container.dispose);

      await container.read(trackingControllerProvider.future);
      final notifier = container.read(trackingControllerProvider.notifier);

      final showWithEpisodes = await testRepo.getShowWithEpisodes(95396); // Severance
      final showDetails = showWithEpisodes.show;
      final summary = showDetails.toSummary();

      final firstEpisode = showWithEpisodes.episodes.first;

      // 1. Single tap add: sets status to watchlist
      await notifier.setSummaryStatus(summary, TrackingStatus.watchlist);
      var state = container.read(trackingControllerProvider).value!;
      expect(state.show(showDetails.id)?.status, TrackingStatus.watchlist);
      expect(state.isWatched(showDetails.id, firstEpisode.key), isFalse);

      // 2. Mark episode watched: automatically moves from watchlist to watching
      await notifier.toggleEpisode(showDetails, firstEpisode);
      state = container.read(trackingControllerProvider).value!;
      expect(state.show(showDetails.id)?.status, TrackingStatus.watching);
      expect(state.isWatched(showDetails.id, firstEpisode.key), isTrue);

      // 3. Mark as dropped (abandonada / pausa)
      await notifier.setStatus(showDetails, TrackingStatus.dropped);
      state = container.read(trackingControllerProvider).value!;
      expect(state.show(showDetails.id)?.status, TrackingStatus.dropped);

      // 4. Remove show: completely removes show and its watched episodes
      await notifier.removeShow(showDetails.id);
      state = container.read(trackingControllerProvider).value!;
      expect(state.show(showDetails.id), isNull);
      expect(state.watchedFor(showDetails.id), isEmpty);
    });
  });
}

