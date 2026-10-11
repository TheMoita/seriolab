import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
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

/// Status of the update check operation.
enum UpdateCheckStatus {
  /// A newer release is available.
  hasUpdate,

  /// Current installation is up to date.
  upToDate,

  /// No releases found on GitHub repository (or repo is private / 404).
  noReleaseFound,

  /// GitHub API rate limit exceeded (HTTP 403).
  rateLimitExceeded,

  /// Real network connectivity error (e.g. SocketException, ClientException).
  networkError,

  /// Other unexpected error.
  unknownError,
}

/// Detailed result of an update check.
class UpdateCheckResult {
  const UpdateCheckResult({
    required this.status,
    this.updateInfo,
    this.currentVersion = '',
    this.errorMessage,
    this.statusCode,
  });

  final UpdateCheckStatus status;
  final AppUpdateInfo? updateInfo;
  final String currentVersion;
  final String? errorMessage;
  final int? statusCode;

  bool get hasUpdate => status == UpdateCheckStatus.hasUpdate;
}

typedef PackageInfoFetcher = Future<PackageInfo> Function();

/// Service that checks for new GitHub releases and reports update status.
class UpdateService {
  UpdateService({
    http.Client? client,
    PackageInfoFetcher? packageInfoFetcher,
    OtaUpdate? otaUpdate,
    String? owner,
    String? repo,
  })  : _client = client ?? http.Client(),
        _packageInfoFetcher = packageInfoFetcher ?? PackageInfo.fromPlatform,
        _otaUpdate = otaUpdate ?? OtaUpdate(),
        owner = owner ?? _resolveOwner(),
        repo = repo ?? _resolveRepo();

  final http.Client _client;
  final PackageInfoFetcher _packageInfoFetcher;
  final OtaUpdate _otaUpdate;
  final String owner;
  final String repo;

  /// Executes an In-App OTA download of the APK and launches the Android package installer.
  Stream<OtaEvent> executeOtaUpdate(
    String downloadUrl, {
    String destinationFilename = 'seriolab-update.apk',
  }) {
    return _otaUpdate.execute(
      downloadUrl,
      destinationFilename: destinationFilename,
    );
  }

  static String _resolveOwner() {
    try {
      if (dotenv.isInitialized && (dotenv.env['GITHUB_OWNER']?.isNotEmpty ?? false)) {
        return dotenv.env['GITHUB_OWNER']!;
      }
    } catch (_) {}
    return 'TheMoita';
  }

  static String _resolveRepo() {
    try {
      if (dotenv.isInitialized && (dotenv.env['GITHUB_REPO']?.isNotEmpty ?? false)) {
        return dotenv.env['GITHUB_REPO']!;
      }
    } catch (_) {}
    return 'seriolab';
  }

  /// Robust SemVer comparison:
  /// - Strips leading 'v' / 'V'
  /// - Strips any suffix following '+' or '-' (e.g. '1.0.14+14' -> '1.0.14')
  /// - Splits by '.' into integer segments [major, minor, patch]
  /// - Compares segment by segment
  static bool isRemoteVersionNewer(String local, String remote) {
    if (remote.trim().isEmpty) return false;

    final cleanLocal = local
        .trim()
        .replaceAll(RegExp(r'^[vV]'), '')
        .split('+')
        .first
        .split('-')
        .first
        .trim();
    final cleanRemote = remote
        .trim()
        .replaceAll(RegExp(r'^[vV]'), '')
        .split('+')
        .first
        .split('-')
        .first
        .trim();

    final localParts =
        cleanLocal.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final remoteParts =
        cleanRemote.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    while (localParts.length < 3) {
      localParts.add(0);
    }
    while (remoteParts.length < 3) {
      remoteParts.add(0);
    }

    for (int i = 0; i < 3; i++) {
      if (remoteParts[i] > localParts[i]) return true;
      if (remoteParts[i] < localParts[i]) return false;
    }
    return false;
  }

  /// Alias for backward compatibility.
  static bool isUpdateAvailable(String currentVersion, String remoteTag) =>
      isRemoteVersionNewer(currentVersion, remoteTag);

  /// Fetches the latest release from GitHub and returns a structured [UpdateCheckResult].
  Future<UpdateCheckResult> checkForUpdatesResult() async {
    String currentVersion = '';
    try {
      final packageInfo = await _packageInfoFetcher();
      currentVersion = packageInfo.version;
    } catch (e) {
      debugPrint('[UpdateService] Erro ao ler PackageInfo: $e');
    }

    final cleanLocalVersion = currentVersion
        .trim()
        .replaceAll(RegExp(r'^[vV]'), '')
        .split('+')
        .first
        .split('-')
        .first
        .trim();

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

    try {
      // 1. Try /releases/latest endpoint first
      final latestUrl = Uri.parse(
        'https://api.github.com/repos/$owner/$repo/releases/latest',
      );
      debugPrint('[UpdateService] Request GET $latestUrl');

      http.Response response = await _client.get(
        latestUrl,
        headers: headers,
      );

      debugPrint(
        '[UpdateService] Resposta da API do GitHub ($latestUrl) - Status Code: ${response.statusCode}',
      );
      debugPrint('[UpdateService] Corpo da resposta: ${response.body}');

      Map<String, dynamic>? releaseData;

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          releaseData = decoded;
        }
      } else if (response.statusCode == 404) {
        // Fallback: Check list of releases at /releases to find first non-draft release
        final releasesUrl = Uri.parse(
          'https://api.github.com/repos/$owner/$repo/releases',
        );
        debugPrint(
          '[UpdateService] Endpoint /releases/latest retornou 404. A tentar fallback em: $releasesUrl',
        );

        final fallbackResponse = await _client.get(
          releasesUrl,
          headers: headers,
        );

        debugPrint(
          '[UpdateService] Resposta da API do GitHub ($releasesUrl) - Status Code: ${fallbackResponse.statusCode}',
        );
        debugPrint('[UpdateService] Corpo da resposta: ${fallbackResponse.body}');

        if (fallbackResponse.statusCode == 200) {
          final decodedList = jsonDecode(fallbackResponse.body);
          if (decodedList is List && decodedList.isNotEmpty) {
            for (final item in decodedList) {
              if (item is Map<String, dynamic> && item['draft'] != true) {
                releaseData = item;
                break;
              }
            }
          }
        } else {
          response = fallbackResponse;
        }
      }

      if (releaseData == null) {
        if (response.statusCode == 404) {
          debugPrint(
            '[UpdateService] Repositório privado ou sem releases públicas encontradas no GitHub (404)',
          );
          return UpdateCheckResult(
            status: UpdateCheckStatus.noReleaseFound,
            statusCode: 404,
            currentVersion: cleanLocalVersion,
            errorMessage: 'Nenhuma versão encontrada no repositório.',
          );
        } else if (response.statusCode == 403) {
          debugPrint('[UpdateService] Rate Limit da API do GitHub atingido (403)');
          return UpdateCheckResult(
            status: UpdateCheckStatus.rateLimitExceeded,
            statusCode: 403,
            currentVersion: cleanLocalVersion,
            errorMessage: 'Limite de pedidos ao GitHub atingido. Tenta mais tarde.',
          );
        } else {
          debugPrint(
            '[UpdateService] Resposta não tratada da API do GitHub: Status ${response.statusCode}',
          );
          return UpdateCheckResult(
            status: UpdateCheckStatus.unknownError,
            statusCode: response.statusCode,
            currentVersion: cleanLocalVersion,
            errorMessage: 'Não foi possível verificar atualizações de momento.',
          );
        }
      }

      final tagName = releaseData['tag_name'] as String? ?? '';
      final body = releaseData['body'] as String? ?? '';
      final htmlUrl = releaseData['html_url'] as String? ??
          'https://github.com/$owner/$repo/releases';

      // Look for APK download URL in assets
      String apkUrl = '';
      final assets = releaseData['assets'] as List<dynamic>? ?? [];
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

      final hasUpdate = isRemoteVersionNewer(cleanLocalVersion, tagName);

      debugPrint('[UpdateService] Versão local lida: $cleanLocalVersion');
      debugPrint('[UpdateService] Tag recebida do GitHub: $tagName');
      debugPrint('[UpdateService] Resultado da comparação booleana: $hasUpdate');

      final cleanLatestVersion = tagName
          .replaceAll(RegExp(r'^[vV]'), '')
          .split('+')
          .first
          .split('-')
          .first
          .trim();

      final updateInfo = AppUpdateInfo(
        currentVersion: cleanLocalVersion,
        latestVersion: cleanLatestVersion,
        releaseNotes: body,
        apkDownloadUrl: apkUrl,
        releaseHtmlUrl: htmlUrl,
        hasUpdate: hasUpdate,
      );

      return UpdateCheckResult(
        status: hasUpdate ? UpdateCheckStatus.hasUpdate : UpdateCheckStatus.upToDate,
        updateInfo: updateInfo,
        currentVersion: cleanLocalVersion,
        statusCode: 200,
      );
    } on SocketException catch (e) {
      debugPrint('[UpdateService] Erro real de rede (SocketException): $e');
      return UpdateCheckResult(
        status: UpdateCheckStatus.networkError,
        currentVersion: cleanLocalVersion,
        errorMessage: 'Sem ligação à internet.',
      );
    } on http.ClientException catch (e) {
      debugPrint('[UpdateService] Erro de cliente HTTP (ClientException): $e');
      return UpdateCheckResult(
        status: UpdateCheckStatus.networkError,
        currentVersion: cleanLocalVersion,
        errorMessage: 'Sem ligação à internet.',
      );
    } catch (e, stack) {
      debugPrint('[UpdateService] Erro ao verificar atualizações: $e\n$stack');
      return UpdateCheckResult(
        status: UpdateCheckStatus.unknownError,
        currentVersion: cleanLocalVersion,
        errorMessage: 'Não foi possível verificar atualizações de momento.',
      );
    }
  }

  /// Backward-compatible method returning [AppUpdateInfo] or null.
  Future<AppUpdateInfo?> checkForUpdates() async {
    final result = await checkForUpdatesResult();
    return result.updateInfo;
  }
}

/// Riverpod provider for [UpdateService].
final updateServiceProvider = Provider<UpdateService>((ref) {
  return UpdateService();
});
