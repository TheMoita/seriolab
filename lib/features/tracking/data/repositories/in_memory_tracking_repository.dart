import '../../../shows/domain/entities/episode.dart';
import '../../domain/entities/tracking_entities.dart';
import '../../domain/repositories/tracking_repository.dart';

/// Volatile implementation — used in tests and as a fallback if the SQLite
/// database cannot be opened.
class InMemoryTrackingRepository implements TrackingRepository {
  final Map<int, TrackedShow> _shows = {};
  final Map<(int, EpisodeKey), WatchedEpisode> _episodes = {};
  final Map<String, String> _meta = {};

  @override
  Future<TrackingSnapshot> load() async => TrackingSnapshot(
        shows: _shows.values.toList(),
        episodes: _episodes.values.toList(),
      );

  @override
  Future<void> upsertShow(TrackedShow show) async => _shows[show.showId] = show;

  @override
  Future<void> removeShow(int showId) async {
    _shows.remove(showId);
    _episodes.removeWhere((k, _) => k.$1 == showId);
  }

  @override
  Future<void> markWatched(List<WatchedEpisode> episodes) async {
    for (final e in episodes) {
      _episodes[(e.showId, e.key)] = e;
    }
  }

  @override
  Future<void> unmarkWatched(int showId, List<EpisodeKey> keys) async {
    for (final k in keys) {
      _episodes.remove((showId, k));
    }
  }

  @override
  Future<void> unmarkAllWatched(int showId) async {
    _episodes.removeWhere((k, _) => k.$1 == showId);
  }

  @override
  Future<String?> readMeta(String key) async => _meta[key];

  @override
  Future<void> writeMeta(String key, String value) async => _meta[key] = value;
}
