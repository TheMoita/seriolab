import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// Structured information about the application update state.
class AppUpdateInfo {
  const AppUpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseNotes,
    required this.apkDownloadUrl,
    required this.releaseHtmlUrl,
    required this.hasUpdate,
  });

  /// The version currently running on the device (e.g. "1.0.14").
  final String currentVersion;

  /// The latest available version on GitHub (e.g. "1.0.15").
  final String latestVersion;

  /// Release notes / changelog describing what's new.
  final String releaseNotes;

  /// Direct download URL for the APK asset (fallback to [releaseHtmlUrl] if absent).
  final String apkDownloadUrl;

  /// The GitHub release page URL.
  final String releaseHtmlUrl;

  /// Whether [latestVersion] is strictly greater than [currentVersion].
  final bool hasUpdate;
}

typedef PackageInfoFetcher = Future<PackageInfo> Function();

/// Service that checks for new GitHub releases and reports update status.
class UpdateService {
  UpdateService({
    http.Client? client,
    PackageInfoFetcher? packageInfoFetcher,
    this.owner = 'TheMoita',
    this.repo = 'seriolab',
  })  : _client = client ?? http.Client(),
        _packageInfoFetcher = packageInfoFetcher ?? PackageInfo.fromPlatform;

  final http.Client _client;
  final PackageInfoFetcher _packageInfoFetcher;
  final String owner;
  final String repo;

  /// Compares [remoteTag] against [currentVersion] following SemVer rules:
  /// - Strips leading 'v' / 'V'
  /// - Strips any suffix following '+' or '-' (e.g. 'v1.0.15+15' -> '1.0.15')
  /// - Splits by '.' into integer segments [major, minor, patch]
  /// - Checks:
  ///   - remote.major > current.major -> true
  ///   - remote.major == current.major && remote.minor > current.minor -> true
  ///   - remote.major == current.major && remote.minor == current.minor && remote.patch > current.patch -> true
  ///   - otherwise -> false
  static bool isUpdateAvailable(String currentVersion, String remoteTag) {
    if (remoteTag.trim().isEmpty) return false;

    List<int> parseSegments(String versionStr) {
      var s = versionStr.trim();
      if (s.startsWith('v') || s.startsWith('V')) {
        s = s.substring(1).trim();
      }

      // Remove any suffix after '+' or '-'
      if (s.contains('+')) {
        s = s.split('+').first.trim();
      }
      if (s.contains('-')) {
        s = s.split('-').first.trim();
      }

      final parts = s.split('.');
      final numbers = <int>[];
      for (final part in parts) {
        final digits = part.replaceAll(RegExp(r'[^\d]'), '');
        numbers.add(int.tryParse(digits) ?? 0);
      }
      while (numbers.length < 3) {
        numbers.add(0);
      }
      return numbers;
    }

    final current = parseSegments(currentVersion);
    final remote = parseSegments(remoteTag);

    final currentMajor = current[0];
    final currentMinor = current[1];
    final currentPatch = current[2];

    final remoteMajor = remote[0];
    final remoteMinor = remote[1];
    final remotePatch = remote[2];

    if (remoteMajor > currentMajor) return true;
    if (remoteMajor == currentMajor && remoteMinor > currentMinor) return true;
    if (remoteMajor == currentMajor &&
        remoteMinor == currentMinor &&
        remotePatch > currentPatch) {
      return true;
    }

    return false;
  }

  /// Fetches the latest release from GitHub and compares it with the local app version.
  Future<AppUpdateInfo?> checkForUpdates() async {
    try {
      final packageInfo = await _packageInfoFetcher();
      final currentVersion = packageInfo.version;

      final url = Uri.parse(
        'https://api.github.com/repos/$owner/$repo/releases/latest',
      );

      final headers = <String, String>{
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'Seriolab-App',
      };

      // Support optional token if configured (e.g. during testing or private repositories)
      try {
        final envToken = dotenv.isInitialized ? dotenv.env['GITHUB_TOKEN'] : null;
        if (envToken != null && envToken.isNotEmpty) {
          headers['Authorization'] = 'Bearer $envToken';
        }
      } catch (_) {}

      final response = await _client.get(
        url,
        headers: headers,
      );

      if (response.statusCode != 200) {
        debugPrint(
          '[UpdateService] Resposta da API do GitHub retornou status ${response.statusCode}: ${response.body}',
        );
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tagName = data['tag_name'] as String? ?? '';
      final body = data['body'] as String? ?? '';
      final htmlUrl = data['html_url'] as String? ??
          'https://github.com/$owner/$repo/releases';

      // Look for APK download URL in assets
      String apkUrl = '';
      final assets = data['assets'] as List<dynamic>? ?? [];
      for (final asset in assets) {
        if (asset is Map<String, dynamic>) {
          final name = (asset['name'] as String? ?? '').toLowerCase();
          final downloadUrl = asset['browser_download_url'] as String? ?? '';
          if (downloadUrl.isNotEmpty) {
            if (name.contains('seriolab') && name.endsWith('.apk')) {
              apkUrl = downloadUrl;
              break;
            } else if (name.endsWith('.apk') && apkUrl.isEmpty) {
              apkUrl = downloadUrl;
            }
          }
        }
      }

      if (apkUrl.isEmpty) {
        apkUrl = htmlUrl;
      }

      final hasUpdate = isUpdateAvailable(currentVersion, tagName);

      debugPrint('[UpdateService] Versão local lida: $currentVersion');
      debugPrint('[UpdateService] Tag recebida do GitHub: $tagName');
      debugPrint('[UpdateService] Resultado da comparação booleana: $hasUpdate');

      final cleanLatestVersion =
          tagName.startsWith('v') || tagName.startsWith('V')
              ? tagName.substring(1)
              : tagName;

      return AppUpdateInfo(
        currentVersion: currentVersion,
        latestVersion: cleanLatestVersion,
        releaseNotes: body,
        apkDownloadUrl: apkUrl,
        releaseHtmlUrl: htmlUrl,
        hasUpdate: hasUpdate,
      );
    } catch (e, stack) {
      debugPrint('[UpdateService] Erro ao verificar atualizações: $e\n$stack');
      return null;
    }
  }
}

/// Riverpod provider for [UpdateService].
final updateServiceProvider = Provider<UpdateService>((ref) {
  return UpdateService();
});
