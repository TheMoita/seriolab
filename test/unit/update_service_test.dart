import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
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

    test('Handles HTTP errors gracefully by returning null', () async {
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
  });

  group('UpdateBottomSheet Widget Tests', () {
    testWidgets('Renders all required elements and dismisses on tap',
        (tester) async {
      var dismissed = false;
      const updateInfo = AppUpdateInfo(
        currentVersion: '1.0.14',
        latestVersion: '1.0.15',
        releaseNotes: '- Novo leitor de atualizações\n- Correções de bugs',
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
      expect(find.text('Nova Versão Disponível'), findsOneWidget);

      // Verify version badge
      expect(find.text('v1.0.15'), findsOneWidget);

      // Verify dynamic text with remote and current versions
      expect(
        find.text(
          'Uma nova versão (v1.0.15) está pronta para download. A tua versão atual é a v1.0.14.',
        ),
        findsOneWidget,
      );

      // Verify release notes
      expect(
        find.text('- Novo leitor de atualizações\n- Correções de bugs'),
        findsOneWidget,
      );

      // Verify "Atualizar Agora" button
      expect(find.text('Atualizar Agora'), findsOneWidget);

      // Verify "Mais Tarde" button
      final laterButton = find.text('Mais Tarde');
      expect(laterButton, findsOneWidget);

      await tester.tap(laterButton);
      await tester.pump();
      expect(dismissed, isTrue);
    });
  });
}
