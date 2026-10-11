import '../../../tracking/domain/entities/tracking_state.dart';
import '../entities/schedule_item.dart';

abstract class ScheduleRepository {
  /// Fetches shows the user is currently watching along with their next episode.
  Future<List<CurrentlyWatchingItem>> getCurrentlyWatching(
    TrackingState trackingState,
  );

  /// Fetches upcoming episodes and premieres for followed shows, sorted chronologically.
  Future<List<ComingSoonItem>> getComingSoon(
    TrackingState trackingState, {
    int windowDays = 60,
  });
}
