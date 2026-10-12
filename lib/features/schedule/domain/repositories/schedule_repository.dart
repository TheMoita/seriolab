import '../../../tracking/domain/entities/tracking_state.dart';
import '../entities/schedule_item.dart';

abstract class ScheduleRepository {
  /// Fetches shows the user is currently watching along with their next episode.
  Future<List<CurrentlyWatchingItem>> getCurrentlyWatching(
    TrackingState trackingState,
  );

  /// Fetches shows the user is actively watching (status: watching) with their next pending episode.
  Future<List<CurrentlyWatchingItem>> getUpNext(
    TrackingState trackingState,
  );

  /// Fetches shows in library not started yet (status: watchlist/plan_to_watch with 0 episodes watched).
  Future<List<CurrentlyWatchingItem>> getStartWatching(
    TrackingState trackingState,
  );

  /// Fetches shows marked as dropped/on-hold to easily resume.
  Future<List<CurrentlyWatchingItem>> getResume(
    TrackingState trackingState,
  );

  /// Fetches upcoming episodes and premieres for followed shows, sorted chronologically.
  Future<List<ComingSoonItem>> getComingSoon(
    TrackingState trackingState, {
    int windowDays = 60,
  });
}
