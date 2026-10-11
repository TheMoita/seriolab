import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/seriolab_loader.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../../settings/presentation/widgets/user_avatar_widget.dart';
import '../../../tracking/domain/entities/tracking_entities.dart';
import '../../../tracking/presentation/providers/tracking_providers.dart';
import '../../domain/entities/episode.dart';
import '../../domain/entities/episode_review_model.dart';
import '../../domain/entities/show.dart';
import '../providers/episode_review_providers.dart';
import '../providers/show_providers.dart';
import '../widgets/episode_review_bottom_sheet.dart';
import '../widgets/rating_modal.dart';

class EpisodeDetailScreen extends ConsumerStatefulWidget {
  const EpisodeDetailScreen({
    super.key,
    required this.seriesId,
    required this.seasonNumber,
    required this.episodeNumber,
    this.initialShow,
    this.initialEpisode,
  });

  final int seriesId;
  final int seasonNumber;
  final int episodeNumber;
  final ShowDetails? initialShow;
  final Episode? initialEpisode;

  @override
  ConsumerState<EpisodeDetailScreen> createState() =>
      _EpisodeDetailScreenState();
}

class _EpisodeDetailScreenState extends ConsumerState<EpisodeDetailScreen> {
  bool _synopsisSpoilerRevealed = false;
  final Set<String> _revealedCommentSpoilers = {};
  late final TextEditingController _commentController;
  bool _commentContainsSpoilers = false;
  bool _isSubmittingComment = false;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  EpisodeRef get _episodeRef => (
        showId: widget.seriesId,
        seasonNumber: widget.seasonNumber,
        episodeNumber: widget.episodeNumber,
      );

  Future<void> _openRatingModal({
    required ShowDetails show,
    required Episode episode,
    required double? currentRating,
    required String? currentReview,
    required bool currentHasSpoilers,
    required DateTime? currentLoggedAt,
  }) async {
    final result = await RatingModal.show(
      context,
      title: 'Avaliar Episódio',
      itemName: '${episode.code} - ${episode.title}',
      badgeText: 'T${widget.seasonNumber} • E${widget.episodeNumber}',
      initialRating: currentRating,
      initialReview: currentReview,
      initialHasSpoilers: currentHasSpoilers,
      initialLoggedAt: currentLoggedAt,
    );

    if (!mounted || result == null) return;

    if (result is RatingSelected) {
      await ref.read(trackingControllerProvider.notifier).rateEpisode(
            show,
            episode,
            result.rating,
            reviewText: result.reviewText,
            hasSpoilers: result.hasSpoilers,
            loggedAt: result.loggedAt,
          );

      if (result.reviewText != null && result.reviewText!.trim().isNotEmpty) {
        final settings = ref.read(settingsControllerProvider);
        final reviewModel = EpisodeReviewModel(
          id: 'user_review_${DateTime.now().millisecondsSinceEpoch}',
          episodeKeyString: EpisodeReviewModel.buildKey(
            widget.seriesId,
            widget.seasonNumber,
            widget.episodeNumber,
          ),
          userId: settings.username.isNotEmpty ? settings.username : 'user',
          username: settings.username.isNotEmpty ? settings.username : 'membro',
          userDisplayName: settings.displayName.isNotEmpty
              ? settings.displayName
              : 'Membro Seriolab',
          userAvatarId: settings.avatarId,
          userAvatarType: settings.avatarType,
          userAvatarValue: settings.avatarValue,
          rating: result.rating,
          comment: result.reviewText!.trim(),
          containsSpoilers: result.hasSpoilers,
          createdAt: result.loggedAt,
        );
        await ref.read(episodeReviewRepositoryProvider).addReview(reviewModel);
        ref.invalidate(episodeReviewsProvider(_episodeRef));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.rating != null
                  ? 'Avaliação de ${result.rating!.toStringAsFixed(1)} ★ guardada para ${episode.code}!'
                  : 'Registo do episódio ${episode.code} guardado!',
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else if (result is RatingRemoved) {
      await ref
          .read(trackingControllerProvider.notifier)
          .rateEpisode(show, episode, null, clearReview: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Avaliação do episódio ${episode.code} removida.'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isSubmittingComment = true;
    });

    final settings = ref.read(settingsControllerProvider);

    try {
      final newReview = EpisodeReviewModel(
        id: 'rev_${DateTime.now().millisecondsSinceEpoch}',
        episodeKeyString: EpisodeReviewModel.buildKey(
          widget.seriesId,
          widget.seasonNumber,
          widget.episodeNumber,
        ),
        userId: settings.username.isNotEmpty ? settings.username : 'user',
        username: settings.username.isNotEmpty ? settings.username : 'membro',
        userDisplayName: settings.displayName.isNotEmpty
            ? settings.displayName
            : 'Membro Seriolab',
        userAvatarId: settings.avatarId,
        userAvatarType: settings.avatarType,
        userAvatarValue: settings.avatarValue,
        comment: text,
        containsSpoilers: _commentContainsSpoilers,
        createdAt: DateTime.now(),
      );

      await ref.read(episodeReviewRepositoryProvider).addReview(newReview);
      ref.invalidate(episodeReviewsProvider(_episodeRef));

      _commentController.clear();
      setState(() {
        _commentContainsSpoilers = false;
      });

      if (mounted) {
        FocusScope.of(context).unfocus();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comentário publicado com sucesso!'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao publicar comentário: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingComment = false;
        });
      }
    }
  }

  String _getRatingQualifier(double score) {
    if (score >= 10.0) return 'Obra-Prima ★★★';
    if (score >= 9.5) return 'Obra-Prima';
    if (score >= 9.0) return 'Brilhante / Excelente';
    if (score >= 8.5) return 'Excelente';
    if (score >= 8.0) return 'Muito Bom';
    if (score >= 7.5) return 'Bom +';
    if (score >= 7.0) return 'Bom';
    if (score >= 6.5) return 'Acima da Média';
    if (score >= 6.0) return 'Razoável +';
    if (score >= 5.5) return 'Razoável';
    if (score >= 5.0) return 'Mediano';
    if (score >= 4.5) return 'Abaixo da Média';
    if (score >= 4.0) return 'Fraco +';
    if (score >= 3.5) return 'Fraco';
    if (score >= 3.0) return 'Muito Fraco';
    if (score >= 2.5) return 'Mau';
    if (score >= 2.0) return 'Muito Mau';
    if (score >= 1.5) return 'Terrível';
    if (score >= 1.0) return 'Pavoroso';
    return 'Insuportável';
  }

  @override
  Widget build(BuildContext context) {
    final showAsync = ref.watch(showDetailsProvider(widget.seriesId));
    final show = showAsync.value ?? widget.initialShow;

    final epDetailsAsync = ref.watch(episodeDetailsProvider(_episodeRef));
    final epDetails = epDetailsAsync.value;
    final fallbackEp = widget.initialEpisode ??
        Episode(
          id: 0,
          showId: widget.seriesId,
          seasonNumber: widget.seasonNumber,
          episodeNumber: widget.episodeNumber,
          name: 'Episódio ${widget.episodeNumber}',
        );
    final episode = epDetails?.episode ?? fallbackEp;

    final settings = ref.watch(settingsControllerProvider);
    final trackingState = ref.watch(trackingControllerProvider).asData?.value;
    final watchedMap = trackingState?.watchedFor(widget.seriesId) ?? {};
    final watchedEpisode = watchedMap[episode.key];
    final isWatched = watchedEpisode != null;

    final personalRating = watchedEpisode?.userRating ?? episode.userRating;
    final personalReview = watchedEpisode?.reviewText ?? episode.reviewText;
    final personalHasSpoilers =
        watchedEpisode?.hasSpoilers ?? episode.hasSpoilers;
    final personalLoggedAt = watchedEpisode?.loggedAt ?? episode.loggedAt;

    final isSynopsisProtected = settings.hideSpoilersForUnwatched &&
        !isWatched &&
        !_synopsisSpoilerRevealed;

    final reviewsAsync = ref.watch(episodeReviewsProvider(_episodeRef));
    final reviews = reviewsAsync.value ?? const [];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // 16:9 Still Backdrop Header with dark gradient
          _buildBackdropHeader(
            context: context,
            show: show,
            episode: episode,
            epDetails: epDetails,
            isWatched: isWatched,
            settings: settings,
          ),

          // Main Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title, Air Date, Runtime & TMDB Info
                  _buildEpisodeMetadata(
                    show: show,
                    episode: episode,
                    settings: settings,
                  ),

                  const SizedBox(height: 18),

                  // Quick Action Tracking Button
                  _buildTrackingActionButton(
                    show: show,
                    episode: episode,
                    isWatched: isWatched,
                  ),

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 20),

                  // Synopsis & Metadata Section
                  _buildSynopsisSection(
                    episode: episode,
                    isProtected: isSynopsisProtected,
                  ),

                  const SizedBox(height: 24),

                  // Cast & Crew (Guest Stars, Directors, Writers)
                  if (epDetails != null) ...[
                    _buildCastAndCrewSection(epDetails),
                    const SizedBox(height: 24),
                  ],

                  const Divider(),
                  const SizedBox(height: 20),

                  // Personal Rating and Review Log (Letterboxd-style)
                  if (show != null)
                    _buildPersonalRatingCard(
                      show: show,
                      episode: episode,
                      rating: personalRating,
                      reviewText: personalReview,
                      hasSpoilers: personalHasSpoilers,
                      loggedAt: personalLoggedAt,
                      watchedEpisode: watchedEpisode,
                    ),

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 20),

                  // Community Reviews & Comments Section
                  _buildCommunitySection(reviews),

                  const SizedBox(height: 20),

                  // Comment Input Box
                  _buildCommentInputSection(),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 16:9 Backdrop Still with dark transition gradient and back button
  Widget _buildBackdropHeader({
    required BuildContext context,
    required ShowDetails? show,
    required Episode episode,
    required EpisodeDetails? epDetails,
    required bool isWatched,
    required dynamic settings,
  }) {
    final stillUrl = epDetails?.stillHighResUrl ??
        episode.stillUrl ??
        show?.backdropUrl;

    return SliverAppBar(
      expandedHeight: 230,
      pinned: true,
      elevation: 0,
      backgroundColor: AppColors.background,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: CircleAvatar(
          backgroundColor: Colors.black.withValues(alpha: 0.6),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Colors.white,
              size: 20,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Episode Still Image (16:9)
            AppNetworkImage(
              imageUrl: stillUrl,
              fallbackImageUrl: show?.backdropUrl,
              title: episode.displayTitle(
                showOriginal: settings.showOriginalTitles,
              ),
              fit: BoxFit.cover,
            ),

            // Subtle dark overlay
            Container(color: Colors.black.withValues(alpha: 0.2)),

            // Gradient transition to #0D0F17
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      AppColors.background.withValues(alpha: 0.75),
                      AppColors.background,
                    ],
                    stops: const [0.0, 0.4, 0.82, 1.0],
                  ),
                ),
              ),
            ),

            // Top-right series title badge
            if (show != null)
              Positioned(
                top: MediaQuery.of(context).padding.top + 12,
                right: 16,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                      width: 0.6,
                    ),
                  ),
                  child: Text(
                    show.displayTitle(
                      showOriginal: settings.showOriginalTitles,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),

            // Bottom-left Season/Episode Badge over the image
            Positioned(
              left: 16,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.7),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.tv_rounded,
                      size: 13,
                      color: AppColors.secondary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'T${widget.seasonNumber} • E${widget.episodeNumber}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Title, Technical info (air date, runtime, TMDB score)
  Widget _buildEpisodeMetadata({
    required ShowDetails? show,
    required Episode episode,
    required dynamic settings,
  }) {
    final title =
        episode.displayTitle(showOriginal: settings.showOriginalTitles);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            letterSpacing: -0.4,
            height: 1.2,
          ),
        ),
        if (settings.showOriginalTitles &&
            episode.title.isNotEmpty &&
            episode.title != episode.displayTitle(showOriginal: true)) ...[
          const SizedBox(height: 3),
          Text(
            episode.title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            if (episode.airDate != null) ...[
              const Icon(
                Icons.calendar_today_rounded,
                size: 13,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                Formatters.fullDate(episode.airDate),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
            ],
            if (episode.runtime != null || show?.episodeRuntime != null) ...[
              const Icon(
                Icons.schedule_rounded,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                '${episode.runtime ?? show?.episodeRuntime ?? 0}m',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
            ],
            if (episode.rating > 0) ...[
              const Icon(
                Icons.star_rounded,
                size: 15,
                color: Color(0xFFFBBF24),
              ),
              const SizedBox(width: 3),
              Text(
                '${episode.rating.toStringAsFixed(1)} TMDB',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// Quick action button to mark episode as watched/unwatched
  Widget _buildTrackingActionButton({
    required ShowDetails? show,
    required Episode episode,
    required bool isWatched,
  }) {
    return SizedBox(
      width: double.infinity,
      child: isWatched
          ? FilledButton.icon(
              onPressed: show != null
                  ? () {
                      ref
                          .read(trackingControllerProvider.notifier)
                          .toggleEpisode(show, episode);
                    }
                  : null,
              icon: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF0F172A),
                size: 18,
              ),
              label: const Text(
                'Episódio Visto',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.secondary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            )
          : OutlinedButton.icon(
              onPressed: show != null
                  ? () async {
                      await ref
                          .read(trackingControllerProvider.notifier)
                          .toggleEpisode(show, episode);
                      if (mounted) {
                        final showOriginal = ref
                            .read(settingsControllerProvider)
                            .showOriginalTitles;
                        showEpisodeRatingAndReviewSheet(
                          context,
                          widget.seriesId,
                          widget.seasonNumber,
                          widget.episodeNumber,
                          episode.displayTitle(
                            showOriginal: showOriginal,
                          ),
                          show: show,
                          episode: episode,
                        );
                      }
                    }
                  : null,
              icon: const Icon(
                Icons.remove_red_eye_outlined,
                color: AppColors.secondary,
                size: 18,
              ),
              label: const Text(
                'Marcar como Visto',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.secondary,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.secondary, width: 1.2),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
    );
  }

  /// Synopsis section with anti-spoiler protection fallback
  Widget _buildSynopsisSection({
    required Episode episode,
    required bool isProtected,
  }) {
    final rawOverview = episode.overview.trim();
    final hasOverview = rawOverview.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sinopse',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        if (isProtected)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                width: 0.8,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(
                  Icons.visibility_off_rounded,
                  size: 26,
                  color: Color(0xFFF59E0B),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sinopse oculta para evitar spoilers',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Ainda não marcaste este episódio como visto. Podes revelar a sinopse se preferires.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      _synopsisSpoilerRevealed = true;
                    });
                  },
                  icon: const Icon(Icons.remove_red_eye_rounded, size: 16),
                  label: const Text(
                    'Revelar Sinopse',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Text(
            hasOverview
                ? rawOverview
                : 'Nenhuma sinopse disponível para este episódio.',
            style: TextStyle(
              fontSize: 14,
              color: hasOverview
                  ? AppColors.textPrimary.withValues(alpha: 0.9)
                  : AppColors.textMuted,
              height: 1.5,
              fontStyle: hasOverview ? FontStyle.normal : FontStyle.italic,
            ),
          ),
      ],
    );
  }

  /// Guest Stars carousel, Directors and Writers badges
  Widget _buildCastAndCrewSection(EpisodeDetails epDetails) {
    final directors = epDetails.directors;
    final writers = epDetails.writers;
    final guestStars = epDetails.guestStars;

    if (directors.isEmpty && writers.isEmpty && guestStars.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Crew: Directors & Writers
        if (directors.isNotEmpty || writers.isNotEmpty) ...[
          const Text(
            'Equipa Técnica',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (directors.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.outline, width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.movie_creation_outlined,
                        size: 14,
                        color: AppColors.secondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Realização: ${directors.map((d) => d.name).join(', ')}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              if (writers.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.outline, width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.edit_note_rounded,
                        size: 15,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Argumento: ${writers.map((w) => w.name).join(', ')}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
        ],

        // Guest Stars
        if (guestStars.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Atores Convidados',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '${guestStars.length}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: guestStars.length,
              separatorBuilder: (context, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final actor = guestStars[index];
                return SizedBox(
                  width: 76,
                  child: Column(
                    children: [
                      AppNetworkImage(
                        imageUrl: actor.profileUrl,
                        title: actor.name,
                        width: 54,
                        height: 54,
                        borderRadius: BorderRadius.circular(27),
                        fit: BoxFit.cover,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        actor.name,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          height: 1.1,
                        ),
                      ),
                      if (actor.character.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          actor.character,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 9,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  /// Letterboxd-style personal evaluation & review card
  Widget _buildPersonalRatingCard({
    required ShowDetails show,
    required Episode episode,
    required double? rating,
    required String? reviewText,
    required bool hasSpoilers,
    required DateTime? loggedAt,
    required WatchedEpisode? watchedEpisode,
  }) {
    final hasRatingOrReview = rating != null ||
        (reviewText != null && reviewText.trim().isNotEmpty);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: rating != null
              ? RatingModal.letterboxdGreen.withValues(alpha: 0.45)
              : AppColors.outline,
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.rate_review_outlined,
                    size: 16,
                    color: RatingModal.letterboxdGreen,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'A Tua Avaliação',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              if (hasRatingOrReview)
                TextButton(
                  onPressed: () => _openRatingModal(
                    show: show,
                    episode: episode,
                    currentRating: rating,
                    currentReview: reviewText,
                    currentHasSpoilers: hasSpoilers,
                    currentLoggedAt: loggedAt,
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.secondary,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text(
                    'Editar Registo',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (hasRatingOrReview) ...[
            if (rating != null) ...[
              Row(
                children: [
                  Text(
                    rating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: RatingModal.letterboxdGreen,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    '★',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: RatingModal.letterboxdGreen,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: RatingModal.letterboxdGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getRatingQualifier(rating),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: RatingModal.letterboxdGreen,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (reviewText != null && reviewText.trim().isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.outline, width: 0.6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasSpoilers)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Contém Spoilers',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                      ),
                    Text(
                      reviewText.trim(),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (loggedAt != null)
              Text(
                'Registado em ${Formatters.fullDate(loggedAt)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
          ] else ...[
            const Text(
              'Ainda não avaliaste este episódio. Dá uma nota de 0.5 a 10.0 estrelas no estilo Letterboxd!',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _openRatingModal(
                  show: show,
                  episode: episode,
                  currentRating: null,
                  currentReview: null,
                  currentHasSpoilers: false,
                  currentLoggedAt: null,
                ),
                icon: const Icon(
                  Icons.star_rounded,
                  color: Color(0xFF0F172A),
                  size: 18,
                ),
                label: const Text(
                  'Registar / Avaliar Episódio',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: RatingModal.letterboxdGreen,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Community section with comments list and spoiler protection
  Widget _buildCommunitySection(List<EpisodeReviewModel> reviews) {
    final ratedList = reviews.where((r) => r.rating != null);
    final avgScore = ratedList.isNotEmpty
        ? ratedList.fold<double>(0.0, (acc, r) => acc + r.rating!) /
            ratedList.length
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text(
                  'Comunidade',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.outline, width: 0.6),
                  ),
                  child: Text(
                    '${reviews.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            if (avgScore != null)
              Row(
                children: [
                  const Text(
                    'Média: ',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  Text(
                    '${avgScore.toStringAsFixed(1)} ★',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: RatingModal.letterboxdGreen,
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 14),

        if (reviews.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.outline, width: 0.6),
            ),
            child: const Center(
              child: Text(
                'Ainda não existem comentários para este episódio. Sê o primeiro a partilhar a tua opinião!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                  height: 1.4,
                ),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: reviews.length,
            separatorBuilder: (context, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final review = reviews[index];
              final isSpoilerProtected = review.containsSpoilers &&
                  !_revealedCommentSpoilers.contains(review.id);

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
                    // Author info & Rating
                    Row(
                      children: [
                        UserAvatarWidget(
                          avatarId: review.userAvatarId,
                          avatarType: review.userAvatarType,
                          avatarValue: review.userAvatarValue,
                          size: 36,
                          borderWidth: 1.5,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                review.userDisplayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                '@${review.username} • ${Formatters.timeAgo(review.createdAt)}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (review.rating != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: RatingModal.letterboxdGreen
                                  .withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '★ ${review.rating!.toStringAsFixed(1)}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: RatingModal.letterboxdGreen,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Comment Body with Spoiler Protection
                    if (isSpoilerProtected)
                      InkWell(
                        onTap: () {
                          setState(() {
                            _revealedCommentSpoilers.add(review.id);
                          });
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFF59E0B).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFFF59E0B)
                                  .withValues(alpha: 0.35),
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
                    else
                      Text(
                        review.comment,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                          height: 1.4,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  /// Comment input bar with "Contém Spoilers" toggle and submit action
  Widget _buildCommentInputSection() {
    final settings = ref.watch(settingsControllerProvider);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatarWidget(
                avatarId: settings.avatarId,
                avatarType: settings.avatarType,
                avatarValue: settings.avatarValue,
                size: 30,
                borderWidth: 1.2,
              ),
              const SizedBox(width: 8),
              const Text(
                'Deixar um comentário',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _commentController,
            minLines: 2,
            maxLines: 4,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
            decoration: const InputDecoration(
              hintText: 'Escreve a tua opinião sobre o episódio...',
              hintStyle: TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Spoilers checkbox / chip toggle
              InkWell(
                onTap: () {
                  setState(() {
                    _commentContainsSpoilers = !_commentContainsSpoilers;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _commentContainsSpoilers
                        ? const Color(0xFFF59E0B).withValues(alpha: 0.2)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _commentContainsSpoilers
                          ? const Color(0xFFF59E0B)
                          : AppColors.outline,
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _commentContainsSpoilers
                            ? Icons.warning_amber_rounded
                            : Icons.visibility_outlined,
                        size: 13,
                        color: _commentContainsSpoilers
                            ? const Color(0xFFF59E0B)
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Contém Spoilers',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _commentContainsSpoilers
                              ? const Color(0xFFF59E0B)
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              // Publish Button
              FilledButton.icon(
                onPressed: _isSubmittingComment ? null : _submitComment,
                icon: _isSubmittingComment
                    ? const SeriolabLoader(
                        size: 16,
                        primaryColor: Colors.white,
                        secondaryColor: AppColors.secondary,
                      )
                    : const Icon(Icons.send_rounded, size: 14),
                label: const Text(
                  'Comentar',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
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
