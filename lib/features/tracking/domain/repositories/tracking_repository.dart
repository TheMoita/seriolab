import '../../../shows/domain/entities/episode.dart';
import '../entities/tracking_entities.dart';

/// Local persistence contract for the user's tracking data.
abstract interface class TrackingRepository {
  Future<TrackingSnapshot> load();

  Future<void> upsertShow(TrackedShow show);

  /// Removes the show and all of its watched episodes.
  Future<void> removeShow(int showId);

  Future<void> markWatched(List<WatchedEpisode> episodes);

  Future<void> unmarkWatched(int showId, List<EpisodeKey> keys);

  /// Unmarks all watched episodes for the given show in batch.
  Future<void> unmarkAllWatched(int showId);

  /// Generic key/value flags (e.g. demo data already seeded).
  Future<String?> readMeta(String key);
  Future<void> writeMeta(String key, String value);
}
