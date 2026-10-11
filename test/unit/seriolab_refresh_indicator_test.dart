import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seriolab/core/widgets/seriolab_loader.dart';
import 'package:seriolab/core/widgets/seriolab_refresh_indicator.dart';

void main() {
  group('SeriolabRefreshIndicator widget tests', () {
    testWidgets('renders child and CustomRefreshIndicator', (tester) async {
      var refreshed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SeriolabRefreshIndicator(
              onRefresh: () async {
                refreshed = true;
              },
              child: ListView(
                children: const [
                  Text('Item 1'),
                  Text('Item 2'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Item 1'), findsOneWidget);
      expect(find.byType(CustomRefreshIndicator), findsOneWidget);
      expect(refreshed, isFalse);
    });

    testWidgets('shows SeriolabLoader on pull-to-refresh and calls onRefresh',
        (tester) async {
      var refreshCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SeriolabRefreshIndicator(
              onRefresh: () async {
                refreshCalled = true;
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(
                    height: 100,
                    child: Text('Pull Target'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Perform downward drag
      await tester.drag(find.text('Pull Target'), const Offset(0, 300));
      await tester.pump();

      // SeriolabLoader should be displayed while pulled/refreshing
      expect(find.byType(SeriolabLoader), findsOneWidget);

      await tester.pumpAndSettle();
      expect(refreshCalled, isTrue);
    });
  });
}
