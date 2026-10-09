import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../domain/entities/genre.dart';
import '../providers/show_providers.dart';
import '../widgets/show_card.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final TextEditingController _searchController = TextEditingController();

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
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                ref.read(searchQueryProvider.notifier).setQuery(val);
              },
              decoration: InputDecoration(
                hintText: 'Pesquisar séries, anime, criadores...',
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
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surfaceHigh,
        onRefresh: () async {
          ref.invalidate(trendingShowsProvider);
          ref.invalidate(exploreShowsProvider);
        },
        child: CustomScrollView(
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
                      child: CircularProgressIndicator(color: AppColors.primary),
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
                  child: CircularProgressIndicator(color: AppColors.primary),
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
        ),
      ),
    );
  }
}
