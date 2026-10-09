import 'package:flutter_test/flutter_test.dart';
import 'package:series_app/features/shows/domain/entities/episode.dart';
import 'package:series_app/features/shows/domain/entities/show.dart';
import 'package:series_app/features/tracking/domain/entities/tracking_entities.dart';
import 'package:series_app/features/tracking/domain/entities/tracking_state.dart';
import 'package:series_app/features/tracking/presentation/providers/tracking_providers.dart';

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

    test('Letterboxd review and rating fields on WatchedEpisode and TrackedShow', () {
      final logDate = DateTime(2026, 10, 9);
      final episode = WatchedEpisode(
        showId: 100,
        key: const EpisodeKey(1, 1),
        runtime: 45,
        watchedAt: logDate,
        userRating: 4.5,
        reviewText: 'Incrível episódio, reviravolta brilhante!',
        hasSpoilers: true,
        loggedAt: logDate,
      );

      expect(episode.userRating, 4.5);
      expect(episode.reviewText, 'Incrível episódio, reviravolta brilhante!');
      expect(episode.hasSpoilers, isTrue);
      expect(episode.loggedAt, logDate);

      final show = TrackedShow(
        showId: 100,
        name: 'Succession',
        status: TrackingStatus.watching,
        addedAt: logDate,
        updatedAt: logDate,
        overallUserRating: 5.0,
        reviewText: 'Uma obra-prima contemporânea.',
        hasSpoilers: false,
        loggedAt: logDate,
      );

      expect(show.overallUserRating, 5.0);
      expect(show.reviewText, 'Uma obra-prima contemporânea.');
      expect(show.hasSpoilers, isFalse);
      expect(show.loggedAt, logDate);
    });
  });
}
