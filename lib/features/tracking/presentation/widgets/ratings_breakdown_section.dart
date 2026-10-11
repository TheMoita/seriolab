import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../settings/domain/entities/user_settings.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../providers/tracking_providers.dart';

/// Letterboxd-inspired 20-bar rating breakdown chart (0.5 to 10.0 with half-points).
class RatingsBreakdownSection extends ConsumerStatefulWidget {
  const RatingsBreakdownSection({super.key});

  @override
  ConsumerState<RatingsBreakdownSection> createState() =>
      _RatingsBreakdownSectionState();
}

class _RatingsBreakdownSectionState
    extends ConsumerState<RatingsBreakdownSection> {
  double? _selectedScore;
  Timer? _dismissTimer;

  static const List<double> _allScores = [
    0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0, 5.5,
    6.0, 6.5, 7.0, 7.5, 8.0, 8.5, 9.0, 9.5, 10.0,
  ];

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  void _handleTouch(double localX, double totalWidth) {
    if (totalWidth <= 0) return;
    _dismissTimer?.cancel();
    final fraction = (localX / totalWidth).clamp(0.0, 0.9999);
    final index =
        (fraction * _allScores.length).floor().clamp(0, _allScores.length - 1);
    final score = _allScores[index];
    if (_selectedScore != score) {
      setState(() {
        _selectedScore = score;
      });
    }
  }

  void _onFingerLift() {
    _dismissTimer?.cancel();
    _dismissTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _selectedScore = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final trackingState = ref.watch(trackingControllerProvider).value;
    final settings = ref.watch(settingsControllerProvider);

    Map<String, int> distribution;
    int totalCount;
    double average;

    if (trackingState != null) {
      final ratedShows = trackingState.shows.values
          .where((s) => s.overallUserRating != null && s.overallUserRating! > 0)
          .toList();

      if (ratedShows.isEmpty) {
        distribution = UserSettings.defaultRatingDistribution;
        totalCount = 0;
        average = 0.0;
        if (settings.totalRatingsCount > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(settingsControllerProvider.notifier).resetRatingDistribution();
          });
        }
      } else {
        distribution =
            Map<String, int>.from(UserSettings.defaultRatingDistribution);
        var sum = 0.0;
        for (final show in ratedShows) {
          final clamped = show.overallUserRating!.clamp(0.5, 10.0);
          final key = ((clamped * 2).round() / 2).toStringAsFixed(1);
          if (distribution.containsKey(key)) {
            distribution[key] = (distribution[key] ?? 0) + 1;
            sum += clamped;
          }
        }
        totalCount = ratedShows.length;
        average = totalCount > 0 ? (sum / totalCount) : 0.0;
      }
    } else {
      distribution = settings.ratingDistribution;
      totalCount = settings.totalRatingsCount;
      average = settings.averageRating;
    }

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
                'RATINGS',
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
                        ? 'Média: —'
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
                if (totalCount == 0 || _selectedScore != null) ...[
                  _buildInspectionBanner(distribution, totalCount),
                  const SizedBox(height: 12),
                ],

                // 20-Bar Histogram with Touch & Drag Scrubbing
                if (totalCount == 0) ...[
                  SizedBox(
                    height: 94,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Center(
                            child: Text(
                              'Avalia séries nos detalhes para gerar o teu gráfico',
                              style: TextStyle(
                                fontSize: 11,
                                color:
                                    AppColors.textMuted.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          height: 1.5,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppColors.outline.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (details) => _handleTouch(
                            details.localPosition.dx, constraints.maxWidth),
                        onTapUp: (_) => _onFingerLift(),
                        onHorizontalDragStart: (details) => _handleTouch(
                            details.localPosition.dx, constraints.maxWidth),
                        onHorizontalDragUpdate: (details) => _handleTouch(
                            details.localPosition.dx, constraints.maxWidth),
                        onHorizontalDragEnd: (_) => _onFingerLift(),
                        onHorizontalDragCancel: () => _onFingerLift(),
                        child: SizedBox(
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
                      );
                    },
                  ),
                ],
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bar_chart_rounded,
            size: 15,
            color: AppColors.textMuted,
          ),
          SizedBox(width: 6),
          Text(
            'Ainda não avaliaste nenhuma série',
            style: TextStyle(
              fontSize: 12,
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
      final percent =
          total > 0 ? ((count / total) * 100).toStringAsFixed(1) : '0';
      final seriesLabel = count == 1 ? 'série' : 'séries';

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF38BDF8).withValues(alpha: 0.5),
            width: 0.9,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.star_rounded,
              size: 16,
              color: Color(0xFF38BDF8),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '★ $key — $count $seriesLabel ($percent%)',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            InkWell(
              onTap: () {
                _dismissTimer?.cancel();
                setState(() => _selectedScore = null);
              },
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

    return const SizedBox.shrink();
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
        ? (isSelected ? 8.0 : 2.0)
        : math.max(6.0, ratio * maxHeight);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1.5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            height: fillHeight,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(3)),
              gradient: isSelected
                  ? const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF38BDF8), Color(0xFF7C5CFC)],
                    )
                  : LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: count > 0
                          ? [
                              const Color(0xFF475569),
                              const Color(0xFF232938),
                            ]
                          : [
                              AppColors.outline,
                              AppColors.outline,
                            ],
                    ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.6),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
