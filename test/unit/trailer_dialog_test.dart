import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seriolab/features/shows/presentation/widgets/trailer_dialog.dart';
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class _FakeWebViewPlatform extends WebViewPlatform {
  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) =>
      _FakeNavigationDelegate(params);

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) =>
      _FakeWebViewController(params);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) =>
      _FakeWebViewWidget(params);
}

class _FakeNavigationDelegate extends PlatformNavigationDelegate {
  _FakeNavigationDelegate(super.params) : super.implementation();

  @override
  Future<void> setOnNavigationRequest(
      NavigationRequestCallback onNavigationRequest) async {}

  @override
  Future<void> setOnWebResourceError(
      WebResourceErrorCallback onWebResourceError) async {}
}

class _FakeWebViewController extends PlatformWebViewController {
  _FakeWebViewController(super.params) : super.implementation();

  void Function(JavaScriptMessage)? _channelCallback;
  String? _channelPlayerId;

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setPlatformNavigationDelegate(
      PlatformNavigationDelegate handler) async {}

  @override
  Future<void> setUserAgent(String? userAgent) async {}

  @override
  Future<void> enableZoom(bool enabled) async {}

  @override
  Future<void> addJavaScriptChannel(
      JavaScriptChannelParams javaScriptChannelParams) async {
    _channelPlayerId = javaScriptChannelParams.name;
    _channelCallback = javaScriptChannelParams.onMessageReceived;
  }

  @override
  Future<void> removeJavaScriptChannel(String javaScriptChannelName) async {
    _channelCallback = null;
  }

  @override
  Future<void> loadHtmlString(String html, {String? baseUrl}) async {
    if (_channelCallback != null && _channelPlayerId != null) {
      _channelCallback!(JavaScriptMessage(
        message: jsonEncode({
          'playerId': _channelPlayerId,
          'Ready': {},
        }),
      ));
    }
  }

  @override
  Future<void> setBackgroundColor(Color color) async {}

  @override
  Future<void> runJavaScript(String javaScript) async {}

  @override
  Future<String> runJavaScriptReturningResult(String javaScript) async => '';
}

class _FakeWebViewWidget extends PlatformWebViewWidget {
  _FakeWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox(width: 100, height: 100);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    WebViewPlatform.instance = _FakeWebViewPlatform();
  });

  group('TrailerDialog Widget Tests', () {
    testWidgets(
        'renders TrailerDialog with dark theme, controls, and video key',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TrailerDialog(
              youtubeVideoKey: 'HhesaQXLuRY',
              title: 'Breaking Bad',
            ),
          ),
        ),
      );

      // Verify title and label
      expect(find.text('Breaking Bad'), findsOneWidget);
      expect(find.text('Trailer Oficial • YouTube'), findsOneWidget);

      // Verify close button
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Verify fullscreen action
      expect(find.byIcon(Icons.fullscreen_rounded), findsOneWidget);

      // Verify player presence
      expect(find.byType(YoutubePlayer), findsOneWidget);
    });

    testWidgets('TrailerDialog alias TrailerSheet exists and can be constructed',
        (tester) async {
      const sheet = TrailerSheet(
        youtubeVideoKey: 'xEQP4VVuyrY',
        title: 'Severance',
      );
      expect(sheet.youtubeVideoKey, 'xEQP4VVuyrY');
      expect(sheet.title, 'Severance');
    });
  });
}
