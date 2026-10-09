import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';

/// Result from [RatingModal.show].
sealed class RatingResult {
  const RatingResult();
}

/// The user saved their rating and/or log details.
class RatingLogSaved extends RatingResult {
  const RatingLogSaved({
    this.rating,
    this.reviewText,
    this.hasSpoilers = false,
    required this.loggedAt,
  });

  /// Rating score in Letterboxd scale (0.5 to 5.0 stars), or null if unrated.
  final double? rating;

  /// Optional written review or notes.
  final String? reviewText;

  /// Whether the review contains spoilers.
  final bool hasSpoilers;

  /// Date when the entry was logged.
  final DateTime loggedAt;
}

/// Backward compatibility alias for [RatingLogSaved].
typedef RatingSelected = RatingLogSaved;

/// The user chose to clear their rating / log entry.
class RatingRemoved extends RatingResult {
  const RatingRemoved();
}

/// Letterboxd-style rating and review log modal for Seriolab.
class RatingModal extends StatefulWidget {
  const RatingModal({
    super.key,
    required this.title,
    required this.itemName,
    this.badgeText,
    this.initialRating,
    this.initialReview,
    this.initialHasSpoilers = false,
    this.initialLoggedAt,
  });

  final String title;
  final String itemName;
  final String? badgeText;
  final double? initialRating;
  final String? initialReview;
  final bool initialHasSpoilers;
  final DateTime? initialLoggedAt;

  static const Color letterboxdGreen = Color(0xFF00E054);
  static const Color emptyStarColor = Color(0xFF27303E);
  static const Color emptyStarBorder = Color(0xFF384357);

  static Future<RatingResult?> show(
    BuildContext context, {
    required String title,
    required String itemName,
    String? badgeText,
    double? initialRating,
    String? initialReview,
    bool initialHasSpoilers = false,
    DateTime? initialLoggedAt,
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
        badgeText: badgeText,
        initialRating: initialRating,
        initialReview: initialReview,
        initialHasSpoilers: initialHasSpoilers,
        initialLoggedAt: initialLoggedAt,
      ),
    );
  }

  @override
  State<RatingModal> createState() => _RatingModalState();
}

class _RatingModalState extends State<RatingModal> {
  double? _currentRating;
  late final TextEditingController _reviewController;
  late bool _hasSpoilers;
  late DateTime _loggedAt;
  late final bool _hadInitialData;

  @override
  void initState() {
    super.initState();
    // Normalize initial rating to Letterboxd 0.5 - 5.0 scale if it was previously in 1-10
    final initial = widget.initialRating;
    if (initial != null) {
      final normalized = initial > 5.0 ? initial / 2.0 : initial;
      _currentRating = (normalized * 2).round() / 2;
    } else {
      _currentRating = null;
    }

    _reviewController =
        TextEditingController(text: widget.initialReview ?? '');
    _hasSpoilers = widget.initialHasSpoilers;
    _loggedAt = widget.initialLoggedAt ?? DateTime.now();
    _hadInitialData = widget.initialRating != null ||
        (widget.initialReview != null && widget.initialReview!.isNotEmpty);
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  String _getRatingQualifier(double score) {
    if (score >= 5.0) return 'Obra-Prima ★★★';
    if (score >= 4.5) return 'Brilhante / Excelente';
    if (score >= 4.0) return 'Muito Bom';
    if (score >= 3.5) return 'Bom';
    if (score >= 3.0) return 'Acima da Média';
    if (score >= 2.5) return 'Razoável / Médio';
    if (score >= 2.0) return 'Abaixo da Média';
    if (score >= 1.5) return 'Fraco';
    if (score >= 1.0) return 'Muito Fraco';
    return 'Terrível';
  }

  void _updateScoreFromOffset(double dx, double totalWidth) {
    if (totalWidth <= 0) return;
    final clampedDx = dx.clamp(0.0, totalWidth);
    final raw = (clampedDx / totalWidth) * 5.0;
    // Snap to steps of 0.5: left half gives .5, right half gives 1.0
    double snapped = (raw * 2).ceil() / 2;
    if (snapped < 0.5) snapped = 0.5;
    if (snapped > 5.0) snapped = 5.0;
    setState(() {
      _currentRating = snapped;
    });
  }

  Future<void> _pickLoggedDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _loggedAt,
      firstDate: DateTime(1980),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: RatingModal.letterboxdGreen,
              onPrimary: Colors.black,
              surface: AppColors.surfaceHigh,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _loggedAt = picked;
      });
    }
  }

  void _saveLog() {
    final reviewText = _reviewController.text.trim();
    Navigator.of(context).pop(
      RatingLogSaved(
        rating: _currentRating,
        reviewText: reviewText.isEmpty ? null : reviewText,
        hasSpoilers: _hasSpoilers,
        loggedAt: _loggedAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday = _loggedAt.year == now.year &&
        _loggedAt.month == now.month &&
        _loggedAt.day == now.day;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top drag handle
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: AppColors.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header: Title, Item Name & Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (widget.badgeText != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: AppColors.primary.withValues(alpha: 0.45),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  widget.badgeText!,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: AppColors.secondary,
                                  ),
                                ),
                              ),
                            ],
                            Text(
                              widget.title,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.itemName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
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
              const SizedBox(height: 16),

              // Letterboxd 5-Star Rating Container
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _currentRating != null
                        ? RatingModal.letterboxdGreen.withValues(alpha: 0.4)
                        : AppColors.outline,
                    width: 1.2,
                  ),
                  boxShadow: _currentRating != null
                      ? [
                          BoxShadow(
                            color: RatingModal.letterboxdGreen
                                .withValues(alpha: 0.12),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  children: [
                    // The 5 Stars gesture bar
                    _buildStarBar(),
                    const SizedBox(height: 14),

                    // Label & Qualifier or Clear Rating button
                    if (_currentRating != null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            _currentRating!.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: RatingModal.letterboxdGreen,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            '★',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: RatingModal.letterboxdGreen,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '(${(_currentRating! * 2).toStringAsFixed(0)}/10)',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: RatingModal.letterboxdGreen
                                  .withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _getRatingQualifier(_currentRating!),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: RatingModal.letterboxdGreen,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          InkWell(
                            onTap: () => setState(() => _currentRating = null),
                            borderRadius: BorderRadius.circular(6),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.close_rounded,
                                    size: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                  SizedBox(width: 3),
                                  Text(
                                    'Limpar nota',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      const Text(
                        'Toca ou desliza para avaliar (0.5 a 5.0 ★)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Review / Notes TextField
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.outline, width: 0.8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: TextField(
                  controller: _reviewController,
                  minLines: 3,
                  maxLines: 6,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    hintText:
                        'Escreve uma análise ou notas sobre esta série/episódio...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                      height: 1.4,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Spoilers Toggle Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _hasSpoilers
                      ? const Color(0xFFF59E0B).withValues(alpha: 0.12)
                      : AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _hasSpoilers
                        ? const Color(0xFFF59E0B).withValues(alpha: 0.5)
                        : AppColors.outline,
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _hasSpoilers
                          ? Icons.warning_amber_rounded
                          : Icons.visibility_outlined,
                      size: 20,
                      color: _hasSpoilers
                          ? const Color(0xFFF59E0B)
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Contém Spoilers',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (_hasSpoilers)
                            const Text(
                              'Aviso visual ativado para proteger outros utilizadores',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFF59E0B),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _hasSpoilers,
                      activeColor: const Color(0xFFF59E0B),
                      onChanged: (val) => setState(() => _hasSpoilers = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Watched / Log Date Selector
              InkWell(
                onTap: _pickLoggedDate,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.outline, width: 0.8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        size: 18,
                        color: AppColors.secondary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Data do registo (Watched Date)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isToday
                                  ? 'Hoje (${Formatters.shortDate(_loggedAt)})'
                                  : Formatters.fullDate(_loggedAt),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.edit_calendar_rounded,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons: Cancel and Save Log
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.outline),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _saveLog,
                      style: FilledButton.styleFrom(
                        backgroundColor: RatingModal.letterboxdGreen,
                        foregroundColor: const Color(0xFF0F172A),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_rounded, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            _currentRating != null
                                ? 'Guardar Registo (${_currentRating!.toStringAsFixed(1)} ★)'
                                : 'Guardar Registo',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Action: Remove Rating / Log (if previously existed)
              if (_hadInitialData) ...[
                const SizedBox(height: 10),
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop(const RatingRemoved());
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger,
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: const Text(
                      'Remover registo e avaliação',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStarBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth = math.min(constraints.maxWidth, 260.0);

        return Center(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) =>
                _updateScoreFromOffset(details.localPosition.dx, barWidth),
            onHorizontalDragUpdate: (details) =>
                _updateScoreFromOffset(details.localPosition.dx, barWidth),
            child: SizedBox(
              width: barWidth,
              height: 52,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(5, (starIndex) {
                  return _buildIndividualStar(starIndex);
                }),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildIndividualStar(int starIndex) {
    const starSize = 44.0;
    final rating = _currentRating;

    if (rating == null || rating < (starIndex + 0.5)) {
      // Empty star
      return Container(
        width: starSize,
        height: starSize,
        alignment: Alignment.center,
        child: const Icon(
          Icons.star_rounded,
          size: starSize,
          color: RatingModal.emptyStarColor,
        ),
      );
    }

    if (rating >= (starIndex + 1.0)) {
      // Full star
      return Container(
        width: starSize,
        height: starSize,
        alignment: Alignment.center,
        child: const Icon(
          Icons.star_rounded,
          size: starSize,
          color: RatingModal.letterboxdGreen,
          shadows: [
            Shadow(
              color: Color(0x6600E054),
              blurRadius: 10,
            ),
          ],
        ),
      );
    }

    // Half star (clipped left half filled with green, right half empty)
    return SizedBox(
      width: starSize,
      height: starSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(
            Icons.star_rounded,
            size: starSize,
            color: RatingModal.emptyStarColor,
          ),
          ClipRect(
            clipper: _LeftHalfClipper(),
            child: const Icon(
              Icons.star_rounded,
              size: starSize,
              color: RatingModal.letterboxdGreen,
              shadows: [
                Shadow(
                  color: Color(0x6600E054),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LeftHalfClipper extends CustomClipper<Rect> {
  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, size.width / 2, size.height);
  }

  @override
  bool shouldReclip(CustomClipper<Rect> oldClipper) => false;
}
