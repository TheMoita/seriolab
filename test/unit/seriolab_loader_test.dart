import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:series_app/core/theme/app_theme.dart';
import 'package:series_app/core/widgets/seriolab_loader.dart';

void main() {
  group('SeriolabLoader widget tests', () {
    testWidgets('renders SeriolabLoader with default size 48', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SeriolabLoader(),
            ),
          ),
        ),
      );

      final loaderFinder = find.byType(SeriolabLoader);
      expect(loaderFinder, findsOneWidget);

      final customPaintFinder = find.descendant(
        of: loaderFinder,
        matching: find.byType(CustomPaint),
      );
      expect(customPaintFinder, findsOneWidget);

      final customPaint = tester.widget<CustomPaint>(customPaintFinder);
      expect(customPaint.size, const Size(48.0, 48.0));
    });

    testWidgets('renders SeriolabLoader with custom size and custom colors', (tester) async {
      const customSize = 64.0;
      final primary = AppColors.primary;
      final secondary = AppColors.secondary;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SeriolabLoader(
                size: customSize,
                primaryColor: primary,
                secondaryColor: secondary,
                strokeWidth: 3.0,
              ),
            ),
          ),
        ),
      );

      final customPaintFinder = find.descendant(
        of: find.byType(SeriolabLoader),
        matching: find.byType(CustomPaint),
      );
      expect(customPaintFinder, findsOneWidget);

      final customPaint = tester.widget<CustomPaint>(customPaintFinder);
      expect(customPaint.size, const Size(customSize, customSize));
    });

    testWidgets('animates and loops smoothly without throwing errors', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SeriolabLoader(),
            ),
          ),
        ),
      );

      // Advance frames across the 1.5s loop duration
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 1500));

      expect(find.byType(SeriolabLoader), findsOneWidget);
    });
  });
}
