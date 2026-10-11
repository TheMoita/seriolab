import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/translation_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../features/settings/presentation/providers/settings_providers.dart';
import '../../../../features/settings/presentation/widgets/user_avatar_widget.dart';
import '../../../reports/domain/entities/report_model.dart';
import '../../../reports/presentation/widgets/report_bottom_sheet.dart';
import '../../domain/entities/episode_review_model.dart';
import '../providers/episode_review_providers.dart';

/// Interactive card widget for an episode comment / review in the community section.
///
/// Features:
/// - Author avatar, display name, username, creation date and rating badge.
/// - Spoiler protection banner with tap-to-reveal.
/// - Inline translation toggling (original <-> translated) with loading indicator.
/// - Thumb up (Like) and thumb down (Dislike) reactions with counters and exclusive toggle.
/// - Report / moderation action for other users' comments.
class CommentCardWidget extends ConsumerStatefulWidget {
  const CommentCardWidget({
    super.key,
    required this.review,
    required this.seriesId,
    required this.seasonNumber,
    required this.episodeNumber,
    this.currentUserId,
    this.isOwnComment = false,
    this.isSpoilerProtected = false,
    this.onRevealSpoiler,
    this.onReport,
    this.onReviewUpdated,
  });

  final EpisodeReviewModel review;
  final int seriesId;
  final int seasonNumber;
  final int episodeNumber;
  final String? currentUserId;
  final bool isOwnComment;
  final bool isSpoilerProtected;
  final VoidCallback? onRevealSpoiler;
  final VoidCallback? onReport;
  final ValueChanged<EpisodeReviewModel>? onReviewUpdated;

  @override
  ConsumerState<CommentCardWidget> createState() => _CommentCardWidgetState();
}

class _CommentCardWidgetState extends ConsumerState<CommentCardWidget> {
  late EpisodeReviewModel _currentReview;

  bool _isTranslating = false;
  bool _isShowingTranslation = false;
  String? _translatedText;

  @override
  void initState() {
    super.initState();
    _currentReview = widget.review;
  }

  @override
  void didUpdateWidget(covariant CommentCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.review != widget.review) {
      _currentReview = widget.review;
    }
  }

  Future<void> _handleReaction({required bool isLike}) async {
    final uid = widget.currentUserId;
    if (uid == null || uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Inicia sessão para reagir aos comentários.'),
          backgroundColor: AppColors.surfaceHigh,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppColors.outline),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final hasLiked = _currentReview.isLikedBy(uid);
    final hasDisliked = _currentReview.isDislikedBy(uid);

    // Optimistic local update
    int nextLikes = _currentReview.likesCount;
    int nextDislikes = _currentReview.dislikesCount;
    final nextLikedBy = List<String>.from(_currentReview.likedBy);
    final nextDislikedBy = List<String>.from(_currentReview.dislikedBy);

    if (isLike) {
      if (hasLiked) {
        nextLikedBy.remove(uid);
        nextLikes = (nextLikes - 1).clamp(0, 999999);
      } else {
        nextLikedBy.add(uid);
        nextLikes += 1;
        if (hasDisliked) {
          nextDislikedBy.remove(uid);
          nextDislikes = (nextDislikes - 1).clamp(0, 999999);
        }
      }
    } else {
      if (hasDisliked) {
        nextDislikedBy.remove(uid);
        nextDislikes = (nextDislikes - 1).clamp(0, 999999);
      } else {
        nextDislikedBy.add(uid);
        nextDislikes += 1;
        if (hasLiked) {
          nextLikedBy.remove(uid);
          nextLikes = (nextLikes - 1).clamp(0, 999999);
        }
      }
    }

    final optimistic = _currentReview.copyWith(
      likesCount: nextLikes,
      dislikesCount: nextDislikes,
      likedBy: nextLikedBy,
      dislikedBy: nextDislikedBy,
    );

    setState(() {
      _currentReview = optimistic;
    });
    widget.onReviewUpdated?.call(optimistic);

    // Remote persistence
    try {
      final updated = await ref
          .read(episodeReviewRepositoryProvider)
          .toggleReaction(
            seriesId: widget.seriesId,
            seasonNumber: widget.seasonNumber,
            episodeNumber: widget.episodeNumber,
            reviewId: _currentReview.id,
            userId: uid,
            isLike: isLike,
          );
      if (updated != null && mounted) {
        setState(() {
          _currentReview = updated;
        });
        widget.onReviewUpdated?.call(updated);
      }
    } catch (_) {
      // Revert if remote failed
      if (mounted) {
        setState(() {
          _currentReview = widget.review;
        });
        widget.onReviewUpdated?.call(widget.review);
      }
    }
  }

  Future<void> _toggleTranslation() async {
    if (_isShowingTranslation) {
      setState(() {
        _isShowingTranslation = false;
      });
      return;
    }

    if (_translatedText != null) {
      setState(() {
        _isShowingTranslation = true;
      });
      return;
    }

    setState(() {
      _isTranslating = true;
    });

    try {
      final settings = ref.read(settingsControllerProvider);
      final targetLang = settings.language.split('-').first.toLowerCase();
      final translationService = ref.read(translationServiceProvider);

      final result = await translationService.translateComment(
        _currentReview.comment,
        targetLang,
      );

      if (!mounted) return;

      if (result != null && result.isNotEmpty) {
        setState(() {
          _translatedText = result;
          _isShowingTranslation = true;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Não foi possível traduzir o comentário de momento.'),
            backgroundColor: AppColors.surfaceHigh,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: AppColors.outline),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Erro ao contactar o serviço de tradução.'),
            backgroundColor: AppColors.surfaceHigh,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: AppColors.outline),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTranslating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = widget.currentUserId;
    final hasLiked = _currentReview.isLikedBy(uid);
    final hasDisliked = _currentReview.isDislikedBy(uid);

    const activeColor = Color(0xFF7C5CFC); // Seriolab Electric Violet
    const activeDislikeColor = Color(0xFF38BDF8); // Seriolab Sky Blue Accent

    final displayedCommentText = _isShowingTranslation && _translatedText != null
        ? _translatedText!
        : _currentReview.comment;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Author info & Rating
          Row(
            children: [
              UserAvatarWidget(
                avatarId: _currentReview.userAvatarId,
                avatarType: _currentReview.userAvatarType,
                avatarValue: _currentReview.userAvatarValue,
                size: 36,
                borderWidth: 1.5,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentReview.userDisplayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '@${_currentReview.username} • ${Formatters.timeAgo(_currentReview.createdAt)}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (_currentReview.rating != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E054).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '★ ${_currentReview.rating!.toStringAsFixed(1)}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF00E054),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              if (!widget.isOwnComment)
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Opções do comentário',
                  color: AppColors.surfaceHigh,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.outline),
                  ),
                  onSelected: (value) async {
                    if (value == 'report') {
                      if (widget.onReport != null) {
                        widget.onReport!();
                      } else {
                        await showReportBottomSheet(
                          context: context,
                          targetType: ReportTargetType.comment,
                          targetId: _currentReview.id,
                          reportedUserId: _currentReview.userId,
                          reportedUsername: _currentReview.username,
                        );
                      }
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem<String>(
                      value: 'report',
                      child: Row(
                        children: [
                          Icon(
                            Icons.flag_outlined,
                            size: 16,
                            color: AppColors.danger,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Denunciar comentário',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.danger,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),

          // 2. Comment Body with Spoiler Protection
          if (widget.isSpoilerProtected)
            InkWell(
              onTap: widget.onRevealSpoiler,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                    width: 0.8,
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: Color(0xFFF59E0B),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Aviso de Spoiler — Toca para ver',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFF59E0B),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: Color(0xFFF59E0B),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            Text(
              displayedCommentText,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
            if (_isShowingTranslation) ...[
              const SizedBox(height: 4),
              Text(
                'Traduzido automaticamente',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textMuted.withValues(alpha: 0.8),
                ),
              ),
            ],
          ],

          const SizedBox(height: 12),

          // 3. Bottom Action Bar: Like, Dislike, and Translate
          Row(
            children: [
              // Like (Thumb Up) Button
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _handleReaction(isLike: true),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasLiked
                            ? Icons.thumb_up_rounded
                            : Icons.thumb_up_outlined,
                        size: 15,
                        color: hasLiked ? activeColor : AppColors.textMuted,
                      ),
                      if (_currentReview.likesCount > 0) ...[
                        const SizedBox(width: 5),
                        Text(
                          '${_currentReview.likesCount}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: hasLiked ? activeColor : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 14),

              // Dislike (Thumb Down) Button
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _handleReaction(isLike: false),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasDisliked
                            ? Icons.thumb_down_rounded
                            : Icons.thumb_down_outlined,
                        size: 15,
                        color: hasDisliked
                            ? activeDislikeColor
                            : AppColors.textMuted,
                      ),
                      if (_currentReview.dislikesCount > 0) ...[
                        const SizedBox(width: 5),
                        Text(
                          '${_currentReview.dislikesCount}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: hasDisliked
                                ? activeDislikeColor
                                : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // Translation Toggle Button
              if (_currentReview.comment.trim().isNotEmpty)
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _isTranslating ? null : _toggleTranslation,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isTranslating) ...[
                          const SizedBox(
                            width: 11,
                            height: 11,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: AppColors.secondary,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'A traduzir...',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ] else ...[
                          Icon(
                            Icons.translate_rounded,
                            size: 13,
                            color: _isShowingTranslation
                                ? AppColors.secondary
                                : AppColors.textMuted,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _isShowingTranslation ? 'Ver original' : 'Traduzir',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _isShowingTranslation
                                  ? AppColors.secondary
                                  : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
