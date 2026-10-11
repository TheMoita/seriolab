import 'package:flutter/foundation.dart';

import '../../../shows/domain/entities/episode.dart';
import 'tracking_entities.dart';

/// Aggregated user statistics.
@immutable
class UserStats {
  const UserStats({
    required this.episodesWatched,
    required this.minutesWatched,
    required this.showsByStatus,
  });

  final int episodesWatched;
  final int minutesWatched;
  final Map<TrackingStatus, int> showsByStatus;

  double get hoursWatched => minutesWatched / 60;
  double get daysWatched => minutesWatched / 1440;
  int get totalShows => showsByStatus.values.fold(0, (a, b) => a + b);
  int count(TrackingStatus s) => showsByStatus[s] ?? 0;
}

/// Immutable, in-memory view of everything the user tracks.
@immutable
class TrackingState {
  const TrackingState({required this.shows, required this.watched});

  factory TrackingState.fromSnapshot(TrackingSnapshot snapshot) {
    final watched = <int, Map<EpisodeKey, WatchedEpisode>>{};
    for (final e in snapshot.episodes) {
      (watched[e.showId] ??= {})[e.key] = e;
    }
    return TrackingState(
      shows: {for (final s in snapshot.shows) s.showId: s},
      watched: watched,
    );
  }

  static const empty = TrackingState(shows: {}, watched: {});

  final Map<int, TrackedShow> shows;
  final Map<int, Map<EpisodeKey, WatchedEpisode>> watched;

  TrackedShow? show(int showId) => shows[showId];

  /// User's overall rating for the given show.
  double? showRating(int showId) => shows[showId]?.overallUserRating;

  /// User's rating for a specific episode.
  double? episodeRating(int showId, EpisodeKey key) =>
      watched[showId]?[key]?.userRating;

  bool isWatched(int showId, EpisodeKey key) =>
      watched[showId]?.containsKey(key) ?? false;

  Map<EpisodeKey, WatchedEpisode> watchedFor(int showId) =>
      watched[showId] ?? const {};

  /// Watched regular-season episodes (specials are excluded from progress).
  int watchedRegularCount(int showId) =>
      watchedFor(showId).keys.where((k) => !k.isSpecial).length;

  /// 0..1 progress against the aired episode count snapshot.
  double progress(int showId) {
    final total = shows[showId]?.airedEpisodeCount ?? 0;
    if (total <= 0) return 0;
    return (watchedRegularCount(showId) / total).clamp(0.0, 1.0);
  }

  List<TrackedShow> byStatus(TrackingStatus status) =>
      shows.values.where((s) => s.status == status).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  /// Shows whose releases appear in the calendar (everything not dropped).
  List<int> get calendarShowIds => (shows.values
          .where((s) => s.status != TrackingStatus.dropped)
          .map((s) => s.showId)
          .toList()
        ..sort());

  /// Returns watched episodes sorted for Recent Activity:
  /// 1º Criteria: watchedAt (descending — latest first)
  /// 2º Criteria: seasonNumber (descending — latest seasons first)
  /// 3º Criteria: episodeNumber (descending — finale episodes first)
  List<WatchedEpisode> recentWatchedEpisodes({int? limit}) {
    final flattened = <WatchedEpisode>[];
    for (final perShow in watched.values) {
      flattened.addAll(perShow.values);
    }
    flattened.sort(WatchedEpisode.compareForRecentActivity);
    if (limit != null && limit > 0) {
      return flattened.take(limit).toList();
    }
    return flattened;
  }

  UserStats get stats {
    var episodes = 0;
    var minutes = 0;
    for (final perShow in watched.values) {
      for (final e in perShow.values) {
        episodes++;
        minutes += e.runtime;
      }
    }
    final byStatus = {for (final s in TrackingStatus.values) s: 0};
    for (final s in shows.values) {
      byStatus[s.status] = byStatus[s.status]! + 1;
    }
    return UserStats(
      episodesWatched: episodes,
      minutesWatched: minutes,
      showsByStatus: byStatus,
    );
  }

  TrackingState copyWith({
    Map<int, TrackedShow>? shows,
    Map<int, Map<EpisodeKey, WatchedEpisode>>? watched,
  }) =>
      TrackingState(shows: shows ?? this.shows, watched: watched ?? this.watched);
}
