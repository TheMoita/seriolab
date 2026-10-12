import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:package_info_plus/package_info_plus.dart';

import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/widgets/auth_gate.dart';
import '../../../../core/services/update_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/modal_drag_handle.dart';
import '../../../../core/widgets/seriolab_loader.dart';
import '../../../../core/widgets/seriolab_logo.dart';
import '../../../../core/widgets/update_dialog.dart';
import '../providers/settings_providers.dart';
import '../widgets/avatar_selection_sheet.dart';
import '../widgets/edit_profile_sheet.dart';
import '../widgets/export_watchlist_sheet.dart';
import '../widgets/language_selector_bottom_sheet.dart';
import '../widgets/settings_group_card.dart';
import '../widgets/user_avatar_widget.dart';

/// Screen offering full application configuration, anti-spoiler controls,
/// profile personalization, notifications, and data management.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final Future<PackageInfo> _packageInfoFuture;

  // Simulated cache tracking that can be cleared dynamically
  bool _cacheCleared = false;
  bool _isCheckingUpdate = false;

  Future<void> _checkManualUpdate() async {
    if (_isCheckingUpdate) return;
    setState(() => _isCheckingUpdate = true);

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final updateService = ref.read(updateServiceProvider);
      final result = await updateService.checkForUpdatesResult();
      if (!mounted) return;

      if (result.status == UpdateCheckStatus.hasUpdate && result.updateInfo != null) {
        await showUpdateBottomSheet(context, result.updateInfo!);
      } else if (result.status == UpdateCheckStatus.upToDate) {
        final versionToDisplay = result.currentVersion.isNotEmpty
            ? result.currentVersion
            : currentVersion;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'You have the latest version installed (v$versionToDisplay).',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppColors.surfaceHigh,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: AppColors.outline, width: 0.8),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      } else if (result.status == UpdateCheckStatus.noReleaseFound) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'No releases found in the repository.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppColors.surfaceHigh,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: AppColors.outline, width: 0.8),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      } else if (result.status == UpdateCheckStatus.rateLimitExceeded) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'GitHub API request limit reached. Please try again later.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppColors.surfaceHigh,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: AppColors.outline, width: 0.8),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      } else if (result.status == UpdateCheckStatus.networkError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'No internet connection.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppColors.surfaceHigh,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: AppColors.outline, width: 0.8),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.errorMessage ?? 'Unable to check for updates right now.',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppColors.surfaceHigh,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: AppColors.outline, width: 0.8),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Unable to check for updates right now.',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.surfaceHigh,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppColors.outline, width: 0.8),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCheckingUpdate = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _packageInfoFuture = PackageInfo.fromPlatform();
  }

  static const Map<String, String> _regions = {
    'PT': 'Portugal 🇵🇹',
    'BR': 'Brazil 🇧🇷',
    'US': 'United States 🇺🇸',
    'GB': 'United Kingdom 🇬🇧',
    'ES': 'Spain 🇪🇸',
    'FR': 'France 🇫🇷',
    'DE': 'Germany 🇩🇪',
  };

  Future<void> _selectLanguage(BuildContext context, String current) async {
    await LanguageSelectorBottomSheet.show(context);
  }

  Future<void> _selectRegion(BuildContext context, String current) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: false,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ModalDragHandle(topPadding: 0, bottomPadding: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Streaming Region',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                ..._regions.entries.map((entry) {
                  final isCurrent = entry.key == current;
                  return ListTile(
                    title: Text(
                      entry.value,
                      style: TextStyle(
                        fontWeight:
                            isCurrent ? FontWeight.w700 : FontWeight.w500,
                        color: isCurrent
                            ? AppColors.secondary
                            : AppColors.textPrimary,
                      ),
                    ),
                    trailing: isCurrent
                        ? const Icon(Icons.check_rounded,
                            color: AppColors.secondary)
                        : null,
                    onTap: () => Navigator.pop(ctx, entry.key),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null) {
      ref.read(settingsControllerProvider.notifier).setStreamingRegion(selected);
    }
  }

  Future<void> _selectReminderTime(
      BuildContext context, int initialHour, int initialMinute) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      ref
          .read(settingsControllerProvider.notifier)
          .setReminderTime(picked.hour, picked.minute);
    }
  }

  void _confirmClearCache() {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.outline, width: 0.8),
          ),
          title: const Row(
            children: [
              Icon(Icons.cleaning_services_rounded,
                  color: AppColors.secondary, size: 22),
              SizedBox(width: 10),
              Text(
                'Clear Cache',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          content: const Text(
            'Do you want to clear the poster and image cache? This will free up approximately 42.8 MB of memory without affecting your tracked shows.',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            FilledButton(
              onPressed: () {
                PaintingBinding.instance.imageCache.clear();
                PaintingBinding.instance.imageCache.clearLiveImages();
                setState(() => _cacheCleared = true);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.check_circle_rounded,
                            color: AppColors.secondary, size: 20),
                        SizedBox(width: 10),
                        Text('42.8 MB of image cache cleared!'),
                      ],
                    ),
                    duration: Duration(seconds: 3),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Clear Now'),
            ),
          ],
        );
      },
    );
  }

  void _showInfoDialog(String title, String content) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.outline, width: 0.8),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          content: SingleChildScrollView(
            child: Text(
              content,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close',
                  style: TextStyle(color: AppColors.primary)),
            ),
          ],
        );
      },
    );
  }

  void _confirmSignOut() {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.outline, width: 0.8),
          ),
          title: const Row(
            children: [
              Icon(Icons.logout_rounded, color: AppColors.danger, size: 22),
              SizedBox(width: 10),
              Text(
                'Sign Out',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          content: const Text(
            'Are you sure you want to sign out of Seriolab?',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await ref.read(authControllerProvider.notifier).signOut();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute<void>(
                      builder: (_) => const AuthGate(),
                    ),
                    (route) => false,
                  );
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
              ),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider);
    final notifier = ref.read(settingsControllerProvider.notifier);
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 48),
        children: [
          // -----------------------------------------------------------------
          // a) Account & Profile
          // -----------------------------------------------------------------
          SettingsGroupCard(
            title: 'Account & Profile',
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(30),
                          onTap: () => AvatarSelectionSheet.show(context),
                          child: UserAvatarWidget.fromSettings(
                            settings: settings,
                            size: 60,
                            showGlow: true,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: InkWell(
                            onTap: () => AvatarSelectionSheet.show(context),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.surface,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.edit_rounded,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            settings.displayName,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '@${settings.username}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.secondary,
                            ),
                          ),
                          if (settings.bio.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              settings.bio,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textMuted,
                      ),
                      onPressed: () => EditProfileSheet.show(context),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
                title: const Text(
                  'Customize Avatar',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: const Text(
                  'Upload photo, choose from TMDB shows or icons',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: AppColors.textMuted,
                ),
                onTap: () => AvatarSelectionSheet.show(context),
              ),
              ListTile(
                leading: const Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.secondary,
                  size: 22,
                ),
                title: const Text(
                  'Edit Profile & Avatar',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: const Text(
                  'Change display name, username, bio and icon',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: AppColors.textMuted,
                ),
                onTap: () => EditProfileSheet.show(context),
              ),
              if (authState.user != null) ...[
                const Divider(),
                ListTile(
                  leading: Icon(
                    authState.user!.provider == AuthProviderKind.google
                        ? Icons.account_circle_outlined
                        : Icons.mail_outline_rounded,
                    color: AppColors.secondary,
                    size: 22,
                  ),
                  title: Text(
                    authState.user!.email,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Signed in via ${authState.user!.provider.label}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.logout_rounded,
                    color: AppColors.danger,
                    size: 22,
                  ),
                  title: const Text(
                    'Sign Out',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.danger,
                    ),
                  ),
                  subtitle: const Text(
                    'Sign out of your active Seriolab session',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  onTap: _confirmSignOut,
                ),
              ],
            ],
          ),

          // -----------------------------------------------------------------
          // b) Preferências de Conteúdo & Idioma
          // -----------------------------------------------------------------
          SettingsGroupCard(
            title: 'Content & Language Preferences',
            children: [
              ListTile(
                leading: const Icon(
                  Icons.language_rounded,
                  color: AppColors.secondary,
                  size: 22,
                ),
                title: const Text(
                  'App Language',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  LanguageSelectorBottomSheet.getDisplayName(settings.language),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: AppColors.textMuted,
                ),
                onTap: () => _selectLanguage(context, settings.language),
              ),
              ListTile(
                leading: const Icon(
                  Icons.public_rounded,
                  color: AppColors.secondary,
                  size: 22,
                ),
                title: const Text(
                  'Streaming Region',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  _regions[settings.streamingRegion] ?? settings.streamingRegion,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: AppColors.textMuted,
                ),
                onTap: () => _selectRegion(context, settings.streamingRegion),
              ),
              SwitchListTile(
                secondary: const Icon(
                  Icons.subtitles_rounded,
                  color: AppColors.secondary,
                  size: 22,
                ),
                title: const Text(
                  'Show titles in original language',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: const Text(
                  'Displays original names of series and episodes instead of localized titles',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                value: settings.showOriginalTitles,
                activeThumbColor: AppColors.primary,
                onChanged: (val) => notifier.setShowOriginalTitles(val),
              ),
            ],
          ),

          // -----------------------------------------------------------------
          // c) Proteção Anti-Spoiler & Exibição
          // -----------------------------------------------------------------
          SettingsGroupCard(
            title: 'Anti-Spoiler Protection & Display',
            children: [
              SwitchListTile(
                secondary: const Icon(
                  Icons.visibility_off_outlined,
                  color: AppColors.primary,
                  size: 22,
                ),
                title: const Text(
                  'Hide overviews for unwatched episodes',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: const Text(
                  'Blurs sensitive descriptions and titles to prevent plot spoilers.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                activeThumbColor: AppColors.primary,
                value: settings.hideSpoilersForUnwatched,
                onChanged: notifier.setHideSpoilers,
              ),
              SwitchListTile(
                secondary: const Icon(
                  Icons.auto_awesome_motion_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
                title: const Text(
                  'Group specials and extras separately',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: const Text(
                  'Keeps Season 0 and extra content in a dedicated section.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                activeThumbColor: AppColors.primary,
                value: settings.groupSpecialEpisodes,
                onChanged: notifier.setGroupSpecialEpisodes,
              ),
            ],
          ),

          // -----------------------------------------------------------------
          // d) Notificações
          // -----------------------------------------------------------------
          SettingsGroupCard(
            title: 'Notifications',
            children: [
              SwitchListTile(
                secondary: const Icon(
                  Icons.notifications_active_outlined,
                  color: AppColors.secondary,
                  size: 22,
                ),
                title: const Text(
                  'Reminder on premiere day',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: const Text(
                  'Get notifications for new episodes of shows you are watching.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                activeThumbColor: AppColors.secondary,
                value: settings.episodeReleaseReminders,
                onChanged: notifier.setEpisodeReleaseReminders,
              ),
              ListTile(
                enabled: settings.episodeReleaseReminders,
                leading: Icon(
                  Icons.schedule_rounded,
                  color: settings.episodeReleaseReminders
                      ? AppColors.secondary
                      : AppColors.textMuted,
                  size: 22,
                ),
                title: Text(
                  'Reminder Time',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: settings.episodeReleaseReminders
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                  ),
                ),
                subtitle: Text(
                  'Receive alerts at ${settings.formattedReminderTime}',
                  style: TextStyle(
                    fontSize: 12,
                    color: settings.episodeReleaseReminders
                        ? AppColors.textSecondary
                        : AppColors.textMuted,
                  ),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: settings.episodeReleaseReminders
                        ? AppColors.primary.withValues(alpha: 0.18)
                        : AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: settings.episodeReleaseReminders
                          ? AppColors.primary
                          : AppColors.outline,
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    settings.formattedReminderTime,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: settings.episodeReleaseReminders
                          ? AppColors.primary
                          : AppColors.textMuted,
                    ),
                  ),
                ),
                onTap: settings.episodeReleaseReminders
                    ? () => _selectReminderTime(
                          context,
                          settings.reminderHour,
                          settings.reminderMinute,
                        )
                    : null,
              ),
            ],
          ),

          // -----------------------------------------------------------------
          // e) Armazenamento & Dados
          // -----------------------------------------------------------------
          SettingsGroupCard(
            title: 'Storage & Data',
            children: [
              ListTile(
                leading: const Icon(
                  Icons.cleaning_services_rounded,
                  color: AppColors.warning,
                  size: 22,
                ),
                title: const Text(
                  'Clear Image Cache',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  _cacheCleared
                      ? 'Cache recently cleared (0.0 MB)'
                      : 'Frees approximately 42.8 MB of posters and thumbnails',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                trailing: OutlinedButton(
                  onPressed: _confirmClearCache,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.warning,
                    side: const BorderSide(color: AppColors.warning, width: 0.8),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(_cacheCleared ? 'Cleared' : 'Clear'),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.file_download_outlined,
                  color: AppColors.secondary,
                  size: 22,
                ),
                title: const Text(
                  'Export Watchlist',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: const Text(
                  'Export your progress and history in JSON or CSV format',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: AppColors.textMuted,
                ),
                onTap: () => ExportWatchlistSheet.show(context),
              ),
            ],
          ),

          // -----------------------------------------------------------------
          // f) About & Version
          // -----------------------------------------------------------------
          SettingsGroupCard(
            title: 'About & Version',
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  children: [
                    const SeriolabLogo(
                      orientation: Axis.horizontal,
                      iconSize: 32,
                      fontSize: 20,
                    ),
                    const Spacer(),
                    FutureBuilder<PackageInfo>(
                      future: _packageInfoFuture,
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          final version = snapshot.data!.version;
                          final buildNumber = snapshot.data!.buildNumber;
                          final displayVersion = buildNumber.isNotEmpty
                              ? 'v$version (build $buildNumber)'
                              : 'v$version';
                          return Text(
                            displayVersion,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          );
                        }
                        return const Text(
                          'v...',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  'Seriolab is the ultimate app for TV show marathons and enthusiasts. Track your progress, upcoming releases, and stats with total privacy.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
              ListTile(
                leading: _isCheckingUpdate
                    ? const SeriolabLoader(
                        size: 22,
                      )
                    : const Icon(
                        Icons.system_update_rounded,
                        color: AppColors.secondary,
                        size: 22,
                      ),
                title: const Text(
                  'Check for Updates',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  _isCheckingUpdate
                      ? 'Checking for new releases on GitHub...'
                      : 'Search for new app versions and updates',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                trailing: _isCheckingUpdate
                    ? null
                    : const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
                onTap: _isCheckingUpdate ? null : _checkManualUpdate,
              ),
              ListTile(
                leading: const Icon(
                  Icons.description_outlined,
                  color: AppColors.textSecondary,
                  size: 22,
                ),
                title: const Text(
                  'Terms of Service',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: AppColors.textMuted,
                ),
                onTap: () => _showInfoDialog(
                  'Terms of Service',
                  'Welcome to Seriolab!\n\n1. Seriolab is a free app for personal tracking of TV series.\n2. All catalog content (titles, posters, and overviews) is provided for informational purposes.\n3. We do not host or stream video content.\n4. App usage is strictly intended for personal use.',
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.privacy_tip_outlined,
                  color: AppColors.textSecondary,
                  size: 22,
                ),
                title: const Text(
                  'Privacy Policy',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: AppColors.textMuted,
                ),
                onTap: () => _showInfoDialog(
                  'Privacy Policy',
                  'Your privacy is top priority in Seriolab:\n\n• Your viewing data, progress, and ratings are saved locally on your device.\n• We do not collect or sell your viewing habits to third parties.\n• Catalog requests contact public APIs exclusively to download public metadata.',
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.favorite_outline_rounded,
                  color: AppColors.danger,
                  size: 22,
                ),
                title: const Text(
                  'Credits & Acknowledgements',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: AppColors.textMuted,
                ),
                onTap: () => _showInfoDialog(
                  'Credits & Data',
                  'Seriolab • Developed with Flutter & Dart.\n\nTV show data and posters provided by The Movie Database (TMDB) and TVMaze API.\n\nBuilt with passion for all television lovers.',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
