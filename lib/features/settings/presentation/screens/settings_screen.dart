import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/widgets/auth_gate.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/seriolab_logo.dart';
import '../providers/settings_providers.dart';
import '../widgets/avatar_selection_sheet.dart';
import '../widgets/edit_profile_sheet.dart';
import '../widgets/export_watchlist_sheet.dart';
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
  // Simulated cache tracking that can be cleared dynamically
  bool _cacheCleared = false;

  static const Map<String, String> _languages = {
    'pt-PT': 'Português (Portugal) 🇵🇹',
    'pt-BR': 'Português (Brasil) 🇧🇷',
    'en-US': 'English (US) 🇺🇸',
    'es-ES': 'Español 🇪🇸',
  };

  static const Map<String, String> _regions = {
    'PT': 'Portugal 🇵🇹',
    'BR': 'Brasil 🇧🇷',
    'US': 'Estados Unidos 🇺🇸',
    'GB': 'Reino Unido 🇬🇧',
    'ES': 'Espanha 🇪🇸',
    'FR': 'França 🇫🇷',
    'DE': 'Alemanha 🇩🇪',
  };

  Future<void> _selectLanguage(BuildContext context, String current) async {
    final effectiveCurrent = current == 'pt'
        ? 'pt-PT'
        : (current == 'en'
            ? 'en-US'
            : (current == 'es' ? 'es-ES' : current));

    final selected = await showModalBottomSheet<String>(
      context: context,
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Idioma da Aplicação',
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
                ..._languages.entries.map((entry) {
                  final isCurrent =
                      entry.key == effectiveCurrent || entry.key == current;
                  return ListTile(
                    title: Text(
                      entry.value,
                      style: TextStyle(
                        fontWeight:
                            isCurrent ? FontWeight.w700 : FontWeight.w500,
                        color: isCurrent
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                    ),
                    trailing: isCurrent
                        ? const Icon(Icons.check_rounded,
                            color: AppColors.primary)
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
      ref.read(settingsControllerProvider.notifier).setLanguage(selected);
    }
  }

  Future<void> _selectRegion(BuildContext context, String current) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Região de Streaming',
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
                'Limpar Cache',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          content: const Text(
            'Desejas limpar a cache de posters e capas? Isto libertará cerca de 42.8 MB de memória sem afetar as tuas séries guardadas.',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar',
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
                        Text('42.8 MB de cache de imagens libertados!'),
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
              child: const Text('Limpar Agora'),
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
              child: const Text('Fechar',
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
                'Terminar Sessão',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          content: const Text(
            'Tens a certeza que pretendes terminar a sessão no Seriolab?',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'Cancelar',
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
              child: const Text('Terminar Sessão'),
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
        title: const Text('Definições'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 48),
        children: [
          // -----------------------------------------------------------------
          // a) Conta & Perfil
          // -----------------------------------------------------------------
          SettingsGroupCard(
            title: 'Conta & Perfil',
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
                  'Personalizar Avatar',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: const Text(
                  'Carregar foto, escolher de série TMDB ou ícones',
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
                  'Editar Perfil e Avatar',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: const Text(
                  'Alterar nome, username, biografia e ícone',
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
                    'Autenticado via ${authState.user!.provider.label}',
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
                    'Terminar Sessão',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.danger,
                    ),
                  ),
                  subtitle: const Text(
                    'Termina a sessão ativa no Seriolab',
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
            title: 'Preferências de Conteúdo & Idioma',
            children: [
              ListTile(
                leading: const Icon(
                  Icons.language_rounded,
                  color: AppColors.secondary,
                  size: 22,
                ),
                title: const Text(
                  'Idioma da Aplicação',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  _languages[settings.language] ?? settings.language,
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
                  'Região de Streaming',
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
                  'Ver títulos no idioma original',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: const Text(
                  'Apresenta os nomes originais de séries e episódios em vez dos títulos traduzidos',
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
            title: 'Proteção Anti-Spoiler & Exibição',
            children: [
              SwitchListTile(
                secondary: const Icon(
                  Icons.visibility_off_outlined,
                  color: AppColors.primary,
                  size: 22,
                ),
                title: const Text(
                  'Ocultar sinopses de episódios por ver',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: const Text(
                  'Desfoca descrições e títulos sensíveis para evitar revelações da trama.',
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
                  'Agrupar especiais e extras separadamente',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: const Text(
                  'Mantém a Temporada 0 e conteúdos adicionais numa secção dedicada.',
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
            title: 'Notificações',
            children: [
              SwitchListTile(
                secondary: const Icon(
                  Icons.notifications_active_outlined,
                  color: AppColors.secondary,
                  size: 22,
                ),
                title: const Text(
                  'Lembrete no dia de estreia',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: const Text(
                  'Recebe alertas de novos episódios das séries que estás a acompanhar.',
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
                  'Hora do Lembrete',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: settings.episodeReleaseReminders
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                  ),
                ),
                subtitle: Text(
                  'Receber avisos às ${settings.formattedReminderTime}',
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
            title: 'Armazenamento & Dados',
            children: [
              ListTile(
                leading: const Icon(
                  Icons.cleaning_services_rounded,
                  color: AppColors.warning,
                  size: 22,
                ),
                title: const Text(
                  'Limpar Cache de Imagens',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  _cacheCleared
                      ? 'Cache limpo recentemente (0.0 MB)'
                      : 'Liberta cerca de 42.8 MB de posters e miniaturas',
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
                  child: Text(_cacheCleared ? 'Limpo' : 'Limpar'),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.file_download_outlined,
                  color: AppColors.secondary,
                  size: 22,
                ),
                title: const Text(
                  'Exportar Watchlist',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: const Text(
                  'Exporta o teu progresso e histórico em formato JSON ou CSV',
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
          // f) Sobre & Versão
          // -----------------------------------------------------------------
          SettingsGroupCard(
            title: 'Sobre & Versão',
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  children: [
                    SeriolabLogo(
                      orientation: Axis.horizontal,
                      iconSize: 32,
                      fontSize: 20,
                    ),
                    Spacer(),
                    Text(
                      'v1.0.0 (Build 1)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  'Seriolab é a aplicação definitiva para maratonistas e amantes de séries de televisão. Acompanha o teu progresso, próximos lançamentos e estatísticas com privacidade total.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.description_outlined,
                  color: AppColors.textSecondary,
                  size: 22,
                ),
                title: const Text(
                  'Termos de Serviço',
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
                  'Termos de Serviço',
                  'Bem-vindo ao Seriolab!\n\n1. O Seriolab é uma aplicação gratuita para registo e tracking pessoal de séries de televisão.\n2. Todo o conteúdo catalogado (títulos, posters e sinopses) é fornecido para fins informativos.\n3. Não hospedamos nem transmitimos conteúdos audiovisuais.\n4. O uso da aplicação destina-se a fins estritamente pessoais.',
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.privacy_tip_outlined,
                  color: AppColors.textSecondary,
                  size: 22,
                ),
                title: const Text(
                  'Política de Privacidade',
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
                  'Política de Privacidade',
                  'A tua privacidade é prioridade máxima no Seriolab:\n\n• Os teus dados de visualização, progresso e notas são guardados localmente no teu dispositivo.\n• Não recolhemos nem comercializamos os teus hábitos de consumo com terceiros.\n• Os pedidos de catálogo contactam as APIs de catálogo exclusivamente para descarregar metadados públicos.',
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.favorite_outline_rounded,
                  color: AppColors.danger,
                  size: 22,
                ),
                title: const Text(
                  'Créditos & Agradecimentos',
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
                  'Créditos & Dados',
                  'Seriolab • Desenvolvido com Flutter & Dart.\n\nDados de séries e posters fornecidos por The Movie Database (TMDB) e TVMaze API.\n\nConstruído com paixão para todos os apaixonados por televisão.',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
