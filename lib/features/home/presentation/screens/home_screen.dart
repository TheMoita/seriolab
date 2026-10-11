import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/seriolab_logo.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../../shows/domain/entities/genre.dart';
import '../../../shows/domain/entities/show.dart';
import '../../../shows/presentation/providers/show_providers.dart';
import '../../../shows/presentation/widgets/letterboxd_show_card.dart';

/// Letterboxd-inspired Home screen exclusively dedicated to TV series & anime.
///
/// Visual hierarchy:
/// 1. Minimalist app header with brand & genre quick-filter
/// 2. Featured "POPULAR THIS WEEK" vertical poster grid (2:3 aspect ratio)
/// 3. "JUST PREMIERED / NOVAS TEMPORADAS" horizontal carousel
/// 4. "TOP RATED TV SHOWS" horizontal carousel
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({
    super.key,
    this.onExploreTap,
  });

  final VoidCallback? onExploreTap;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Genre? _selectedGenreFilter;
  bool _showAllPopular = false;

  Future<void> _refresh() async {
    ref.invalidate(popularThisWeekProvider);
    ref.invalidate(justPremieredShowsProvider);
    ref.invalidate(topRatedShowsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider);
    final l10n = AppLocalizations.of(context, settingsLanguage: settings.language);
    final isMockForced = ref.watch(mockFallbackProvider);
    final popularAsync = ref.watch(popularThisWeekProvider);
    final premieredAsync = ref.watch(justPremieredShowsProvider);
    final topRatedAsync = ref.watch(topRatedShowsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            const SeriolabLogo(
              iconSize: 28,
              fontSize: 19,
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: AppColors.outline,
                  width: 0.8,
                ),
              ),
              child: Text(
                l10n.tvShowsBadge,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (widget.onExploreTap != null)
            IconButton(
              icon: const Icon(Icons.search_rounded, color: Colors.white70),
              tooltip: l10n.searchTooltip,
              onPressed: widget.onExploreTap,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            if (isMockForced) ...[
              _buildMockBanner(l10n),
              const SizedBox(height: 12),
            ],

            // Quick Minimalist Genre Filter Bar
            _buildGenreFilterBar(l10n),

            const SizedBox(height: 20),

            // 1. POPULAR THIS WEEK (Main Featured Grid Section)
            _buildPopularThisWeekSection(popularAsync, l10n),

            const SizedBox(height: 32),

            // 2. JUST PREMIERED / NEW SEASONS (Horizontal Carousel)
            _buildHorizontalSection(
              title: l10n.justPremieredAndNewSeasons.toUpperCase(),
              subtitle: l10n.justPremieredSubtitle,
              asyncValue: premieredAsync,
              l10n: l10n,
            ),

            const SizedBox(height: 32),

            // 3. TOP RATED TV SHOWS (Horizontal Carousel)
            _buildHorizontalSection(
              title: l10n.topRated.toUpperCase(),
              subtitle: l10n.topRatedSubtitle,
              asyncValue: topRatedAsync,
              l10n: l10n,
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Minimalist Filter Bar
  // ---------------------------------------------------------------------------

  Widget _buildGenreFilterBar(AppLocalizations l10n) {
    final filters = <({String label, Genre? genre})>[
      (label: l10n.all, genre: null),
      (label: l10n.genreDrama, genre: Genre.drama),
      (label: l10n.genreSciFi, genre: Genre.sciFiFantasy),
      (label: l10n.genreCrime, genre: Genre.crime),
      (label: l10n.genreAnime, genre: Genre.anime),
      (label: l10n.genreComedy, genre: Genre.comedy),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedGenreFilter == f.genre;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(f.label),
              selected: isSelected,
              showCheckmark: false,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
              selectedColor: AppColors.primary,
              backgroundColor: AppColors.surface,
              side: BorderSide(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.outline,
                width: 0.8,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              onSelected: (_) {
                setState(() {
                  _selectedGenreFilter = f.genre;
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section 1: POPULAR THIS WEEK (Letterboxd-style Poster Grid)
  // ---------------------------------------------------------------------------

  Widget _buildPopularThisWeekSection(
    AsyncValue<List<ShowSummary>> asyncValue,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header (Letterboxd Style: sober, tracked uppercase)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.popularThisWeek.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.popularSubtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
            InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () {
                if (widget.onExploreTap != null) {
                  widget.onExploreTap!();
                } else {
                  setState(() {
                    _showAllPopular = !_showAllPopular;
                  });
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _showAllPopular ? l10n.seeLess : l10n.seeAll,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 14,
                      color: AppColors.secondary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 4),
        const Divider(height: 16, color: AppColors.outline),
        const SizedBox(height: 8),

        // Grid Content
        asyncValue.when(
          loading: () => _buildGridSkeleton(),
          error: (err, _) {
            final errStr = err.toString();
            final isMissingKey = errStr.contains('TMDB_API_KEY') ||
                errStr.contains('chave de API do TMDB');
            return EmptyState(
              icon: isMissingKey ? Icons.key_off_rounded : Icons.tv_off_rounded,
              title: isMissingKey
                  ? l10n.tmdbKeyMissingTitle
                  : l10n.failedToLoadPopular,
              message: isMissingKey
                  ? l10n.tmdbKeyMissingMessage
                  : errStr,
              actionLabel: l10n.retry,
              onAction: _refresh,
              secondaryActionLabel: isMissingKey
                  ? l10n.enableDemoMode
                  : null,
              onSecondaryAction: isMissingKey
                  ? () {
                      ref.read(mockFallbackProvider.notifier).enableMock();
                      _refresh();
                    }
                  : null,
            );
          },
          data: (shows) {
            final filtered = _selectedGenreFilter == null
                ? shows
                : shows
                    .where((s) => s.matchesGenre(_selectedGenreFilter!))
                    .toList();

            if (filtered.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    l10n.noShowsForGenre,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              );
            }

            final displayShows = _showAllPopular
                ? filtered
                : filtered.take(6).toList();

            return LayoutBuilder(
              builder: (context, constraints) {
                // Responsive column count: 3 on mobile, 4-6 on wider screens
                final width = constraints.maxWidth;
                final crossAxisCount = width > 900
                    ? 6
                    : width > 600
                        ? 4
                        : 3;

                // Child aspect ratio tuned for 2:3 poster + title + year/rating
                const childAspectRatio = 0.52;

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: displayShows.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 16,
                    childAspectRatio: childAspectRatio,
                  ),
                  itemBuilder: (context, index) {
                    final show = displayShows[index];
                    return LetterboxdShowCard(show: show);
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Secondary Horizontal Carousels (Just Premiered & Top Rated)
  // ---------------------------------------------------------------------------

  Widget _buildHorizontalSection({
    required String title,
    required String subtitle,
    required AsyncValue<List<ShowSummary>> asyncValue,
    required AppLocalizations l10n,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
            if (widget.onExploreTap != null)
              InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: widget.onExploreTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.seeAll,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.secondary,
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 14,
                        color: AppColors.secondary,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 4),
        const Divider(height: 16, color: AppColors.outline),
        const SizedBox(height: 8),

        // Carousel Content
        asyncValue.when(
          loading: () => _buildCarouselSkeleton(),
          error: (err, _) {
            final isMissingKey = err.toString().contains('TMDB_API_KEY') ||
                err.toString().contains('chave de API do TMDB');
            return Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.outline),
              ),
              child: Row(
                children: [
                  Icon(
                    isMissingKey
                        ? Icons.key_off_rounded
                        : Icons.error_outline_rounded,
                    color: isMissingKey ? AppColors.primary : AppColors.danger,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isMissingKey
                          ? l10n.waitingTmdbKey
                          : l10n.failedToLoadWithMessage(err.toString()),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _refresh,
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            );
          },
          data: (shows) {
            final filtered = _selectedGenreFilter == null
                ? shows
                : shows
                    .where((s) => s.matchesGenre(_selectedGenreFilter!))
                    .toList();

            if (filtered.isEmpty) {
              return SizedBox(
                height: 120,
                child: Center(
                  child: Text(
                    l10n.noShowsFound,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              );
            }

            return SizedBox(
              height: 236,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: filtered.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final show = filtered[index];
                  return LetterboxdShowCard(
                    show: show,
                    width: 115,
                    compact: true,
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Skeletons
  // ---------------------------------------------------------------------------

  Widget _buildGridSkeleton() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
        childAspectRatio: 0.52,
      ),
      itemBuilder: (context, index) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 2 / 3,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 12,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 10,
            width: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarouselSkeleton() {
    return SizedBox(
      height: 236,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 5,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) => SizedBox(
          width: 115,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 2 / 3,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 12,
                width: 90,
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMockBanner(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.science_outlined,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.demoModeActive,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(mockFallbackProvider.notifier).disableMock();
              _refresh();
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              l10n.tryLiveApi,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.secondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
