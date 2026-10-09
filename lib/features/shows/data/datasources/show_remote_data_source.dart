import '../../domain/entities/genre.dart';
import '../../domain/entities/show.dart';

/// Raw catalogue access. Implemented by TMDB (network) and the mock catalogue.
abstract interface class ShowRemoteDataSource {
  Future<List<ShowSummary>> trending();
  Future<List<ShowSummary>> popularThisWeek();
  Future<List<ShowSummary>> justPremiered();
  Future<List<ShowSummary>> topRated();
  Future<List<ShowSummary>> discover({Genre? genre, required ShowSort sort});
  Future<List<ShowSummary>> search(String query);
  Future<ShowDetails> showDetails(int showId);
  Future<SeasonDetails> season(int showId, int seasonNumber);
}

class CatalogException implements Exception {
  const CatalogException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() =>
      'CatalogException(${statusCode ?? '-'}): $message';
}
