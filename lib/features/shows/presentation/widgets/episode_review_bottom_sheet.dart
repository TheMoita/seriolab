import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/modal_drag_handle.dart';
import '../../../../core/widgets/seriolab_loader.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../../tracking/presentation/providers/tracking_providers.dart';
import '../../domain/entities/episode.dart';
import '../../domain/entities/episode_review_model.dart';
import '../../domain/entities/show.dart';
import '../providers/episode_review_providers.dart';
import '../providers/show_providers.dart';

/// Opens the optional episode rating and review bottom sheet.
///
/// Designed to appear immediately after an episode transitions to "Watched".
/// Filling the rating and/or comment is completely optional; closing or ignoring
/// the sheet preserves the episode's watched status.
Future<void> showEpisodeRatingAndReviewSheet(
  BuildContext context,
  int seriesId,
  int seasonNumber,
  int episodeNumber,
  String episodeTitle, {
  ShowDetails? show,
  Episode? episode,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    backgroundColor: const Color(0xFF161922),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => EpisodeReviewBottomSheet(
      seriesId: seriesId,
      seasonNumber: seasonNumber,
      episodeNumber: episodeNumber,
      episodeTitle: episodeTitle,
      show: show,
      episode: episode,
    ),
  );
}

/// Optional BottomSheet modal for rating (0.5 to 10.0 stars) and commenting
/// on an episode right after marking it as watched.
class EpisodeReviewBottomSheet extends ConsumerStatefulWidget {
  const EpisodeReviewBottomSheet({
    super.key,
    required this.seriesId,
    required this.seasonNumber,
    required this.episodeNumber,
    required this.episodeTitle,
    this.show,
    this.episode,
  });

  final int seriesId;
  final int seasonNumber;
  final int episodeNumber;
  final String episodeTitle;
  final ShowDetails? show;
  final Episode? episode;

  @override
  ConsumerState<EpisodeReviewBottomSheet> createState() =>
      _EpisodeReviewBottomSheetState();
}

class _EpisodeReviewBottomSheetState
    extends ConsumerState<EpisodeReviewBottomSheet> {
  double? _selectedRating;
  late final TextEditingController _commentController;
  bool _hasSpoilers = false;
  bool _isSaving = false;

  static const Color _starFilledColor = Color(0xFFF59E0B);
  static const Color _starEmptyColor = Color(0xFF27303E);
  static const Color _primaryPurple = Color(0xFF7C5CFC);

  @override
  void initState() {
    super.initState();
    final tracking = ref.read(trackingControllerProvider).asData?.value;
    final watched = tracking?.watchedFor(widget.seriesId)[
        EpisodeKey(widget.seasonNumber, widget.episodeNumber)];

    final initialRating = watched?.userRating ?? widget.episode?.userRating;
    if (initialRating != null) {
      final clamped = initialRating.clamp(0.5, 10.0);
      _selectedRating = (clamped * 2).round() / 2;
    } else {
      _selectedRating = null;
    }

    _commentController = TextEditingController(
      text: watched?.reviewText ?? widget.episode?.reviewText ?? '',
    );
    _hasSpoilers =
        watched?.hasSpoilers ?? widget.episode?.hasSpoilers ?? false;
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  String _getRatingQualifier(double score) {
    if (score >= 10.0) return 'Masterpiece ★★★';
    if (score >= 9.5) return 'Masterpiece';
    if (score >= 9.0) return 'Brilliant / Excellent';
    if (score >= 8.5) return 'Excellent';
    if (score >= 8.0) return 'Very Good';
    if (score >= 7.5) return 'Good +';
    if (score >= 7.0) return 'Good';
    if (score >= 6.5) return 'Above Average';
    if (score >= 6.0) return 'Decent +';
    if (score >= 5.5) return 'Decent';
    if (score >= 5.0) return 'Average';
    if (score >= 4.5) return 'Below Average';
    if (score >= 4.0) return 'Poor +';
    if (score >= 3.5) return 'Poor';
    if (score >= 3.0) return 'Very Poor';
    if (score >= 2.5) return 'Bad';
    if (score >= 2.0) return 'Very Bad';
    if (score >= 1.5) return 'Terrible';
    if (score >= 1.0) return 'Dreadful';
    return 'Unbearable';
  }

  void _updateScore(double dx, double totalWidth) {
    if (totalWidth <= 0) return;
    final clampedDx = dx.clamp(0.0, totalWidth);
    final raw = (clampedDx / totalWidth) * 10.0;
    double snapped = (raw * 2).ceil() / 2;
    if (snapped < 0.5) snapped = 0.5;
    if (snapped > 10.0) snapped = 10.0;
    setState(() {
      _selectedRating = snapped;
    });
  }

  Future<void> _handleSave() async {
    final comment = _commentController.text.trim();
    final hasRating = _selectedRating != null;
    final hasComment = comment.isNotEmpty;

    // If nothing was entered, close gracefully without changes
    if (!hasRating && !hasComment) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _isSaving = true);

    try {
      // 1. Resolve ShowDetails
      final effectiveShow = widget.show ??
          ref.read(showDetailsProvider(widget.seriesId)).value ??
          ShowDetails(
            id: widget.seriesId,
            name: widget.episodeTitle,
          );

      // 2. Resolve Episode
      final effectiveEpisode = widget.episode ??
          ref
              .read(episodeDetailsProvider((
                showId: widget.seriesId,
                seasonNumber: widget.seasonNumber,
                episodeNumber: widget.episodeNumber,
              )))
              .value
              ?.episode ??
          Episode(
            id: 0,
            showId: widget.seriesId,
            seasonNumber: widget.seasonNumber,
            episodeNumber: widget.episodeNumber,
            name: widget.episodeTitle,
          );

      final now = DateTime.now();

      // 3. Persist rating and review to tracking controller (SQLite + Firestore users/{uid}/watched_episodes)
      await ref.read(trackingControllerProvider.notifier).rateEpisode(
            effectiveShow,
            effectiveEpisode,
            _selectedRating,
            reviewText: hasComment ? comment : null,
            hasSpoilers: _hasSpoilers,
            loggedAt: now,
          );

      // 4. Save review in community / episode review repository (SQLite meta + Firestore subcollections)
      final settings = ref.read(settingsControllerProvider);
      final reviewModel = EpisodeReviewModel(
        id: 'rev_${now.millisecondsSinceEpoch}',
        episodeKeyString: EpisodeReviewModel.buildKey(
          widget.seriesId,
          widget.seasonNumber,
          widget.episodeNumber,
        ),
        userId: settings.username.isNotEmpty ? settings.username : 'user',
        username: settings.username.isNotEmpty ? settings.username : 'member',
        userDisplayName: settings.displayName.isNotEmpty
            ? settings.displayName
            : 'Seriolab Member',
        userAvatarId: settings.avatarId,
        userAvatarType: settings.avatarType,
        userAvatarValue: settings.avatarValue,
        rating: _selectedRating,
        comment: comment,
        containsSpoilers: _hasSpoilers,
        createdAt: now,
      );

      await ref.read(episodeReviewRepositoryProvider).addReview(reviewModel);
      ref.invalidate(episodeReviewsProvider((
        showId: widget.seriesId,
        seasonNumber: widget.seasonNumber,
        episodeNumber: widget.episodeNumber,
      )));

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _selectedRating != null
                  ? 'Rating of ${_selectedRating!.toStringAsFixed(1)} ★ saved!'
                  : 'Review logged successfully!',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving review: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          top: 10,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Single discreet gray drag handle
              const ModalDragHandle(topPadding: 0, bottomPadding: 14),

              // Header: Subtitle, Title & Discreet Close Button
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'S${widget.seasonNumber} • E${widget.episodeNumber} — ${widget.episodeTitle}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                            color: AppColors.secondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'What did you think of this episode?',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: AppColors.textSecondary,
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Rating Selector (0.5 to 10.0 Stars)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _selectedRating != null
                        ? _starFilledColor.withValues(alpha: 0.35)
                        : AppColors.outline,
                    width: 1.0,
                  ),
                  boxShadow: _selectedRating != null
                      ? [
                          BoxShadow(
                            color: _starFilledColor.withValues(alpha: 0.10),
                            blurRadius: 14,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  children: [
                    // Star bar with horizontal drag & tap detection
                    _buildStarBar(),
                    const SizedBox(height: 12),

                    // Rating value display or invitation to tap/drag
                    if (_selectedRating != null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _selectedRating!.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: _starFilledColor,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Text(
                            '★',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: _starFilledColor,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            '/ 10',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _starFilledColor.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _getRatingQualifier(_selectedRating!),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: _starFilledColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () => setState(() => _selectedRating = null),
                        borderRadius: BorderRadius.circular(6),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.close_rounded,
                                size: 12,
                                color: AppColors.textMuted,
                              ),
                              SizedBox(width: 3),
                              Text(
                                'Clear rating',
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
                    ] else ...[
                      const Text(
                        'Tap or slide to rate (0.5 to 10.0 ★)',
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
              const SizedBox(height: 14),

              // Comment / Opinion Input
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.outline, width: 0.8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: TextField(
                  controller: _commentController,
                  minLines: 3,
                  maxLines: 5,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    hintText:
                        'Write your thoughts on this episode (optional)...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                      height: 1.4,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Spoilers Minimalist Toggle
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: _hasSpoilers
                      ? const Color(0xFFF59E0B).withValues(alpha: 0.12)
                      : AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _hasSpoilers
                        ? const Color(0xFFF59E0B).withValues(alpha: 0.45)
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
                      size: 18,
                      color: _hasSpoilers
                          ? const Color(0xFFF59E0B)
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Contains spoilers',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _hasSpoilers
                              ? const Color(0xFFF59E0B)
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Switch.adaptive(
                      value: _hasSpoilers,
                      activeThumbColor: const Color(0xFFF59E0B),
                      onChanged: (val) => setState(() => _hasSpoilers = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Action Buttons: Secondary ("Not now") and Primary ("Save")
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
                        'Not now',
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
                      onPressed: _isSaving ? null : _handleSave,
                      style: FilledButton.styleFrom(
                        backgroundColor: _primaryPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SeriolabLoader(size: 20)
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_rounded, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  _selectedRating != null
                                      ? 'Save (${_selectedRating!.toStringAsFixed(1)} ★)'
                                      : 'Save',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStarBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth = math.min(constraints.maxWidth, 340.0);

        return Center(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) =>
                _updateScore(details.localPosition.dx, barWidth),
            onHorizontalDragUpdate: (details) =>
                _updateScore(details.localPosition.dx, barWidth),
            child: SizedBox(
              width: barWidth,
              height: 42,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(10, (starIndex) {
                  return _buildIndividualStar(starIndex, size: 26.0);
                }),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildIndividualStar(int starIndex, {required double size}) {
    final rating = _selectedRating;

    if (rating == null || rating < (starIndex + 0.5)) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        child: Icon(
          Icons.star_rounded,
          size: size,
          color: _starEmptyColor,
        ),
      );
    }

    if (rating >= (starIndex + 1.0)) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        child: Icon(
          Icons.star_rounded,
          size: size,
          color: _starFilledColor,
          shadows: const [
            Shadow(
              color: Color(0x66F59E0B),
              blurRadius: 8,
            ),
          ],
        ),
      );
    }

    // Half star (clipped left half filled with amber, right half empty)
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.star_rounded,
            size: size,
            color: _starEmptyColor,
          ),
          ClipRect(
            clipper: _LeftHalfClipper(),
            child: Icon(
              Icons.star_rounded,
              size: size,
              color: _starFilledColor,
              shadows: const [
                Shadow(
                  color: Color(0x66F59E0B),
                  blurRadius: 8,
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
