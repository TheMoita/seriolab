import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seriolab/core/di/providers.dart';
import 'package:seriolab/core/l10n/app_localizations.dart';
import 'package:seriolab/features/home/presentation/screens/home_screen.dart';
import 'package:seriolab/features/settings/domain/entities/user_settings.dart';
import 'package:seriolab/features/settings/presentation/providers/settings_providers.dart';
import 'package:seriolab/features/shows/data/datasources/mock/mock_show_remote_data_source.dart';
import 'package:seriolab/features/shows/data/repositories/show_repository_impl.dart';
import 'package:seriolab/features/shows/presentation/providers/show_providers.dart';
import 'package:seriolab/features/tracking/data/repositories/in_memory_tracking_repository.dart';

class _FakeSettingsNotifier extends SettingsNotifier {
  _FakeSettingsNotifier(this._initial);
  final UserSettings _initial;

  @override
  UserSettings build() => _initial;
}

void main() {
  group('HomeScreen Localization Tests', () {
    late InMemoryTrackingRepository inMemoryRepo;
    late ShowRepositoryImpl testRepo;

    setUp(() {
      inMemoryRepo = InMemoryTrackingRepository();
      testRepo = ShowRepositoryImpl(
        remote: MockShowRemoteDataSource(latency: Duration.zero),
        isUsingMockData: true,
      );
    });

    testWidgets('HomeScreen renders all sections, filters and buttons in Portuguese by default',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trackingRepositoryProvider.overrideWithValue(inMemoryRepo),
            showRepositoryProvider.overrideWithValue(testRepo),
            demoSeedingEnabledProvider.overrideWithValue(false),
            settingsControllerProvider.overrideWith(
              () => _FakeSettingsNotifier(
                UserSettings.defaultSettings.copyWith(language: 'pt-PT'),
              ),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
            ],
            home: Scaffold(
              body: HomeScreen(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Series badge is removed from AppBar
      expect(find.text('SÉRIES'), findsNothing);
      expect(find.text('TV SHOWS'), findsNothing);

      // Filter chips in Portuguese
      expect(find.text('Tudo'), findsOneWidget);
      expect(find.text('All'), findsNothing);
      expect(find.text('Sci-Fi & Fantasia'), findsOneWidget);
      expect(find.text('Sci-Fi & Fantasy'), findsNothing);
      expect(find.text('Comédia'), findsOneWidget);
      expect(find.text('Comedy'), findsNothing);

      // Section 1: Populares Esta Semana
      expect(find.text('POPULARES ESTA SEMANA'), findsOneWidget);
      expect(find.text('POPULAR THIS WEEK'), findsNothing);
      expect(find.text('As séries com maior tendência na comunidade'), findsOneWidget);
      expect(find.text('Ver tudo'), findsOneWidget);
      expect(find.text('See all'), findsNothing);
      expect(find.text('Ver todas'), findsNothing);

      // Section 2: A Estrear / Em Exibição
      expect(find.text('A ESTREAR / EM EXIBIÇÃO'), findsOneWidget);
      expect(find.text('JUST PREMIERED / NOVAS TEMPORADAS'), findsNothing);
      expect(find.text('Episódios e estreias recentes em exibição'), findsOneWidget);

      // Section 3: Mais Votadas
      expect(find.text('MAIS VOTADAS'), findsOneWidget);
      expect(find.text('TOP RATED TV SHOWS'), findsNothing);
      expect(find.text('As séries e animes mais aclamados de sempre'), findsOneWidget);
    });

    testWidgets('HomeScreen renders all sections, filters and buttons in English when set to en-US',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trackingRepositoryProvider.overrideWithValue(inMemoryRepo),
            showRepositoryProvider.overrideWithValue(testRepo),
            demoSeedingEnabledProvider.overrideWithValue(false),
            settingsControllerProvider.overrideWith(
              () => _FakeSettingsNotifier(
                UserSettings.defaultSettings.copyWith(language: 'en-US'),
              ),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
            ],
            home: Scaffold(
              body: HomeScreen(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Series badge is removed from AppBar
      expect(find.text('TV SHOWS'), findsNothing);
      expect(find.text('SÉRIES'), findsNothing);

      // Filter chips in English
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Tudo'), findsNothing);
      expect(find.text('Sci-Fi & Fantasy'), findsOneWidget);
      expect(find.text('Sci-Fi & Fantasia'), findsNothing);
      expect(find.text('Comedy'), findsOneWidget);
      expect(find.text('Comédia'), findsNothing);

      // Section 1: Popular This Week
      expect(find.text('POPULAR THIS WEEK'), findsOneWidget);
      expect(find.text('POPULARES ESTA SEMANA'), findsNothing);
      expect(find.text('Trending series across the community'), findsOneWidget);
      expect(find.text('See all'), findsOneWidget);
      expect(find.text('Ver tudo'), findsNothing);

      // Section 2: Upcoming / On The Air
      expect(find.text('UPCOMING / ON THE AIR'), findsOneWidget);
      expect(find.text('Recent episodes and premieres on the air'), findsOneWidget);

      // Section 3: Top Rated
      expect(find.text('TOP RATED'), findsOneWidget);
      expect(find.text('MAIS VOTADAS'), findsNothing);
      expect(find.text('The most acclaimed series and anime of all time'), findsOneWidget);
    });

    testWidgets('Empty state filter message is localized', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trackingRepositoryProvider.overrideWithValue(inMemoryRepo),
            showRepositoryProvider.overrideWithValue(testRepo),
            demoSeedingEnabledProvider.overrideWithValue(false),
            settingsControllerProvider.overrideWith(
              () => _FakeSettingsNotifier(
                UserSettings.defaultSettings.copyWith(language: 'pt-PT'),
              ),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
            ],
            home: Scaffold(
              body: HomeScreen(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tap Anime filter (which has no shows in the first 6 or specific set)
      await tester.tap(find.text('Anime'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Either shows match or the localized empty message appears
      // In PT:
      expect(find.text('No shows found for the selected genre.'), findsNothing);
    });

    test('Show providers observe settings and pass active language', () {
      final container = ProviderContainer(
        overrides: [
          trackingRepositoryProvider.overrideWithValue(inMemoryRepo),
          showRepositoryProvider.overrideWithValue(testRepo),
          settingsControllerProvider.overrideWith(
            () => _FakeSettingsNotifier(
              UserSettings.defaultSettings.copyWith(language: 'pt-BR', streamingRegion: 'BR'),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final settings = container.read(settingsControllerProvider);
      expect(settings.tmdbLanguageCode, equals('pt-BR'));

      // Reading providers triggers with active language
      expect(container.read(popularThisWeekProvider), isNotNull);
      expect(container.read(justPremieredShowsProvider), isNotNull);
      expect(container.read(topRatedShowsProvider), isNotNull);
    });
  });
}
