import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/modal_drag_handle.dart';
import '../../../../core/widgets/seriolab_loader.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../../shows/domain/entities/show.dart';
import '../../../shows/presentation/providers/show_providers.dart';

/// Modal bottom sheet allowing users to search any TMDB series, inspect its
/// high-resolution official backdrops/wallpapers, and set one as their profile banner.
class SeriesBackdropPickerSheet extends ConsumerStatefulWidget {
  const SeriesBackdropPickerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: false,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const SeriesBackdropPickerSheet(),
    );
  }

  @override
  ConsumerState<SeriesBackdropPickerSheet> createState() =>
      _SeriesBackdropPickerSheetState();
}

class _SeriesBackdropPickerSheetState
    extends ConsumerState<SeriesBackdropPickerSheet> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _query = '';
  ShowSummary? _selectedShow;
  List<ShowSummary> _searchResults = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      final trimmed = value.trim();
      setState(() {
        _query = trimmed;
      });
      if (trimmed.isNotEmpty) {
        _performSearch(trimmed);
      } else {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isSearching = true);
    try {
      final repo = ref.read(showRepositoryProvider);
      final results = await repo.search(query);
      if (mounted && _query == query) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _selectBackdrop(String url) async {
    await ref.read(settingsControllerProvider.notifier).setProfileBannerUrl(url);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.secondary, size: 20),
            SizedBox(width: 10),
            Text('Banner do perfil atualizado com sucesso!'),
          ],
        ),
        backgroundColor: AppColors.surfaceHigh,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.outline),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final sheetHeight = mediaQuery.size.height * 0.88;
    final popularAsync = ref.watch(popularThisWeekProvider);
    final settings = ref.watch(settingsControllerProvider);

    return SizedBox(
      height: sheetHeight,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const ModalDragHandle(topPadding: 12, bottomPadding: 4),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 12, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.movie_filter_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Escolher Backdrop de Série',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Wallpapers oficiais do catálogo TMDB em alta resolução',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.outline),

            // Content: Either Show Selection or Backdrop Grid
            Expanded(
              child: _selectedShow == null
                  ? _buildShowSelection(popularAsync)
                  : _buildBackdropGallery(_selectedShow!, settings.profileBannerUrl),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShowSelection(AsyncValue<List<ShowSummary>> popularAsync) {
    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.outline),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Pesquisar série (ex: Severance, Breaking Bad...)',
                hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
        ),

        // List of Results / Suggestions
        Expanded(
          child: _isSearching
              ? const Center(
                  child: SeriolabLoader(size: 40),
                )
              : _query.isNotEmpty
                  ? _buildSearchResults()
                  : _buildPopularSuggestions(popularAsync),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.search_off_rounded,
                size: 48,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: 12),
              Text(
                'Nenhuma série encontrada para "$_query"',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Tenta outro título em português ou inglês.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _searchResults.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final show = _searchResults[index];
        return _buildShowTile(show);
      },
    );
  }

  Widget _buildPopularSuggestions(AsyncValue<List<ShowSummary>> popularAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Row(
            children: [
              Icon(Icons.trending_up_rounded, size: 16, color: AppColors.secondary),
              SizedBox(width: 8),
              Text(
                'Séries Populares no Seriolab',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: popularAsync.when(
            loading: () => const Center(
              child: SeriolabLoader(size: 40),
            ),
            error: (err, _) => Center(
              child: Text(
                'Pesquisa uma série no campo acima.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ),
            data: (shows) {
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                itemCount: shows.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  return _buildShowTile(shows[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildShowTile(ShowSummary show) {
    return Material(
      color: AppColors.surfaceHigh.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            _selectedShow = show;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 48,
                  height: 68,
                  child: AppNetworkImage(
                    imageUrl: show.posterUrl,
                    fallbackImageUrl: show.backdropUrl,
                    title: show.name,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      show.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (show.year != null) ...[
                          Text(
                            '${show.year}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (show.rating > 0) ...[
                          const Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            show.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackdropGallery(ShowSummary show, String? currentBannerUrl) {
    final backdropsAsync = ref.watch(showBackdropsProvider(show.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Navigation bar back to search
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: () => setState(() => _selectedShow = null),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Outra série'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.secondary,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  show.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Text(
            'Toca num wallpaper para aplicar imediatamente:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ),

        // Backdrops List
        Expanded(
          child: backdropsAsync.when(
            loading: () => const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SeriolabLoader(size: 44),
                  SizedBox(height: 16),
                  Text(
                    'A carregar wallpapers oficiais...',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.broken_image_rounded,
                      size: 44,
                      color: AppColors.danger,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Não foi possível obter wallpapers para ${show.name}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: () => ref.refresh(showBackdropsProvider(show.id)),
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            ),
            data: (backdrops) {
              if (backdrops.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.image_not_supported_rounded,
                          size: 48,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Sem backdrops oficiais disponíveis para esta série.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () => setState(() => _selectedShow = null),
                          child: const Text('Escolher outra série'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Horizontal carousel/grid of backdrops
                  SizedBox(
                    height: 200,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      itemCount: backdrops.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 14),
                      itemBuilder: (context, index) {
                        final url = backdrops[index];
                        final isSelected = url == currentBannerUrl;

                        return GestureDetector(
                          onTap: () => _selectBackdrop(url),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 320,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.outline,
                                width: isSelected ? 3 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: AppColors.primary.withValues(alpha: 0.45),
                                        blurRadius: 12,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(isSelected ? 13 : 15),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CachedNetworkImage(
                                    imageUrl: url,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      color: AppColors.surfaceHigh,
                                      child: const Center(
                                        child: SeriolabLoader(size: 24),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) => Container(
                                      color: AppColors.surfaceHigh,
                                      child: const Icon(
                                        Icons.broken_image_rounded,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ),
                                  // Gradient overlay
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black.withValues(alpha: 0.5),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Resolution badge
                                  Positioned(
                                    top: 10,
                                    left: 10,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.65),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'HD w1280',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    Positioned(
                                      top: 10,
                                      right: 10,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.check_rounded,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  Positioned(
                                    bottom: 10,
                                    left: 12,
                                    right: 12,
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.touch_app_rounded,
                                          size: 13,
                                          color: Colors.white70,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          isSelected ? 'Banner Ativo' : 'Tocar para aplicar',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      '${backdrops.length} wallpapers oficiais disponíveis. Desliza na horizontal para ver todos.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
