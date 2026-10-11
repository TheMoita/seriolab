import 'dart:convert';
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

/// Helper class to parse and compare semantic version strings.
class ParsedVersion implements Comparable<ParsedVersion> {
  const ParsedVersion({
    required this.numbers,
    this.buildNumber,
  });

  final List<int> numbers;
  final int? buildNumber;

  factory ParsedVersion.parse(String raw) {
    var s = raw.trim();
    if (s.startsWith('v') || s.startsWith('V')) {
      s = s.substring(1).trim();
    }

    int? build;
    if (s.contains('+')) {
      final plusIndex = s.indexOf('+');
      final buildStr = s.substring(plusIndex + 1);
      s = s.substring(0, plusIndex);
      build = int.tryParse(buildStr);
    } else if (s.contains('-')) {
      final dashIndex = s.indexOf('-');
      final dashStr = s.substring(dashIndex + 1);
      s = s.substring(0, dashIndex);
      build = int.tryParse(dashStr);
    }

    final segments = s.split('.');
    final numbers = <int>[];
    for (final seg in segments) {
      final digitsOnly = seg.replaceAll(RegExp(r'[^\d]'), '');
      if (digitsOnly.isNotEmpty) {
        numbers.add(int.parse(digitsOnly));
      } else {
        numbers.add(0);
      }
    }
    while (numbers.length < 3) {
      numbers.add(0);
    }

    return ParsedVersion(numbers: numbers, buildNumber: build);
  }

  @override
  int compareTo(ParsedVersion other) {
    final maxLen = numbers.length > other.numbers.length
        ? numbers.length
        : other.numbers.length;
    for (var i = 0; i < maxLen; i++) {
      final num1 = i < numbers.length ? numbers[i] : 0;
      final num2 = i < other.numbers.length ? other.numbers[i] : 0;
      if (num1 != num2) {
        return num1.compareTo(num2);
      }
    }
    final b1 = buildNumber ?? 0;
    final b2 = other.buildNumber ?? 0;
    return b1.compareTo(b2);
  }
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

  /// Fetches the latest release from GitHub and compares it with the local app version.
  Future<AppUpdateInfo?> checkForUpdates() async {
    try {
      final packageInfo = await _packageInfoFetcher();
      final currentVersion = packageInfo.version;
      final currentFullVersion = packageInfo.buildNumber.isNotEmpty
          ? '${packageInfo.version}+${packageInfo.buildNumber}'
          : packageInfo.version;

      final url = Uri.parse(
        'https://api.github.com/repos/$owner/$repo/releases/latest',
      );
      final response = await _client.get(
        url,
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'Seriolab-App',
        },
      );

      if (response.statusCode != 200) {
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

      final hasUpdate = isUpdateAvailable(
        currentVersion: currentFullVersion,
        latestVersion: tagName,
      );

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
    } catch (_) {
      return null;
    }
  }

  /// Compares [latestVersion] against [currentVersion] semantically.
  static bool isUpdateAvailable({
    required String currentVersion,
    required String latestVersion,
  }) {
    if (latestVersion.isEmpty) return false;
    final curr = ParsedVersion.parse(currentVersion);
    final latest = ParsedVersion.parse(latestVersion);
    return latest.compareTo(curr) > 0;
  }
}

/// Riverpod provider for [UpdateService].
final updateServiceProvider = Provider<UpdateService>((ref) {
  return UpdateService();
});
