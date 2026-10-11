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

  /// Deletes a show from the user's library and cloud storage.
  Future<void> removeShow(String userId, int showId);
}
