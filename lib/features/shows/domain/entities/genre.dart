import 'package:flutter/foundation.dart';

/// TV genre (TMDB TV genre ids) — no movie genres are modelled on purpose.
@immutable
class Genre {
  const Genre({required this.id, required this.name});

  final int id;
  final String name;

  /// Pseudo-genre: Japanese animation (TMDB: genre 16 + original language `ja`).
  static const anime = Genre(id: animeId, name: 'Anime');
  static const int animeId = -16;
  static const int animationId = 16;

  static const drama = Genre(id: 18, name: 'Drama');
  static const actionAdventure = Genre(id: 10759, name: 'Action & Adventure');
  static const sciFiFantasy = Genre(id: 10765, name: 'Sci-Fi & Fantasy');
  static const comedy = Genre(id: 35, name: 'Comedy');
  static const crime = Genre(id: 80, name: 'Crime');
  static const mystery = Genre(id: 9648, name: 'Mystery');

  static const List<Genre> all = [
    anime,
    drama,
    actionAdventure,
    sciFiFantasy,
    comedy,
    crime,
    mystery,
    Genre(id: 16, name: 'Animation'),
    Genre(id: 10768, name: 'War & Politics'),
    Genre(id: 99, name: 'Documentary'),
    Genre(id: 10751, name: 'Family'),
    Genre(id: 10764, name: 'Reality'),
    Genre(id: 10762, name: 'Kids'),
    Genre(id: 37, name: 'Western'),
  ];

  static Genre? byId(int id) {
    for (final g in all) {
      if (g.id == id) return g;
    }
    return null;
  }

  @override
  bool operator ==(Object other) => other is Genre && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Genre($id, $name)';
}

/// Sorting options available in Explore.
enum ShowSort {
  popularity('Popularity'),
  rating('Top Rated'),
  newest('Newest');

  const ShowSort(this.label);
  final String label;
}
