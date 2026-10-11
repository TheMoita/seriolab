import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seriolab/core/di/providers.dart';
import 'package:seriolab/core/widgets/modal_drag_handle.dart';
import 'package:seriolab/features/shows/domain/entities/episode.dart';
import 'package:seriolab/features/shows/domain/entities/show.dart';
import 'package:seriolab/features/shows/presentation/widgets/episode_review_bottom_sheet.dart';
import 'package:seriolab/features/tracking/data/repositories/in_memory_tracking_repository.dart';

void main() {
  testWidgets(
      'EpisodeReviewBottomSheet renders header, stars, comment box, and action buttons',
      (WidgetTester tester) async {
    final inMemoryRepo = InMemoryTrackingRepository();

    const testShow = ShowDetails(
      id: 100,
      name: 'Série Exemplo',
    );

    const testEpisode = Episode(
      id: 101,
      showId: 100,
      seasonNumber: 1,
      episodeNumber: 1,
      name: 'Episódio Piloto',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trackingRepositoryProvider.overrideWithValue(inMemoryRepo),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showEpisodeRatingAndReviewSheet(
                    context,
                    testShow.id,
                    testEpisode.seasonNumber,
                    testEpisode.episodeNumber,
                    testEpisode.name,
                    show: testShow,
                    episode: testEpisode,
                  );
                },
                child: const Text('Abrir Modal'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.tap(find.text('Abrir Modal'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify exactly one modal drag handle is rendered
    expect(find.byType(ModalDragHandle), findsOneWidget);

    // Verify Header texts
    expect(find.text('T1 • E1 — Episódio Piloto'), findsOneWidget);
    expect(find.text('O que achaste deste episódio?'), findsOneWidget);

    // Verify rating prompt initially present
    expect(find.text('Toca ou desliza para avaliar (0.5 a 10.0 ★)'),
        findsOneWidget);

    // Verify comment text field placeholder
    expect(
      find.text('Escreve a tua opinião sobre o episódio (opcional)...'),
      findsOneWidget,
    );

    // Verify spoiler toggle
    expect(find.text('Contém spoilers'), findsOneWidget);

    // Verify Action buttons
    expect(find.text('Agora não'), findsOneWidget);
    expect(find.text('Guardar'), findsOneWidget);

    // Tap "Agora não" to test dismissal without saving
    await tester.tap(find.text('Agora não'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Modal should be closed
    expect(find.text('O que achaste deste episódio?'), findsNothing);
  });

  testWidgets(
      'EpisodeReviewBottomSheet allows entering review, toggling spoilers and saving',
      (WidgetTester tester) async {
    final inMemoryRepo = InMemoryTrackingRepository();

    const testShow = ShowDetails(
      id: 100,
      name: 'Série Exemplo',
    );

    const testEpisode = Episode(
      id: 101,
      showId: 100,
      seasonNumber: 1,
      episodeNumber: 1,
      name: 'Episódio Piloto',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trackingRepositoryProvider.overrideWithValue(inMemoryRepo),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showEpisodeRatingAndReviewSheet(
                    context,
                    testShow.id,
                    testEpisode.seasonNumber,
                    testEpisode.episodeNumber,
                    testEpisode.name,
                    show: testShow,
                    episode: testEpisode,
                  );
                },
                child: const Text('Abrir Modal'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.tap(find.text('Abrir Modal'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Enter comment
    await tester.enterText(
      find.byType(TextField),
      'Episódio incrível com excelente banda sonora!',
    );
    await tester.pump();

    // Toggle spoilers
    await tester.tap(find.byType(Switch));
    await tester.pump();

    // Save
    await tester.tap(find.text('Guardar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify modal is closed
    expect(find.text('O que achaste deste episódio?'), findsNothing);
  });
}
