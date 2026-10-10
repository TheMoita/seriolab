import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../../shows/domain/entities/show.dart';
import '../../../shows/presentation/providers/show_providers.dart';
import '../../../shows/presentation/screens/show_detail_screen.dart';
import '../../domain/entities/tracking_entities.dart';
import '../providers/tracking_providers.dart';

/// Renders the user's top 5 favorite TV series in a sleek horizontal row
/// with ranks (1 to 5), empty slot addition, and long-press management.
class TopFavoritesSection extends ConsumerWidget {
  const TopFavoritesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final favoriteIds = settings.favoriteShowIds;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TOP 5 FAVORITES',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: AppColors.textMuted,
                ),
              ),
              Text(
                '${favoriteIds.length}/5 selecionadas',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 5 slots layout
          LayoutBuilder(
            builder: (context, constraints) {
              const count = 5;
              const spacing = 8.0;
              final totalSpacing = spacing * (count - 1);
              final cardWidth = (constraints.maxWidth - totalSpacing) / count;
              final cardHeight = cardWidth * 1.5; // Aspect ratio 2:3

              return Row(
                children: List.generate(count, (index) {
                  final hasShow = index < favoriteIds.length;
                  final showId = hasShow ? favoriteIds[index] : null;

                  return Padding(
                    padding: EdgeInsets.only(
                      right: index < count - 1 ? spacing : 0,
                    ),
                    child: SizedBox(
                      width: cardWidth,
                      height: cardHeight,
                      child: hasShow
                          ? _FavoriteSlotTile(
                              rank: index + 1,
                              showId: showId!,
                              onLongPress: () => _showManageFavoriteSheet(
                                context,
                                ref,
                                showId,
                                index,
                              ),
                            )
                          : _EmptySlotTile(
                              rank: index + 1,
                              onTap: () =>
                                  _openAddFavoriteSheet(context, targetSlot: index),
                            ),
                    ),
                  );
                }),
              );
            },
          ),
          if (favoriteIds.isEmpty) ...[
            const SizedBox(height: 10),
            const Center(
              child: Text(
                'Ainda não selecionaste as tuas séries favoritas',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openAddFavoriteSheet(BuildContext context, {int? targetSlot}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddFavoriteShowSheet(targetSlot: targetSlot),
    );
  }

  void _showManageFavoriteSheet(
    BuildContext context,
    WidgetRef ref,
    int showId,
    int index,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '#${index + 1}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Opções de Favorito',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(modalCtx),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(
                    Icons.open_in_new_rounded,
                    color: AppColors.secondary,
                  ),
                  title: const Text('Ver Detalhes da Série'),
                  onTap: () {
                    Navigator.pop(modalCtx);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ShowDetailScreen(showId: showId),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.swap_vert_rounded,
                    color: AppColors.secondary,
                  ),
                  title: const Text('Mudar Posição / Reordenar'),
                  subtitle: const Text('Mover para outro slot (1 a 5)'),
                  onTap: () {
                    Navigator.pop(modalCtx);
                    _showReorderDialog(context, ref, index);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.swap_horiz_rounded,
                    color: AppColors.primary,
                  ),
                  title: const Text('Substituir por outra série'),
                  onTap: () {
                    Navigator.pop(modalCtx);
                    _openAddFavoriteSheet(context, targetSlot: index);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.danger,
                  ),
                  title: const Text(
                    'Remover do Top 5',
                    style: TextStyle(color: AppColors.danger),
                  ),
                  onTap: () {
                    ref
                        .read(settingsControllerProvider.notifier)
                        .removeTopFiveSlot(index);
                    Navigator.pop(modalCtx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Série removida do Top 5.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showReorderDialog(
    BuildContext context,
    WidgetRef ref,
    int currentIndex,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (reorderCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.outline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Text(
                  'Mover para nova posição:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(5, (targetIdx) {
                    final isCurrent = targetIdx == currentIndex;
                    return SizedBox(
                      width: 52,
                      height: 52,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          padding: EdgeInsets.zero,
                          backgroundColor: isCurrent
                              ? AppColors.primary
                              : AppColors.surfaceHigh,
                          foregroundColor:
                              isCurrent ? Colors.white : AppColors.textPrimary,
                          side: BorderSide(
                            color: isCurrent
                                ? AppColors.primary
                                : AppColors.outline,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: isCurrent
                            ? null
                            : () {
                                Navigator.pop(reorderCtx);
                                ref
                                    .read(settingsControllerProvider.notifier)
                                    .reorderTopFive(currentIndex, targetIdx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Série movida para a posição #${targetIdx + 1}.',
                                    ),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                        child: Text(
                          '#${targetIdx + 1}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isCurrent
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FavoriteSlotTile extends ConsumerWidget {
  const _FavoriteSlotTile({
    required this.rank,
    required this.showId,
    required this.onLongPress,
  });

  final int rank;
  final int showId;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showAsync = ref.watch(showDetailsProvider(showId));

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ShowDetailScreen(showId: showId),
          ),
        );
      },
      onLongPress: onLongPress,
      child: Stack(
        fit: StackFit.expand,
        children: [
          showAsync.when(
            data: (show) => AppNetworkImage(
              imageUrl: show.posterUrl ?? show.backdropUrl,
              fallbackImageUrl: show.backdropUrl,
              title: show.displayTitle(
                showOriginal: ref.watch(
                  settingsControllerProvider.select((s) => s.showOriginalTitles),
                ),
              ),
              fit: BoxFit.cover,
              borderRadius: BorderRadius.circular(10),
            ),
            loading: () => Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            error: (_, _) => Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Icon(Icons.tv_rounded, color: AppColors.textMuted),
              ),
            ),
          ),
          // Subtle border outline
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.outline.withValues(alpha: 0.8),
                width: 0.8,
              ),
            ),
          ),
          // Discreet Rank Badge in Top-Left Corner
          Positioned(
            top: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.8),
                  width: 0.8,
                ),
              ),
              child: Text(
                '$rank',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySlotTile extends StatelessWidget {
  const _EmptySlotTile({
    required this.rank,
    required this.onTap,
  });

  final int rank;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedRRectPainter(
          color: AppColors.outline,
          strokeWidth: 1.2,
          radius: 10,
          dashPattern: const [4, 4],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.15),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '#$rank',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Modal allowing selection of a show to add to Top 5 or a specific slot.
class _AddFavoriteShowSheet extends ConsumerStatefulWidget {
  const _AddFavoriteShowSheet({this.targetSlot});

  final int? targetSlot;

  @override
  ConsumerState<_AddFavoriteShowSheet> createState() =>
      _AddFavoriteShowSheetState();
}

class _AddFavoriteShowSheetState extends ConsumerState<_AddFavoriteShowSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSelectShow(int showId) {
    if (widget.targetSlot != null) {
      ref
          .read(settingsControllerProvider.notifier)
          .setTopFiveSlot(widget.targetSlot!, showId);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Série colocada na posição #${widget.targetSlot! + 1} do Top 5.',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ref.read(settingsControllerProvider.notifier).addFavoriteShow(showId);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final trackingState = ref.watch(trackingControllerProvider).value;
    final trendingAsync = ref.watch(trendingShowsProvider);
    final settings = ref.watch(settingsControllerProvider);

    final trackedShows = trackingState?.shows.values.toList() ?? [];
    final currentFavorites = settings.favoriteShowIds;

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AppColors.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.targetSlot != null
                      ? 'Escolher para o Top 5 (#${widget.targetSlot! + 1})'
                      : 'Adicionar aos Favoritos',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  color: AppColors.textSecondary,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Search box
            TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _query = val.trim()),
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Pesquisar série...',
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.textMuted, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
            const SizedBox(height: 14),

            // Results List
            Expanded(
              child: _query.isNotEmpty
                  ? _buildSearchResults(context, ref, currentFavorites)
                  : _buildSuggestedList(
                      context,
                      ref,
                      trackedShows,
                      trendingAsync.value ?? [],
                      currentFavorites,
                      settings.favoritedShowIds,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(
    BuildContext context,
    WidgetRef ref,
    List<int> currentFavorites,
  ) {
    final searchAsync = ref.watch(searchShowsProvider(_query));

    return searchAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (e, _) => Center(
        child: Text(
          'Erro ao pesquisar: $e',
          style: const TextStyle(color: AppColors.danger),
        ),
      ),
      data: (shows) {
        if (shows.isEmpty) {
          return const Center(
            child: Text(
              'Nenhuma série encontrada.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          );
        }
        return ListView.separated(
          itemCount: shows.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final show = shows[index];
            final isAlreadyFavorite = currentFavorites.contains(show.id);
            final showOriginal = ref.watch(
              settingsControllerProvider.select((s) => s.showOriginalTitles),
            );
            final title = show.displayTitle(showOriginal: showOriginal);

            return ListTile(
              leading: AppNetworkImage(
                imageUrl: show.posterUrl ?? show.backdropUrl,
                fallbackImageUrl: show.backdropUrl,
                title: title,
                width: 36,
                height: 52,
                borderRadius: BorderRadius.circular(6),
              ),
              title: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: Text(
                '${show.year ?? ''} • ${show.rating > 0 ? '${show.rating.toStringAsFixed(1)} ★' : ''}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
              trailing: isAlreadyFavorite
                  ? const Chip(
                      label: Text('No Top 5',
                          style: TextStyle(
                              fontSize: 10, color: AppColors.secondary)),
                    )
                  : FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => _onSelectShow(show.id),
                      child: Text(
                        widget.targetSlot != null ? 'Escolher' : 'Adicionar',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
            );
          },
        );
      },
    );
  }

  Widget _buildSuggestedList(
    BuildContext context,
    WidgetRef ref,
    List<TrackedShow> tracked,
    List<ShowSummary> trending,
    List<int> currentFavorites,
    List<int> favoritedShowIds,
  ) {
    return ListView(
      children: [
        // 1. User's Favorited Series (Heart icon)
        if (favoritedShowIds.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text(
              'AS TUAS SÉRIES FAVORITAS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
                letterSpacing: 1.1,
              ),
            ),
          ),
          ...favoritedShowIds.map((favId) {
            final isAlreadyFavorite = currentFavorites.contains(favId);
            return Consumer(
              builder: (ctx, ref, _) {
                final showAsync = ref.watch(showDetailsProvider(favId));
                return showAsync.when(
                  data: (show) {
                    final showOriginal = ref.watch(
                      settingsControllerProvider
                          .select((s) => s.showOriginalTitles),
                    );
                    final title = show.displayTitle(showOriginal: showOriginal);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: AppNetworkImage(
                        imageUrl: show.posterUrl ?? show.backdropUrl,
                        fallbackImageUrl: show.backdropUrl,
                        title: title,
                        width: 36,
                        height: 52,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      title: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        '${show.year ?? ''} • Favorita ❤️',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                      trailing: isAlreadyFavorite
                          ? const Text(
                              'No Top 5',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.secondary,
                              ),
                            )
                          : FilledButton(
                              onPressed: () => _onSelectShow(show.id),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                visualDensity: VisualDensity.compact,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                widget.targetSlot != null
                                    ? 'Escolher'
                                    : 'Adicionar',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                );
              },
            );
          }),
          const SizedBox(height: 12),
        ],

        // 2. User's Tracked Series (Completed / Watching)
        if (tracked.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text(
              'SÉRIES NA TUA LISTA',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.textMuted,
                letterSpacing: 1.1,
              ),
            ),
          ),
          ...tracked.map((trackedShow) {
            final isAlreadyFavorite =
                currentFavorites.contains(trackedShow.showId);
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: AppNetworkImage(
                imageUrl: trackedShow.posterUrl,
                title: trackedShow.name,
                width: 36,
                height: 52,
                borderRadius: BorderRadius.circular(6),
              ),
              title: Text(
                trackedShow.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: Text(
                trackedShow.status.label,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
              trailing: isAlreadyFavorite
                  ? const Text(
                      'No Top 5',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.secondary,
                      ),
                    )
                  : FilledButton(
                      onPressed: () => _onSelectShow(trackedShow.showId),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        widget.targetSlot != null ? 'Escolher' : 'Adicionar',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
            );
          }),
          const SizedBox(height: 12),
        ],

        // 3. Trending Suggestions
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Text(
            'SUGESTÕES POPULARES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.textMuted,
              letterSpacing: 1.1,
            ),
          ),
        ),
        ...trending.map((show) {
          final isAlreadyFavorite = currentFavorites.contains(show.id);
          final showOriginal = ref.watch(
            settingsControllerProvider.select((s) => s.showOriginalTitles),
          );
          final title = show.displayTitle(showOriginal: showOriginal);
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: AppNetworkImage(
              imageUrl: show.posterUrl ?? show.backdropUrl,
              fallbackImageUrl: show.backdropUrl,
              title: title,
              width: 36,
              height: 52,
              borderRadius: BorderRadius.circular(6),
            ),
            title: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            subtitle: Text(
              '${show.year ?? ''} • ${show.rating.toStringAsFixed(1)} ★',
              style:
                  const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            trailing: isAlreadyFavorite
                ? const Text(
                    'No Top 5',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondary,
                    ),
                  )
                : FilledButton(
                    onPressed: () => _onSelectShow(show.id),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      widget.targetSlot != null ? 'Escolher' : 'Adicionar',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
          );
        }),
      ],
    );
  }
}

/// Custom painter for dotted/dashed rounded rectangles.
class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter({
    required this.color,
    required this.strokeWidth,
    required this.radius,
    required this.dashPattern,
  });

  final Color color;
  final double strokeWidth;
  final double radius;
  final List<double> dashPattern;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    final dashedPath = _createDashedPath(path, dashPattern);
    canvas.drawPath(dashedPath, paint);
  }

  Path _createDashedPath(Path source, List<double> pattern) {
    final dest = Path();
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      var patternIndex = 0;
      while (distance < metric.length) {
        final length = pattern[patternIndex % pattern.length];
        if (patternIndex % 2 == 0) {
          dest.addPath(
            metric.extractPath(distance, distance + length),
            Offset.zero,
          );
        }
        distance += length;
        patternIndex++;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(_DashedRRectPainter oldDelegate) =>
      color != oldDelegate.color ||
      strokeWidth != oldDelegate.strokeWidth ||
      radius != oldDelegate.radius;
}
