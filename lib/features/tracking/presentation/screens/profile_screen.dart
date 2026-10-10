import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../settings/presentation/widgets/edit_profile_sheet.dart';
import '../../../shows/presentation/providers/show_providers.dart';
import '../../../shows/presentation/screens/show_detail_screen.dart';
import '../../domain/entities/tracking_entities.dart';
import '../providers/tracking_providers.dart';
import '../widgets/profile_banner_header.dart';
import '../widgets/ratings_breakdown_section.dart';
import '../widgets/top_favorites_section.dart';
import '../../../social/presentation/widgets/follow_list_sheet.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, this.onExploreTap});

  final VoidCallback? onExploreTap;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: TrackingStatus.values.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trackingAsync = ref.watch(trackingControllerProvider);
    final stats = ref.watch(userStatsProvider);
    final settings = ref.watch(settingsControllerProvider);
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('O Meu Perfil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.textPrimary),
            tooltip: 'Definições',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: trackingAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, _) => EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Erro ao carregar perfil',
          message: err.toString(),
          actionLabel: 'Tentar novamente',
          onAction: () => ref.refresh(trackingControllerProvider),
        ),
        data: (trackingState) {
          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                // Profile Header, Favorites & Ratings
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Top Customizable Banner & Overlapping Avatar
                        ProfileBannerHeader(settings: settings),
                        const SizedBox(height: 12),

                        // User Profile Header Info
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                settings.displayName,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '@${settings.username}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.secondary,
                                ),
                              ),
                              if (authState.user != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      authState.user!.provider ==
                                              AuthProviderKind.google
                                          ? Icons.account_circle_outlined
                                          : Icons.mail_outline_rounded,
                                      size: 13,
                                      color: AppColors.textMuted,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      authState.user!.email,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textMuted,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (settings.bio.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 24),
                                  child: Text(
                                    settings.bio,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ] else ...[
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () => EditProfileSheet.show(context),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.add_circle_outline_rounded,
                                          size: 13,
                                          color: AppColors.textMuted.withValues(alpha: 0.8),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          'Adicionar biografia',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.textMuted.withValues(alpha: 0.8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 14),

                              // Social Follow / Followers Counters
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () {
                                      FollowListSheet.show(
                                        context,
                                        userId: authState.user?.uid ?? 'current_user',
                                        username: settings.username,
                                        initialIndex: 0,
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${settings.followingCount}',
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(width: 5),
                                          const Text(
                                            'A Seguir',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 8),
                                    width: 4,
                                    height: 4,
                                    decoration: const BoxDecoration(
                                      color: AppColors.textMuted,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () {
                                      FollowListSheet.show(
                                        context,
                                        userId: authState.user?.uid ?? 'current_user',
                                        username: settings.username,
                                        initialIndex: 1,
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${settings.followersCount}',
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(width: 5),
                                          const Text(
                                            'Seguidores',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Stats Dashboard Metrics
                              if (stats != null) ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: _MetricCard(
                                        icon: Icons.timer_outlined,
                                        label: 'Tempo Gasto',
                                        value: Formatters.watchTime(stats.minutesWatched),
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _MetricCard(
                                        icon: Icons.done_all_rounded,
                                        label: 'Episódios',
                                        value: '${stats.episodesWatched}',
                                        color: AppColors.secondary,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _MetricCard(
                                        icon: Icons.tv_rounded,
                                        label: 'Séries',
                                        value: '${stats.totalShows}',
                                        color: AppColors.success,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Top 5 Favorites Section
                        const TopFavoritesSection(),
                        const SizedBox(height: 24),

                        // Letterboxd-Style Ratings Breakdown
                        const RatingsBreakdownSection(),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),

                // Status Tabs
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverTabBarDelegate(
                    TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      labelColor: AppColors.primary,
                      unselectedLabelColor: AppColors.textSecondary,
                      indicatorColor: AppColors.primary,
                      indicatorWeight: 3,
                      dividerColor: AppColors.outline,
                      tabs: TrackingStatus.values.map((status) {
                        final count = trackingState.byStatus(status).length;
                        return Tab(
                          child: Row(
                            children: [
                              Icon(status.icon, size: 16),
                              const SizedBox(width: 6),
                              Text('${status.label} ($count)'),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: TrackingStatus.values.map((status) {
                final shows = trackingState.byStatus(status);
                if (shows.isEmpty) {
                  return EmptyState(
                    icon: status.icon,
                    title: 'Nenhuma série em "${status.label}"',
                    message:
                        'Descobre novas séries no separador Explorar para adicionar a esta lista.',
                    actionLabel: 'Explorar séries',
                    onAction: widget.onExploreTap,
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  itemCount: shows.length,
                  itemBuilder: (context, idx) {
                    final tracked = shows[idx];
                    return _TrackedShowTile(
                      tracked: tracked,
                      status: status,
                    );
                  },
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline, width: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackedShowTile extends ConsumerWidget {
  const _TrackedShowTile({
    required this.tracked,
    required this.status,
  });

  final TrackedShow tracked;
  final TrackingStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackingState = ref.watch(trackingControllerProvider).value;
    final progress = trackingState?.progress(tracked.showId) ?? 0.0;
    final watchedCount = trackingState?.watchedRegularCount(tracked.showId) ?? 0;
    final totalEpisodes = tracked.airedEpisodeCount;

    final nextAsync = ref.watch(showWithEpisodesProvider(tracked.showId));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline, width: 0.6),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ShowDetailScreen(showId: tracked.showId),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Poster
                  AppNetworkImage(
                    imageUrl: tracked.posterUrl,
                    title: tracked.name,
                    width: 58,
                    height: 86,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  const SizedBox(width: 14),
                  // Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                tracked.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            if (tracked.network != null)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceHigh,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: AppColors.outline,
                                    width: 0.6,
                                  ),
                                ),
                                child: Text(
                                  tracked.network!,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Watched count & percent
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              totalEpisodes > 0
                                  ? '$watchedCount / $totalEpisodes episódios'
                                  : '$watchedCount episódios vistos',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (totalEpisodes > 0)
                              Text(
                                Formatters.percent(progress),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.secondary,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Progress Bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: totalEpisodes > 0 ? progress : 0,
                            minHeight: 6,
                            backgroundColor: AppColors.surfaceHigh,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              progress >= 1.0
                                  ? AppColors.success
                                  : AppColors.secondary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Next Episode info if Watching
                        if (status == TrackingStatus.watching)
                          nextAsync.when(
                            data: (data) {
                              if (trackingState == null) {
                                return const SizedBox.shrink();
                              }
                              final nextEp = nextEpisodeToWatch(
                                data,
                                trackingState,
                                DateTime.now(),
                              );
                              if (nextEp == null) {
                                return Row(
                                  children: [
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      size: 13,
                                      color: AppColors.success,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      tracked.showStatus.isFinished
                                          ? 'Série terminada!'
                                          : 'Em dia com os episódios',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.success,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                );
                              }
                              return Row(
                                children: [
                                  const Icon(
                                    Icons.play_circle_outline_rounded,
                                    size: 13,
                                    color: AppColors.secondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'A seguir: ${nextEp.code} • ${nextEp.name}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.secondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                            loading: () => const SizedBox.shrink(),
                            error: (_, _) => const SizedBox.shrink(),
                          ),
                      ],
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
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverTabBarDelegate(this.tabBar);

  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: AppColors.background,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}
