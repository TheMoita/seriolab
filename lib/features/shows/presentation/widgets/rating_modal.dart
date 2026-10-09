import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Result from [RatingModal.show].
sealed class RatingResult {
  const RatingResult();
}

class RatingSelected extends RatingResult {
  const RatingSelected(this.rating);
  final double rating;
}

class RatingRemoved extends RatingResult {
  const RatingRemoved();
}

/// Seriolab Rating Modal (1.0 to 10.0 with 0.5 half-point increments).
class RatingModal extends StatefulWidget {
  const RatingModal({
    super.key,
    required this.title,
    required this.itemName,
    this.initialRating,
  });

  final String title;
  final String itemName;
  final double? initialRating;

  static Future<RatingResult?> show(
    BuildContext context, {
    required String title,
    required String itemName,
    double? initialRating,
  }) {
    return showModalBottomSheet<RatingResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => RatingModal(
        title: title,
        itemName: itemName,
        initialRating: initialRating,
      ),
    );
  }

  @override
  State<RatingModal> createState() => _RatingModalState();
}

class _RatingModalState extends State<RatingModal> {
  late double _currentRating;
  late final bool _hasInitialRating;

  @override
  void initState() {
    super.initState();
    _hasInitialRating = widget.initialRating != null;
    _currentRating = (widget.initialRating ?? 8.0).clamp(1.0, 10.0);
  }

  String _getRatingQualifier(double score) {
    if (score >= 10.0) return 'Obra-Prima ★★★';
    if (score >= 9.0) return 'Brilhante / Excelente';
    if (score >= 8.0) return 'Muito Bom';
    if (score >= 7.0) return 'Bom';
    if (score >= 6.0) return 'Acima da Média';
    if (score >= 5.0) return 'Razoável';
    if (score >= 4.0) return 'Abaixo da Média';
    if (score >= 3.0) return 'Fraco';
    return 'Muito Fraco';
  }

  void _stepRating(double delta) {
    setState(() {
      _currentRating = (_currentRating + delta).clamp(1.0, 10.0);
      // Ensure rounded to nearest 0.5
      _currentRating = (_currentRating * 2).round() / 2;
    });
  }

  @override
  Widget build(BuildContext context) {
    final qualifier = _getRatingQualifier(_currentRating);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header title & close
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.itemName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  color: AppColors.textSecondary,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Big Highlight Score Card
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.5),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        _currentRating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 54,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '★',
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          color: AppColors.secondary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        '/ 10',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      qualifier,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Stepper and Slider
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: _currentRating > 1.0 ? () => _stepRating(-0.5) : null,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surfaceHigh,
                    foregroundColor: AppColors.textPrimary,
                  ),
                  icon: const Icon(Icons.remove_rounded),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppColors.primary,
                      inactiveTrackColor: AppColors.outline,
                      thumbColor: AppColors.secondary,
                      overlayColor: AppColors.secondary.withValues(alpha: 0.2),
                      trackHeight: 6,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 10),
                    ),
                    child: Slider(
                      value: _currentRating,
                      min: 1.0,
                      max: 10.0,
                      divisions: 18,
                      onChanged: (val) {
                        setState(() {
                          _currentRating = (val * 2).round() / 2;
                        });
                      },
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: _currentRating < 10.0 ? () => _stepRating(0.5) : null,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surfaceHigh,
                    foregroundColor: AppColors.textPrimary,
                  ),
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Quick Shortcut Chips (Benchmarks)
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final benchmark in [5.0, 6.0, 7.0, 7.5, 8.0, 8.5, 9.0, 9.5, 10.0])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(
                          '${benchmark.toStringAsFixed(benchmark % 1 == 0 ? 0 : 1)} ★',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: _currentRating == benchmark
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: _currentRating == benchmark
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                        ),
                        selected: _currentRating == benchmark,
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.surfaceHigh,
                        side: BorderSide(
                          color: _currentRating == benchmark
                              ? AppColors.primary
                              : AppColors.outline,
                          width: 0.8,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _currentRating = benchmark);
                          }
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action: Save Rating
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(RatingSelected(_currentRating));
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Guardar Avaliação (${_currentRating.toStringAsFixed(1)} ★)',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),

            // Action: Remove Rating (if previously rated)
            if (_hasInitialRating) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop(const RatingRemoved());
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.danger,
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text(
                  'Remover nota',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
