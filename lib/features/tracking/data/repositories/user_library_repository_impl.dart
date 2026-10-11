import '../../domain/entities/tracking_entities.dart';
import '../../domain/entities/tracking_state.dart';
import '../../domain/repositories/tracking_repository.dart';
import '../../domain/repositories/user_library_repository.dart';
import '../services/firestore_sync_service.dart';

/// Implementation of [UserLibraryRepository] combining local persistence
/// with real-time Cloud Firestore syncing under `users/{uid}/library`.
class UserLibraryRepositoryImpl implements UserLibraryRepository {
  UserLibraryRepositoryImpl({
    required this.syncService,
    required this.trackingRepo,
  });

  final FirestoreSyncService syncService;
  final TrackingRepository trackingRepo;

  @override
  Stream<List<TrackedShow>> watchLibrary(String userId) {
    return syncService.streamUserLibrary(userId);
  }

  @override
  Stream<UserStats> watchUserStats(String userId) {
    return syncService.streamUserStats(userId);
  }

  @override
  Future<List<TrackedShow>> getLibrary(String userId) async {
    final snapshot = await trackingRepo.load();
    return snapshot.shows;
  }

  @override
  Future<void> updateShow(
    String userId,
    TrackedShow show, {
    List<WatchedEpisode>? watchedEpisodes,
  }) async {
    await trackingRepo.upsertShow(show);
    if (watchedEpisodes != null && watchedEpisodes.isNotEmpty) {
      await trackingRepo.markWatched(watchedEpisodes);
    }
    await syncService.syncTrackedShow(
      show,
      watchedEpisodes: watchedEpisodes,
      uid: userId,
    );
  }

  @override
  Future<void> removeShow(String userId, int showId) async {
    await trackingRepo.removeShow(showId);
    await syncService.deleteTrackedShow(showId, uid: userId);
  }
}
