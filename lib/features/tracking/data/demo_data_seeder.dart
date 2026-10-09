import '../../shows/domain/entities/episode.dart';
import '../../shows/domain/repositories/show_repository.dart';
import '../domain/entities/tracking_entities.dart';
import '../domain/repositories/tracking_repository.dart';

/// Populates a realistic profile on first launch in demo mode so every screen
/// (profile, stats, calendar) is interactive immediately.
class DemoDataSeeder {
  DemoDataSeeder({
    required this.shows,
    required this.tracking,
    DateTime Function()? clock,
  })  : _clock = clock ?? DateTime.now;

  static const String seededFlag = 'demo_seeded_v1';

  final ShowRepository shows;
  final TrackingRepository tracking;
  final DateTime Function() _clock;

  /// Seeds once; returns `true` when data was written.
  Future<bool> seedIfNeeded() async {
    if (await tracking.readMeta(seededFlag) != null) return false;
    final existing = await tracking.load();
    if (existing.shows.isEmpty) {
      await _seed();
    }
    await tracking.writeMeta(seededFlag, _clock().toIso8601String());
    return existing.shows.isEmpty;
  }

  Future<void> _seed() async {
    // showId -> (status, predicate deciding which aired episodes are watched)
    final plan = <int, (TrackingStatus, bool Function(Episode))>{
      1396: (TrackingStatus.completed, (_) => true), // Breaking Bad
      95396: (TrackingStatus.watching, (e) => e.seasonNumber == 1 || (e.seasonNumber == 2 && e.episodeNumber <= 4)), // Severance
      100088: (TrackingStatus.watching, (e) => e.seasonNumber < 3 || e.episodeNumber == 1), // The Last of Us
      209867: (TrackingStatus.watching, (e) => e.seasonNumber == 1 || e.episodeNumber <= 3), // Frieren
      95480: (TrackingStatus.watching, (e) => e.seasonNumber <= 4), // Slow Horses
      97546: (TrackingStatus.watching, (e) => e.seasonNumber <= 3), // Ted Lasso
      94997: (TrackingStatus.watching, (e) => e.seasonNumber <= 2), // House of the Dragon
      95479: (TrackingStatus.watching, (e) => e.seasonNumber == 1), // Jujutsu Kaisen
      126308: (TrackingStatus.watchlist, (_) => false), // Shōgun
      83867: (TrackingStatus.watchlist, (_) => false), // Andor
      70523: (TrackingStatus.dropped, (e) => e.seasonNumber == 1 && e.episodeNumber <= 3), // Dark
    };

    final now = _clock();
    var order = 0;
    for (final entry in plan.entries) {
      final data = await shows.getShowWithEpisodes(entry.key);
      final (status, isWatched) = entry.value;
      final show = data.show;

      await tracking.upsertShow(TrackedShow(
        showId: show.id,
        name: show.name,
        posterUrl: show.posterUrl,
        status: status,
        airedEpisodeCount: show.airedEpisodeCount,
        episodeRuntime: show.episodeRuntime,
        showStatus: show.status,
        network: show.primaryNetwork,
        addedAt: now.subtract(Duration(days: 200 - order)),
        updatedAt: now.subtract(Duration(minutes: order * 7)),
      ));
      order++;

      await tracking.markWatched([
        for (final e in data.episodes)
          if (e.isAiredAt(now) && isWatched(e))
            WatchedEpisode(
              showId: show.id,
              key: e.key,
              runtime: e.runtime ?? show.episodeRuntime,
              watchedAt: (e.airDate ?? now).add(const Duration(days: 1, hours: 21)),
            ),
      ]);
    }
  }
}
