import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:seriolab/core/services/update_service.dart';
import 'package:seriolab/core/widgets/modal_drag_handle.dart';
import 'package:seriolab/core/widgets/update_dialog.dart';

class MockHttpClient extends http.BaseClient {
  MockHttpClient(this._handler);
  final Future<http.Response> Function(http.BaseRequest request) _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _handler(request);
    return http.StreamedResponse(
      Stream.value(utf8.encode(response.body)),
      response.statusCode,
      headers: response.headers,
    );
  }
}

void main() {
  group('Semantic Version Comparison Tests', () {
    test('Correctly compares standard major, minor, patch versions', () {
      expect(
        UpdateService.isUpdateAvailable('1.0.14', '1.0.15'),
        isTrue,
      );

      expect(
        UpdateService.isUpdateAvailable('1.0.15', '1.0.14'),
        isFalse,
      );

      expect(
        UpdateService.isUpdateAvailable('1.0.14', '1.0.14'),
        isFalse,
      );

      expect(
        UpdateService.isUpdateAvailable('1.0.99', '1.1.0'),
        isTrue,
      );

      expect(
        UpdateService.isUpdateAvailable('1.9.9', '2.0.0'),
        isTrue,
      );
    });

    test('Handles v-prefix and whitespace gracefully', () {
      expect(
        UpdateService.isUpdateAvailable('1.0.14', 'v1.0.15'),
        isTrue,
      );

      expect(
        UpdateService.isUpdateAvailable('v1.0.15', '1.0.15'),
        isFalse,
      );

      expect(
        UpdateService.isUpdateAvailable(' 1.0.14 ', ' v1.0.15 '),
        isTrue,
      );
    });

    test('Handles build numbers (+ or -) correctly by stripping suffix', () {
      expect(
        UpdateService.isUpdateAvailable('1.0.14+14', '1.0.15+15'),
        isTrue,
      );

      expect(
        UpdateService.isUpdateAvailable('1.0.15+15', '1.0.14+14'),
        isFalse,
      );

      expect(
        UpdateService.isUpdateAvailable('1.0.14', 'v1.0.15+15'),
        isTrue,
      );

      expect(
        UpdateService.isUpdateAvailable('1.0.14-beta', '1.0.15'),
        isTrue,
      );

      expect(
        UpdateService.isUpdateAvailable('1.0.14+14', '1.0.14'),
        isFalse,
      );
    });

    test('Returns false for empty or invalid remote versions', () {
      expect(
        UpdateService.isUpdateAvailable('1.0.14', ''),
        isFalse,
      );
    });
  });

  group('Release Notes Sanitizer and Formatting Tests', () {
    test('Returns defaultReleaseNotes for null, empty or whitespace input', () {
      expect(
        UpdateService.formatReleaseNotes(null),
        UpdateService.defaultReleaseNotes,
      );
      expect(
        UpdateService.formatReleaseNotes(''),
        UpdateService.defaultReleaseNotes,
      );
      expect(
        UpdateService.formatReleaseNotes('   \n\n  \t '),
        UpdateService.defaultReleaseNotes,
      );
    });

    test('Strips markdown links, URLs, author tags, and PR mentions', () {
      const raw = '''
* feat: add comments by @themoita in https://github.com/themoita/seriolab/pull/12
* fix: crash on tap (#25) (see [PR #25](https://github.com/themoita/seriolab/pull/25))
* 7a3c89f perf: improve startup time
''';
      final formatted = UpdateService.formatReleaseNotes(raw);
      expect(formatted, contains('• New: Add comments'));
      expect(formatted, contains('• Fixes: Crash on tap'));
      expect(formatted, contains('• Improvements: Improve startup time'));
      expect(formatted, isNot(contains('@themoita')));
      expect(formatted, isNot(contains('https://')));
      expect(formatted, isNot(contains('7a3c89f')));
      expect(formatted, isNot(contains('#12')));
      expect(formatted, isNot(contains('#25')));
    });

    test('Converts Portuguese keywords into clean bullet categories', () {
      const raw = '''
- Novo: suporte a notificações em tempo real
- Novidades: feed comunitário aprimorado
- Correções: falha ao guardar série na biblioteca
- Melhorias: fluidez nas animações
''';
      final formatted = UpdateService.formatReleaseNotes(raw);
      expect(formatted, contains('• New: Suporte a notificações em tempo real'));
      expect(formatted, contains('• What\'s New: Feed comunitário aprimorado'));
      expect(formatted, contains('• Fixes: Falha ao guardar série na biblioteca'));
      expect(formatted, contains('• Improvements: Fluidez nas animações'));
    });

    test('Filters out automated GitHub text and section headings', () {
      const raw = '''
## What's Changed
* fix: episode progress calculation by @themoita in #10
## New Contributors
* @someone made their first contribution in #11
Merged pull request #12 from themoita/fix
* Dependabot bump dependencies
Full Changelog: https://github.com/themoita/seriolab/compare/v1.0.14...v1.0.15
''';
      final formatted = UpdateService.formatReleaseNotes(raw);
      expect(formatted, '• Fixes: Episode progress calculation');
      expect(formatted, isNot(contains("What's Changed")));
      expect(formatted, isNot(contains('Full Changelog')));
      expect(formatted, isNot(contains('Dependabot')));
      expect(formatted, isNot(contains('Merged pull request')));
    });

    test('Returns defaultReleaseNotes if release body only contains stripped technical data', () {
      const raw = '''
## What's Changed
* Merged pull request #10 from themoita/patch
* Full Changelog: https://github.com/themoita/seriolab/compare/v1.0.14...v1.0.15
''';
      expect(
        UpdateService.formatReleaseNotes(raw),
        UpdateService.defaultReleaseNotes,
      );
    });
  });

  group('UpdateService GitHub API tests', () {
    test('Parses latest GitHub release successfully with APK asset', () async {
      final mockReleaseJson = jsonEncode({
        'tag_name': 'v1.0.15',
        'body': 'Novidades incríveis na versão 1.0.15!',
        'html_url': 'https://github.com/TheMoita/seriolab/releases/tag/v1.0.15',
        'assets': [
          {
            'name': 'other_file.txt',
            'browser_download_url': 'https://example.com/other_file.txt',
          },
          {
            'name': 'seriolab-v1.0.15.apk',
            'browser_download_url':
                'https://github.com/TheMoita/seriolab/releases/download/v1.0.15/seriolab-v1.0.15.apk',
          },
        ],
      });

      final client = MockHttpClient((request) async {
        expect(request.url.toString(),
            'https://api.github.com/repos/TheMoita/seriolab/releases/latest');
        expect(request.headers['User-Agent'], 'Seriolab-App');
        return http.Response(mockReleaseJson, 200,
            headers: {'content-type': 'application/json'});
      });

      final service = UpdateService(
        client: client,
        packageInfoFetcher: () async => PackageInfo(
          appName: 'Seriolab',
          packageName: 'com.seriolab.app',
          version: '1.0.14',
          buildNumber: '14',
        ),
      );

      final result = await service.checkForUpdates();
      expect(result, isNotNull);
      expect(result!.currentVersion, '1.0.14');
      expect(result.latestVersion, '1.0.15');
      expect(result.releaseNotes, 'Novidades incríveis na versão 1.0.15!');
      expect(result.apkDownloadUrl,
          'https://github.com/TheMoita/seriolab/releases/download/v1.0.15/seriolab-v1.0.15.apk');
      expect(result.releaseHtmlUrl,
          'https://github.com/TheMoita/seriolab/releases/tag/v1.0.15');
      expect(result.hasUpdate, isTrue);
    });

    test('Falls back to html_url when no APK asset exists', () async {
      final mockReleaseJson = jsonEncode({
        'tag_name': 'v1.0.15',
        'body': 'Correções de erros.',
        'html_url': 'https://github.com/TheMoita/seriolab/releases/tag/v1.0.15',
        'assets': [],
      });

      final client = MockHttpClient((request) async {
        return http.Response(mockReleaseJson, 200,
            headers: {'content-type': 'application/json'});
      });

      final service = UpdateService(
        client: client,
        packageInfoFetcher: () async => PackageInfo(
          appName: 'Seriolab',
          packageName: 'com.seriolab.app',
          version: '1.0.15',
          buildNumber: '15',
        ),
      );

      final result = await service.checkForUpdates();
      expect(result, isNotNull);
      expect(result!.apkDownloadUrl,
          'https://github.com/TheMoita/seriolab/releases/tag/v1.0.15');
      expect(result.hasUpdate, isFalse);
    });

    test('Handles HTTP errors gracefully by returning null in checkForUpdates', () async {
      final client = MockHttpClient((request) async {
        return http.Response('Not Found', 404);
      });

      final service = UpdateService(
        client: client,
        packageInfoFetcher: () async => PackageInfo(
          appName: 'Seriolab',
          packageName: 'com.seriolab.app',
          version: '1.0.14',
          buildNumber: '14',
        ),
      );

      final result = await service.checkForUpdates();
      expect(result, isNull);
    });

    test('Falls back to /releases when /releases/latest returns 404', () async {
      final mockReleasesListJson = jsonEncode([
        {
          'tag_name': 'v1.0.16-draft',
          'draft': true,
          'body': 'Draft notes',
          'html_url': 'https://github.com/TheMoita/seriolab/releases/tag/v1.0.16-draft',
          'assets': [],
        },
        {
          'tag_name': 'v1.0.15',
          'draft': false,
          'body': 'Release published via tags',
          'html_url': 'https://github.com/TheMoita/seriolab/releases/tag/v1.0.15',
          'assets': [
            {
              'name': 'seriolab-release.apk',
              'browser_download_url':
                  'https://github.com/TheMoita/seriolab/releases/download/v1.0.15/seriolab-release.apk',
            },
          ],
        },
      ]);

      final client = MockHttpClient((request) async {
        if (request.url.path.endsWith('/releases/latest')) {
          return http.Response('Not Found', 404);
        }
        if (request.url.path.endsWith('/releases')) {
          return http.Response(mockReleasesListJson, 200,
              headers: {'content-type': 'application/json'});
        }
        return http.Response('Not Found', 404);
      });

      final service = UpdateService(
        client: client,
        packageInfoFetcher: () async => PackageInfo(
          appName: 'Seriolab',
          packageName: 'com.seriolab.app',
          version: '1.0.14+14',
          buildNumber: '14',
        ),
      );

      final result = await service.checkForUpdatesResult();
      expect(result.status, UpdateCheckStatus.hasUpdate);
      expect(result.updateInfo, isNotNull);
      expect(result.updateInfo!.latestVersion, '1.0.15');
      expect(result.updateInfo!.currentVersion, '1.0.14');
      expect(result.updateInfo!.hasUpdate, isTrue);
    });

    test('Returns noReleaseFound when 404 on both latest and releases', () async {
      final client = MockHttpClient((request) async {
        return http.Response('Not Found', 404);
      });

      final service = UpdateService(
        client: client,
        packageInfoFetcher: () async => PackageInfo(
          appName: 'Seriolab',
          packageName: 'com.seriolab.app',
          version: '1.0.14',
          buildNumber: '14',
        ),
      );

      final result = await service.checkForUpdatesResult();
      expect(result.status, UpdateCheckStatus.noReleaseFound);
      expect(result.errorMessage, 'No releases found in repository.');
      expect(result.statusCode, 404);
    });

    test('Returns rateLimitExceeded on HTTP 403', () async {
      final client = MockHttpClient((request) async {
        return http.Response('API rate limit exceeded', 403);
      });

      final service = UpdateService(
        client: client,
        packageInfoFetcher: () async => PackageInfo(
          appName: 'Seriolab',
          packageName: 'com.seriolab.app',
          version: '1.0.14',
          buildNumber: '14',
        ),
      );

      final result = await service.checkForUpdatesResult();
      expect(result.status, UpdateCheckStatus.rateLimitExceeded);
      expect(result.errorMessage, 'GitHub API rate limit exceeded. Please try again later.');
      expect(result.statusCode, 403);
    });

    test('Returns networkError on client network exception', () async {
      final client = MockHttpClient((request) async {
        throw http.ClientException('Failed to connect to host');
      });

      final service = UpdateService(
        client: client,
        packageInfoFetcher: () async => PackageInfo(
          appName: 'Seriolab',
          packageName: 'com.seriolab.app',
          version: '1.0.14',
          buildNumber: '14',
        ),
      );

      final result = await service.checkForUpdatesResult();
      expect(result.status, UpdateCheckStatus.networkError);
      expect(result.errorMessage, 'No internet connection.');
    });

    test('executeOtaUpdate delegates to OtaUpdate with destinationFilename', () {
      final controller = StreamController<OtaEvent>.broadcast();
      String? capturedUrl;
      String? capturedFilename;
      final fakeOta = FakeOtaUpdate(
        streamBuilder: (url, filename) {
          capturedUrl = url;
          capturedFilename = filename;
          return controller.stream;
        },
      );

      final service = UpdateService(otaUpdate: fakeOta);
      final stream = service.executeOtaUpdate('https://example.com/app.apk');
      expect(stream, isNotNull);
      expect(capturedUrl, 'https://example.com/app.apk');
      expect(capturedFilename, 'seriolab-update.apk');
      controller.close();
    });
  });

  group('UpdateBottomSheet Widget Tests', () {
    testWidgets('Renders all required elements and dismisses on tap',
        (tester) async {
      var dismissed = false;
      const updateInfo = AppUpdateInfo(
        currentVersion: '1.0.14',
        latestVersion: '1.0.15',
        releaseNotes: '- Novo: leitor de atualizações\n- Fix: bugs',
        apkDownloadUrl: 'https://example.com/seriolab.apk',
        releaseHtmlUrl: 'https://example.com/release',
        hasUpdate: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UpdateBottomSheet(
              updateInfo: updateInfo,
              onDismiss: () {
                dismissed = true;
              },
            ),
          ),
        ),
      );

      // Verify single ModalDragHandle
      expect(find.byType(ModalDragHandle), findsOneWidget);

      // Verify Title
      expect(find.text('New Update Available'), findsOneWidget);

      // Verify version badge
      expect(find.text('v1.0.15'), findsOneWidget);

      // Verify subtitle
      expect(find.text('See what changed in this version:'), findsOneWidget);

      // Verify formatted release notes
      expect(
        find.text('• New: Leitor de atualizações\n• Fixes: Bugs'),
        findsOneWidget,
      );

      // Verify "Update Now" button
      expect(find.text('Update Now'), findsOneWidget);

      // Verify "Later" button
      final laterButton = find.text('Later');
      expect(laterButton, findsOneWidget);

      await tester.tap(laterButton);
      await tester.pump();
      expect(dismissed, isTrue);
    });

    testWidgets('Tapping "Atualizar Agora" enters downloading state and updates progress',
        (tester) async {
      final controller = StreamController<OtaEvent>.broadcast();
      final fakeOta = FakeOtaUpdate(
        streamBuilder: (url, filename) {
          expect(url, 'https://example.com/seriolab-v1.0.15.apk');
          expect(filename, 'seriolab-update.apk');
          return controller.stream;
        },
      );

      const updateInfo = AppUpdateInfo(
        currentVersion: '1.0.14',
        latestVersion: '1.0.15',
        releaseNotes: 'Melhorias de desempenho',
        apkDownloadUrl: 'https://example.com/seriolab-v1.0.15.apk',
        releaseHtmlUrl: 'https://example.com/release',
        hasUpdate: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UpdateBottomSheet(
              updateInfo: updateInfo,
              otaUpdate: fakeOta,
            ),
          ),
        ),
      );

      final updateButton = find.text('Update Now');
      expect(updateButton, findsOneWidget);

      await tester.tap(updateButton);
      await tester.pump();

      // Emit downloading event at 45%
      controller.add(OtaEvent(OtaStatus.DOWNLOADING, '45'));
      await tester.pump();

      expect(find.text('Downloading Update...'), findsOneWidget);
      expect(find.text('45%'), findsOneWidget);
      expect(find.text('Cancel Download'), findsOneWidget);

      // Emit installing event
      controller.add(OtaEvent(OtaStatus.INSTALLING, null));
      await tester.pump();

      expect(find.text('Starting Installation'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);

      await controller.close();
    });

    testWidgets('Displays error message and browser fallback button on permission error',
        (tester) async {
      final controller = StreamController<OtaEvent>.broadcast();
      final fakeOta = FakeOtaUpdate(
        streamBuilder: (url, filename) => controller.stream,
      );

      const updateInfo = AppUpdateInfo(
        currentVersion: '1.0.14',
        latestVersion: '1.0.15',
        releaseNotes: 'Melhorias de desempenho',
        apkDownloadUrl: 'https://example.com/seriolab-v1.0.15.apk',
        releaseHtmlUrl: 'https://example.com/release',
        hasUpdate: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UpdateBottomSheet(
              updateInfo: updateInfo,
              otaUpdate: fakeOta,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Update Now'));
      await tester.pump();

      // Emit permission not granted error
      controller.add(OtaEvent(OtaStatus.PERMISSION_NOT_GRANTED_ERROR, null));
      await tester.pump();

      expect(
        find.textContaining('Install permission required'),
        findsOneWidget,
      );
      expect(find.text('Download in Browser'), findsOneWidget);
      expect(find.text('Update Now'), findsOneWidget);

      await controller.close();
    });

    testWidgets('Tapping "Cancelar Transferência" restores initial view',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = StreamController<OtaEvent>.broadcast();
      final fakeOta = FakeOtaUpdate(
        streamBuilder: (url, filename) => controller.stream,
      );

      const updateInfo = AppUpdateInfo(
        currentVersion: '1.0.14',
        latestVersion: '1.0.15',
        releaseNotes: 'Melhorias de desempenho',
        apkDownloadUrl: 'https://example.com/seriolab-v1.0.15.apk',
        releaseHtmlUrl: 'https://example.com/release',
        hasUpdate: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UpdateBottomSheet(
              updateInfo: updateInfo,
              otaUpdate: fakeOta,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Update Now'));
      await tester.pump();

      controller.add(OtaEvent(OtaStatus.DOWNLOADING, '20'));
      await tester.pump();

      final cancelButton = find.text('Cancel Download');
      expect(cancelButton, findsOneWidget);

      await tester.ensureVisible(cancelButton);
      await tester.tap(cancelButton);
      await tester.pump();
      await tester.pump();

      expect(find.text('Update Now'), findsOneWidget);
      expect(find.text('New Update Available'), findsOneWidget);

      await controller.close();
    });
  });
}

class FakeOtaUpdate extends OtaUpdate {
  FakeOtaUpdate({required this.streamBuilder});
  final Stream<OtaEvent> Function(String url, String? filename) streamBuilder;

  @override
  Stream<OtaEvent> execute(
    String url, {
    Map<String, String> headers = const <String, String>{},
    String? androidProviderAuthority,
    String? destinationFilename,
    String? sha256checksum,
    bool usePackageInstaller = false,
  }) {
    return streamBuilder(url, destinationFilename);
  }
}

