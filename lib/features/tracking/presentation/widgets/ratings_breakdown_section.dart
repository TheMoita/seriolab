import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../settings/presentation/providers/settings_providers.dart';

/// Letterboxd-inspired 19-bar rating breakdown chart (1.0 to 10.0 with half-points).
class RatingsBreakdownSection extends ConsumerStatefulWidget {
  const RatingsBreakdownSection({super.key});

  @override
  ConsumerState<RatingsBreakdownSection> createState() =>
      _RatingsBreakdownSectionState();
}

class _RatingsBreakdownSectionState
    extends ConsumerState<RatingsBreakdownSection> {
  double? _selectedScore;

  static const List<double> _allScores = [
    0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0, 5.5,
    6.0, 6.5, 7.0, 7.5, 8.0, 8.5, 9.0, 9.5, 10.0,
  ];

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider);
    final distribution = settings.ratingDistribution;
    final totalCount = settings.totalRatingsCount;
    final average = settings.averageRating;

    // Find peak count for scale
    var maxCount = 1;
    for (final s in _allScores) {
      final c = distribution[s.toStringAsFixed(1)] ?? 0;
      if (c > maxCount) maxCount = c;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title & Overall Average Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text(
                'RATINGS BREAKDOWN',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: AppColors.textMuted,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.star_rounded,
                    size: 16,
                    color: AppColors.secondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    totalCount == 0
                        ? 'Média: N/A'
                        : 'Média: ${average.toStringAsFixed(1)} ★',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '($totalCount)',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Main Chart Container
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.outline, width: 0.8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Interactive inspection banner
                _buildInspectionBanner(distribution, totalCount),
                const SizedBox(height: 14),

                // 20-Bar Histogram
                SizedBox(
                  height: 94,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: _allScores.map((score) {
                      final key = score.toStringAsFixed(1);
                      final count = distribution[key] ?? 0;
                      final isSelected = _selectedScore == score;

                      return Expanded(
                        child: _buildBarColumn(
                          score: score,
                          count: count,
                          maxCount: maxCount,
                          isSelected: isSelected,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),

                // X-Axis Axis labels (0.5, 3, 5, 7, 10)
                _buildXAxisLabels(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInspectionBanner(Map<String, int> distribution, int total) {
    if (total == 0) {
      return const Row(
        children: [
          Icon(
            Icons.bar_chart_rounded,
            size: 14,
            color: AppColors.textMuted,
          ),
          SizedBox(width: 6),
          Text(
            'Nenhuma série avaliada até ao momento',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    if (_selectedScore != null) {
      final key = _selectedScore!.toStringAsFixed(1);
      final count = distribution[key] ?? 0;
      final percent = total > 0 ? ((count / total) * 100).toStringAsFixed(1) : '0';

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF00E054).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF00E054).withValues(alpha: 0.5),
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.star_rounded,
              size: 15,
              color: Color(0xFF00E054),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$key / 10 ★  •  $count ${count == 1 ? 'avaliação' : 'avaliações'} ($percent%)',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            InkWell(
              onTap: () => setState(() => _selectedScore = null),
              child: const Icon(
                Icons.close_rounded,
                size: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return const Row(
      children: [
        Icon(
          Icons.touch_app_rounded,
          size: 13,
          color: AppColors.textMuted,
        ),
        SizedBox(width: 6),
        Text(
          'Toca numa barra para ver a contagem de séries',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildBarColumn({
    required double score,
    required int count,
    required int maxCount,
    required bool isSelected,
  }) {
    const maxHeight = 88.0;
    final ratio = maxCount > 0 ? (count / maxCount) : 0.0;
    final fillHeight = count == 0
        ? 2.0
        : math.max(6.0, ratio * maxHeight);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() {
          _selectedScore = isSelected ? null : score;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1.5),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              height: fillHeight,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                gradient: isSelected
                    ? const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.secondary, AppColors.primary],
                      )
                    : LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: count > 0
                            ? [
                                AppColors.primary,
                                AppColors.primary.withValues(alpha: 0.6),
                              ]
                            : [
                                AppColors.outline,
                                AppColors.outline,
                              ],
                      ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.secondary.withValues(alpha: 0.6),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildXAxisLabels() {
    // 19 scores total:
    // index 0 -> 1.0
    // index 4 -> 3.0
    // index 8 -> 5.0
    // index 12 -> 7.0
    // index 18 -> 10.0
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: const [
        Text(
          '1',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
          ),
        ),
        Text(
          '3',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
          ),
        ),
        Text(
          '5',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
          ),
        ),
        Text(
          '7',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
          ),
        ),
        Text(
          '10',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}
