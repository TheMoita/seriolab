import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/seriolab_loader.dart';
import '../../../settings/presentation/widgets/user_avatar_widget.dart';
import '../../../social/domain/entities/user_profile.dart';
import '../../../social/presentation/providers/social_providers.dart';
import '../../../social/presentation/screens/user_profile_screen.dart';
import '../../domain/entities/genre.dart';
import '../providers/show_providers.dart';
import '../widgets/show_card.dart';

enum ExploreTab { shows, users }

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final TextEditingController _searchController = TextEditingController();
  ExploreTab _currentTab = ExploreTab.shows;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trendingAsync = ref.watch(trendingShowsProvider);
    final selectedGenre = ref.watch(selectedGenreProvider);
    final selectedSort = ref.watch(selectedSortProvider);
    final searchQuery = ref.watch(searchQueryProvider);
    final exploreAsync = ref.watch(exploreShowsProvider);

    final isSearching = searchQuery.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Explorar'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(114),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    ref.read(searchQueryProvider.notifier).setQuery(val);
                  },
                  decoration: InputDecoration(
                    hintText: _currentTab == ExploreTab.shows
                        ? 'Pesquisar séries, anime, criadores...'
                        : 'Pesquisar utilizadores por @username ou nome...',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.textSecondary,
                    ),
                    suffixIcon: isSearching
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(searchQueryProvider.notifier).setQuery('');
                            },
                          )
                        : null,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Row(
                  children: [
                    _ExploreTabPill(
                      label: 'Séries',
                      icon: Icons.tv_rounded,
                      isSelected: _currentTab == ExploreTab.shows,
                      onTap: () => setState(() => _currentTab = ExploreTab.shows),
                    ),
                    const SizedBox(width: 8),
                    _ExploreTabPill(
                      label: 'Utilizadores',
                      icon: Icons.people_alt_rounded,
                      isSelected: _currentTab == ExploreTab.users,
                      onTap: () => setState(() => _currentTab = ExploreTab.users),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surfaceHigh,
        onRefresh: () async {
          if (_currentTab == ExploreTab.shows) {
            ref.invalidate(trendingShowsProvider);
            ref.invalidate(exploreShowsProvider);
          } else {
            ref.invalidate(suggestedUsersProvider);
            if (isSearching) {
              ref.invalidate(searchUsersProvider(searchQuery));
            }
          }
        },
        child: _currentTab == ExploreTab.shows
            ? CustomScrollView(
          slivers: [
            // If not searching, show Trending Section
            if (!isSearching) ...[
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.local_fire_department_rounded,
                        color: AppColors.warning,
                        size: 20,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Em Destaque Esta Semana',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 220,
                  child: trendingAsync.when(
                    loading: () => const Center(
                      child: SeriolabLoader(size: 40),
                    ),
                    error: (err, _) {
                      final errStr = err.toString();
                      final isMissingKey = errStr.contains('TMDB_API_KEY') ||
                          errStr.contains('chave de API do TMDB');
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            isMissingKey
                                ? 'Configura TMDB_API_KEY no ficheiro .env para carregar tendências em tempo real.'
                                : 'Erro ao carregar tendências: $err',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isMissingKey
                                  ? AppColors.textSecondary
                                  : AppColors.danger,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    },
                    data: (trending) {
                      if (trending.isEmpty) {
                        return const Center(
                          child: Text('Sem destaques de momento.'),
                        );
                      }
                      return ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: trending.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (context, idx) {
                          return ShowCard(show: trending[idx], width: 110);
                        },
                      );
                    },
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
            ],

            // Filter Bar: Genres Chips + Sort
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isSearching ? 'Resultados da Pesquisa' : 'Catálogo Completo',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        // Sort Dropdown
                        PopupMenuButton<ShowSort>(
                          initialValue: selectedSort,
                          onSelected: (sort) {
                            ref.read(selectedSortProvider.notifier).select(sort);
                          },
                          color: AppColors.surfaceHigh,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: AppColors.outline),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceHigh,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.outline),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.sort_rounded,
                                  size: 14,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  selectedSort.label,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          itemBuilder: (context) => ShowSort.values.map((s) {
                            return PopupMenuItem<ShowSort>(
                              value: s,
                              child: Text(
                                s.label,
                                style: TextStyle(
                                  fontWeight: s == selectedSort
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  color: s == selectedSort
                                      ? AppColors.primary
                                      : AppColors.textPrimary,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  // Genres Filter Horizontal Scroll
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: const Text('Todos'),
                            selected: selectedGenre == null,
                            onSelected: (_) {
                              ref
                                  .read(selectedGenreProvider.notifier)
                                  .select(null);
                            },
                            selectedColor: AppColors.primary,
                            labelStyle: TextStyle(
                              color: selectedGenre == null
                                  ? AppColors.onPrimary
                                  : AppColors.textPrimary,
                              fontWeight: selectedGenre == null
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                        ...Genre.all.map((g) {
                          final isSelected = selectedGenre?.id == g.id;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(g.name),
                              selected: isSelected,
                              onSelected: (_) {
                                ref
                                    .read(selectedGenreProvider.notifier)
                                    .select(isSelected ? null : g);
                              },
                              selectedColor: AppColors.primary,
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? AppColors.onPrimary
                                    : AppColors.textPrimary,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),

            // Explore Shows Grid
            exploreAsync.when(
              loading: () => const SliverFillRemaining(
                child: Center(
                  child: SeriolabLoader(),
                ),
              ),
              error: (err, _) {
                final errStr = err.toString();
                final isMissingKey = errStr.contains('TMDB_API_KEY') ||
                    errStr.contains('chave de API do TMDB');
                return SliverFillRemaining(
                  child: EmptyState(
                    icon: isMissingKey
                        ? Icons.key_off_rounded
                        : Icons.search_off_rounded,
                    title: isMissingKey
                        ? 'Chave TMDB Não Configurada'
                        : 'Erro na pesquisa',
                    message: isMissingKey
                        ? 'Configura a tua TMDB_API_KEY no ficheiro .env na raiz do projeto para pesquisares no catálogo TMDB em tempo real.'
                        : errStr,
                    actionLabel: 'Tentar novamente',
                    onAction: () => ref.refresh(exploreShowsProvider),
                    secondaryActionLabel: isMissingKey
                        ? 'Ativar Modo Demonstração (Mock)'
                        : null,
                    onSecondaryAction: isMissingKey
                        ? () {
                            ref
                                .read(mockFallbackProvider.notifier)
                                .enableMock();
                            ref.invalidate(exploreShowsProvider);
                            ref.invalidate(trendingShowsProvider);
                          }
                        : null,
                  ),
                );
              },
              data: (shows) {
                if (shows.isEmpty) {
                  return SliverFillRemaining(
                    child: EmptyState(
                      icon: Icons.tv_off_rounded,
                      title: 'Nenhuma série encontrada',
                      message: isSearching
                          ? 'Não encontrámos resultados para "$searchQuery". Tenta outro termo ou limpa os filtros.'
                          : 'Não há séries disponíveis para este género.',
                      actionLabel: isSearching ? 'Limpar pesquisa' : 'Ver todas',
                      onAction: () {
                        if (isSearching) {
                          _searchController.clear();
                          ref
                              .read(searchQueryProvider.notifier)
                              .setQuery('');
                        }
                        ref
                            .read(selectedGenreProvider.notifier)
                            .select(null);
                      },
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.48,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 16,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return ShowCard(show: shows[index]);
                      },
                      childCount: shows.length,
                    ),
                  ),
                );
              },
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: 32),
            ),
          ],
        )
            : _buildUsersView(context, isSearching, searchQuery),
      ),
    );
  }

  Widget _buildUsersView(
    BuildContext context,
    bool isSearching,
    String searchQuery,
  ) {
    if (isSearching) {
      final searchAsync = ref.watch(searchUsersProvider(searchQuery));
      return searchAsync.when(
        loading: () => const Center(
          child: SeriolabLoader(),
        ),
        error: (err, _) => Center(
          child: EmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Erro na pesquisa',
            message: err.toString(),
          ),
        ),
        data: (users) {
          if (users.isEmpty) {
            return const Center(
              child: EmptyState(
                icon: Icons.person_search_rounded,
                title: 'Nenhum utilizador encontrado',
                message: 'Tenta pesquisar por outro nome ou @username.',
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            itemCount: users.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return _UserExploreTile(user: users[index]);
            },
          );
        },
      );
    }

    final suggestedAsync = ref.watch(suggestedUsersProvider);
    return suggestedAsync.when(
      loading: () => const Center(
        child: SeriolabLoader(),
      ),
      error: (err, _) => Center(
        child: EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Erro ao carregar comunidade',
          message: err.toString(),
        ),
      ),
      data: (users) {
        return CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.diversity_3_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Comunidade & Sugestões para Seguir',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (users.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: EmptyState(
                    icon: Icons.check_circle_outline_rounded,
                    title: 'Estás a par de tudo!',
                    message:
                        'Já segues todos os utilizadores sugeridos da comunidade.',
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _UserExploreTile(user: users[index]),
                      );
                    },
                    childCount: users.length,
                  ),
                ),
              ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 32),
            ),
          ],
        );
      },
    );
  }
}

class _ExploreTabPill extends StatelessWidget {
  const _ExploreTabPill({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.outline,
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserExploreTile extends ConsumerWidget {
  const _UserExploreTile({required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFollowing = ref.watch(isFollowingUserProvider(user.id));

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => UserProfileScreen(userId: user.id),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outline),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UserAvatarWidget(
              avatarType: user.avatarType,
              avatarValue: user.effectiveAvatarValue,
              avatarId: user.avatarId,
              size: 48,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.handle,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.secondary,
                    ),
                  ),
                  if (user.bio.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      user.bio,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    '${user.followersCount} seguidores • ${user.topFiveFavorites.length} favoritos',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (!user.isCurrentUser)
              _ExploreFollowButton(
                userId: user.id,
                username: user.handle,
                isFollowing: isFollowing,
              ),
          ],
        ),
      ),
    );
  }
}

class _ExploreFollowButton extends ConsumerWidget {
  const _ExploreFollowButton({
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
      return OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          backgroundColor: const Color(0xFF232938),
          side: const BorderSide(color: Color(0xFF333D52), width: 1.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        backgroundColor: const Color(0xFF7C5CFC),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
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
          'Vais deixar de ver as séries e atualizações de $username.',
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
