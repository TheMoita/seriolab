import 'package:flutter/foundation.dart';

import '../../data/models/tmdb_mapper.dart';

/// Production status of a TV show.
enum ShowStatus {
  returning('Em exibição', 'Returning Series'),
  inProduction('Em produção', 'In Production'),
  planned('Planeada', 'Planned'),
  ended('Terminada', 'Ended'),
  canceled('Cancelada', 'Canceled'),
  unknown('Desconhecido', '');

  const ShowStatus(this.label, this.tmdbValue);

  final String label;
  final String tmdbValue;

  /// Whether no more episodes are expected.
  bool get isFinished => this == ended || this == canceled;

  static ShowStatus fromTmdb(String? value) {
    for (final s in values) {
      if (s.tmdbValue == value && s != unknown) return s;
    }
    return unknown;
  }

  static ShowStatus fromName(String? name) =>
      values.firstWhere((s) => s.name == name, orElse: () => unknown);
}

/// Identifies an episode inside a show.
@immutable
class EpisodeKey implements Comparable<EpisodeKey> {
  const EpisodeKey(this.season, this.episode);

  final int season;
  final int episode;

  bool get isSpecial => season == 0;

  @override
  int compareTo(EpisodeKey other) => season != other.season
      ? season.compareTo(other.season)
      : episode.compareTo(other.episode);

  @override
  bool operator ==(Object other) =>
      other is EpisodeKey && other.season == season && other.episode == episode;

  @override
  int get hashCode => Object.hash(season, episode);

  @override
  String toString() => episodeCode(season, episode);
}

String episodeCode(int season, int episode) =>
    'S${season.toString().padLeft(2, '0')}E${episode.toString().padLeft(2, '0')}';

@immutable
class Episode {
  const Episode({
    required this.id,
    required this.showId,
    required this.seasonNumber,
    required this.episodeNumber,
    required this.name,
    this.overview = '',
    this.airDate,
    this.runtime,
    this.stillUrl,
    this.rating = 0,
    this.userRating,
  });

  final int id;
  final int showId;
  final int seasonNumber;
  final int episodeNumber;
  final String name;
  final String overview;

  /// Date-only air date (local), `null` when still to be announced.
  final DateTime? airDate;
  final int? runtime;
  final String? stillUrl;
  final double rating;

  /// Optional rating given by the user (1.0 to 10.0, step 0.5).
  final double? userRating;

  EpisodeKey get key => EpisodeKey(seasonNumber, episodeNumber);
  String get code => episodeCode(seasonNumber, episodeNumber);

  /// An episode is considered aired from its air date (inclusive).
  bool isAiredAt(DateTime now) {
    final date = airDate;
    if (date == null) return false;
    return !date.isAfter(DateTime(now.year, now.month, now.day));
  }

  bool get isAired => isAiredAt(DateTime.now());

  factory Episode.fromTmdbJson(Map<String, dynamic> json, {required int showId}) =>
      TmdbMapper.episode(json, showId: showId);

  Map<String, dynamic> toJson() => TmdbMapper.episodeToJson(this);

  Episode copyWith({
    int? id,
    int? showId,
    int? seasonNumber,
    int? episodeNumber,
    String? name,
    String? overview,
    DateTime? airDate,
    int? runtime,
    String? stillUrl,
    double? rating,
    double? userRating,
    bool clearUserRating = false,
  }) =>
      Episode(
        id: id ?? this.id,
        showId: showId ?? this.showId,
        seasonNumber: seasonNumber ?? this.seasonNumber,
        episodeNumber: episodeNumber ?? this.episodeNumber,
        name: name ?? this.name,
        overview: overview ?? this.overview,
        airDate: airDate ?? this.airDate,
        runtime: runtime ?? this.runtime,
        stillUrl: stillUrl ?? this.stillUrl,
        rating: rating ?? this.rating,
        userRating: clearUserRating ? null : (userRating ?? this.userRating),
      );
}

typedef EpisodeModel = Episode;

@immutable
class CastMember {
  const CastMember({
    required this.id,
    required this.name,
    required this.character,
    this.profileUrl,
  });

  factory CastMember.fromTmdbJson(Map<String, dynamic> json) {
    final roles = json['roles'] as List?;
    final character = roles != null && roles.isNotEmpty && roles.first is Map
        ? (roles.first['character'] as String? ?? '')
        : (json['character'] as String? ?? '');
    return CastMember(
      id: json['id'] is num ? (json['id'] as num).toInt() : 0,
      name: json['name'] as String? ?? '',
      character: character,
      profileUrl: TmdbMapper.image(json['profile_path'], size: 'w185'),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'character': character,
        'profile_path': profileUrl,
      };

  final int id;
  final String name;
  final String character;
  final String? profileUrl;
}
