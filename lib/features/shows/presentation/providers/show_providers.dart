import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../tracking/presentation/providers/tracking_providers.dart';
import '../../domain/entities/episode.dart';
import '../../domain/entities/genre.dart';
import '../../domain/entities/show.dart';

typedef SeasonRef = ({int showId, int seasonNumber});
typedef EpisodeRef = ({int showId, int seasonNumber, int episodeNumber});

/// Trending shows for the Explore header
final trendingShowsProvider =
    FutureProvider.autoDispose<List<ShowSummary>>((ref) {
  return ref.watch(showRepositoryProvider).getTrending();
});

/// Popular shows this week for the Letterboxd-style Home screen
final popularThisWeekProvider =
    FutureProvider.autoDispose<List<ShowSummary>>((ref) {
  return ref.watch(showRepositoryProvider).getPopularThisWeek();
});

/// Just premiered / new seasons for the Home screen carousel
final justPremieredShowsProvider =
    FutureProvider.autoDispose<List<ShowSummary>>((ref) {
  return ref.watch(showRepositoryProvider).getJustPremiered();
});

/// Top rated TV shows of all time for the Home screen carousel
final topRatedShowsProvider =
    FutureProvider.autoDispose<List<ShowSummary>>((ref) {
  return ref.watch(showRepositoryProvider).getTopRated();
});

/// Genre filter notifier
class SelectedGenreNotifier extends Notifier<Genre?> {
  @override
  Genre? build() => null;

  void select(Genre? genre) => state = genre;
}

final selectedGenreProvider =
    NotifierProvider<SelectedGenreNotifier, Genre?>(SelectedGenreNotifier.new);

/// Sort order filter notifier
class SelectedSortNotifier extends Notifier<ShowSort> {
  @override
  ShowSort build() => ShowSort.popularity;

  void select(ShowSort sort) => state = sort;
}

final selectedSortProvider =
    NotifierProvider<SelectedSortNotifier, ShowSort>(SelectedSortNotifier.new);

/// Search query filter notifier
class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
}

final searchQueryProvider =
    NotifierProvider<SearchQueryNotifier, String>(SearchQueryNotifier.new);

/// Explore shows query taking into account search query, genre and sort
final exploreShowsProvider =
    FutureProvider.autoDispose<List<ShowSummary>>((ref) async {
  final repo = ref.watch(showRepositoryProvider);
  final query = ref.watch(searchQueryProvider).trim();
  final genre = ref.watch(selectedGenreProvider);
  final sort = ref.watch(selectedSortProvider);

  if (query.isNotEmpty) {
    return repo.search(query, genre: genre, sort: sort);
  } else {
    return repo.discover(genre: genre, sort: sort);
  }
});

/// Search shows by title query string
final searchShowsProvider =
    FutureProvider.autoDispose.family<List<ShowSummary>, String>(
  (ref, query) => ref.watch(showRepositoryProvider).search(query),
);

/// Show details
final showDetailsProvider =
    FutureProvider.autoDispose.family<ShowDetails, int>(
  (ref, showId) => ref.watch(showRepositoryProvider).getShowDetails(showId),
);

/// Season details with episodes
final seasonDetailsProvider =
    FutureProvider.autoDispose.family<SeasonDetails, SeasonRef>(
  (ref, r) =>
      ref.watch(showRepositoryProvider).getSeason(r.showId, r.seasonNumber),
);

/// Episode details with guest stars, crew, and high-res stills
final episodeDetailsProvider =
    FutureProvider.autoDispose.family<EpisodeDetails, EpisodeRef>(
  (ref, r) => ref
      .watch(showRepositoryProvider)
      .getEpisodeDetails(r.showId, r.seasonNumber, r.episodeNumber),
);

/// Show + all regular episodes (used for "next episode" on the profile)
final showWithEpisodesProvider =
    FutureProvider.autoDispose.family<ShowWithEpisodes, int>(
  (ref, showId) =>
      ref.watch(showRepositoryProvider).getShowWithEpisodes(showId),
);

/// Upcoming episodes for all shows the user is currently tracking
final upcomingEpisodesProvider =
    FutureProvider.autoDispose<List<UpcomingEpisode>>((ref) async {
  final trackingState = ref.watch(trackingControllerProvider).value;
  if (trackingState == null) return const [];

  final showIds = trackingState.calendarShowIds;
  if (showIds.isEmpty) return const [];

  final repo = ref.watch(showRepositoryProvider);
  return repo.getUpcomingEpisodes(showIds);
});

/// High-resolution backdrops / wallpapers for a show
final showBackdropsProvider =
    FutureProvider.autoDispose.family<List<String>, int>(
  (ref, showId) =>
      ref.watch(showRepositoryProvider).getShowBackdrops(showId),
);
