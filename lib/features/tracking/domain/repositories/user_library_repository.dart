import '../../../shows/domain/entities/show.dart';
import '../../domain/entities/tracking_entities.dart';
import '../../domain/entities/tracking_state.dart';

/// Repository interface for reactive management of a user's series library.
abstract class UserLibraryRepository {
  /// Emits real-time updates of the user's tracked series library.
  Stream<List<TrackedShow>> watchLibrary(String userId);

  /// Emits real-time recalculated statistics (episodes, watch time, series per status).
  Stream<UserStats> watchUserStats(String userId);

  /// Loads the current list of tracked shows for [userId].
  Future<List<TrackedShow>> getLibrary(String userId);

  /// Saves or updates a show in the user's library and cloud storage.
  Future<void> updateShow(
    String userId,
    TrackedShow show, {
    List<WatchedEpisode>? watchedEpisodes,
  });

  /// Automatically updates or adds a show when an episode is marked as watched:
  /// - If the show is not in library: adds as 'watching'
  /// - If the show is in 'watchlist' ('plan_to_watch'): updates to 'watching'
  /// - If all episodes are watched on a finished show: updates to 'completed'
  Future<TrackingStatus> handleEpisodeWatched({
    required String userId,
    required ShowDetails show,
    required int watchedRegularEpisodesCount,
  });

  /// Deletes a show from the user's library and cloud storage.
  Future<void> removeShow(String userId, int showId);
}

