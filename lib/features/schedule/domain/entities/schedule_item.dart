import 'package:flutter/foundation.dart';

import 'package:seriolab/core/utils/formatters.dart';
import 'package:seriolab/features/shows/domain/entities/episode.dart';
import 'package:seriolab/features/shows/domain/entities/show.dart';
import 'package:seriolab/features/tracking/domain/entities/tracking_entities.dart';

/// Represents a show the user is actively watching with its next episode state.
@immutable
class CurrentlyWatchingItem {
  const CurrentlyWatchingItem({
    required this.trackedShow,
    this.showDetails,
    this.nextEpisode,
    this.isAired = false,
    this.isCaughtUp = false,
  });

  final TrackedShow trackedShow;
  final ShowDetails? showDetails;
  final Episode? nextEpisode;
  final bool isAired;
  final bool isCaughtUp;

  int get showId => trackedShow.showId;
  String get showName => trackedShow.name;
  String? get posterUrl => trackedShow.posterUrl ?? showDetails?.posterUrl;
  String? get backdropUrl => showDetails?.backdropUrl;
  String? get network => trackedShow.network ?? showDetails?.primaryNetwork;

  /// Episode identifier, e.g. "S2 • E4"
  String get episodeIdentifier {
    if (nextEpisode == null) return '';
    return 'S${nextEpisode!.seasonNumber} • E${nextEpisode!.episodeNumber}';
  }

  String get episodeTitle => nextEpisode?.name ?? '';
}

/// Represents an upcoming episode or season premiere scheduled for the future.
@immutable
class ComingSoonItem {
  const ComingSoonItem({
    required this.showId,
    required this.showName,
    required this.airDate,
    required this.seasonNumber,
    this.episodeNumber,
    this.episodeTitle = '',
    this.posterUrl,
    this.backdropUrl,
    this.network,
    this.episode,
    this.isSeasonPremiere = false,
    this.showDetails,
  });

  factory ComingSoonItem.fromUpcomingEpisode(
    UpcomingEpisode item, {
    ShowDetails? show,
  }) {
    return ComingSoonItem(
      showId: item.showId,
      showName: item.showName,
      airDate: item.episode.airDate ?? DateTime.now(),
      seasonNumber: item.episode.seasonNumber,
      episodeNumber: item.episode.episodeNumber,
      episodeTitle: item.episode.name,
      posterUrl: item.posterUrl,
      backdropUrl: item.backdropUrl ?? show?.backdropUrl,
      network: item.network ?? show?.primaryNetwork,
      episode: item.episode,
      isSeasonPremiere: item.isSeasonPremiere,
      showDetails: show,
    );
  }

  final int showId;
  final String showName;
  final DateTime airDate;
  final int seasonNumber;
  final int? episodeNumber;
  final String episodeTitle;
  final String? posterUrl;
  final String? backdropUrl;
  final String? network;
  final Episode? episode;
  final bool isSeasonPremiere;
  final ShowDetails? showDetails;

  /// Episode identifier, e.g. "S2 • E4" or "Season 3"
  String get episodeIdentifier {
    if (episodeNumber != null) {
      return 'S$seasonNumber • E$episodeNumber';
    }
    return 'Season $seasonNumber';
  }

  /// Whether this release date has arrived today (allowing quick mark as watched).
  bool get isAiredToday {
    final today = Formatters.dateOnly(DateTime.now());
    final releaseDate = Formatters.dateOnly(airDate);
    return !releaseDate.isAfter(today);
  }
}
