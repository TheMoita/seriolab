import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seriolab/core/theme/app_theme.dart';
import 'package:seriolab/core/widgets/modal_drag_handle.dart';
import 'package:seriolab/features/settings/presentation/widgets/avatar_selection_sheet.dart';
import 'package:seriolab/features/shows/presentation/widgets/rating_modal.dart';

void main() {
  group('ModalDragHandle widget tests', () {
    testWidgets('ModalDragHandle renders with correct dimensions and soft gray color',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ModalDragHandle(),
          ),
        ),
      );

      final handleFinder = find.byType(ModalDragHandle);
      expect(handleFinder, findsOneWidget);

      final containerFinder = find.descendant(
        of: handleFinder,
        matching: find.byType(Container),
      );
      expect(containerFinder, findsOneWidget);

      final containerWidget = tester.widget<Container>(containerFinder);
      expect(containerWidget.constraints?.minWidth, 38.0);
      expect(containerWidget.constraints?.maxWidth, 38.0);
      expect(containerWidget.constraints?.minHeight, 4.0);
      expect(containerWidget.constraints?.maxHeight, 4.0);

      final decoration = containerWidget.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFF4B5563));
      expect(decoration.borderRadius, BorderRadius.circular(2));
    });

    test('AppTheme has showDragHandle set to false on bottomSheetTheme', () {
      final theme = AppTheme.dark();
      expect(theme.bottomSheetTheme.showDragHandle, isFalse);
    });

    testWidgets('AvatarSelectionSheet renders strictly ONE ModalDragHandle',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AvatarSelectionSheet(),
            ),
          ),
        ),
      );

      final dragHandles = find.byType(ModalDragHandle);
      expect(dragHandles, findsOneWidget);
    });

    testWidgets('RatingModal renders strictly ONE ModalDragHandle',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: RatingModal(
                title: 'Test Show',
                itemName: 'Episode 1',
                initialRating: 8.0,
              ),
            ),
          ),
        ),
      );

      final dragHandles = find.byType(ModalDragHandle);
      expect(dragHandles, findsOneWidget);
    });
  });
}
