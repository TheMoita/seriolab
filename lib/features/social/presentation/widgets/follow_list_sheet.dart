import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../settings/presentation/widgets/user_avatar_widget.dart';
import '../../domain/entities/user_profile.dart';
import '../providers/social_providers.dart';
import '../screens/user_profile_screen.dart';

/// Modal bottom sheet displaying Followers and Following tabs for a user.
class FollowListSheet extends ConsumerStatefulWidget {
  const FollowListSheet({
    super.key,
    required this.userId,
    required this.username,
    this.initialIndex = 0,
  });

  final String userId;
  final String username;
  final int initialIndex;

  static Future<void> show(
    BuildContext context, {
    required String userId,
    required String username,
    int initialIndex = 0,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => FollowListSheet(
        userId: userId,
        username: username,
        initialIndex: initialIndex,
      ),
    );
  }

  @override
  ConsumerState<FollowListSheet> createState() => _FollowListSheetState();
}

class _FollowListSheetState extends ConsumerState<FollowListSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialIndex.clamp(0, 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final followingAsync = ref.watch(userFollowingProvider(widget.userId));
    final followersAsync = ref.watch(userFollowersProvider(widget.userId));

    final cleanUsername =
        widget.username.startsWith('@') ? widget.username : '@${widget.username}';

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            // Handle bar
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      cleanUsername,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Tabs
            TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textMuted,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
              tabs: [
                Tab(
                  text: followingAsync.maybeWhen(
                    data: (list) => 'A Seguir (${list.length})',
                    orElse: () => 'A Seguir',
                  ),
                ),
                Tab(
                  text: followersAsync.maybeWhen(
                    data: (list) => 'Seguidores (${list.length})',
                    orElse: () => 'Seguidores',
                  ),
                ),
              ],
            ),
            const Divider(height: 1),

            // Tab contents
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Following
                  followingAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                    error: (err, _) => Center(
                      child: Text('Erro: $err', style: const TextStyle(color: AppColors.danger)),
                    ),
                    data: (list) {
                      if (list.isEmpty) {
                        return const Center(
                          child: EmptyState(
                            icon: Icons.person_search_rounded,
                            title: 'Ainda não segue ninguém',
                            message: 'Descobre novos utilizadores no separador Explorar.',
                          ),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const Divider(
                          indent: 72,
                          color: AppColors.surfaceHigh,
                          height: 1,
                        ),
                        itemBuilder: (context, index) {
                          return _UserTile(user: list[index]);
                        },
                      );
                    },
                  ),

                  // Tab 2: Followers
                  followersAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                    error: (err, _) => Center(
                      child: Text('Erro: $err', style: const TextStyle(color: AppColors.danger)),
                    ),
                    data: (list) {
                      if (list.isEmpty) {
                        return const Center(
                          child: EmptyState(
                            icon: Icons.people_outline_rounded,
                            title: 'Ainda sem seguidores',
                            message: 'Partilha a tua paixão por séries para ganhar seguidores!',
                          ),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const Divider(
                          indent: 72,
                          color: AppColors.surfaceHigh,
                          height: 1,
                        ),
                        itemBuilder: (context, index) {
                          return _UserTile(user: list[index]);
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserTile extends ConsumerWidget {
  const _UserTile({required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFollowing = ref.watch(isFollowingUserProvider(user.id));

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: UserAvatarWidget(
        avatarType: user.avatarType,
        avatarValue: user.effectiveAvatarValue,
        avatarId: user.avatarId,
        size: 46,
      ),
      title: Text(
        user.displayName,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        user.handle,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.secondary,
        ),
      ),
      trailing: user.isCurrentUser
          ? null
          : _FollowButton(
              userId: user.id,
              isFollowing: isFollowing,
              username: user.handle,
            ),
      onTap: () {
        Navigator.pop(context); // Close sheet
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => UserProfileScreen(userId: user.id),
          ),
        );
      },
    );
  }
}

class _FollowButton extends ConsumerWidget {
  const _FollowButton({
    required this.userId,
    required this.isFollowing,
    required this.username,
  });

  final String userId;
  final bool isFollowing;
  final String username;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isFollowing) {
      return OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          backgroundColor: const Color(0xFF232938),
          side: const BorderSide(color: Color(0xFF333D52), width: 1.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        onPressed: () => _confirmUnfollow(context, ref),
        child: const Text(
          'A Seguir',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return FilledButton(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        backgroundColor: const Color(0xFF7C5CFC),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      onPressed: () {
        ref.read(socialActionsProvider).followUser(userId);
      },
      child: const Text(
        'Seguir',
        style: TextStyle(
          fontSize: 12,
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
          'Vais deixar de ver a atividade e as séries avaliadas por $username.',
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
