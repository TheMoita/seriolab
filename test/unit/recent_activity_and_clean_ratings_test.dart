import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:series_app/core/di/providers.dart';
import 'package:series_app/features/shows/data/datasources/mock/mock_show_remote_data_source.dart';
import 'package:series_app/features/shows/data/repositories/show_repository_impl.dart';
import 'package:series_app/features/shows/domain/entities/episode.dart';
import 'package:series_app/features/shows/presentation/screens/episode_detail_screen.dart';
import 'package:series_app/features/tracking/data/repositories/in_memory_tracking_repository.dart';
import 'package:series_app/features/tracking/domain/entities/tracking_entities.dart';
import 'package:series_app/features/tracking/presentation/widgets/ratings_breakdown_section.dart';
import 'package:series_app/features/tracking/presentation/widgets/recent_activity_section.dart';

void main() {
  group('formatRelativeWatchedAt', () {
    final baseNow = DateTime(2026, 10, 11, 12, 0);

    test('returns Hoje for same day', () {
      final today = DateTime(2026, 10, 11, 8, 30);
      expect(formatRelativeWatchedAt(today, now: baseNow), 'Hoje');
    });

    test('returns Ontem for previous day', () {
      final yesterday = DateTime(2026, 10, 10, 20, 0);
      expect(formatRelativeWatchedAt(yesterday, now: baseNow), 'Ontem');
    });

    test('returns há X dias for 2 to 6 days ago', () {
      final threeDaysAgo = DateTime(2026, 10, 8, 14, 0);
      expect(formatRelativeWatchedAt(threeDaysAgo, now: baseNow), 'há 3 dias');
    });

    test('returns há 1 semana for 7 to 13 days ago', () {
      final sevenDaysAgo = DateTime(2026, 10, 4, 10, 0);
      expect(formatRelativeWatchedAt(sevenDaysAgo, now: baseNow), 'há 1 semana');
    });

    test('returns há 2 semanas for 14 days ago', () {
      final twoWeeksAgo = DateTime(2026, 9, 27, 10, 0);
      expect(formatRelativeWatchedAt(twoWeeksAgo, now: baseNow), 'há 2 semanas');
    });
  });

  group('RatingsBreakdownSection clean UI', () {
    testWidgets('does not render bottom axis numbers and static hint tip',
        (WidgetTester tester) async {
      final inMemoryRepo = InMemoryTrackingRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trackingRepositoryProvider.overrideWithValue(inMemoryRepo),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: RatingsBreakdownSection(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // RATINGS BREAKDOWN header is present
      expect(find.text('RATINGS BREAKDOWN'), findsOneWidget);
      // Empty state text is present when total = 0
      expect(find.text('Ainda não avaliaste nenhuma série'), findsOneWidget);

      // Old bottom axis labels must NOT exist
      expect(find.text('0.5'), findsNothing);
      expect(find.text('1'), findsNothing);
      expect(find.text('3'), findsNothing);
      expect(find.text('5'), findsNothing);
      expect(find.text('7'), findsNothing);
      expect(find.text('10'), findsNothing);

      // Static tip text must NOT exist
      expect(find.text('Desliza sobre o gráfico para ver as notas'), findsNothing);
      expect(find.text('Desliza para ver detalhes'), findsNothing);
    });
  });

  group('RecentActivitySection UI & Navigation', () {
    testWidgets('displays empty state when no episodes watched',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: RecentActivitySection(customEpisodes: []),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('ATIVIDADE RECENTE'), findsOneWidget);
      expect(find.text('Ainda sem atividade recente'), findsOneWidget);
    });

    testWidgets('displays recent episode cards and navigates on tap',
        (WidgetTester tester) async {
      final inMemoryRepo = InMemoryTrackingRepository();
      final testRepo = ShowRepositoryImpl(
        remote: MockShowRemoteDataSource(latency: Duration.zero),
        isUsingMockData: true,
      );

      final now = DateTime.now();
      final sampleEpisodes = [
        WatchedEpisode(
          showId: 1399, // Game of Thrones in mock datasource
          key: const EpisodeKey(1, 1),
          runtime: 60,
          watchedAt: now,
          userRating: 9.5,
        ),
        WatchedEpisode(
          showId: 1399,
          key: const EpisodeKey(1, 2),
          runtime: 55,
          watchedAt: now.subtract(const Duration(days: 1)),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trackingRepositoryProvider.overrideWithValue(inMemoryRepo),
            showRepositoryProvider.overrideWithValue(testRepo),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: RecentActivitySection(customEpisodes: sampleEpisodes),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('ATIVIDADE RECENTE'), findsOneWidget);
      expect(find.text('2 recentes'), findsNothing);

      // Episode key badge
      expect(find.text('T1 • E1'), findsOneWidget);
      expect(find.text('T1 • E2'), findsOneWidget);

      // Rating badge for rated episode
      expect(find.text('9.5'), findsOneWidget);

      // Relative times
      expect(find.text('Hoje'), findsOneWidget);
      expect(find.text('Ontem'), findsOneWidget);

      // Tap on first card to navigate to EpisodeDetailScreen
      await tester.tap(find.text('T1 • E1'));
      await tester.pumpAndSettle();

      expect(find.byType(EpisodeDetailScreen), findsOneWidget);
    });
  });
}
