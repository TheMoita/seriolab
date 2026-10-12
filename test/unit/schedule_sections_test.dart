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
import 'package:seriolab/features/settings/domain/entities/user_settings.dart';
import 'package:seriolab/features/settings/presentation/providers/settings_providers.dart';
import 'package:seriolab/features/tracking/domain/entities/tracking_entities.dart';
import 'package:seriolab/features/tracking/domain/entities/tracking_state.dart';

class _FakeSettingsNotifier extends SettingsNotifier {
  _FakeSettingsNotifier(this._initial);
  final UserSettings _initial;

  @override
  UserSettings build() => _initial;
}

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

    test('getStartWatching returns shows in watchlist with 0 episodes watched starting from S1E1', () async {
      final tracked = TrackedShow(
        showId: 95396,
        name: 'Severance',
        status: TrackingStatus.watchlist,
        addedAt: fixedDate,
        updatedAt: fixedDate,
      );

      final trackingState = TrackingState(
        shows: {95396: tracked},
        watched: const {},
      );

      final startList = await scheduleRepo.getStartWatching(trackingState);
      expect(startList, isNotEmpty);
      expect(startList.first.showId, 95396);
      expect(startList.first.nextEpisode, isNotNull);
      expect(startList.first.nextEpisode!.seasonNumber, 1);
      expect(startList.first.nextEpisode!.episodeNumber, 1);
      expect(startList.first.episodeIdentifier, 'T1 • E1');
    });

    test('getResume returns dropped shows with next unwatched episode', () async {
      final tracked = TrackedShow(
        showId: 95396,
        name: 'Severance',
        status: TrackingStatus.dropped,
        addedAt: fixedDate,
        updatedAt: fixedDate,
      );

      // Watched S1E1
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
          },
        },
      );

      final resumeList = await scheduleRepo.getResume(trackingState);
      expect(resumeList, isNotEmpty);
      expect(resumeList.first.showId, 95396);
      expect(resumeList.first.nextEpisode, isNotNull);
      expect(resumeList.first.nextEpisode!.seasonNumber, 1);
      expect(resumeList.first.nextEpisode!.episodeNumber, 2);
      expect(resumeList.first.episodeIdentifier, 'T1 • E2');
    });
  });

  group('ScheduleScreen UI and Tab Switching Tests', () {
    testWidgets('renders AppBar with Agenda and both tabs', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsControllerProvider.overrideWith(
              () => _FakeSettingsNotifier(
                UserSettings.defaultSettings.copyWith(language: 'pt-PT'),
              ),
            ),
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
      expect(find.text('Lista para Assistir'), findsOneWidget);
      expect(find.text('Brevemente'), findsOneWidget);

      // Empty state for Lista para Assistir is displayed by default
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
        upNext: [watchingItem],
        comingSoon: [comingSoonItem],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsControllerProvider.overrideWith(
              () => _FakeSettingsNotifier(
                UserSettings.defaultSettings.copyWith(language: 'pt-PT'),
              ),
            ),
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

      // In Tab 1 ("Lista para Assistir" -> section "VER A SEGUIR"):
      expect(find.text('VER A SEGUIR'), findsOneWidget);
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

    testWidgets(
        'renders distinct sections for Ver a Seguir, Começar a Ver, and Retomar',
        (tester) async {
      final upNextItem = CurrentlyWatchingItem(
        trackedShow: TrackedShow(
          showId: 95396,
          name: 'Severance',
          status: TrackingStatus.watching,
          addedAt: now,
          updatedAt: now,
        ),
        showDetails: const ShowDetails(id: 95396, name: 'Severance'),
        nextEpisode: Episode(
          id: 101,
          showId: 95396,
          seasonNumber: 2,
          episodeNumber: 4,
          name: 'Waffle Party',
          airDate: now.subtract(const Duration(days: 1)),
        ),
        isAired: true,
      );

      final startWatchingItem = CurrentlyWatchingItem(
        trackedShow: TrackedShow(
          showId: 100088,
          name: 'The Last of Us',
          status: TrackingStatus.watchlist,
          addedAt: now,
          updatedAt: now,
        ),
        showDetails: const ShowDetails(id: 100088, name: 'The Last of Us'),
        nextEpisode: Episode(
          id: 201,
          showId: 100088,
          seasonNumber: 1,
          episodeNumber: 1,
          name: 'When You\'re Lost in the Darkness',
          airDate: now.subtract(const Duration(days: 300)),
        ),
        isAired: true,
      );

      final resumeItem = CurrentlyWatchingItem(
        trackedShow: TrackedShow(
          showId: 1399,
          name: 'Game of Thrones',
          status: TrackingStatus.dropped,
          addedAt: now,
          updatedAt: now,
        ),
        showDetails: const ShowDetails(id: 1399, name: 'Game of Thrones'),
        nextEpisode: Episode(
          id: 301,
          showId: 1399,
          seasonNumber: 3,
          episodeNumber: 9,
          name: 'The Rains of Castamere',
          airDate: now.subtract(const Duration(days: 1000)),
        ),
        isAired: true,
      );

      final multiState = ScheduleState(
        upNext: [upNextItem],
        startWatching: [startWatchingItem],
        resume: [resumeItem],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsControllerProvider.overrideWith(
              () => _FakeSettingsNotifier(
                UserSettings.defaultSettings.copyWith(language: 'pt-PT'),
              ),
            ),
            scheduleControllerProvider.overrideWith(
              () => _FakeScheduleController(multiState),
            ),
          ],
          child: const MaterialApp(
            home: ScheduleScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // All 3 section headers are displayed
      expect(find.text('VER A SEGUIR'), findsOneWidget);
      expect(find.text('COMEÇAR A VER'), findsOneWidget);
      expect(find.text('RETOMAR'), findsOneWidget);

      // Section-specific cards and badges
      expect(find.text('Severance'), findsWidgets);
      expect(find.text('The Last of Us'), findsWidgets);
      expect(find.text('Game of Thrones'), findsWidgets);

      expect(find.text('Começar'), findsOneWidget);
      expect(find.text('Pausada'), findsOneWidget);
    });

    testWidgets('renders tabs in English by default when no settings override is present',
        (tester) async {
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

      // In English by default without any override
      expect(find.text('Watchlist'), findsOneWidget);
      expect(find.text('Coming Soon'), findsOneWidget);
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
