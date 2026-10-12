import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:seriolab/core/services/update_service.dart';
import 'package:seriolab/features/settings/presentation/screens/settings_screen.dart';

class _FakeUpdateService extends UpdateService {
  _FakeUpdateService(this._result);
  final UpdateCheckResult _result;

  @override
  Future<UpdateCheckResult> checkForUpdatesResult() async {
    return _result;
  }
}

void main() {
  group('SettingsScreen Manual Update Feedback Tests', () {
    setUp(() {
      PackageInfo.setMockInitialValues(
        appName: 'Seriolab',
        packageName: 'com.seriolab.app',
        version: '1.0.14',
        buildNumber: '14',
        buildSignature: '',
      );
    });

    testWidgets('Displays "You have the latest version installed" when app is up to date',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const fakeResult = UpdateCheckResult(
        status: UpdateCheckStatus.upToDate,
        currentVersion: '1.0.14',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            updateServiceProvider.overrideWithValue(_FakeUpdateService(fakeResult)),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final checkTile = find.text('Check for Updates');
      expect(checkTile, findsOneWidget);

      await tester.tap(checkTile);
      await tester.pumpAndSettle();

      expect(
        find.text('You have the latest version installed (v1.0.14).'),
        findsOneWidget,
      );
    });

    testWidgets('Displays "No releases found in the repository." when 404',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const fakeResult = UpdateCheckResult(
        status: UpdateCheckStatus.noReleaseFound,
        statusCode: 404,
        errorMessage: 'No releases found in the repository.',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            updateServiceProvider.overrideWithValue(_FakeUpdateService(fakeResult)),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final checkTile = find.text('Check for Updates');
      await tester.tap(checkTile);
      await tester.pumpAndSettle();

      expect(
        find.text('No releases found in the repository.'),
        findsOneWidget,
      );
    });

    testWidgets('Displays "No internet connection." on network connectivity error',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const fakeResult = UpdateCheckResult(
        status: UpdateCheckStatus.networkError,
        errorMessage: 'No internet connection.',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            updateServiceProvider.overrideWithValue(_FakeUpdateService(fakeResult)),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final checkTile = find.text('Check for Updates');
      await tester.tap(checkTile);
      await tester.pumpAndSettle();

      expect(
        find.text('No internet connection.'),
        findsOneWidget,
      );
    });
  });
}
