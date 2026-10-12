import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:seriolab/core/di/providers.dart';
import 'package:seriolab/features/shows/data/datasources/mock/mock_show_remote_data_source.dart';
import 'package:seriolab/features/shows/data/repositories/show_repository_impl.dart';
import 'package:seriolab/features/shows/presentation/screens/episode_detail_screen.dart';
import 'package:seriolab/features/tracking/data/repositories/in_memory_tracking_repository.dart';

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
    expect(find.text('S1 • E1'), findsOneWidget);

    // Verify Quick Action button
    expect(find.text('Mark as Watched'), findsOneWidget);

    // Verify Overview section
    expect(find.text('Overview'), findsOneWidget);

    // Verify personal rating CTA and clean unrated placeholder
    expect(find.text('Your Rating'), findsOneWidget);
    expect(find.text('You haven\'t rated this episode yet'), findsOneWidget);
    expect(find.text('Log / Rate Episode'), findsOneWidget);

    // Toggle watched state
    await tester.tap(find.text('Mark as Watched'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Episode Watched'), findsOneWidget);

    // Dismiss the optional review bottom sheet to continue testing EpisodeDetailScreen
    if (find.text('Not now').evaluate().isNotEmpty) {
      await tester.tap(find.text('Not now'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    // Scroll down to community reviews section
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await tester.pump(const Duration(milliseconds: 100));

    // Verify Community reviews section
    expect(find.text('Community'), findsOneWidget);

    // Verify empty state is displayed initially
    expect(
      find.text(
        'No comments for this episode yet. Be the first to share your thoughts!',
      ),
      findsOneWidget,
    );

    // Verify comment input bar
    expect(find.text('Leave a comment'), findsOneWidget);
    expect(find.text('Contains Spoilers'), findsOneWidget);
    expect(find.text('Post'), findsOneWidget);

    // Add a comment with spoiler
    await tester.enterText(
      find.widgetWithText(TextField, 'Share your thoughts about this episode...'),
      'Shocking twist at the end!',
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Contains Spoilers'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Post'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify spoiler warning card in community section
    expect(find.text('Spoiler Warning — Tap to reveal'), findsOneWidget);

    // Tap spoiler warning to reveal spoiler comment
    await tester.tap(
      find.text('Spoiler Warning — Tap to reveal'),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(find.text('Shocking twist at the end!'), findsOneWidget);
  });
}
