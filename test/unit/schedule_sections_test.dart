import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seriolab/features/schedule/data/repositories/schedule_repository_impl.dart';
import 'package:seriolab/features/schedule/domain/entities/schedule_item.dart';
import 'package:seriolab/features/schedule/presentation/controllers/schedule_controller.dart';
import 'package:seriolab/features/schedule/presentation/screens/schedule_screen.dart';
import 'package:seriolab/features/shows/data/datasources/mock/mock_show_remote_data_source.dart';
import 'package:seriolab/features/shows/data/repositories/show_repository_impl.dart';
import 'package:seriolab/features/shows/domain/entities/episode.dart';
import 'package:seriolab/features/shows/domain/entities/show.dart';
import 'package:seriolab/features/tracking/domain/entities/tracking_entities.dart';
import 'package:seriolab/features/tracking/domain/entities/tracking_state.dart';

void main() {
  final now = DateTime(2026, 10, 11, 12, 0, 0);

  group('Schedule Domain Models', () {
    test('CurrentlyWatchingItem computes identifiers and properties', () {
      final tracked = TrackedShow(
        showId: 95396,
        name: 'Severance',
        status: TrackingStatus.watching,
        addedAt: now,
        updatedAt: now,
        posterUrl: '/severance.jpg',
        network: 'Apple TV+',
      );

      final nextEp = Episode(
        id: 101,
        showId: 95396,
        seasonNumber: 2,
        episodeNumber: 4,
        name: 'Waffle Party',
        airDate: now.subtract(const Duration(days: 3)),
      );

      final item = CurrentlyWatchingItem(
        trackedShow: tracked,
        nextEpisode: nextEp,
        isAired: true,
      );

      expect(item.showId, 95396);
      expect(item.showName, 'Severance');
      expect(item.episodeIdentifier, 'T2 • E4');
      expect(item.episodeTitle, 'Waffle Party');
      expect(item.isAired, isTrue);
      expect(item.isCaughtUp, isFalse);
    });

    test('ComingSoonItem computes identifier and premiere attributes', () {
      final futureDate = now.add(const Duration(days: 14));
      final item = ComingSoonItem(
        showId: 100088,
        showName: 'The Last of Us',
        airDate: futureDate,
        seasonNumber: 3,
        episodeNumber: 1,
        episodeTitle: 'Future Days',
        isSeasonPremiere: true,
      );

      expect(item.episodeIdentifier, 'T3 • E1');
      expect(item.isSeasonPremiere, isTrue);
      expect(item.isAiredToday, isFalse);
    });
  });

  group('ScheduleRepositoryImpl Tests', () {
    late ShowRepositoryImpl showRepo;
    late ScheduleRepositoryImpl scheduleRepo;
    final fixedDate = DateTime(2026, 10, 9);

    setUp(() {
      showRepo = ShowRepositoryImpl(
        remote: MockShowRemoteDataSource(
          latency: Duration.zero,
          clock: () => fixedDate,
        ),
        isUsingMockData: true,
        clock: () => fixedDate,
      );
      scheduleRepo = ScheduleRepositoryImpl(
        showRepository: showRepo,
        clock: () => fixedDate,
      );
    });

    test('getCurrentlyWatching identifies next unwatched episode', () async {
      final tracked = TrackedShow(
        showId: 95396,
        name: 'Severance',
        status: TrackingStatus.watching,
        addedAt: fixedDate,
        updatedAt: fixedDate,
      );

      // User watched S1E1, S1E2, S1E3
      final trackingState = TrackingState(
        shows: {95396: tracked},
        watched: {
          95396: {
            const EpisodeKey(1, 1): WatchedEpisode(
              showId: 95396,
              key: const EpisodeKey(1, 1),
              runtime: 55,
              watchedAt: fixedDate,
            ),
            const EpisodeKey(1, 2): WatchedEpisode(
              showId: 95396,
              key: const EpisodeKey(1, 2),
              runtime: 55,
              watchedAt: fixedDate,
            ),
            const EpisodeKey(1, 3): WatchedEpisode(
              showId: 95396,
              key: const EpisodeKey(1, 3),
              runtime: 55,
              watchedAt: fixedDate,
            ),
          },
        },
      );

      final watchingList = await scheduleRepo.getCurrentlyWatching(trackingState);
      expect(watchingList, isNotEmpty);
      final item = watchingList.first;
      expect(item.showId, 95396);
      expect(item.nextEpisode, isNotNull);
      expect(item.nextEpisode!.seasonNumber, 1);
      expect(item.nextEpisode!.episodeNumber, 4);
      expect(item.episodeIdentifier, 'T1 • E4');
      expect(item.isAired, isTrue);
    });

    test('getCurrentlyWatching excludes caught-up shows where all aired episodes are watched', () async {
      final tracked = TrackedShow(
        showId: 95396,
        name: 'Severance',
        status: TrackingStatus.watching,
        addedAt: fixedDate,
        updatedAt: fixedDate,
      );

      final showWithEpisodes = await showRepo.getShowWithEpisodes(95396);
      final airedEpisodes =
          showWithEpisodes.episodes.where((ep) => ep.isAiredAt(fixedDate)).toList();

      final watchedMap = <EpisodeKey, WatchedEpisode>{
        for (final ep in airedEpisodes)
          ep.key: WatchedEpisode(
            showId: 95396,
            key: ep.key,
            runtime: 55,
            watchedAt: fixedDate,
          ),
      };

      final trackingState = TrackingState(
        shows: {95396: tracked},
        watched: {95396: watchedMap},
      );

      final watchingList = await scheduleRepo.getCurrentlyWatching(trackingState);
      expect(watchingList, isEmpty);

      // And future episodes are available in ComingSoon
      final comingSoonList =
          await scheduleRepo.getComingSoon(trackingState, windowDays: 60);
      expect(comingSoonList.any((item) => item.showId == 95396), isTrue);
    });

    test('getComingSoon returns future episodes sorted chronologically', () async {
      final tracked = TrackedShow(
        showId: 95396, // Severance has season 2 episodes in future in mock catalog
        name: 'Severance',
        status: TrackingStatus.watchlist,
        addedAt: fixedDate,
        updatedAt: fixedDate,
      );

      final trackingState = TrackingState(
        shows: {95396: tracked},
        watched: const {},
      );

      final comingSoonList = await scheduleRepo.getComingSoon(trackingState, windowDays: 60);
      expect(comingSoonList, isNotEmpty);
      for (var i = 0; i < comingSoonList.length - 1; i++) {
        expect(
          comingSoonList[i].airDate.isBefore(comingSoonList[i + 1].airDate) ||
              comingSoonList[i].airDate.isAtSameMomentAs(comingSoonList[i + 1].airDate),
          isTrue,
        );
      }
    });
  });

  group('ScheduleScreen UI and Tab Switching Tests', () {
    testWidgets('renders AppBar with Agenda and both tabs', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            scheduleControllerProvider.overrideWith(
              () => _FakeScheduleController(const ScheduleState()),
            ),
          ],
          child: const MaterialApp(
            home: ScheduleScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // AppBar title is Agenda
      expect(find.widgetWithText(AppBar, 'Agenda'), findsOneWidget);

      // Both tabs are rendered
      expect(find.text('A Ver Atualmente'), findsOneWidget);
      expect(find.text('Brevemente'), findsOneWidget);

      // Empty state for A Ver Atualmente is displayed by default
      expect(
        find.text('Nenhuma série com episódios pendentes para ver.'),
        findsOneWidget,
      );
      expect(find.text('Estás em dia!'), findsOneWidget);

      // Tap on Brevemente tab
      await tester.tap(find.text('Brevemente'));
      await tester.pumpAndSettle();

      // Empty state for Brevemente is displayed
      expect(
        find.text('Nenhuma estreia agendada para breve nas tuas séries.'),
        findsOneWidget,
      );
      expect(find.text('Sem estreias agendadas'), findsOneWidget);
    });

    testWidgets('renders active cards with episode code, badges and actions',
        (tester) async {
      const showDetails = ShowDetails(
        id: 95396,
        name: 'Severance',
        posterUrl: '/severance.jpg',
      );

      final nextEp = Episode(
        id: 101,
        showId: 95396,
        seasonNumber: 2,
        episodeNumber: 4,
        name: 'The Grim Barbarity of Magnetism and Artifacts',
        airDate: now.subtract(const Duration(days: 2)),
      );

      final watchingItem = CurrentlyWatchingItem(
        trackedShow: TrackedShow(
          showId: 95396,
          name: 'Severance',
          status: TrackingStatus.watching,
          addedAt: now,
          updatedAt: now,
          network: 'Apple TV+',
        ),
        showDetails: showDetails,
        nextEpisode: nextEp,
        isAired: true,
      );

      final comingSoonItem = ComingSoonItem(
        showId: 100088,
        showName: 'The Last of Us',
        airDate: now.add(const Duration(days: 14)),
        seasonNumber: 3,
        episodeNumber: 1,
        episodeTitle: 'Through the Valley',
        isSeasonPremiere: true,
        network: 'HBO',
      );

      final fakeState = ScheduleState(
        watching: [watchingItem],
        comingSoon: [comingSoonItem],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            scheduleControllerProvider.overrideWith(
              () => _FakeScheduleController(fakeState),
            ),
          ],
          child: const MaterialApp(
            home: ScheduleScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // In Tab 1 ("A Ver Atualmente"):
      expect(find.text('Severance'), findsWidgets);
      expect(find.text('T2 • E4'), findsOneWidget);
      expect(find.text('The Grim Barbarity of Magnetism and Artifacts'), findsOneWidget);
      expect(find.text('Disponível'), findsOneWidget);
      // Quick mark-as-watched button exists
      expect(find.byTooltip('Marcar como visto'), findsOneWidget);

      // Switch to Tab 2 ("Brevemente"):
      await tester.tap(find.text('Brevemente'));
      await tester.pumpAndSettle();

      expect(find.text('The Last of Us'), findsWidgets);
      expect(find.text('T3 • E1'), findsOneWidget);
      expect(find.text('Through the Valley'), findsOneWidget);
      expect(find.text('T3 Estreia em 2 semanas'), findsOneWidget);
    });
  });
}

class _FakeScheduleController extends ScheduleController {
  _FakeScheduleController(this._initial);

  final ScheduleState _initial;

  @override
  Future<ScheduleState> build() async {
    return _initial;
  }
}
