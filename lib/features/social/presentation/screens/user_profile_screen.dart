import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/seriolab_loader.dart';
import '../../../settings/presentation/widgets/user_avatar_widget.dart';
import '../../../shows/presentation/screens/show_detail_screen.dart';
import '../../../tracking/presentation/widgets/top_favorites_section.dart';
import '../../domain/entities/user_profile.dart';
import '../providers/social_providers.dart';
import '../widgets/follow_list_sheet.dart';

/// Screen displaying the public profile of any Seriolab user.
class UserProfileScreen extends ConsumerWidget {
  const UserProfileScreen({
    super.key,
    required this.userId,
  });

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider(userId));
    final isFollowing = ref.watch(isFollowingUserProvider(userId));

    return Scaffold(
      body: profileAsync.when(
        loading: () => const Scaffold(
          body: Center(
            child: SeriolabLoader(),
          ),
        ),
        error: (err, _) => Scaffold(
          appBar: AppBar(),
          body: Center(
            child: EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Erro ao carregar perfil',
              message: err.toString(),
              actionLabel: 'Tentar novamente',
              onAction: () => ref.refresh(userProfileProvider(userId)),
            ),
          ),
        ),
        data: (profile) {
          if (profile == null) {
            return Scaffold(
              appBar: AppBar(),
              body: const Center(
                child: EmptyState(
                  icon: Icons.person_off_rounded,
                  title: 'Utilizador não encontrado',
                  message: 'O perfil que procuras não existe ou foi removido.',
                ),
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              // Custom Header Sliver with Banner, Avatar & Appbar
              SliverToBoxAdapter(
                child: _UserProfileHeader(
                  profile: profile,
                  isFollowing: isFollowing,
                ),
              ),

              // Top 5 Favorite Series
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 24, bottom: 20),
                  child: TopFavoritesSection(
                    favoriteIds: profile.topFiveFavorites,
                    isEditable: false,
                  ),
                ),
              ),

              // Recent Ratings & Activity Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ATIVIDADE & AVALIAÇÕES RECENTES',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (profile.recentRatings.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 24,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.outline),
                          ),
                          child: const Center(
                            child: Text(
                              'Ainda sem avaliações públicas registadas.',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: profile.recentRatings.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, idx) {
                            final rating = profile.recentRatings[idx];
                            return _RecentRatingCard(rating: rating);
                          },
                        ),
                      const SizedBox(height: 36),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _UserProfileHeader extends ConsumerWidget {
  const _UserProfileHeader({
    required this.profile,
    required this.isFollowing,
  });

  final UserProfile profile;
  final bool isFollowing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const bannerHeight = 180.0;
    const avatarSize = 84.0;

    return Stack(
      children: [
        Column(
          children: [
            // Banner Background
            SizedBox(
              height: bannerHeight,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (profile.profileBannerUrl != null &&
                      profile.profileBannerUrl!.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: profile.profileBannerUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(color: AppColors.surfaceHigh),
                      errorWidget: (_, _, _) => _defaultGradient(),
                    )
                  else
                    _defaultGradient(),
                  // Dark gradient overlay
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Color(0xCC0D0F17),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Profile info content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const SizedBox(height: (avatarSize / 2) + 8),

                  // Display Name
                  Text(
                    profile.displayName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),

                  // Username
                  Text(
                    profile.handle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondary,
                    ),
                  ),

                  // Bio
                  if (profile.bio.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        profile.bio,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Followers & Following Counters Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _FollowCounterPill(
                        label: 'A Seguir',
                        count: profile.followingCount,
                        onTap: () {
                          FollowListSheet.show(
                            context,
                            userId: profile.id,
                            username: profile.handle,
                            initialIndex: 0,
                          );
                        },
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: AppColors.textMuted,
                          shape: BoxShape.circle,
                        ),
                      ),
                      _FollowCounterPill(
                        label: 'Seguidores',
                        count: profile.followersCount,
                        onTap: () {
                          FollowListSheet.show(
                            context,
                            userId: profile.id,
                            username: profile.handle,
                            initialIndex: 1,
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Dynamic Action Button (Seguir / A Seguir)
                  if (!profile.isCurrentUser)
                    _FollowActionButton(
                      userId: profile.id,
                      username: profile.handle,
                      isFollowing: isFollowing,
                    ),
                ],
              ),
            ),
          ],
        ),

        // Back button on top of banner
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 12,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),

        // Overlapping Avatar
        Positioned(
          top: bannerHeight - (avatarSize / 2),
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: AppColors.background,
                shape: BoxShape.circle,
              ),
              child: UserAvatarWidget(
                avatarType: profile.avatarType,
                avatarValue: profile.effectiveAvatarValue,
                avatarId: profile.avatarId,
                size: avatarSize,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _defaultGradient() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF7C5CFC),
            Color(0xFF0D0F17),
          ],
        ),
      ),
    );
  }
}

class _FollowCounterPill extends StatelessWidget {
  const _FollowCounterPill({
    required this.label,
    required this.count,
    required this.onTap,
  });

  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$count',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FollowActionButton extends ConsumerWidget {
  const _FollowActionButton({
    required this.userId,
    required this.username,
    required this.isFollowing,
  });

  final String userId;
  final String username;
  final bool isFollowing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isFollowing) {
      return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          backgroundColor: const Color(0xFF232938),
          side: const BorderSide(color: Color(0xFF333D52), width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        onPressed: () => _confirmUnfollow(context, ref),
        icon: const Icon(
          Icons.check_rounded,
          size: 18,
          color: AppColors.textSecondary,
        ),
        label: const Text(
          'A Seguir',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      );
    }

    return FilledButton.icon(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
        backgroundColor: const Color(0xFF7C5CFC),
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      onPressed: () {
        ref.read(socialActionsProvider).followUser(userId);
      },
      icon: const Icon(Icons.person_add_rounded, size: 18, color: Colors.white),
      label: const Text(
        'Seguir',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  void _confirmUnfollow(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Deixar de seguir $username?',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Vais deixar de ver a atividade e atualizações de $username no Seriolab.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              Navigator.pop(dlgCtx);
              ref.read(socialActionsProvider).unfollowUser(userId);
            },
            child: const Text('Deixar de Seguir'),
          ),
        ],
      ),
    );
  }
}

class _RecentRatingCard extends StatelessWidget {
  const _RecentRatingCard({required this.rating});

  final UserShowRating rating;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ShowDetailScreen(showId: rating.showId),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.outline),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 44,
                height: 66,
                child: rating.posterUrl != null
                    ? AppNetworkImage(
                        imageUrl: rating.posterUrl,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        color: AppColors.surfaceHigh,
                        child: const Icon(Icons.tv_rounded, color: AppColors.textMuted),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rating.showTitle,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 16,
                        color: Color(0xFF38BDF8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        rating.rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
