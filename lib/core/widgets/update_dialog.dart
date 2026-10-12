import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/update_service.dart';
import '../theme/app_theme.dart';
import 'modal_drag_handle.dart';
import 'seriolab_loader.dart';

/// Seriolab Update Bottom Sheet alerting users of new releases available on GitHub
/// with In-App OTA (Over-The-Air) download and direct package installer launch.
class UpdateBottomSheet extends StatefulWidget {
  const UpdateBottomSheet({
    super.key,
    required this.updateInfo,
    this.onDismiss,
    this.otaUpdate,
  });

  final AppUpdateInfo updateInfo;
  final VoidCallback? onDismiss;
  final OtaUpdate? otaUpdate;

  /// Shows the styled update bottom sheet.
  static Future<void> show(
    BuildContext context,
    AppUpdateInfo updateInfo, {
    OtaUpdate? otaUpdate,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      showDragHandle: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => UpdateBottomSheet(
        updateInfo: updateInfo,
        otaUpdate: otaUpdate,
        onDismiss: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  @override
  State<UpdateBottomSheet> createState() => _UpdateBottomSheetState();
}

class _UpdateBottomSheetState extends State<UpdateBottomSheet> {
  bool _isDownloading = false;
  bool _isInstalling = false;
  int _progress = 0;
  String? _errorMessage;
  StreamSubscription<OtaEvent>? _otaSubscription;

  @override
  void dispose() {
    _otaSubscription?.cancel();
    super.dispose();
  }

  void _cancelDownload() {
    _otaSubscription?.cancel();
    _otaSubscription = null;
    if (mounted) {
      setState(() {
        _isDownloading = false;
        _isInstalling = false;
        _progress = 0;
      });
    }
  }

  Future<void> _startOtaUpdate() async {
    // If not running on Android, fallback to browser
    if (defaultTargetPlatform != TargetPlatform.android) {
      await _launchBrowserFallback();
      return;
    }

    final downloadUrl = widget.updateInfo.apkDownloadUrl;
    final isApk = downloadUrl.toLowerCase().contains('.apk');
    if (!isApk) {
      // If no direct APK binary asset is available, fallback to browser
      await _launchBrowserFallback();
      return;
    }

    setState(() {
      _isDownloading = true;
      _isInstalling = false;
      _progress = 0;
      _errorMessage = null;
    });

    try {
      final ota = widget.otaUpdate ?? OtaUpdate();
      _otaSubscription?.cancel();
      _otaSubscription = ota.execute(
        downloadUrl,
        destinationFilename: 'seriolab-update.apk',
      ).listen(
        (OtaEvent event) {
          if (!mounted) return;
          switch (event.status) {
            case OtaStatus.DOWNLOADING:
              final percent = int.tryParse(event.value ?? '0') ?? 0;
              setState(() {
                _isDownloading = true;
                _isInstalling = false;
                _progress = percent.clamp(0, 100);
              });
              break;

            case OtaStatus.INSTALLING:
              setState(() {
                _isDownloading = false;
                _isInstalling = true;
                _progress = 100;
              });
              break;

            case OtaStatus.ALREADY_RUNNING_ERROR:
              setState(() {
                _isDownloading = false;
                _isInstalling = false;
                _errorMessage =
                    'Update download is already running.';
              });
              break;

            case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
              setState(() {
                _isDownloading = false;
                _isInstalling = false;
                _errorMessage =
                    'Install permission required. Enable "Install unknown apps" in Android Settings.';
              });
              break;

            case OtaStatus.DOWNLOAD_ERROR:
              setState(() {
                _isDownloading = false;
                _isInstalling = false;
                _errorMessage =
                    'Failed to download the APK file. Check your connection or download via browser.';
              });
              break;

            case OtaStatus.CHECKSUM_ERROR:
              setState(() {
                _isDownloading = false;
                _isInstalling = false;
                _errorMessage =
                    'APK file checksum verification failed.';
              });
              break;

            case OtaStatus.INSTALLATION_DONE:
              setState(() {
                _isDownloading = false;
                _isInstalling = false;
                _progress = 100;
              });
              break;

            case OtaStatus.INSTALLATION_ERROR:
              setState(() {
                _isDownloading = false;
                _isInstalling = false;
                _errorMessage =
                    'Failed to install update. You can try downloading from the browser.';
              });
              break;

            case OtaStatus.CANCELED:
              setState(() {
                _isDownloading = false;
                _isInstalling = false;
                _progress = 0;
              });
              break;

            case OtaStatus.INTERNAL_ERROR:
              setState(() {
                _isDownloading = false;
                _isInstalling = false;
                _errorMessage =
                    'Could not complete the update. You can try downloading from the browser.';
              });
              break;
          }
        },
        onError: (dynamic error) {
          if (!mounted) return;
          setState(() {
            _isDownloading = false;
            _isInstalling = false;
            _errorMessage =
                'Failed to download update. You can try from your browser.';
          });
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _isInstalling = false;
        _errorMessage =
            'Could not start OTA update. You can download from your browser.';
      });
    }
  }

  Future<void> _launchBrowserFallback() async {
    final uri = Uri.parse(widget.updateInfo.apkDownloadUrl);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        final fallbackUri = Uri.parse(widget.updateInfo.releaseHtmlUrl);
        await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      try {
        final fallbackUri = Uri.parse(widget.updateInfo.releaseHtmlUrl);
        await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height * 0.85;

    final inProgress = _isDownloading || _isInstalling;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ModalDragHandle(topPadding: 4, bottomPadding: 16),

              // Beaker / App Highlight with soft glow
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary.withValues(alpha: 0.22),
                        AppColors.secondary.withValues(alpha: 0.22),
                      ],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.45),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: SeriolabLoader(
                      size: 38,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title and version badge
              Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Text(
                      _isInstalling
                          ? 'Starting Installation'
                          : _isDownloading
                              ? 'Downloading Update...'
                              : 'New Update Available',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.secondary.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'v${widget.updateInfo.latestVersion}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.secondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Subtitle
              Center(
                child: Text(
                  _isInstalling
                      ? 'The native Android installer has started. Please confirm installation on screen to update Seriolab.'
                      : _isDownloading
                          ? 'Downloading seriolab-update.apk (v${widget.updateInfo.latestVersion}). Please wait.'
                          : 'See what changed in this version:',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Progress Section (when downloading or installing)
              if (inProgress) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.outline,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _isInstalling
                                ? 'Opening system installer...'
                                : 'Download progress',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            _isInstalling ? 'Ready' : '$_progress%',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _isInstalling ? 1.0 : (_progress / 100.0),
                          backgroundColor: AppColors.surfaceHigh,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ] else ...[
                // Error message banner if any
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.danger.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.danger,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textPrimary,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Release notes content container
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161922),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.outline.withValues(alpha: 0.6),
                      width: 1,
                    ),
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: SizedBox(
                      width: double.infinity,
                      child: Text(
                        UpdateService.formatReleaseNotes(widget.updateInfo.releaseNotes),
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.55,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Action buttons
              if (_isDownloading) ...[
                TextButton(
                  onPressed: _cancelDownload,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Cancel Download',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ] else if (_isInstalling) ...[
                FilledButton(
                  onPressed: () {
                    if (widget.onDismiss != null) {
                      widget.onDismiss!();
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ] else ...[
                FilledButton(
                  onPressed: _startOtaUpdate,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.download_rounded, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Update Now',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _launchBrowserFallback,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.outline),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.open_in_browser_rounded, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Download in Browser',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    if (widget.onDismiss != null) {
                      widget.onDismiss!();
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Later',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// Helper function to display the Seriolab update bottom sheet.
Future<void> showUpdateBottomSheet(
  BuildContext context,
  AppUpdateInfo updateInfo, {
  OtaUpdate? otaUpdate,
}) {
  return UpdateBottomSheet.show(context, updateInfo, otaUpdate: otaUpdate);
}
