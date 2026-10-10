import '../../../../../core/utils/formatters.dart';
import '../../../domain/entities/episode.dart';
import '../../../domain/entities/genre.dart';
import '../../../domain/entities/show.dart';
import '../../models/tmdb_mapper.dart';
import '../show_remote_data_source.dart';
import 'mock_catalog.dart';

/// Offline, deterministic catalogue used while no TMDB key is configured.
class MockShowRemoteDataSource implements ShowRemoteDataSource {
  MockShowRemoteDataSource({
    this.latency = const Duration(milliseconds: 250),
    DateTime Function()? clock,
    List<MockShowSeed>? catalog,
  })  : _clock = clock ?? DateTime.now,
        _catalog = catalog ?? mockCatalog;

  /// Simulated network latency (use [Duration.zero] in tests).
  final Duration latency;
  final DateTime Function() _clock;
  final List<MockShowSeed> _catalog;

  DateTime get _today => Formatters.dateOnly(_clock());

  Future<T> _respond<T>(T Function() body) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    return body();
  }

  MockShowSeed _seed(int id) => _catalog.firstWhere(
        (s) => s.id == id,
        orElse: () => throw CatalogException('Série $id não encontrada',
            statusCode: 404),
      );

  // ---------------------------------------------------------------------------
  // Builders
  // ---------------------------------------------------------------------------

  List<Episode> _episodesFor(MockShowSeed seed, int seasonNumber) {
    final season = seed.seasons[seasonNumber - 1];
    final premiere = season.premiereDate(_today);
    return List.generate(season.episodes, (i) {
      final number = i + 1;
      final title = i < season.titles.length
          ? season.titles[i]
          : (number == 1 ? 'Estreia da temporada' : 'Episódio $number');
      final finale = number == season.episodes;
      return Episode(
        id: seed.id * 10000 + seasonNumber * 100 + number,
        showId: seed.id,
        seasonNumber: seasonNumber,
        episodeNumber: number,
        name: finale && i >= season.titles.length ? 'Final da temporada' : title,
        overview: 'Temporada $seasonNumber, episódio $number de ${seed.name}.',
        airDate: premiere.add(Duration(days: season.intervalDays * i)),
        runtime: seed.runtime + (finale ? 12 : 0),
        rating: (seed.rating - 0.4 + (number % 5) * 0.15).clamp(0.0, 10.0),
      );
    });
  }

  ShowSummary _summary(MockShowSeed seed) => ShowSummary(
        id: seed.id,
        name: seed.name,
        overview: seed.overview,
        posterUrl: seed.posterUrl,
        backdropUrl: seed.backdropUrl,
        rating: seed.rating,
        voteCount: seed.voteCount,
        popularity: seed.popularity,
        firstAirDate: seed.seasons.first.premiereDate(_today),
        genreIds: seed.genreIds,
        originalLanguage: seed.originalLanguage,
      );

  ShowDetails _details(MockShowSeed seed) {
    final today = _today;
    final all = <Episode>[
      for (var s = 1; s <= seed.seasons.length; s++) ..._episodesFor(seed, s),
    ];
    final aired = all.where((e) => e.isAiredAt(today)).toList();
    final upcoming = all.where((e) => !e.isAiredAt(today)).toList();

    return ShowDetails(
      id: seed.id,
      name: seed.name,
      originalName: seed.originalName,
      overview: seed.overview,
      tagline: seed.tagline,
      posterUrl: seed.posterUrl,
      backdropUrl: seed.backdropUrl,
      genres: seed.genres,
      rating: seed.rating,
      voteCount: seed.voteCount,
      popularity: seed.popularity,
      status: seed.status,
      networks: seed.networks,
      firstAirDate: seed.seasons.first.premiereDate(today),
      lastAirDate: aired.isEmpty ? null : aired.last.airDate,
      episodeRuntime: seed.runtime,
      originalLanguage: seed.originalLanguage,
      originCountries: seed.originCountries,
      cast: seed.cast,
      lastEpisodeToAir: aired.isEmpty ? null : aired.last,
      nextEpisodeToAir: upcoming.isEmpty ? null : upcoming.first,
      seasons: [
        for (var s = 1; s <= seed.seasons.length; s++)
          SeasonSummary(
            seasonNumber: s,
            name: 'Temporada $s',
            episodeCount: seed.seasons[s - 1].episodes,
            airDate: seed.seasons[s - 1].premiereDate(today),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // ShowRemoteDataSource
  // ---------------------------------------------------------------------------

  @override
  Future<List<ShowSummary>> trending({String? language}) => _respond(() {
        final today = _today;
        // "Trending" = shows with episodes airing in the last/next weeks first.
        int score(MockShowSeed s) {
          final d = _details(s);
          final ref = d.nextEpisodeToAir?.airDate ?? d.lastAirDate;
          if (ref == null) return 9999;
          return ref.difference(today).inDays.abs();
        }

        final list = [..._catalog]..sort((a, b) {
            final byRecency = score(a).compareTo(score(b));
            return byRecency != 0
                ? byRecency
                : b.popularity.compareTo(a.popularity);
          });
        return list.take(10).map(_summary).toList();
      });

  @override
  Future<List<ShowSummary>> popularThisWeek({String? language}) => _respond(() {
        const priorityIds = [
          100088, // The Last of Us
          95396, // Severance
          76331, // Succession
          126308, // Shōgun
          94997, // House of the Dragon
          136315, // The Bear
          94605, // Arcane
          209867, // Frieren
          95480, // Slow Horses
          76479, // The Boys
          1396, // Breaking Bad
        ];
        final popularMap = {for (final s in _catalog) s.id: s};
        final ordered = <MockShowSeed>[];
        for (final id in priorityIds) {
          final s = popularMap[id];
          if (s != null) ordered.add(s);
        }
        for (final s in _catalog) {
          if (!priorityIds.contains(s.id)) ordered.add(s);
        }
        return ordered.take(12).map(_summary).toList();
      });

  @override
  Future<List<ShowSummary>> justPremiered({String? language}) => _respond(() {
        const premieredIds = [
          95396, // Severance (S2)
          100088, // The Last of Us (S2)
          126308, // Shōgun
          136315, // The Bear
          209867, // Frieren
          95480, // Slow Horses
          94997, // House of the Dragon
          94605, // Arcane
          95479, // Jujutsu Kaisen
          120089, // SPY x FAMILY
        ];
        final showMap = {for (final s in _catalog) s.id: s};
        return premieredIds
            .map((id) => showMap[id])
            .whereType<MockShowSeed>()
            .map(_summary)
            .toList();
      });

  @override
  Future<List<ShowSummary>> topRated({String? language}) => _respond(() {
        final list = [..._catalog]
          ..sort((a, b) {
            final byRating = b.rating.compareTo(a.rating);
            return byRating != 0
                ? byRating
                : b.voteCount.compareTo(a.voteCount);
          });
        return list.take(12).map(_summary).toList();
      });

  @override
  Future<List<ShowSummary>> discover({
    Genre? genre,
    required ShowSort sort,
    String? language,
  }) =>
      _respond(() {
        final results = _catalog
            .map(_summary)
            .where((s) => genre == null || s.matchesGenre(genre))
            .toList();
        return sortShows(results, sort);
      });

  @override
  Future<List<ShowSummary>> search(String query, {String? language}) =>
      _respond(() {
        final q = normalizeForSearch(query);
        if (q.isEmpty) return <ShowSummary>[];
        final matches = _catalog.where((s) {
          final haystack = [s.name, s.originalName ?? '', ...s.aliases]
              .map(normalizeForSearch);
          return haystack.any((h) => h.contains(q));
        });
        return sortShows(matches.map(_summary).toList(), ShowSort.popularity);
      });

  @override
  Future<ShowDetails> showDetails(int showId, {String? language}) =>
      _respond(() => _details(_seed(showId)));

  @override
  Future<SeasonDetails> season(int showId, int seasonNumber,
          {String? language}) =>
      _respond(() {
        final seed = _seed(showId);
        if (seasonNumber < 1 || seasonNumber > seed.seasons.length) {
          throw CatalogException('Temporada $seasonNumber não encontrada',
              statusCode: 404);
        }
        return SeasonDetails(
          showId: showId,
          seasonNumber: seasonNumber,
          name: 'Temporada $seasonNumber',
          airDate: seed.seasons[seasonNumber - 1].premiereDate(_today),
          episodes: _episodesFor(seed, seasonNumber),
        );
      });

  @override
  Future<EpisodeDetails> episode(
    int showId,
    int seasonNumber,
    int episodeNumber, {
    String? language,
  }) =>
      _respond(() {
        final seed = _seed(showId);
        final episodes = _episodesFor(seed, seasonNumber);
        final ep = episodes.firstWhere(
          (e) => e.episodeNumber == episodeNumber,
          orElse: () => throw CatalogException(
            'Episódio S${seasonNumber}E$episodeNumber não encontrado',
            statusCode: 404,
          ),
        );
        return EpisodeDetails(
          episode: ep,
          guestStars: const [
            CastMember(
              id: 991,
              name: 'Participação Especial',
              character: 'Personagem Convidado',
            ),
          ],
          crew: [
            CrewMember(
              id: 992,
              name: seed.networks.isNotEmpty
                  ? seed.networks.first
                  : 'Realizador Seriolab',
              job: 'Director',
              department: 'Directing',
            ),
            const CrewMember(
              id: 993,
              name: 'Argumentista Principal',
              job: 'Writer',
              department: 'Writing',
            ),
          ],
          stillHighResUrl: seed.backdropUrl,
        );
      });

  @override
  Future<List<String>> showBackdrops(int showId) => _respond(() {
        final seed = _seed(showId);
        final urls = <String>[];
        if (seed.backdropPath != null) {
          final url = TmdbMapper.image(seed.backdropPath, size: 'w1280');
          if (url != null) urls.add(url);
        }
        if (seed.posterPath != null) {
          final url = TmdbMapper.image(seed.posterPath, size: 'w1280');
          if (url != null && !urls.contains(url)) urls.add(url);
        }
        return urls;
      });
}
