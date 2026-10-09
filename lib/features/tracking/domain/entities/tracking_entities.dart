import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color, IconData, Icons;

import '../../../shows/domain/entities/episode.dart';

/// Personal list a show belongs to.
enum TrackingStatus {
  watching('A ver', Icons.play_circle_fill_rounded),
  watchlist('Quero ver', Icons.bookmark_rounded),
  completed('Terminadas', Icons.check_circle_rounded),
  dropped('Abandonadas', Icons.do_not_disturb_on_rounded);

  const TrackingStatus(this.label, this.icon);

  final String label;
  final IconData icon;

  Color get color => switch (this) {
        watching => const Color(0xFF7C5CFC), // Primary iris/violet
        watchlist => const Color(0xFF38BDF8), // Vibrant cyan
        completed => const Color(0xFF10B981), // Emerald
        dropped => const Color(0xFFEF4444), // Crimson
      };

  /// Singular label used on buttons ("Terminada" instead of "Terminadas").
  String get actionLabel => switch (this) {
        watching => 'A ver',
        watchlist => 'Quero ver',
        completed => 'Terminada',
        dropped => 'Abandonada',
      };

  static TrackingStatus fromName(String name) =>
      values.firstWhere((s) => s.name == name, orElse: () => watchlist);
}

/// Snapshot of a followed show, persisted locally so the profile/stats work
/// fully offline.
@immutable
class TrackedShow {
  const TrackedShow({
    required this.showId,
    required this.name,
    required this.status,
    required this.addedAt,
    required this.updatedAt,
    this.posterUrl,
    this.airedEpisodeCount = 0,
    this.episodeRuntime = 0,
    this.showStatus = ShowStatus.unknown,
    this.network,
    this.overallUserRating,
  });

  final int showId;
  final String name;
  final String? posterUrl;
  final TrackingStatus status;
  final int airedEpisodeCount;
  final int episodeRuntime;
  final ShowStatus showStatus;
  final String? network;
  final DateTime addedAt;
  final DateTime updatedAt;
  final double? overallUserRating;

  TrackedShow copyWith({
    String? name,
    String? posterUrl,
    TrackingStatus? status,
    int? airedEpisodeCount,
    int? episodeRuntime,
    ShowStatus? showStatus,
    String? network,
    DateTime? updatedAt,
    double? overallUserRating,
    bool clearOverallUserRating = false,
  }) =>
      TrackedShow(
        showId: showId,
        name: name ?? this.name,
        posterUrl: posterUrl ?? this.posterUrl,
        status: status ?? this.status,
        airedEpisodeCount: airedEpisodeCount ?? this.airedEpisodeCount,
        episodeRuntime: episodeRuntime ?? this.episodeRuntime,
        showStatus: showStatus ?? this.showStatus,
        network: network ?? this.network,
        addedAt: addedAt,
        updatedAt: updatedAt ?? this.updatedAt,
        overallUserRating: clearOverallUserRating
            ? null
            : (overallUserRating ?? this.overallUserRating),
      );
}

@immutable
class WatchedEpisode {
  const WatchedEpisode({
    required this.showId,
    required this.key,
    required this.runtime,
    required this.watchedAt,
    this.userRating,
  });

  final int showId;
  final EpisodeKey key;

  /// Minutes, used for watch-time statistics.
  final int runtime;
  final DateTime watchedAt;

  /// User rating given to this episode (1.0 to 10.0, step 0.5).
  final double? userRating;

  WatchedEpisode copyWith({
    int? showId,
    EpisodeKey? key,
    int? runtime,
    DateTime? watchedAt,
    double? userRating,
    bool clearUserRating = false,
  }) =>
      WatchedEpisode(
        showId: showId ?? this.showId,
        key: key ?? this.key,
        runtime: runtime ?? this.runtime,
        watchedAt: watchedAt ?? this.watchedAt,
        userRating: clearUserRating ? null : (userRating ?? this.userRating),
      );
}

/// Raw persisted data returned by the tracking repository.
@immutable
class TrackingSnapshot {
  const TrackingSnapshot({required this.shows, required this.episodes});

  final List<TrackedShow> shows;
  final List<WatchedEpisode> episodes;

  static const empty = TrackingSnapshot(shows: [], episodes: []);
}
