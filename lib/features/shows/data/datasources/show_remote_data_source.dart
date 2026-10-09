import '../../domain/entities/genre.dart';
import '../../domain/entities/show.dart';

/// Raw catalogue access. Implemented by TMDB (network) and the mock catalogue.
abstract interface class ShowRemoteDataSource {
  Future<List<ShowSummary>> trending({String? language});
  Future<List<ShowSummary>> popularThisWeek({String? language});
  Future<List<ShowSummary>> justPremiered({String? language});
  Future<List<ShowSummary>> topRated({String? language});
  Future<List<ShowSummary>> discover({
    Genre? genre,
    required ShowSort sort,
    String? language,
  });
  Future<List<ShowSummary>> search(String query, {String? language});
  Future<ShowDetails> showDetails(int showId, {String? language});
  Future<SeasonDetails> season(int showId, int seasonNumber, {String? language});
  Future<List<String>> showBackdrops(int showId);
}

class CatalogException implements Exception {
  const CatalogException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() =>
      'CatalogException(${statusCode ?? '-'}): $message';
}
