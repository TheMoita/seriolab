import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/modal_drag_handle.dart';
import '../../../tracking/presentation/providers/tracking_providers.dart';
import '../providers/settings_providers.dart';

/// Modal bottom sheet allowing users to export their Seriolab watchlist
/// and episode history in structured JSON or CSV format.
class ExportWatchlistSheet extends ConsumerStatefulWidget {
  const ExportWatchlistSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const ExportWatchlistSheet(),
    );
  }

  @override
  ConsumerState<ExportWatchlistSheet> createState() =>
      _ExportWatchlistSheetState();
}

class _ExportWatchlistSheetState extends ConsumerState<ExportWatchlistSheet> {
  bool _exportAsJson = true;

  @override
  Widget build(BuildContext context) {
    final trackingState = ref.watch(trackingControllerProvider).value;
    final settings = ref.watch(settingsControllerProvider);

    final shows = trackingState?.shows.values.toList() ?? [];
    final watchedEpisodes =
        trackingState?.watched.values.expand((m) => m.values).toList() ?? [];

    final String exportContent;
    if (_exportAsJson) {
      final exportData = {
        'seriolab_export_version': '1.0',
        'exported_at': DateTime.now().toIso8601String(),
        'user': {
          'displayName': settings.displayName,
          'username': settings.username,
        },
        'shows_count': shows.length,
        'episodes_watched_count': watchedEpisodes.length,
        'shows': shows.map((s) {
          final watchedCount = trackingState?.watchedRegularCount(s.showId) ?? 0;
          final progress = trackingState?.progress(s.showId) ?? 0.0;
          return {
            'id': s.showId,
            'name': s.name,
            'status': s.status.name,
            'network': s.network,
            'aired_episodes': s.airedEpisodeCount,
            'watched_episodes': watchedCount,
            'progress_percent': (progress * 100).toStringAsFixed(1),
            'added_at': s.addedAt.toIso8601String(),
          };
        }).toList(),
        'watched_episodes': watchedEpisodes.map((e) {
          return {
            'show_id': e.showId,
            'season': e.key.season,
            'episode': e.key.episode,
            'watched_at': e.watchedAt.toIso8601String(),
          };
        }).toList(),
      };
      exportContent = const JsonEncoder.withIndent('  ').convert(exportData);
    } else {
      final buffer = StringBuffer();
      buffer.writeln(
          'ShowId,ShowName,Status,Network,AiredEpisodes,WatchedEpisodes,ProgressPercent,AddedAt');
      for (final s in shows) {
        final watchedCount = trackingState?.watchedRegularCount(s.showId) ?? 0;
        final progress = (trackingState?.progress(s.showId) ?? 0.0) * 100;
        final cleanName = s.name.replaceAll(',', ' ');
        final network = (s.network ?? '').replaceAll(',', ' ');
        buffer.writeln(
            '${s.showId},"$cleanName",${s.status.name},"$network",${s.airedEpisodeCount},$watchedCount,${progress.toStringAsFixed(1)}%,${s.addedAt.toIso8601String()}');
      }
      exportContent = buffer.toString();
    }

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top handle
            const ModalDragHandle(topPadding: 0, bottomPadding: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Exportar Watchlist',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  color: AppColors.textSecondary,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${shows.length} séries e ${watchedEpisodes.length} episódios registados prontos para exportação.',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),

            // Format switcher (JSON vs CSV)
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.outline, width: 0.6),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() => _exportAsJson = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _exportAsJson
                              ? AppColors.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Formato JSON',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _exportAsJson
                                ? AppColors.onPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() => _exportAsJson = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: !_exportAsJson
                              ? AppColors.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Formato CSV',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: !_exportAsJson
                                ? AppColors.onPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Preview code area
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.outline, width: 0.8),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    exportContent,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Copy action button
            FilledButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: exportContent));
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(
                          Icons.done_all_rounded,
                          color: AppColors.secondary,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Dados copiados em ${_exportAsJson ? 'JSON' : 'CSV'} para a área de transferência!',
                        ),
                      ],
                    ),
                    duration: const Duration(seconds: 3),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text(
                'Copiar para Área de Transferência',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
