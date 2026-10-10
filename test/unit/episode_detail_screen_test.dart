import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:series_app/core/di/providers.dart';
import 'package:series_app/features/shows/data/datasources/mock/mock_show_remote_data_source.dart';
import 'package:series_app/features/shows/data/repositories/show_repository_impl.dart';
import 'package:series_app/features/shows/presentation/screens/episode_detail_screen.dart';
import 'package:series_app/features/tracking/data/repositories/in_memory_tracking_repository.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_PT', null);
  });

  testWidgets('EpisodeDetailScreen renders header, metadata, rating and community reviews',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final inMemoryRepo = InMemoryTrackingRepository();
    final testRepo = ShowRepositoryImpl(
      remote: MockShowRemoteDataSource(latency: Duration.zero),
      isUsingMockData: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trackingRepositoryProvider.overrideWithValue(inMemoryRepo),
          showRepositoryProvider.overrideWithValue(testRepo),
        ],
        child: const MaterialApp(
          home: EpisodeDetailScreen(
            seriesId: 100088, // The Last of Us
            seasonNumber: 1,
            episodeNumber: 1,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify season and episode badge
    expect(find.text('T1 • E1'), findsOneWidget);

    // Verify Quick Action button
    expect(find.text('Marcar como Visto'), findsOneWidget);

    // Verify Synopsis section
    expect(find.text('Sinopse'), findsOneWidget);

    // Verify Letterboxd-style personal rating CTA
    expect(find.text('A Tua Avaliação'), findsOneWidget);
    expect(find.text('Registar / Avaliar Episódio'), findsOneWidget);

    // Verify Community reviews section
    expect(find.text('Comunidade'), findsOneWidget);

    // Verify spoiler warning card in community section
    expect(find.text('Aviso de Spoiler — Toca para ver'), findsOneWidget);

    // Tap spoiler warning to reveal spoiler comment
    await tester.tap(
      find.text('Aviso de Spoiler — Toca para ver'),
      warnIfMissed: false,
    );
    await tester.pump();

    // Verify comment input bar
    expect(find.text('Deixar um comentário'), findsOneWidget);
    expect(find.text('Contém Spoilers'), findsOneWidget);
    expect(find.text('Comentar'), findsOneWidget);

    // Toggle watched state
    await tester.tap(find.text('Marcar como Visto'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Episódio Visto'), findsOneWidget);
  });
}
