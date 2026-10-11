import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seriolab/features/shows/domain/entities/show.dart';
import 'package:seriolab/features/shows/presentation/providers/show_providers.dart';
import 'package:seriolab/features/shows/presentation/screens/show_detail_screen.dart';

void main() {
  const testShow = ShowDetails(
    id: 1396,
    name: 'Breaking Bad',
    originalName: 'Breaking Bad',
    overview: 'A chemistry teacher diagnosed with cancer...',
    posterUrl: '/breaking_bad.jpg',
    backdropUrl: '/bb_backdrop.jpg',
  );

  group('ShowDetailScreen Trailer Button Tests', () {
    testWidgets('renders exactly ONE "Ver Trailer" button on the backdrop when trailer is available', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            showDetailsProvider(1396).overrideWith((ref) => Future.value(testShow)),
            showTrailerProvider(1396).overrideWith((ref) => Future.value('HhesaQXLuRY')),
          ],
          child: const MaterialApp(
            home: ShowDetailScreen(showId: 1396),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Exactly ONE "Ver Trailer" button must exist in the entire screen
      final trailerButtonFinder = find.text('Ver Trailer');
      expect(trailerButtonFinder, findsOneWidget);

      // Verify no disabled button is rendered
      expect(find.text('Trailer indisponível'), findsNothing);
    });

    testWidgets('hides trailer button completely when no trailer is available (null/empty)', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            showDetailsProvider(1396).overrideWith((ref) => Future.value(testShow)),
            showTrailerProvider(1396).overrideWith((ref) => Future.value(null)),
          ],
          child: const MaterialApp(
            home: ShowDetailScreen(showId: 1396),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // No trailer button and no disabled button
      expect(find.text('Ver Trailer'), findsNothing);
      expect(find.text('Trailer indisponível'), findsNothing);
    });
  });
}
