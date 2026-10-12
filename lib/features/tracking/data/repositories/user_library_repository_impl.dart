import '../../../shows/domain/entities/show.dart';
import '../../domain/entities/tracking_entities.dart';
import '../../domain/entities/tracking_state.dart';
import '../../domain/repositories/tracking_repository.dart';
import '../../domain/repositories/user_library_repository.dart';
import '../../presentation/providers/tracking_providers.dart';
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
  Future<TrackingStatus> handleEpisodeWatched({
    required String userId,
    required ShowDetails show,
    required int watchedRegularEpisodesCount,
  }) async {
    final library = await getLibrary(userId);
    final existing = library.where((s) => s.showId == show.id).firstOrNull;
    final nextStatus = TrackingController.nextStatusFor(
      current: existing?.status,
      markedWatched: true,
      watchedRegular: watchedRegularEpisodesCount,
      airedEpisodes: show.airedEpisodeCount,
      showFinished: show.status.isFinished,
      totalEpisodes: show.totalEpisodeCount,
      seriesStatus: show.status,
    );

    final now = DateTime.now();
    final updated = (existing ??
            TrackedShow(
              showId: show.id,
              name: show.name,
              posterUrl: show.posterUrl,
              status: nextStatus,
              airedEpisodeCount: show.airedEpisodeCount,
              episodeRuntime: show.episodeRuntime,
              showStatus: show.status,
              network: show.primaryNetwork,
              addedAt: now,
              updatedAt: now,
            ))
        .copyWith(status: nextStatus, updatedAt: now);

    await updateShow(userId, updated);
    return nextStatus;
  }

  @override
  Future<void> removeShow(String userId, int showId) async {
    await trackingRepo.removeShow(showId);
    await syncService.deleteTrackedShow(showId, uid: userId);
  }
}
